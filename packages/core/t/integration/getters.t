use v5.44;
use Test2::V1;
use LibTmuxFixture;

LibTmuxFixture->run(
    sub ($server, $root) {
        my $session = $server->new_session(
            name    => 'getters',
            command => ['/bin/sleep', '120']
        );
        my @corpus = (
            '',                      '0',
            "opaque-\xff",           '\377',
            '\n',                    "\t\n\r\b\a\f\x0b",
            '$HOME ${path} $_ $1 $', '\$HOME \\${x}',
            'two words',             '"',
            "'",                     '~',
            '~abc',                  '#',
            ';',                     '%',
            '{',                     '}',
            '`text`',                join('', map chr, 1 .. 255)
        );
        for my $value (@corpus) {
            my $label = unpack('H*', $value);
            $server->set_option(
                name   => '@getter',
                global => true,
                value  => $value
            );
            T2->is($server->get_option(name => '@getter', global => true),
                $value, "option octets $label");
            $server->set_environment(name => 'LIBTMUX_GETTER', value => $value);
            T2->is($server->get_environment(name => 'LIBTMUX_GETTER'),
                $value, "environment octets $label");
        }
        for my $name ('@has space', "\@has\nnewline", '@has$HOME',
            "\@opaque-\xff")
        {
            $server->set_option(
                name   => $name,
                global => true,
                value  => 'quote " word\377'
            );
            T2->is(
                $server->get_option(name => $name, global => true),
                'quote " word\377',
                'user option names do not become value framing'
            );
        }
        $server->set_option(
            name   => '@getter',
            global => true,
            value  => 'global'
        );
        $server->set_option(
            name   => '@getter',
            target => $session->id,
            value  => 'local'
        );
        T2->is(
            $server->get_option(
                name      => '@getter',
                target    => $session->id,
                inherited => true
            ),
            'local',
            'local option wins over inherited value'
        );
        $server->unset_option(name => '@getter', target => $session->id);
        T2->is(
            $server->get_option(
                name      => '@getter',
                target    => $session->id,
                inherited => true
            ),
            'global',
            'explicit inheritance selects parent value'
        );
        $server->set_option(
            name   => 'status-left-length',
            target => $session->id,
            value  => 42
        );
        T2->is(
            $server->get_option(
                name   => 'status-left-l',
                target => $session->id
            ),
            '42',
            'native option abbreviation and numeric rendering remain supported'
        );
        $server->set_option(
            name   => 'update-environment',
            target => $session->id,
            value  => ''
        );
        T2->is(
            $server->get_option(
                name   => 'update-environment',
                target => $session->id
            ),
            '',
            'empty native array returns an empty value'
        );
        $server->set_option(
            name   => 'update-environment[2]',
            target => $session->id,
            value  => '\377'
        );
        $server->set_option(
            name   => 'update-environment[7]',
            target => $session->id,
            value  => "raw-\xff"
        );
        T2->is(
            $server->get_option(
                name   => 'update-environment',
                target => $session->id
            ),
            "\\377\nraw-\xff",
            'sparse string arrays retain native index order and byte values'
        );
        T2->is(
            $server->get_option(
                name   => 'update-environment[7]',
                target => $session->id
            ),
            "raw-\xff",
            'indexed string array returns one decoded value'
        );
        my $version =
            $server->cmd('display-message', '-p', '#{version}')->stdout;

        for my $name ('prefix', 'prefix2', 'backspace') {
            my %scope =
                $name eq 'backspace'
                ? (scope => 'server')
                : (target => $session->id);
            for my $value ('"', "'", '\\', 'M-\\') {
                $server->set_option(name => $name, %scope, value => $value);
                T2->is($server->get_option(name => $name, %scope),
                    $value, 'key-valued options preserve native key spelling');
            }
        }
        T2->is($server->get_option(name => 'backs', scope => 'server'),
            'M-\\',
            'abbreviated key names use the resolved native option type');
        if ($server->at_least($version, '3.8')) {
            for my ($key, $value)
                ('custom', 'first', "with\nspace \"quote", 'last\\377')
            {
                $server->set_option(
                    name   => "update-environment[$key]",
                    target => $session->id,
                    value  => $value
                );
                T2->is(
                    $server->get_option(
                        name   => "update-environment[$key]",
                        target => $session->id
                    ),
                    $value,
                    'string array keys retain their complete native boundary'
                );
            }
            T2->is(
                $server->get_option(
                    name   => 'update-environment',
                    target => $session->id
                ),
                "\\377\nraw-\xff\nfirst\nlast\\377",
                'numeric and string array keys retain native ordering'
            );
        }
        $server->set_hook(
            name    => 'after-new-window[17]',
            target  => $session->id,
            command => 'display-message -p "two words"'
        );
        my $native = $server->cmd('show-options', '-v', '-t', $session->id,
            '--', 'after-new-window[17]')->stdout;
        $native =~ s/\n\z//;
        T2->is(
            $server->get_option(
                name   => 'after-new-window[17]',
                target => $session->id
            ),
            $native,
            'command options retain native command syntax'
        );
        $server->set_environment(
            name    => 'LIBTMUX_GETTER',
            session => $session,
            value   => 'scoped\\377'
        );
        T2->is(
            $server->get_environment(
                name    => 'LIBTMUX_GETTER',
                session => $session
            ),
            'scoped\\377',
            'captured session selects its own environment'
        );
        $server->cmd('set-environment', '-r', '-t', $session->id,
            'LIBTMUX_GETTER');
        my $error;
        try {
            $server->get_environment(
                name    => 'LIBTMUX_GETTER',
                session => $session
            )
        }
        catch ($caught) { $error = $caught }
        T2->isa_ok($error, ['LibTmux::X::Command'],
            'explicitly removed environment remains an error');
    },
    env => {LC_ALL => 'C', LC_CTYPE => 'C', LANG => 'C'}
);
T2->done_testing;
