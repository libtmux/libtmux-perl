package LibTmux::Capabilities;
use v5.44;
use Storable qw(dclone);
use LibTmux::X;

my $minimum  = '3.3a';
my @features = (
    {
        id       => 'cursor-shape',
        since    => '3.6',
        summary  => 'Captured pane cursor shape',
        handling => 'refuse',
        error    => 'LibTmux::X::Unsupported',
        apis     => [
            'LibTmux::Pane/cursor_shape',
            'LibTmux::Server/listings',
            'LibTmux::Server/snapshot',
            'LibTmux::Server/query_panes',
            'LibTmux::Server/explain_panes',
            'LibTmux::QueryPlan/lowering',
            'LibTmux::Async::Server/listings',
            'LibTmux::Async::Server/snapshot',
            'LibTmux::Async::Server/query_panes',
            'LibTmux::Async::Server/explain_panes'
        ],
        commands => [{command => 'list-panes', format => 'cursor_shape'}]
    }
);

sub _minimum ($class) { $minimum }

sub _release ($class, $version) {
    return undef
        if !defined($version) || ref($version) || length($version) > 32;
    my $number = qr/(?:0|[1-9][0-9]{0,5})/;
    my ($next, $major, $minor, $patch, $rc) = $version =~
        /\A(next-)?($number)\.($number)(?:([a-z])|(-rc(?:$number)?))?\z/;
    return undef unless defined $major;
    return undef if $next && (defined($patch) || defined($rc));
    my $candidate = defined($rc) ? substr($rc, 3) : '';
    return [
        0 + $major,
        0 + $minor,
        $next              ? -2                         : defined($rc) ? -1 : 0,
        length($candidate) ? 0 + $candidate             : 0,
        defined($patch)    ? ord($patch) - ord('a') + 1 : 0
    ];
}

sub _at_least ($class, $version, $required) {
    my $got  = $class->_release($version);
    my $want = $class->_release($required);
    return false unless $got && $want;
    for my $index (0 .. $#$got) {
        return $got->[$index] > $want->[$index]
            if $got->[$index] != $want->[$index];
    }
    return true;
}

sub _feature ($class, $id) {
    if (defined($id) && !ref($id)) {
        for my $feature (@features) {
            return dclone($feature) if $feature->{id} eq $id;
        }
    }
    LibTmux::X::InvalidArgument->throw(message => 'unknown capability ID');
}

sub _manifest ($class) {
    return {
        schema       => 'libtmux-capabilities/1',
        port         => 'perl',
        minimum_tmux => $minimum,
        features     => dclone(\@features),
        workarounds  => []
    };
}

sub _from_identity ($class, $identity) {
    my $version = $identity->{version};
    LibTmux::X::Unsupported->throw(message =>
            'capability discovery requires a recognized tmux release at least '
            . $minimum)
        unless $class->_at_least($version, $minimum);
    my $rows = dclone(\@features);
    $_->{supported} = $class->_at_least($version, $_->{since}) for @$rows;
    return bless {
        version  => $version,
        identity =>
            {pid => $identity->{pid}, start_time => $identity->{start_time}},
        features => $rows
    }, $class;
}

sub version     ($self) { $self->{version} }
sub identity    ($self) { dclone($self->{identity}) }
sub features    ($self) { dclone($self->{features}) }
sub workarounds ($self) { [] }

sub status ($self, $id) {
    $self->_feature($id);
    for my $feature ($self->{features}->@*) {
        return dclone($feature) if $feature->{id} eq $id;
    }
}

sub supports ($self, $id) { $self->status($id)->{supported} }

=head1 NAME

LibTmux::Capabilities - Detached report from a running tmux daemon

=head1 DESCRIPTION

Obtain a report through L<LibTmux::Server/capabilities> or
L<LibTmux::Async::Server/capabilities>. It describes one observation, performs
no later I/O and grants no mutation authority. A later discovery may reach a
replacement daemon through the same connection settings.

The registry covers implemented optional gates. The support floor is separate
from feature availability. No Program or unimplemented workaround is listed.

=head1 METHODS

=head2 version

Return the observed daemon release, never the executable's C<-V> banner.
Development C<next-X.Y> and C<X.Y-rc[N]> releases precede C<X.Y>; patch letters
follow it. Unrecognized or below-floor releases fail during discovery with
L<LibTmux::X/Unsupported>.

=head2 identity

Return a fresh hashref containing decimal C<pid> and C<start_time> strings.
This identifies the observation; it is not a persistent connection binding.

=head2 features

Return a fresh arrayref of feature records. Each has C<id>, C<since>,
C<supported>, C<summary>, C<handling>, C<error>, C<apis> and C<commands>.
C<cursor-shape> describes L<LibTmux::Pane/cursor_shape> from tmux 3.6.

=head2 status

C<status($id)> returns a fresh feature record, including its Boolean
C<supported> decision. An unknown ID throws L<LibTmux::X/InvalidArgument>.

=head2 supports

C<supports($id)> returns the same Boolean decision. Unknown IDs throw
L<LibTmux::X/InvalidArgument>; they never silently mean unsupported.

=head2 workarounds

Return a fresh empty arrayref. This port registers no implemented workaround.
Returned identity and metadata containers, including nested values, are
detached copies; editing them changes neither the report nor native gates.

=cut
