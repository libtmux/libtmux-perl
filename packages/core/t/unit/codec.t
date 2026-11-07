use v5.44;
use Test2::V1;
use Scalar::Util qw(blessed);

my $loaded = eval { require LibTmux::Codec; 1 };
T2->ok($loaded, 'reversible tmux field codec is loadable');
unless ($loaded) { T2->diag($@); T2->done_testing; exit }

my $decoded =
    LibTmux::Codec->decode("a\\tb\tline\\nend\tback\\\\slash\t\xff\n", 4);
T2->is(
    $decoded,
    [["a\tb", "line\nend", "back\\slash", "\xff"]],
    'decode escapes before field typing without losing bytes'
);
T2->is(
    LibTmux::Codec->decode("\t\n", 2),
    [['', '']],
    'empty fields remain fields'
);

for my $bad ("a\tb", "a\\q\tb\n", "a\\\tb\n", "a\tb\tc\n") {
    my $e;
    try { LibTmux::Codec->decode($bad, 2) } catch ($caught) {
        $e = $caught
    }
    T2->ok(blessed($e) && $e->isa('LibTmux::X::Codec'),
        'malformed frames are failures');
}
T2->done_testing;
