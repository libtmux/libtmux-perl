package LibTmuxDev;
use v5.44;
use Exporter 'import';
use File::Find ();
use Perl::Tidy ();
our @EXPORT_OK = qw(perl_files tidy_text);

sub perl_files () {
    my @files = ('cpanfile');
    for my $package (qw(core async workspace)) {
        push @files, "packages/$package/Makefile.PL",
            "packages/$package/cpanfile";
        for my $dir (
            "packages/$package/lib", "packages/$package/t",
            "packages/$package/bin", "packages/$package/examples"
            )
        {
            next unless -d $dir;
            File::Find::find(
                {
                    no_chdir => 1,
                    wanted   => sub {
                        push @files, $File::Find::name
                            if -f $_ && (/\.(?:pm|pl|t)\z/ || m!/bin/[^/]+\z!);
                    }
                },
                $dir
            );
        }
    }
    File::Find::find(
        {
            no_chdir => 1,
            wanted   => sub {
                push @files, $File::Find::name if -f $_ && /\.(?:pm|pl)\z/;
            }
        },
        'scripts'
    );
    if (-d 'examples') {
        File::Find::find(
            {
                no_chdir => 1,
                wanted   =>
                    sub { push @files, $File::Find::name if -f $_ && /\.pl\z/ }
            },
            'examples'
        );
    }
    return sort @files;
}

sub tidy_text ($source) {
    my ($formatted, $errors) = ('', '');
    my $code = Perl::Tidy::perltidy(
        argv        => [],
        source      => \$source,
        destination => \$formatted,
        stderr      => \$errors,
        perltidyrc  => '.perltidyrc'
    );
    die $errors || "Perl::Tidy failed: $code\n" if $code;
    $formatted =~ s/\n+\z/\n/;
    return $formatted;
}
