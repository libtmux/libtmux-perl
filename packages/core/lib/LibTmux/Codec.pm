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
    for my $row (split /\n/, substr($bytes, 0, -1), -1) {
        my @fields = split /\t/, $row, -1;
        LibTmux::X::Codec->throw(message => 'incorrect field count')
            unless @fields == $count;
        for my $field (@fields) {
            my $out = '';
            while (length $field) {
                if ($field =~ s/\A([^\\]+)//s) { $out .= $1; next }
                LibTmux::X::Codec->throw(
                    message => 'unknown or incomplete field escape')
                    unless $field =~ s/\A\\([\\nt])//;
                $out .= $1 eq 'n' ? "\n" : $1 eq 't' ? "\t" : '\\';
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
Decoding returns octets. Malformed streams throw LibTmux::X::Codec.

=cut
