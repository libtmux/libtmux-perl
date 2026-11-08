use v5.44;
use Test2::V1;
use IO::Async::Loop;
use LibTmux::Async::Server;
use LibTmuxFixture;
LibTmuxFixture->run(
    sub ($sync, $root) {
        T2->note('creating the synchronous fixture session');
        my $session = $sync->new_session(
            name    => 'async',
            command => ['/bin/sleep', '120']
        );
        my $loop  = IO::Async::Loop->new;
        my $async = LibTmux::Async::Server->new(
            loop           => $loop,
            socket_path    => "$root/s",
            config_file    => '/dev/null',
            executable     => $ENV{LIBTMUX_TEST_TMUX} // 'tmux',
            timeout        => 0.8,
            max_concurrent => 2
        );
        T2->note('acquiring the asynchronous snapshot');
        my $snapshot = $async->snapshot;
        $loop->await($snapshot);
        my $async_snapshot = $snapshot->get;
        T2->note('acquiring the synchronous comparison snapshot');
        my $sync_snapshot = $sync->snapshot;
        T2->is(
            [map { $_->id } $async_snapshot->panes->@*],
            [map { $_->id } $sync_snapshot->panes->@*],
            'sync and async graph identity agree'
        );
        my $query = $async->query_panes(
            where    => {active => true, width => {-gt => 0}},
            pushdown => 'require'
        );
        $loop->await($query);
        T2->is($query->get->count, 1,
            'async exact query returns one selection');
        my $rename =
            $async->rename_session(session => $session, name => 'renamed');
        $loop->await($rename);
        T2->is($rename->get, undef, 'void operation yields one undef');
        T2->is($sync->snapshot->sessions->one->name,
            'renamed', 'async mutation observed through public sync API');
        my $set = $async->set_environment(
            session => $session,
            name    => 'LIBTMUX_ASYNC',
            value   => '0'
        );
        $loop->await($set);
        T2->is($set->get, undef,
            'async environment accepts a captured session');
        my $get = $async->get_environment(
            session => $session,
            name    => 'LIBTMUX_ASYNC'
        );
        $loop->await($get);
        T2->is($get->get, '0',
            'async environment returns one captured-target value');
        my $unset = $async->unset_environment(
            session => $session,
            name    => 'LIBTMUX_ASYNC'
        );
        $loop->await($unset);
        T2->is($unset->get, undef,
            'async environment unset accepts a captured session');
        my $closed = $async->close;
        $loop->await($closed);
        T2->ok($closed->is_done, 'facade close proves owned job cleanup');
        T2->is($sync->snapshot->sessions->count,
            1, 'closing facade preserves the borrowed tmux server');
    }
);
T2->done_testing;
