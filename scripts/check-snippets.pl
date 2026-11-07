use v5.44;
use FindBin;
chdir "$FindBin::Bin/.." or die $!;
my $write = @ARGV && $ARGV[0] eq '--write';
die 'Usage: check-snippets.pl [--write]' if @ARGV > 1 || @ARGV && !$write;
my $failed = false;
for my $file (sort glob 'docs/*.md') {
    open my $in, '<:raw', $file or die $!;
    my $text = do { local $/; <$in> };
    close $in;
    my $changed = false;
    $text =~ s{(<!-- example: ([a-z-]+\.pl) -->\n```perl\n)(.*?)(```)}{
        my ($before,$example,$body,$after)=($1,$2,$3,$4);
        open my $source,'<:raw',"examples/$example" or die $!;
        my $expected=do {local $/;<$source>};close $source;
        if ($expected ne $body) {$changed=true}
        $before.$expected.'```';
    }gse;
    next unless $changed;
    if ($write) {
        open my $out, '>:raw', $file or die $!;
        print {$out} $text;
        close $out;
    }
    else { warn "Example snippet drift: $file\n"; $failed = true }
}
exit $failed;
