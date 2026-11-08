use v5.44;
use Test2::V1;
use Encode qw(encode decode);
use LibTmuxFixture;
use LibTmux::Codec;

LibTmuxFixture->run(
    sub ($server, $root) {
        my $path = "$root/opaque-\xff";
        mkdir $path or die "mkdir: $!";
        my $name    = decode('UTF-8', "caf\xc3\xa9");
        my $session = $server->new_session(
            name    => $name,
            cwd     => $path,
            command => ['/bin/sleep', '120']
        );
        my $pane = $session->window_links->one->window->panes->one;
        T2->is($session->name, $name, 'C locale preserves UTF-8 text');
        T2->is($pane->current_path, $path,
            'C locale preserves pathname octets');
        T2->is($server->get_environment(name => 'LC_ALL'),
            'C', 'client framing does not replace the server environment');

        my @corpus = (
            '',                           "\t",
            "\n",                         '\n',
            '\\\\',                       "a\\\t\nb",
            encode('UTF-8', "caf\x{e9}"), "opaque-\xff",
            '$HOME ${path} $_',           '\377\n\r\$x',
            join('', map chr, 1 .. 255)
        );

        for my $value (@corpus) {
            $server->cmd('set-option', '-g', '@codec', $value);
            my $bytes = $server->cmd('display-message', '-p', '-t', $pane->id,
                LibTmux::Codec->format('@codec', 'session_id'))->stdout;
            T2->is(
                LibTmux::Codec->decode($bytes, 2),
                [[$value, $session->id]],
                'live tmux encoder preserves corpus bytes and field boundary'
            );
        }
        $server->cmd('set-option', '-g', '@codec', '');
        my $empty = $server->cmd('display-message', '-p',
            LibTmux::Codec->format('@codec'))->stdout;
        T2->is(LibTmux::Codec->decode($empty, 1),
            [['']], 'live empty single-field frame remains one record');
    },
    env => {LC_ALL => 'C', LC_CTYPE => 'C', LANG => 'C'}
);
T2->done_testing;
