package LibTmuxRelease;
use v5.44;
use Archive::Tar;
use CPAN::Meta;
use Digest::SHA ();
use File::Spec;
use JSON::PP ();

sub read_json ($path) {
    open my $in, '<:raw', $path or die "read $path: $!\n";
    return JSON::PP->new->utf8->decode(do { local $/; <$in> });
}

sub plan ($class, %args) {
    my $tag = $args{tag} // '';
    die
"tag must use v followed by a decimal Perl version (for example v0.002)\n"
        unless $tag =~ /\Av([0-9]+\.[0-9]+)\z/;
    my $version = $1;
    my $source  = $args{source} // '';
    die "source must be a full commit SHA\n"
        unless $source =~ /\A[0-9a-f]{40}\z/;
    my $directory = $args{directory} // die "missing archive directory\n";
    my $evidence  = read_json("$directory/evidence.json");
    my $observed  = $evidence->{source} // '';
    $observed =~ s/\s+\z//;
    die "archive source differs from the selected commit\n"
        unless $observed eq $source;
    die "release archives must come from a clean committed source tree\n"
        unless JSON::PP::is_bool($evidence->{clean}) && $evidence->{clean};
    die "installed artifact verification did not pass\n"
        unless ($evidence->{consumer} // '') eq 'PASS';
    die "expected exactly three artifact records\n"
        unless ref($evidence->{artifacts}) eq 'ARRAY'
        && $evidence->{artifacts}->@* == 3;
    my %records;

    for my $record ($evidence->{artifacts}->@*) {
        my $kind = $record->{package} // '';
        die "unknown or duplicate artifact package\n"
            unless $kind =~ /\A(?:core|workspace|async)\z/ && !$records{$kind};
        $records{$kind} = $record;
    }
    opendir my $dir, $directory or die "read archive directory: $!\n";
    my @archives = grep { /\.tar\.gz\z/ } readdir $dir;
    closedir $dir;
    die "expected exactly three native archives\n" unless @archives == 3;
    my @items;
    for my $kind (qw(core workspace async)) {
        my $distribution =
            $kind eq 'core' ? 'LibTmux' : 'LibTmux-' . ucfirst($kind);
        my $name   = "$distribution-$version.tar.gz";
        my $record = $records{$kind} // die "missing $kind artifact\n";
        die "artifact filename does not match the release tag\n"
            unless ($record->{file} // '') eq $name;
        my $path = File::Spec->rel2abs("$directory/$name");
        die "archive must be a regular file\n" unless -f $path && !-l $path;
        open my $in, '<:raw', $path or die "read $name: $!\n";
        my $digest = Digest::SHA->new(256)->addfile($in)->hexdigest;
        close $in;
        die "archive digest differs from installed evidence: $name\n"
            unless ($record->{sha256} // '') eq $digest;
        my $tar  = Archive::Tar->new($path, 1);
        my $root = "$distribution-$version";
        my $meta =
            CPAN::Meta->load_json_string($tar->get_content("$root/META.json"),
            {lazy_validation => 0});
        die "archive metadata does not match tag/name\n"
            unless $meta->name eq $distribution && $meta->version eq $version;
        die "only ordinary indexed releases may be published\n"
            unless $meta->release_status eq 'stable';
        my $provides = $meta->provides;
        my $main = $kind eq 'core' ? 'LibTmux' : 'LibTmux::' . ucfirst($kind);
        die "main module is absent from provides\n" unless $provides->{$main};

        for my $module (keys %$provides) {
            die "provided module version differs from tag: $module\n"
                unless ($provides->{$module}{version} // '') eq $version;
        }
        if ($kind ne 'core') {
            my $requirements =
                $meta->effective_prereqs->requirements_for('runtime',
                'requires');
            my $minimum = $requirements->requirements_for_module('LibTmux');
            die "sibling core requirement must match the release version\n"
                unless defined($minimum) && $minimum eq $version;
        }
        push @items,
            {
            package      => $kind,
            distribution => $distribution,
            file         => $name,
            path         => $path,
            sha256       => $digest
            };
    }
    return {
        schema  => 1,
        tag     => $tag,
        version => $version,
        source  => $source,
        order   => \@items
    };
}

sub upload ($class, $plan, %args) {
    my $user     = $args{user}     // '';
    my $password = $args{password} // '';
    die "Set PAUSE_USERNAME and PAUSE_PASSWORD in the cpan environment\n"
        unless $user =~ /\A[A-Z][A-Z0-9]{2,8}\z/ && length($password);
    require CPAN::Uploader;
    my @accepted;
    for my $item ($plan->{order}->@*) {
        try {
            CPAN::Uploader->upload_file(
                $item->{path},
                {
                    user       => $user,
                    password   => $password,
                    upload_uri =>
'https://pause.perl.org/pause/authenquery?ACTION=add_uri',
                    retries => 0,
                }
            );
            push @accepted, $item->{file};
        }
        catch ($error) {

      # Uploader failures can include HTTP diagnostics; do not echo credentials.
            die 'PAUSE upload outcome is uncertain for '
                . $item->{file}
                . '; accepted earlier: '
                . (@accepted ? join(', ', @accepted) : 'none')
                . ". Inspect PAUSE and retain these exact archives before retrying.\n";
        }
    }
    return {accepted => \@accepted, indexed => false};
}

sub check_tag ($class, $tag, $source, $repository = '.') {
    die "invalid release tag\n"   unless $tag    =~ /\Av[0-9]+\.[0-9]+\z/;
    die "invalid source commit\n" unless $source =~ /\A[0-9a-f]{40}\z/;
    open my $origin, '-|', 'git', '-C', $repository, 'remote', 'get-url',
        'origin'
        or die "read canonical origin: $!\n";
    chomp(my $url = <$origin> // '');
    close $origin or die "read canonical origin failed\n";
    die "origin must be the canonical libtmux/libtmux-perl repository\n"
        unless $url =~
m!\A(?:https://github\.com/|git\@github\.com:)libtmux/libtmux-perl(?:\.git)?\z!;
    my $ref = "refs/tags/$tag";
    system('git', '-C', $repository, 'show-ref', '--verify', '--quiet', $ref)
        == 0
        or die "release tag is absent\n";
    open my $git, '-|', 'git', '-C', $repository, 'rev-parse',
        $ref . '^{commit}'
        or die "resolve release tag: $!\n";
    chomp(my $resolved = <$git> // '');
    close $git or die "resolve release tag failed\n";
    die "release tag points at another commit\n" unless $resolved eq $source;
    system('git', '-C', $repository, 'merge-base', '--is-ancestor', $source,
        'refs/remotes/origin/master') == 0
        or die "release commit must be reachable from origin/master\n";
    return true;
}
1;
