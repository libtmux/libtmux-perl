use v5.44;
use FindBin;
use lib "$FindBin::Bin/../local/lib/perl5", "$FindBin::Bin/lib";
use LibTmuxDev qw(perl_files directory_problems);
use Pod::Simple::SimpleTree;
use Test::Pod 1.52;
use Test2::V1;
chdir "$FindBin::Bin/.." or die $!;
my (%targets, @links);
my $failed = 0;

sub plain ($node) {
    return $node unless ref $node;
    return join '', map { plain($_) } @{$node}[2 .. $#$node];
}

sub walk ($node, $module, $file) {
    return unless ref($node) eq 'ARRAY';
    my ($tag, $attributes, @children) = @$node;
    if ($tag =~ /\A(?:head[1-6]|item)\z/) {
        $targets{$module}{plain($node)} = true;
    }
    if ($tag eq 'L' && ($attributes->{type} // '') eq 'pod') {
        my $to = exists($attributes->{to}) ? plain($attributes->{to}) : $module;
        my $section =
            exists($attributes->{section})
            ? plain($attributes->{section})
            : undef;
        push @links, {module => $to, section => $section, file => $file};
    }
    walk($_, $module, $file) for grep { ref($_) eq 'ARRAY' } @children;
}
for my $file (grep { m!^packages/[^/]+/lib/.*\.pm\z! } perl_files()) {
    (my $module = $file) =~ s!^packages/[^/]+/lib/!!;
    $module              =~ s!\.pm\z!!;
    $module              =~ s!/!::!g;
    $targets{$module} = {};
    $failed = 1 unless pod_file_ok($file, $module);
    my $parser = Pod::Simple::SimpleTree->new;
    $parser->parse_file($file);
    walk($parser->root, $module, $file);
}
for my $link (@links) {
    next unless $link->{module} =~ /\ALibTmux(?:::|\z)/;
    if (
        !exists($targets{$link->{module}})
        || (defined($link->{section})
            && !exists($targets{$link->{module}}{$link->{section}}))
        )
    {
        warn "Unresolved POD target $link->{module}"
            . (defined($link->{section}) ? "/$link->{section}" : '')
            . " in $link->{file}\n";
        $failed = 1;
    }
}
my @directory = directory_problems('packages/core/lib/LibTmux/Server.pm');
warn "$_\n" for @directory;
T2->ok(!@directory, 'LibTmux::Server directory names every method');
$failed = 1 if @directory;
T2->done_testing;
print '# ' . scalar(@links) . " native POD links checked\n" unless $failed;
exit $failed;
