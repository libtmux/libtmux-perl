use v5.44;
use FindBin;
use Test2::V1;
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use JSON::PP   ();

# Run the real exporter over a one-class checkout so the assertions cover the
# Markdown that libtmux.org receives, not an internal helper.
my $source = "$FindBin::Bin/../..";
my $root = tempdir('libtmux-perl-export-test-XXXX', TMPDIR => 1, CLEANUP => 1);

sub put ($path, $text) {
    my $file = "$root/$path";
    $file =~ s!/[^/]+\z!!;
    make_path($file);
    open my $out, '>:raw', "$root/$path" or die "$path: $!";
    print {$out} $text;
    close $out;
}
for my $package (qw(core async workspace)) {
    make_path("$root/packages/$package/lib");
    put("packages/$package/$_", "fixture\n")
        for qw(Makefile.PL cpanfile README.md LICENSE);
}
put("examples/$_.pl", "use v5.44;\n")
    for qw(quickstart selection workspace async await);
make_path("$root/scripts");
copy("$source/scripts/export-api.pl", "$root/scripts/export-api.pl") or die $!;
symlink("$source/local", "$root/local") if -d "$source/local";

put('packages/core/lib/LibTmux/Server.pm', <<"PERL");
package LibTmux::Server;
use v5.44;
sub new (\$class, \%args) { bless {}, \$class }

=head1 NAME

LibTmux::Server - Fixture

=head1 SYNOPSIS

    use v5.44;
    my \$server = LibTmux::Server->new(
        socket_name => 'application',
    );

    say 'after a blank line';

=head1 Deeper first line

            first line is the most indented
        second line is not
    third line sets the common indent

=head1 Tab indented

\tuse v5.44;
\t\tsay 'nested';

=head1 Lists

=over 4

=item Start: C<new>, C<snapshot>

=item Stop: C<kill_server>

=back

=over 4

=item C<policy>, C<status>

Policy is auto.

=item Colon ends the label:

Label keeps its own colon.

=back

=over 4

=item *

First bullet.

=item *

Second bullet.

=back

=over 4

=item 1.

One.

=item 2.

Two.

=back

=head1 METHODS

=head2 new

Create a wrapper.

    my \$server = LibTmux::Server->new;
    \$server->snapshot;

=cut

1;
PERL

my %git = (GIT_CONFIG_GLOBAL => '/dev/null', GIT_CONFIG_NOSYSTEM => 1);
delete local @ENV{grep { /\AGIT_/ } keys %ENV};
local @ENV{keys %git} = values %git;
system('git', '-C', $root, 'init', '--quiet', '--initial-branch=master') == 0
    or die 'git init';
system(
    'git',    '-C', $root, '-c', 'user.name=Export test',
    '-c',     'user.email=test@example.invalid',
    'commit', '--allow-empty', '--quiet', '-m', 'fixture'
) == 0 or die 'git commit';
system($^X, "$root/scripts/export-api.pl", '--allow-dirty', '--output',
    "$root/api.json") == 0
    or die 'export-api.pl failed';
open my $in, '<:raw', "$root/api.json" or die $!;
my $api = JSON::PP->new->utf8->decode(do { local $/; <$in> });
close $in;
my %symbol = map { $_->{id} => $_ } $api->{symbols}->@*;
my $body   = $symbol{'LibTmux::Server'}{doc}{body};

T2->like(
    $body,
qr/```perl\nuse v5\.44;\nmy \$server = LibTmux::Server->new\(\n    socket_name => 'application',\n\);\n\nsay 'after a blank line';\n```/,
    'SYNOPSIS drops the POD indent and keeps the relative indent'
);
T2->like(
    $body,
qr/```perl\n        first line is the most indented\n    second line is not\nthird line sets the common indent\n```/,
    'the least indented line sets the indent, not the first line'
);
T2->like(
    $body,
    qr/```perl\nuse v5\.44;\n        say 'nested';\n```/,
    'a tab counts as eight columns'
);
T2->like(
    $symbol{'LibTmux::Server::new'}{doc}{body},
    qr/```perl\nmy \$server = LibTmux::Server->new;\n\$server->snapshot;\n```/,
    'a method example drops the POD indent'
);
T2->unlike(
    $body,
    qr/^ +use v5\.44;$/m,
    'no exported fence keeps leading POD indent'
);

T2->like(
    $body,
    qr/^- Start: `new`, `snapshot`\n- Stop: `kill_server`\n\n/m,
    'labelled items export as a Markdown list'
);
T2->like(
    $body,
    qr/^- `policy`, `status`: Policy is auto\.$/m,
    'an item with a body joins label and body with a colon'
);
T2->like(
    $body,
    qr/^- Colon ends the label: Label keeps its own colon\.$/m,
    'a label ending in a colon gains no second colon'
);
T2->like(
    $body,
    qr/^- First bullet\.\n- Second bullet\.\n/m,
    'bullet items export as a Markdown list'
);

T2->like(
    $body,
    qr/^1\. One\.\n2\. Two\.\n/m,
    'numbered items export as a numbered Markdown list'
);

T2->done_testing;
