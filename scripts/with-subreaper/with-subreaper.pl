use v5.44;
use FindBin;
use lib "$FindBin::Bin/../../packages/core/lib";
use LibTmux::Platform::Linux;

# Run one owned Linux integration program as a child subreaper, so tmux
# daemons it leaks reparent to it instead of to init.
#
#   perl scripts/with-subreaper/with-subreaper.pl PROGRAM [ARGS...]
die "Usage: with-subreaper.pl PROGRAM [ARGS...]\n" unless @ARGV;
LibTmux::Platform::Linux::_subreaper();
exec {$ARGV[0]} @ARGV or die "exec $ARGV[0]: $!\n";
