use v5.44;
use Test2::V1;
use File::Temp qw(tempdir);
use LibTmuxDev qw(directory_problems);

my $dir =
    tempdir('libtmux-perl-directory-test-XXXX', TMPDIR => 1, CLEANUP => 1);
my $count = 0;

# A class with methods alpha, beta and gamma and the given directory body.
sub problems ($directory) {
    my $file = "$dir/Class" . ++$count . '.pm';
    open my $out, '>:raw', $file or die "$file: $!";
    print {$out} "=head1 What is on here\n\n$directory\n"
        if defined $directory;
    print {$out} "=head1 METHODS\n\n"
        . join('', map { "=head2 $_\n\nText.\n\n" } qw(alpha beta gamma))
        . "=cut\n";
    close $out;
    return map { s/\A\Q$file\E: //r } directory_problems($file);
}
my $rows = <<'POD';
Intro.

B<One.> Guidance.

L</alpha> and L<beta|/beta>

B<Two.> Guidance.

=over 4

=item First: L<gamma|/gamma>

=back

B<Three.> Guidance.

L</alpha>
POD

T2->is([problems($rows)], [], 'paragraph and labelled rows cover every method');
T2->is([problems($rows =~ s/L<gamma\|\/gamma>/L<beta|\/beta>/r)],
    ['directory omits gamma'],
    'a method missing from the references is reported');
T2->is(
    [
        problems(
            $rows =~ s/L<gamma\|\/gamma>/L<beta|\/beta>/r =~
                s/Guidance\./Guidance L<gamma|\/gamma>./r
        )
    ],
    ['directory omits gamma'],
    'a name in a row\'s own prose does not count'
);
T2->is(
    [problems($rows . "\nB<Four.> Guidance.\n\nL</delta>\n")],
    ['directory names delta, which is not a documented method'],
    'a name that is not a method is reported'
);
T2->is(
    [
        problems(
            $rows =~
s/L<\/alpha> and L<beta\|\/beta>/Use L<\/alpha> and L<beta|\/beta>./r
        )
    ],
    [
"directory row 'One.' needs a paragraph or 'Label: references' list of L</name> links after it",
        'directory needs at least 3 rows',
        'directory omits beta'
    ],
    'references mixed with prose are not a row'
);
my $row_problem =
"directory row 'One.' needs a paragraph or 'Label: references' list of L</name> links after it";
T2->is(
    [
        problems(
            $rows =~ s/L<\/alpha> and L<beta\|\/beta>/C<alpha> and C<beta>/r
        )
    ],
    [$row_problem, 'directory needs at least 3 rows', 'directory omits beta'],
    'C<> names are not references'
);
T2->is(
    [problems($rows =~ s/L<\/alpha>/L<LibTmux::X\/alpha>/r)],
    [$row_problem, 'directory needs at least 3 rows', 'directory omits beta'],
    'a link into another module is not a reference'
);
T2->is(
    [problems($rows =~ s/\nB<Three\.>.*\z/\n/sr)],
    ['directory needs at least 3 rows'],
    'two rows are not a directory'
);
T2->is(
    [problems(undef)],
    ["no 'What is on here' directory"],
    'a class without the section is reported'
);

T2->done_testing;
