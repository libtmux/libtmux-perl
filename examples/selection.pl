use v5.44;
use FindBin;
use lib "$FindBin::Bin/../scripts/lib";
use LibTmuxFixture;
use LibTmux::Filter;
use List::Util qw(any first);
LibTmuxFixture->run(
    sub ($server, $root) {
        my $session = $server->new_session(
            name    => 'example',
            command => ['/bin/sleep', '120']
        );
        my $initial = $session->window_links->one->window->panes->one;
        $server->split_pane(
            pane       => $initial,
            horizontal => true,
            command    => ['/bin/sleep', '120']
        );
        my $snapshot = $server->snapshot;
        my $panes    = $snapshot->panes->where({current_command => 'sleep'})
            ->grep(sub ($pane) { $pane->width >= 1 });
        die 'expected two panes' unless $panes->count == 2;
        for my $pane ($panes->@*) {
            say $pane->id . ' ' . $pane->current_command;
        }
        my $only_active = $panes->one({active => true});
        die 'active pane unavailable' unless defined $only_active;
        my $has_active   = any { $_->active } $panes->@*;
        my $first_active = first { $_->active } $panes->@*;
        die 'List::Util alternatives differ'
            unless $has_active && $first_active->id eq $only_active->id;
        my @ids      = map  { $_->id } $panes->@*;
        my @positive = grep { $_->width > 0 } $panes->@*;
        die 'ordinary Perl arrays differ' unless @ids == 2 && @positive == 2;
        my $filter =
            LibTmux::Filter->new(entity => 'pane', where => {active => true});
        my $decoded = LibTmux::Filter->from_json($filter->to_json);
        die 'wire filter changed meaning'
            unless $panes->where($decoded)->one->id eq $only_active->id;
        my $retained = do {
            my $observed = $server->snapshot;
            $observed->pane_by_id($only_active->id);
        };
        die 'retained graph lost a relationship'
            unless $retained->window->panes->count == 2;
        my $same_child = $snapshot->windows->where(
            {panes => {-some => {-and => [{index => 0}, {index => 1}]}}});
        my $different_children = $snapshot->windows->where(
            {
                -and => [
                    {panes => {-some => {index => 0}}},
                    {panes => {-some => {index => 1}}}
                ]
            }
        );
        die 'quantifiers conflated children'
            unless $same_child->count == 0 && $different_children->count == 1;
        my $where = {active => true, width => {-gte => 1}};
        my $local = $server->query_panes(where => $where, pushdown => 'never');
        my $native =
            $server->query_panes(where => $where, pushdown => 'require');
        die 'native/local disagreement'
            unless join(',', map { $_->id } @$local) eq
            join(',', map { $_->id } @$native);
        say 'selection, wire, graph lifetime, quantifiers, and query: ok';
    }
);
