package LibTmux::Pane;
use v5.44;
use parent 'LibTmux::Entity';

sub active          ($self) { $self->_read('active') }
sub current_command ($self) { $self->_read('current_command') }
sub current_path    ($self) { $self->_read('current_path') }
sub cursor_shape    ($self) { $self->_read('cursor_shape') }
sub dead            ($self) { $self->_read('dead') }
sub exit_status     ($self) { $self->_read('exit_status') }
sub height          ($self) { $self->_read('height') }
sub id              ($self) { $self->_read('id') }
sub index           ($self) { $self->_read('index') }
sub pid             ($self) { $self->_read('pid') }
sub title           ($self) { $self->_read('title') }
sub width           ($self) { $self->_read('width') }
sub window          ($self) { $self->_read('window') }

=head1 NAME

LibTmux::Pane - Captured pane entity

=head1 What is on here

A captured pane holds what tmux reported when its snapshot was taken. Its
readers answer from that snapshot and run no tmux command, so capture again to
see later changes. They fall into the groups below.

B<Identifying.> Name a pane by its tmux ID, such as C<%3>, which stays the same
for the pane's life. A L<LibTmux::Server> method takes the handle in place of
that ID. The index is the pane's position in its window, and the title is
whatever the application set.

=over 4

=item Stable ID: L<id|/id>

=item Position in the window: L<index|/index>

=item Title: L<title|/title>

=back

B<Running.> Read what the pane runs: the foreground command, the working
directory of its process, and the PID tmux started in it. A pane whose process
has exited and that tmux kept reports C<dead> as true, and its C<exit_status> is
C<undef> when tmux reports none.

=over 4

=item Foreground command: L<current_command|/current_command>

=item Working directory: L<current_path|/current_path>

=item Process ID: L<pid|/pid>

=item Exit state: L<dead|/dead>, L<exit_status|/exit_status>

=back

B<Size and focus.> Width and height count character cells, and the active pane
is the one its window currently selects. The cursor shape needs tmux 3.6 or
newer; reading it from an older daemon's snapshot throws
L<LibTmux::X::Unsupported|LibTmux::X/Unsupported>.

=over 4

=item Size in cells: L<width|/width>, L<height|/height>

=item Active in its window: L<active|/active>

=item Cursor shape: L<cursor_shape|/cursor_shape>

=back

B<Reaching the window.> The window that holds the pane, as a captured
L<LibTmux::Window> resolved in the same graph.

L<window|/window>

=head1 METHODS

=head2 active

boolean. Local captured data; no I/O.

=head2 current_command

string. Local captured data; no I/O.

=head2 current_path

bytes. Local captured data; no I/O.

=head2 cursor_shape

string. Local captured data; no I/O.

=head2 dead

boolean. Local captured data; no I/O.

=head2 exit_status

integer or undef. Local captured data; no I/O.

=head2 height

integer. Local captured data; no I/O.

=head2 id

string. Local captured data; no I/O.

=head2 index

integer. Local captured data; no I/O.

=head2 pid

integer. Local captured data; no I/O.

=head2 title

string. Local captured data; no I/O.

=head2 width

integer. Local captured data; no I/O.

=head2 window

L<LibTmux::Window> entity. Local captured data; no I/O.

=head1 OWNERSHIP

Readers use the retained graph and never refresh it. Acquire a new snapshot for
new state. Inherited L<to_record|LibTmux::Entity/to_record> exports a detached scalar record.

=cut
