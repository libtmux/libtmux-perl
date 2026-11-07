package LibTmux::Async;
use v5.44;
our $VERSION = '0.001_001';

=head1 NAME

LibTmux::Async - Optional Future-based libtmux execution

=head1 DESCRIPTION

The async distribution depends on L<LibTmux>, L<IO::Async>, and L<Future>.
Use L<LibTmux::Async::Server> or L<LibTmux::Async::Transport> with an explicitly supplied loop. Core
snapshot filtering remains local and synchronous. Async dependencies are not
required by the core or workspace distributions.

=cut
