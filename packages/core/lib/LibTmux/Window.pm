package LibTmux::Window;
use v5.44;
use parent 'LibTmux::Entity';

sub active_pane ($self) { $self->_read('active_pane') }
sub height      ($self) { $self->_read('height') }
sub id          ($self) { $self->_read('id') }
sub layout      ($self) { $self->_read('layout') }
sub links       ($self) { $self->_read('links') }
sub name        ($self) { $self->_read('name') }
sub panes       ($self) { $self->_read('panes') }
sub width       ($self) { $self->_read('width') }

=head1 NAME

LibTmux::Window - Captured window entity

=head1 What is on here

A captured window holds what tmux reported when its snapshot was taken. Its
readers answer from that snapshot and run no tmux command, so capture again to
see later changes. They fall into the groups below.

B<Identifying.> The ID, such as C<@2>, names the window itself in every session
that links it and stays the same for the window's life. A L<LibTmux::Server>
method takes the handle in place of that ID. The name is a label and changes
when the window is renamed.

=over 4

=item Stable ID: L<id|/id>

=item Name: L<name|/name>

=back

B<Size and layout.> Width and height count character cells. The layout is tmux's
native layout string, which L<select_layout|LibTmux::Server/select_layout>
accepts back.

=over 4

=item Size in cells: L<width|/width>, L<height|/height>

=item Layout string: L<layout|/layout>

=back

B<Reaching panes and links.> A window holds its panes directly and reaches the
sessions that link it through its window links, one per link. Its active pane is
C<undef> when the snapshot holds none.

=over 4

=item Panes: L<panes|/panes>

=item Active pane: L<active_pane|/active_pane>

=item Links into sessions: L<links|/links>

=back

=head1 METHODS

=head2 active_pane

L<LibTmux::Pane> entity or undef. Local captured data; no I/O.

=head2 height

integer. Local captured data; no I/O.

=head2 id

string. Local captured data; no I/O.

=head2 layout

string. Local captured data; no I/O.

=head2 links

L<LibTmux::Selection> of L<LibTmux::WindowLink> entities. Local captured data; no I/O.

=head2 name

string. Local captured data; no I/O.

=head2 panes

L<LibTmux::Selection> of L<LibTmux::Pane> entities. Local captured data; no I/O.

=head2 width

integer. Local captured data; no I/O.

=head1 OWNERSHIP

Readers use the retained graph and never refresh it. Acquire a new snapshot for
new state. Inherited L<to_record|LibTmux::Entity/to_record> exports a detached scalar record.

=cut
