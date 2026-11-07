package LibTmuxFixture;
use v5.44;
use File::Temp qw(tempdir);
use File::Path qw(remove_tree);
use LibTmux::Server;
use Errno qw(ECHILD EINTR);

sub _children ($pid) {
    open my $in, '<', "/proc/$pid/task/$pid/children" or return ();
    my $line = do { local $/; <$in> };
    close $in;
    return grep { length } split /\s+/, $line;
}

sub _stamp ($pid) {
    open my $in, '<', "/proc/$pid/stat" or return undef;
    my $line = do { local $/; <$in> };
    close $in;
    return undef unless $line =~ /\A[0-9]+ \(.*\) (.*)\z/s;
    my @fields = split /\s+/, $1;
    return $fields[19];
}

sub _tree ($pid, $owned, $order) {
    return if exists $owned->{$pid};
    my $stamp = _stamp($pid);
    return unless defined $stamp;
    $owned->{$pid} = $stamp;
    push @$order, $pid;
    _tree($_, $owned, $order) for _children($pid);
}

sub run ($class, $code, %args) {
    my %allowed = map { $_ => true } qw(executable timeout max_output env);
    die 'fixture selectors/configuration cannot be overridden'
        if grep { !$allowed{$_} } keys %args;
    my %baseline = map { $_ => true } _children($$);
    my $root = tempdir('libtmux-perl-fixture-XXXX', TMPDIR => 1, CLEANUP => 0);
    my $server = LibTmuxFixture::Server->new(
        socket_path => "$root/s",
        config_file => '/dev/null',
        executable  => $ENV{LIBTMUX_TEST_TMUX} // 'tmux',
        timeout     => 0.8,
        %args
    );
    my ($result, $failure);
    local $SIG{TERM} = sub { die 'fixture interrupted by TERM' };
    local $SIG{INT}  = sub { die 'fixture interrupted by INT' };
    try { $result = $code->($server, $root) } catch ($error) {
        $failure = $error
    }
    my $cleanup_error;
    {
        local $SIG{TERM} = 'IGNORE';
        local $SIG{INT}  = 'IGNORE';
        try {
            my (%owned, @order);
            my $pid = $server->{fixture_pid};
            if (!$pid && -S "$root/s") {
                try {
                    $pid = 0 +
                        $server->cmd('display-message', '-p', '#{pid}')->stdout
                }
                catch ($error) {
                    die $error
                        unless ref($error)
                        && $error->isa('LibTmux::X::NoServer')
                }
            }
            _tree($pid, \%owned, \@order) if $pid;
            if (-S "$root/s") {
                try { $server->kill_server }
                catch ($error) {
                    die $error
                        unless ref($error)
                        && $error->isa('LibTmux::X::NoServer')
                }
            }

       # This author fixture runs in an isolated test process. Preserve children
       # that existed before its scope, including nested/borrowed fixtures.
            _tree($_, \%owned, \@order)
                for grep { !$baseline{$_} } _children($$);
            for my $child (@order) {
                my $stamp = _stamp($child);
                kill 'KILL', $child
                    if defined($stamp) && $stamp eq $owned{$child};
            }
            local $SIG{ALRM} = sub { die 'owned fixture child did not exit' };
            alarm 1;
            for my $child (@order) {
                my $waited;
                do { $waited = waitpid($child, 0) }
                    while ($waited < 0 && $! == EINTR);
                my $wait_error = 0 + $!;
                my $stamp      = _stamp($child);
                die 'owned fixture process remained after teardown'
                    if defined($stamp) && $stamp eq $owned{$child};
                die 'fixture child exit was not observed'
                    if $waited < 0 && $wait_error != ECHILD;
            }
            alarm 0;
        }
        catch ($error) { alarm 0; $cleanup_error = $error }
    }
    remove_tree($root);
    if (defined $failure) {
        warn "fixture cleanup also failed: $cleanup_error"
            if defined $cleanup_error;
        die $failure;
    }
    die $cleanup_error if defined $cleanup_error;
    return $result;
}

package LibTmuxFixture::Server;
use parent 'LibTmux::Server';

sub new_session ($self, %args) {
    my $session = $self->SUPER::new_session(%args);
    $self->{fixture_pid} =
        0 + $self->cmd('display-message', '-p', '#{pid}')->stdout
        unless $self->{fixture_pid};
    return $session;
}
1;
