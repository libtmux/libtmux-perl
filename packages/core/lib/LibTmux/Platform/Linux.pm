package LibTmux::Platform::Linux;
use v5.44;
use Config;
use LibTmux::X;

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
1;
