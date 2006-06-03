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

Net::DBus::Annotation - annotations for changing behaviour of APIs

=head1 SYNOPSIS

  use Net::DBus::Annotation qw(:call);

  my $object = $service->get_object("/org/example/systemMonitor");

  # Block until processes are listed
  my $processes = $object->list_processes("someuser");

  # Just throw away list of processes, pretty pointless
  # in this example, but useful if the method doesn't have
  # a return value
  $object->list_processes(dbus_call_noreply, "someuser");

  # List processes & get on with other work until
  # the list is returned.
  my $asyncreply = $object->list_processes(dbus_call_async, "someuser");

  ... some time later...
  my $processes = $asyncreply->get_data;

=head1 DESCRIPTION

This module provides a number of annotations which will be useful
when dealing with the DBus APIs. There are annotations for switching
remote calls between sync, async and no-reply mode. More annotations
may be added over time.

=head1 METHODS

=over 4

=cut

package Net::DBus::Annotation;

use strict;
use warnings;

our $CALL_SYNC = "sync";
our $CALL_ASYNC = "async";
our $CALL_NOREPLY = "noreply";

bless \$CALL_SYNC, __PACKAGE__;
bless \$CALL_ASYNC, __PACKAGE__;
bless \$CALL_NOREPLY, __PACKAGE__;

require Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dbus_call_sync dbus_call_async dbus_call_noreply);
our %EXPORT_TAGS = (call => [qw(dbus_call_sync dbus_call_async dbus_call_noreply)]);

=item dbus_call_sync

Requests that a method call be performed synchronously, waiting
for the reply or error return to be received before continuing.

=cut

sub dbus_call_sync() {
    return \$CALL_SYNC;
}


=item dbus_call_async

Requests that a method call be performed a-synchronously, returning
a pending call object, which will collect the reply when it eventually
arrives.

=cut

sub dbus_call_async() {
    return \$CALL_ASYNC;
}

=item dbus_call_noreply

Requests that a method call be performed a-synchronously, discarding
any possible reply or error message.

=cut

sub dbus_call_noreply() {
    return \$CALL_NOREPLY;
}

1;

=pod

=back

=head1 AUTHOR

Daniel Berrange <dan@berrange.com>

=head1 COPYRIGHT

Copright (C) 2006, Daniel Berrange.

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::RemoteObject>

=cut
