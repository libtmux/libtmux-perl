package LibTmux::Workspace::X;
use v5.44;
use LibTmux::X;

package LibTmux::Workspace::X::Config { use parent -norequire, 'LibTmux::X' }

package LibTmux::Workspace::X::Conflict { use parent -norequire, 'LibTmux::X' }

package LibTmux::Workspace::X::Load {
    use parent -norequire, 'LibTmux::X';
    sub report ($self) { $self->{report} }
    sub cause  ($self) { $self->{cause} }
}

=head1 NAME

LibTmux::Workspace::X - Workspace configuration and partial-load failures

=head1 EXCEPTIONS

=head2 Config

Invalid versioned configuration. C<path> identifies the rejected input.

=head2 Conflict

An existing session conflicts with the selected repeat-application policy.
No session is created until all names pass the conflict check.

=head2 Load

C<cause> retains the original exception. C<report> records completed steps,
the failed step, dispatch uncertainty, and cleanup errors. Rollback affects
only sessions whose creation was proven by returned core handles.
See L<LibTmux::Workspace/load> and L<LibTmux::X>.

=head1 METHODS

=head2 report

For Load exceptions, return the partial-load report. It contains created IDs,
completed and failed steps, dispatch uncertainty, and cleanup failures.

=head2 cause

For Load exceptions, return the original core or orchestration failure object.

=cut
