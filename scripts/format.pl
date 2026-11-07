use v5.44;
use FindBin;
use lib "$FindBin::Bin/../local/lib/perl5", "$FindBin::Bin/lib";
use LibTmuxDev qw(perl_files tidy_text);
die "Usage: perl scripts/format.pl --check|--write\n"
    unless @ARGV == 1 && $ARGV[0] =~ /\A--(?:check|write)\z/;
chdir "$FindBin::Bin/.." or die $!;
my $failed = 0;
for my $file (perl_files()) {
    open my $in, '<:raw', $file or die "$file: $!";
    my $source    = do { local $/; <$in> };
    my $formatted = tidy_text($source);
    next if $source eq $formatted;
    if ($ARGV[0] eq '--check') {
        warn "Formatting differs: $file\n";
        $failed = 1;
    }
    else {
        open my $out, '>:raw', $file or die "$file: $!";
        print {$out} $formatted;
    }
}
exit $failed;
