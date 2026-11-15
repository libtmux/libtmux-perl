use v5.44;
use Test2::V1;
use FindBin;

# PR_GET_CHILD_SUBREAPER reads the flag into an int; 157 is prctl on x86_64.
my $probe = q{
    my $flag = pack('i', 0);
    syscall(157, 37, $flag, 0, 0, 0) == 0 or die "prctl: $!";
    print unpack('i', $flag);
};
my $wrapper = "$FindBin::Bin/../with-subreaper.pl";

sub run_program (@argv) {
    open my $out, '-|', @argv or die "$argv[0]: $!";
    my $text = do { local $/; <$out> };
    close $out;
    return ($? >> 8, $text);
}

T2->is([run_program($^X, '-e', $probe)], [0, '0'], 'the flag starts clear');
T2->is([run_program($^X, $wrapper, $^X, '-e', $probe)],
    [0, '1'], 'the wrapped program is a child subreaper');
T2->is([run_program($^X, $wrapper, $^X, '-e', 'exit 7')],
    [7, ''], 'the program keeps its exit status');
T2->isnt(scalar(run_program($^X, $wrapper)),
    0, 'a missing program is a usage error');
T2->done_testing;
