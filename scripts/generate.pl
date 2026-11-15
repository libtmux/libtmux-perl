use v5.44;
use FindBin;
use lib "$FindBin::Bin/../packages/core/lib";
use LibTmux::Schema;
use lib "$FindBin::Bin/../local/lib/perl5", "$FindBin::Bin/lib";
use LibTmuxDev qw(tidy_text);
use File::Spec;
use Text::Wrap qw(wrap);
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

# Hand-written "What is on here" directories, by entity kind. A row is a bold
# lead with its guidance, then the fields it covers: labelled
# [label, field, ...] items, or bare field names in a paragraph. check-pod.pl
# requires every field to be named.
my %directory = (
    pane => {
        intro => q{A captured pane holds what tmux reported when its snapshot
            was taken. Its readers answer from that snapshot and run no tmux
            command, so capture again to see later changes. They fall into the
            groups below.},
        rows => [
            {
                lead => 'Identifying',
                text => q{Name a pane by its tmux ID, such as C<%3>, which stays
                    the same for the pane's life. A L<LibTmux::Server> method
                    takes the handle in place of that ID. The index is the
                    pane's position in its window, and the title is whatever
                    the application set.},
                items => [
                    ['Stable ID',              'id'],
                    ['Position in the window', 'index'],
                    ['Title',                  'title'],
                ],
            },
            {
                lead => 'Running',
                text => q{Read what the pane runs: the foreground command, the
                    working directory of its process, and the PID tmux started
                    in it. A pane whose process has exited and that tmux kept
                    reports C<dead> as true, and its C<exit_status> is C<undef>
                    when tmux reports none.},
                items => [
                    ['Foreground command', 'current_command'],
                    ['Working directory',  'current_path'],
                    ['Process ID',         'pid'],
                    ['Exit state',         'dead', 'exit_status'],
                ],
            },
            {
                lead => 'Size and focus',
                text => q{Width and height count character cells, and the active
                    pane is the one its window currently selects. The cursor
                    shape needs tmux 3.6 or newer; reading it from an older
                    daemon's snapshot throws
                    L<LibTmux::X::Unsupported|LibTmux::X/Unsupported>.},
                items => [
                    ['Size in cells',        'width', 'height'],
                    ['Active in its window', 'active'],
                    ['Cursor shape',         'cursor_shape'],
                ],
            },
            {
                lead => 'Reaching the window',
                text => q{The window that holds the pane, as a captured
                    L<LibTmux::Window> resolved in the same graph.},
                fields => ['window'],
            },
        ],
    },
    window => {
        intro => q{A captured window holds what tmux reported when its snapshot
            was taken. Its readers answer from that snapshot and run no tmux
            command, so capture again to see later changes. They fall into the
            groups below.},
        rows => [
            {
                lead => 'Identifying',
                text => q{The ID, such as C<@2>, names the window itself in
                    every session that links it and stays the same for the
                    window's life. A L<LibTmux::Server> method takes the handle
                    in place of that ID. The name is a label and changes when
                    the window is renamed.},
                items => [['Stable ID', 'id'], ['Name', 'name']],
            },
            {
                lead => 'Size and layout',
                text => q{Width and height count character cells. The layout is
                    tmux's native layout string, which
                    L<select_layout|LibTmux::Server/select_layout> accepts
                    back.},
                items => [
                    ['Size in cells', 'width', 'height'],
                    ['Layout string', 'layout'],
                ],
            },
            {
                lead => 'Reaching panes and links',
                text => q{A window holds its panes directly and reaches the
                    sessions that link it through its window links, one per
                    link. Its active pane is C<undef> when the snapshot holds
                    none.},
                items => [
                    ['Panes',               'panes'],
                    ['Active pane',         'active_pane'],
                    ['Links into sessions', 'links'],
                ],
            },
        ],
    },
);

sub directory_pod ($entry) {
    local $Text::Wrap::columns = 81;
    my $link = sub ($field) { "L<$field|/$field>" };
    my $flow = sub ($text) { join ' ', split ' ', $text };
    my @pod  = (
        '=head1 What is on here',
        '', wrap('', '', $flow->($entry->{intro})), ''
    );
    for my $row ($entry->{rows}->@*) {
        push @pod, wrap('', '', $flow->("B<$row->{lead}.> $row->{text}")), '';
        if ($row->{items}) {
            push @pod, '=over 4', '';
            for my $item ($row->{items}->@*) {
                my ($label, @fields) = @$item;
                push @pod,
                    "=item $label: " . join(', ', map { $link->($_) } @fields),
                    '';
            }
            push @pod, '=back', '';
        }
        else {
            push @pod, join(', ', map { $link->($_) } $row->{fields}->@*), '';
        }
    }
    return join("\n", @pod) . "\n";
}

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
        . "\n\n=head1 NAME\n\n$class - Captured $kind entity\n\n"
        . ($directory{$kind} ? directory_pod($directory{$kind}) : '')
        . "=head1 METHODS\n\n"
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
