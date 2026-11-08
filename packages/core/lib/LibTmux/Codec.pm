package LibTmux::Codec;
use v5.44;
use LibTmux::X;

sub format ($class, @tokens) {
    for (@tokens) {
        LibTmux::X::InvalidArgument->throw(message => 'invalid format token')
            unless /\A[\@A-Za-z_][A-Za-z_0-9]*\z/;
    }
    my $modifiers =
        's|\\\\|\\\\\\\\|;s|' . "\t" . '|\\\\t|;s|' . "\n" . '|\\\\n|:';
    return join "\t", map { '#{' . $modifiers . $_ . '}' } @tokens;
}

sub decode ($class, $bytes, $count) {
    LibTmux::X::Codec->throw(message => 'expected byte stream')
        if utf8::is_utf8($bytes);
    return [] if $bytes eq '';
    LibTmux::X::Codec->throw(message => 'missing final record newline')
        unless $bytes =~ /\n\z/;
    my @rows;
    my %escapes = (
        '\\' => '\\',
        n    => "\n",
        t    => "\t",
        a    => "\a",
        b    => "\b",
        f    => "\f",
        v    => "\x0b",
        r    => "\r",
        '$'  => '$'
    );
    my @frames = split /\n/, $bytes, -1;
    pop @frames;
    for my $row (@frames) {
        my @fields = length($row) ? split(/\t/, $row, -1) : ('');
        LibTmux::X::Codec->throw(message => 'incorrect field count')
            unless @fields == $count;
        for my $field (@fields) {
            my $out = '';
            while (length $field) {
                if ($field =~ s/\A([^\\]+)//s) { $out .= $1; next }

                # Older tmux print paths add vis escapes after format expansion.
                if ($field =~ s/\A\\([0-3][0-7]{2})//) {
                    $out .= chr(oct($1));
                    next;
                }
                LibTmux::X::Codec->throw(
                    message => 'unknown or incomplete field escape')
                    unless $field =~ s/\A\\([\\ntabfvr\$])//;
                $out .= $escapes{$1};
            }
            $field = $out;
        }
        push @rows, \@fields;
    }
    return \@rows;
}

=head1 NAME

LibTmux::Codec - Reversible single-lookup tmux format records

=head1 DESCRIPTION

Backslash, tab, and newline are escaped by tmux substitution modifiers.
Decoding composes those escapes with older tmux print escapes in one pass,
returning octets. Use this decoder only with L</format> output from a UTF-8
command client; raw command output has a separate contract. An empty stream
has no rows; one newline is one empty single-field record. Malformed streams
throw L<LibTmux::X::Codec|LibTmux::X/Codec>.

=head1 METHODS

=head2 format

C<LibTmux::Codec-E<gt>format(@tokens)> returns one tmux format string in token
order without I/O. Tokens must be registered-style names, including user option
names beginning with C<@>; invalid names throw
L<LibTmux::X::InvalidArgument|LibTmux::X/InvalidArgument>. No input is mutated.

=head2 decode

C<LibTmux::Codec-E<gt>decode($bytes, $field_count)> returns an arrayref of row
arrayrefs in stream order, including empty fields and duplicate rows. It
performs no I/O and does not mutate the input. An empty byte stream returns
C<[]>; malformed framing throws L<LibTmux::X::Codec|LibTmux::X/Codec>.

=cut
