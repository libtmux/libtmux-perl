#!/usr/bin/env perl
use v5.44;
use FindBin;
use File::Path qw(make_path);
use Cwd        qw(abs_path);
use Module::CPANfile;
use CPAN::Meta::Requirements;
use JSON::PP    ();
use Digest::SHA qw(sha256_hex);

my $root = abs_path("$FindBin::Bin/..");
my $json = JSON::PP->new->canonical->pretty;
my ($action, $directory, $selection) = @ARGV;
die "usage: dependency-profile.pl generate DIRECTORY minimum|latest\n"
    . "       dependency-profile.pl check DIRECTORY PREFIX\n"
    unless @ARGV == 3 && $action =~ /\A(?:generate|check)\z/;
my $record = "$directory/profile.json";

sub write_json ($file, $data) {
    open my $out, '>:raw', $file or die "$file: $!";
    print {$out} $json->encode($data);
    close $out or die "$file: $!";
}

if ($action eq 'generate') {
    die 'profile must be minimum or latest'
        unless $selection =~ /\A(?:minimum|latest)\z/;
    my $merged = CPAN::Meta::Requirements->new;
    my (%sources, %internal);
    for my $file ('cpanfile',
        map { "packages/$_/cpanfile" } qw(core async workspace))
    {
        open my $in, '<:raw', "$root/$file" or die "$file: $!";
        $sources{$file} = sha256_hex(do { local $/; <$in> });
        close $in;
        my $prereqs = Module::CPANfile->load("$root/$file")->prereqs;
        for my $phase (qw(configure build runtime test develop)) {
            $merged->add_requirements(
                $prereqs->requirements_for($phase, 'requires'));
        }
    }
    my $declared = $merged->as_string_hash;
    my %selected;
    for my $module (sort keys %$declared) {
        next if $module eq 'perl';
        if ($module =~ /\ALibTmux(?:::\w+)*\z/) {
            $internal{$module} = $declared->{$module};
            next;
        }
        die "invalid dependency module: $module"
            unless $module =~ /\A[A-Za-z_]\w*(?:::\w+)*\z/;
        my $range = $declared->{$module};
        if ($selection eq 'minimum') {
            die
"minimum selector needs an explicit decision for $module: $range"
                unless $range =~ /\A(?:(?:>=|==)\s*)?([v0-9][v0-9._]*)\z/;
            $range = "== $1";
        }
        $selected{$module} = $range;
    }
    make_path($directory);
    open my $out, '>', "$directory/cpanfile" or die $!;
    print {$out} "requires '$_', '$selected{$_}';\n" for sort keys %selected;
    close $out or die $!;
    write_json(
        $record,
        {
            profile      => $selection,
            declared     => $declared,
            selected     => \%selected,
            internal     => \%internal,
            sources      => \%sources,
            generated_at => scalar gmtime,
            scope        =>
'direct requirements; author pins retained; transitive versions resolved by cpm',
        }
    );
    say "Generated $selection dependency profile";
    exit 0;
}

open my $in, '<:raw', $record or die "$record: $!";
my $profile = $json->decode(do { local $/; <$in> });
close $in;
my $prefix = abs_path($selection)
    // die "missing dependency prefix: $selection";
my $requirements =
    CPAN::Meta::Requirements->from_string_hash($profile->{selected});
my (%modules, @failures);
for my $module (sort keys $profile->{selected}->%*) {
    die "invalid dependency module: $module"
        unless $module =~ /\A[A-Za-z_]\w*(?:::\w+)*\z/;
    (my $file = "$module.pm") =~ s!::!/!g;
    try {
        require $file;
        my $version = $module->VERSION;
        my $origin  = abs_path($INC{$file});
        $modules{$module} = {version => "$version", origin => $origin};
        push @failures,
            "$module $version does not satisfy $profile->{selected}{$module}"
            unless $requirements->accepts_module($module, $version);
        push @failures, "$module loaded outside the selected prefix"
            unless index($origin, "$prefix/") == 0;
    }
    catch ($error) { push @failures, "$module could not load: $error" }
}
my $perl_requirement = CPAN::Meta::Requirements->from_string_hash(
    {perl => $profile->{declared}{perl}});
push @failures, 'Perl does not meet the declared minimum'
    unless $perl_requirement->accepts_module(perl => $^V);
write_json(
    "$directory/versions.json",
    {
        profile  => $profile->{profile},
        perl     => "$^V",
        modules  => \%modules,
        failures => \@failures,
        status   => @failures ? 'FAIL' : 'PASS',
    }
);
die join("\n", @failures) . "\n" if @failures;
say "PASS $profile->{profile}: all direct versions and module origins verified";
