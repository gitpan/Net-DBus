# -*- perl -*-
#
# Copyright (C) 2006 Daniel P. Berrange
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# $Id: RemoteObject.pm,v 1.20 2006/01/27 15:34:24 dan Exp $

=pod

=head1 NAME

Net::DBus::ASyncReply - asynchronous method reply handler

=head1 SYNOPSIS

  use Net::DBus::Annotation qw(:call);

  my $object = $service->get_object("/org/example/systemMonitor");

  # List processes & get on with other work until
  # the list is returned.
  my $asyncreply = $object->list_processes(dbus_call_async, "someuser");

  while (!$asyncreply->is_ready) {
    ... do some background work..
  }

  my $processes = $asyncreply->get_result;


=head1 DESCRIPTION

This object provides a handler for receiving asynchronous
method replies. An asynchronous reply object is generated
when making remote method call with the C<dbus_call_async>
annotation set.

=head1 METHODS

=over 4

=cut

package Net::DBus::ASyncReply;

use strict;
use warnings;


sub _new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{pending_call} = $params{pending_call} ? $params{pending_call} : die "pending_call parameter is required";
    $self->{introspector} = $params{introspector} ? $params{introspector} : undef;
    $self->{method_name} = $params{method_name} ? $params{method_name} : ($self->{introspector} ? die "method_name is parameter required for introspection" : undef);

    bless $self, $class;

    return $self;
}


=item $asyncreply->discard_result;

Indicates that the caller is no longer interested in
recieving the reply & that it should be discarded. After
calling this method, this object should not be used again.

=cut

sub discard_result {
    my $self = shift;

    $self->{pending_call}->cancel;
}


=item $asyncreply->wait_for_result;

Blocks the caller waiting for completion of the of the
asynchronous reply. Upon returning from this method, the
result can be obtained with the C<get_result> method.

=cut

sub wait_for_result {
    my $self = shift;

    $self->{pending_call}->block;
}

=item my $boolean = $asyncreply->is_ready;

Returns a true value if the asynchronous reply is now
complete (or a timeout has occurred). When this method
returns true, the result can be obtained with the C<get_result>
method.

=cut

sub is_ready {
    my $self = shift;

    return $self->{pending_call}->get_completed;
}


=item my @data = $asyncreply->get_result;

Retrieves the data associated with the asynchronous reply.
If a timeout occurred, then this method will throw an
exception. This method can only be called once the reply
is complete, as indicated by the C<is_ready> method
returning a true value. After calling this method, this
object should no longer be used.

=cut

sub get_result {
    my $self = shift;

    my $reply = $self->{pending_call}->get_reply;

    my @reply;
    if ($self->{introspector}) {
	@reply = $self->{introspector}->decode($reply, "methods", $self->{method_name}, "returns");
    } else {
	@reply = $reply->get_args_list;
    }

    return wantarray ? @reply : $reply[0];
}

1;

=pod

=back

=head1 AUTHOR

Daniel Berrange <dan@berrange.com>

=head1 COPYRIGHT

Copright (C) 2006, Daniel Berrange.

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::RemoteObject>, L<Net::DBus::Annotation>

=cut
