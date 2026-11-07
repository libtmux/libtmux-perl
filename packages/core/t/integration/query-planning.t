use v5.44;
use Test2::V1;
use LibTmuxFixture;
LibTmuxFixture->run(
    sub ($server, $root) {
        my $session = $server->new_session(
            name    => 'query-plan',
            command => ['/bin/sleep', '120']
        );
        my $pane = $session->window_links->one->window->panes->one;
        $server->split_pane(
            pane       => $pane,
            horizontal => true,
            command    => ['/bin/sleep', '120']
        );
        my $literal = 'literal,#} back\\slash';
        $server->set_title(pane => $pane, title => $literal);
        for my $where (
            {title => $literal},
            {-or   => [{title => $literal}, {width => {-lt => 1}}]},
            {-not  => {active  => false}},
            {width => {-not_in => []}},
            {-not  => {width   => {-in => []}}}
            )
        {
            my $local =
                $server->query_panes(where => $where, pushdown => 'never');
            my $native =
                $server->query_panes(where => $where, pushdown => 'require');
            T2->is(
                [map { $_->id } @$native],
                [map { $_->id } @$local],
'exact lowering preserves results with literal punctuation and Boolean composition'
            );
        }
        my $partial =
            {width => {-gte => 1}, title => {-contains => 'literal,'}};
        T2->is(
            $server->query_panes(where => $partial, pushdown => 'auto')->count,
            1,
            'safe AND pruning retains local literal residual'
        );
        my $error;
        try { $server->query_panes(where => $partial, pushdown => 'require') }
        catch ($caught) {
            $error = $caught
        }
        T2->ok(ref($error) && $error->isa('LibTmux::X::Unsupported'),
            'require refuses incomplete lowering');
        my $short = {-or => [{}, {cursor_shape => 'block'}]};
        T2->is(
            $server->query_panes(where => $short, pushdown => 'auto')->count,
            2,
'OR cannot push one branch and preserves availability short-circuiting'
        );
        my $plan =
            $server->explain_panes(where => {window => {-is => {name => 'x'}}})
            ->to_data;
        T2->ok(
            $plan->{required_relations}
                && $plan->{required_relations}[0]{field} eq 'window',
            'plan identifies required relation acquisition'
        );
    }
);
T2->done_testing;
