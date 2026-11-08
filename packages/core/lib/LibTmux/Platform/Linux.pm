package LibTmux::Platform::Linux;
use v5.44;
use Config;
use LibTmux::X;
use POSIX ();
use Errno qw(EBADF);

# Linux v6.18: arch/x86/entry/syscalls/syscall_64.tbl and uapi/linux/prctl.h.
sub _subreaper () {
    LibTmux::X::Unsupported->throw(
        message =>
            'supervised execution is qualified only for Linux x86_64 LP64',
        dispatched => false
        )
        unless $^O eq 'linux'
        && $Config{archname} =~ /\Ax86_64-linux(?:-|\z)/
        && $Config{ptrsize} == 8
        && $Config{longsize} == 8;
    LibTmux::X::Transport->throw(
        message    => "enable isolated child subreaper: $!",
        dispatched => false
    ) unless syscall(157, 36, 1, 0, 0, 0) == 0;
}

sub _close_fds_except (@handles) {
    my %keep = map { $_ => true } (0, 1, 2);
    for my $handle (@handles) {
        my $fd = fileno($handle);
        LibTmux::X::Transport->throw(
            message    => 'missing owned protocol descriptor',
            dispatched => false
        ) unless defined $fd;
        $keep{$fd} = true;
    }
    opendir my $directory,
        '/proc/self/fd'
        or LibTmux::X::Transport->throw(
        message    => "enumerate inherited descriptors: $!",
        dispatched => false
        );
    $! = 0;
    my @fds        = grep { /\A[0-9]+\z/ } readdir $directory;
    my $read_error = $! ? "$!" : undef;
    closedir $directory
        or LibTmux::X::Transport->throw(
        message    => "close descriptor directory: $!",
        dispatched => false
        );
    LibTmux::X::Transport->throw(
        message    => "read inherited descriptors: $read_error",
        dispatched => false
    ) if defined $read_error;
    for my $fd (@fds) {
        next if $keep{$fd};
        my $closed = POSIX::close($fd);

        # The enumeration descriptor is already closed. Linux also releases
        # descriptors on close errors, so retrying could close a reused one.
        next if defined($closed) && $closed == 0 || $! == EBADF;
        LibTmux::X::Transport->throw(
            message    => "close inherited descriptor $fd: $!",
            dispatched => false
        );
    }
}
1;
