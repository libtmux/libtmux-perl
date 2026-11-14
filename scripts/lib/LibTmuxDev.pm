package LibTmuxDev;
use v5.44;
use Exporter 'import';
use File::Find              ();
use Perl::Tidy              ();
use Pod::Simple::SimpleTree ();
our @EXPORT_OK = qw(perl_files tidy_text directory_problems);

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
                push @files, $File::Find::name if -f $_ && /\.(?:pm|pl|t)\z/;
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

sub _plain ($node) {
    return $node unless ref $node;
    return join '', map { _plain($_) } @{$node}[2 .. $#$node];
}

# The C<> names of nodes that hold nothing else but separators, or undef.
sub _references (@nodes) {
    my @names;
    for my $node (@nodes) {
        if (ref $node) {
            return unless $node->[0] eq 'C';
            push @names, _plain($node);
        }
        else { return unless $node =~ /\A(?:[\s,;.]|and\b)*\z/ }
    }
    return @names ? \@names : undef;
}

# A paragraph of references, or a list of "Label: references" items.
sub _row_references ($node) {
    my ($tag, undef, @children) = @$node;
    return _references(@children) if $tag eq 'Para';
    return unless $tag eq 'over-text';
    my @names;
    for my $item (@children) {
        return unless $item->[0] eq 'item-text';
        my ($label, @rest) = @{$item}[2 .. $#$item];
        return unless !ref($label) && $label =~ /\A[^:\[`]{1,40}:\s+\z/;
        my $names = _references(@rest) or return;
        push @names, @$names;
    }
    return @names ? \@names : undef;
}

# Problems with the "What is on here" directory in a class's POD: the
# structure libtmux.org folds into a table, and a name for every =head2
# method. A bold-led row names its methods in the references that follow it;
# the row's own prose does not count.
sub directory_problems ($file) {
    my $parser = Pod::Simple::SimpleTree->new;
    $parser->parse_file($file);
    my ($in, $found, $rows, %methods, %named, @problems);
    my @nodes = grep { ref } @{$parser->root}[2 .. $#{$parser->root}];
    for my $i (0 .. $#nodes) {
        my $node = $nodes[$i];
        my $tag  = $node->[0];
        if ($tag eq 'head1') {
            $in = _plain($node) eq 'What is on here';
            $found ||= $in;
        }
        elsif ($tag eq 'head2') { $methods{_plain($node)} = true }
        elsif ($in && $tag eq 'Para' && ref($node->[2]) && $node->[2][0] eq 'B')
        {
            my $title = _plain($node->[2]);
            my $names = $i < $#nodes ? _row_references($nodes[$i + 1]) : undef;
            if ($names) { $rows++; $named{$_} = true for @$names }
            else {
                push @problems,
                    "$file: directory row '$title' needs a paragraph or "
                    . "'Label: references' list of C<> names after it";
            }
        }
    }
    return "$file: no 'What is on here' directory" unless $found;
    push @problems, "$file: directory needs at least 3 rows"
        if ($rows // 0) < 3;
    push @problems, "$file: directory omits $_"
        for grep { !$named{$_} } sort keys %methods;
    push @problems,
        "$file: directory names $_, which is not a documented method"
        for grep { !$methods{$_} } sort keys %named;
    return @problems;
}
