use v5.44;
use LibTmux::Server;

# Planning does no I/O, so this program needs no tmux server.
my $server = LibTmux::Server->new;

my $criteria = {active => true, width => {-gte => 1}};
my $plan     = $server->explain_panes(where => $criteria);
say 'tmux filter: ', $plan->to_data->{native_filter};

my $relation = {window => {-is => {name => 'editor'}}};
my $residual = $server->explain_panes(where => $relation);
say 'stays local: ', $residual->to_data->{residual_reasons}[0];

my $never = $server->explain_panes(where => $criteria, pushdown => 'never');
say 'pushdown off: ', $never->summary;
