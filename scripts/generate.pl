use v5.44;
use FindBin;
use lib "$FindBin::Bin/../packages/core/lib";
use LibTmux::Schema;
use lib "$FindBin::Bin/../local/lib/perl5", "$FindBin::Bin/lib";
use LibTmuxDev qw(tidy_text);
use File::Spec;
my $check = @ARGV && $ARGV[0] eq '--check';
die "Usage: perl scripts/generate.pl [--check]\n"
    if @ARGV > 1 || (@ARGV && !$check);
my $root    = "$FindBin::Bin/..";
my $catalog = LibTmux::Schema->catalog;
my @table   = (
    '# Entity fields',
    '',
'Generated from the packaged field catalog. Missing fields throw; known null is explicit.',
    '',
    '| Entity | Field | Wire | Type | Nullable | tmux source / minimum |',
    '| --- | --- | --- | --- | --- | --- |'
);
my %outputs;

for my $kind (sort keys $catalog->{entities}->%*) {
    my $class  = LibTmux::Schema->class_for($kind);
    my $fields = $catalog->{entities}{$kind}{fields};
    my @subs;
    my @pod;
    for my $field (sort keys %$fields) {
        my $f = $fields->{$field};
        push @subs, "sub $field (\$self) { \$self->_read('$field') }";
        push @pod,
            "=head2 $field\n\n"
            . (
            $f->{type} eq 'relation'
            ? (
                $f->{many}
                ? "L<LibTmux::Selection> of L<"
                    . LibTmux::Schema->class_for($f->{entity})
                    . "> entities."
                : "L<"
                    . LibTmux::Schema->class_for($f->{entity})
                    . "> entity"
                    . ($f->{nullable} ? ' or undef.' : '.')
                )
            : "$f->{type}" . ($f->{nullable} ? ' or undef.' : '.')
            ) . " Local captured data; no I/O.\n";
        push @table,
              "| $kind | $field | $f->{wire} | $f->{type} | "
            . ($f->{nullable} ? 'yes' : 'no') . ' | '
            . (
            $f->{source} ? "`$f->{source}` / $f->{minimum}" : 'captured graph')
            . ' |';
    }
    (my $rel = $class) =~ s!::!/!g;
    $outputs{"packages/core/lib/$rel.pm"} =
          "package $class;\nuse v5.44;\nuse parent 'LibTmux::Entity';\n\n"
        . join("\n", @subs)
        . "\n\n=head1 NAME\n\n$class - Captured $kind entity\n\n=head1 METHODS\n\n"
        . join("\n", @pod)
        . "\n=head1 OWNERSHIP\n\nReaders use the retained graph and never refresh it. Acquire a new snapshot for\nnew state. Inherited L<to_record|LibTmux::Entity/to_record> exports a detached scalar record.\n\n=cut\n";
}
for my $file (keys %outputs) { $outputs{$file} = tidy_text($outputs{$file}) }
$outputs{'docs/fields.md'} = join("\n", @table) . "\n";
my $changed = 0;
for my $path (sort keys %outputs) {
    my $actual = '';
    if (open my $in, '<:raw', "$root/$path") { local $/; $actual = <$in> }
    next if $actual eq $outputs{$path};
    if ($check) { warn "Generated file differs: $path\n"; $changed = 1; next }
    open my $out, '>:raw', "$root/$path" or die "Write $path: $!";
    print {$out} $outputs{$path};
}
exit $changed;
