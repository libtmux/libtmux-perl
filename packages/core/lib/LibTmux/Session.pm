package LibTmux::Session;
use v5.44;
use parent 'LibTmux::Entity';

sub attached     ($self) { $self->_read('attached') }
sub created      ($self) { $self->_read('created') }
sub id           ($self) { $self->_read('id') }
sub name         ($self) { $self->_read('name') }
sub path         ($self) { $self->_read('path') }
sub window_links ($self) { $self->_read('window_links') }

=head1 NAME

LibTmux::Session - Captured session entity

=head1 What is on here

A captured session holds what tmux reported when its snapshot was taken. Its
readers answer from that snapshot and run no tmux command, so capture again to
see later changes. They fall into the groups below.

B<Identifying.> The ID, such as C<$1>, stays the same for the session's life.
The name changes when the session is renamed. A L<LibTmux::Server> method takes
the handle in place of the ID.

=over 4

=item Stable ID: L<id|/id>

=item Name: L<name|/name>

=back

B<Describing.> When tmux created the session, how many clients were attached to
it, and the directory it started in. The creation time is an integer as tmux
reports it, and the path comes back as bytes.

=over 4

=item Creation time: L<created|/created>

=item Attached clients: L<attached|/attached>

=item Start directory: L<path|/path>

=back

B<Reaching windows.> A session reaches its windows through window links, because
one window can be linked into several sessions and carries its own index in
each. Each L<LibTmux::WindowLink> names its session, its window, its index, and
whether it is active in the session.

L<window_links|/window_links>

=head1 METHODS

=head2 attached

integer. Local captured data; no I/O.

=head2 created

integer. Local captured data; no I/O.

=head2 id

string. Local captured data; no I/O.

=head2 name

string. Local captured data; no I/O.

=head2 path

bytes. Local captured data; no I/O.

=head2 window_links

L<LibTmux::Selection> of L<LibTmux::WindowLink> entities. Local captured data; no I/O.

=head1 OWNERSHIP

Readers use the retained graph and never refresh it. Acquire a new snapshot for
new state. Inherited L<to_record|LibTmux::Entity/to_record> exports a detached scalar record.

=cut
