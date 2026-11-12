use v5.44;
use FindBin;
chdir "$FindBin::Bin/.." or die $!;
my $write = @ARGV && $ARGV[0] eq '--write';
die 'Usage: check-snippets.pl [--write]' if @ARGV > 1 || @ARGV && !$write;
my $failed = false;
for my $file (
    sort('README.md', glob('packages/*/README.md'), glob('docs/*.md')))
{
    open my $in, '<:raw', $file or die $!;
    my $text = do { local $/; <$in> };
    close $in;
    my $changed = false;
    my $marked  = () = $text =~ /<!-- example:/g;
    my $checked = 0;
    $text =~
s{(<!-- example: ([a-zA-Z0-9_./-]+\.(?:pl|json))(?:\#([a-z-]+))? -->\n```(?:perl|json)\n)(.*?)(```)}{
        my ($before,$example,$region,$body,$after)=($1,$2,$3,$4,$5);
        ++$checked;
        my $path = index($example, '/') < 0 ? "examples/$example" : $example;
        die "Invalid example source: $path\n"
            unless $path =~ m!\A(?:examples/|packages/(?:core|async|workspace)/examples/)[a-z-]+\.(?:pl|json)\z!;
        open my $source,'<:raw',$path or die "$path: $!";
        my $expected=do {local $/;<$source>};close $source;
        if (defined $region) {
            my @regions = $expected =~ /^([ \t]*)\# example: begin \Q$region\E\n(.*?)^\1\# example: end \Q$region\E\n/msg;
            die "Expected one example region $path#$region\n" unless @regions == 2;
            my ($indent, $section) = @regions;
            $section =~ s/^\Q$indent\E//mg;
            $expected = $section;
        }
        if ($expected ne $body) {$changed=true}
        $before.$expected.'```';
    }gse;
    die "Unrecognized example marker in $file\n" unless $checked == $marked;
    next                                         unless $changed;

    if ($write) {
        open my $out, '>:raw', $file or die $!;
        print {$out} $text;
        close $out;
    }
    else { warn "Example snippet drift: $file\n"; $failed = true }
}
exit $failed;
