# -*- perl -*-
#
# Copyright (C) 2004-2005 Daniel P. Berrange
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
# $Id: Bus.pm,v 1.11 2006/01/27 15:34:24 dan Exp $

=pod

=head1 NAME

Net::DBus::Binding::Bus - Handle to a well-known message bus instance

=head1 SYNOPSIS

  use Net::DBus::Binding::Bus;

  # Get a handle to the system bus
  my $bus = Net::DBus::Binding::Bus->new(type => &Net::DBus::Binding::Bus::SYSTEM);

=head1 DESCRIPTION

This is a specialization of the L<Net::DBus::Binding::Connection>
module providing convenience constructor for connecting to one of
the well-known bus types. There is no reason to use this module
directly, instead get a handle to the bus with the C<session> or
C<system> methods in L<Net::DBus>.

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Bus;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;

use base qw(Net::DBus::Binding::Connection);

=item my $bus = Net::DBus::Binding::Bus->new(type => $type);

=item my $bus = Net::DBus::Binding::Bus->new(address => $addr);

Open a connection to a message bus, either a well known bus type
specified using the C<type> parameter, or an arbitrary bus specified
using the C<address> parameter.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    
    my $connection;
    if (defined $params{type}) {
	$connection = Net::DBus::Binding::Bus::_open($params{type});
    } elsif (defined $params{address}) {
	$connection = Net::DBus::Binding::Connection::_open($params{address});
	$connection->dbus_bus_register();
    } else {
	confess "either type or address parameter is required";
    }
	  
    my $self = $class->SUPER::new(%params, connection => $connection);

    bless $self, $class;

    return $self;
}


=item $bus->request_name($service_name)

Send a request to the bus registering the well known name 
specified in the C<$service_name> parameter. If another client
already owns the name, registration will be queued up, pending
the exit of the other client.

=cut

sub request_name {
    my $self = shift;
    my $service_name = shift;
    
    $self->{connection}->dbus_bus_request_name($service_name);
}

=item my $name = $bus->get_unique_name

Returns the unique name by which this processes' connection to
the bus is known. Unique names are never re-used for the entire
lifetime of the bus daemon.

=cut

sub get_unique_name {
    my $self = shift;

    $self->{connection}->dbus_bus_get_unique_name;
}


=item $bus->add_match($rule)

Register a signal match rule with the bus controller, allowing
matching broadcast signals to routed to this client.

=cut

sub add_match {
    my $self = shift;
    my $rule = shift;
    
    $self->{connection}->dbus_bus_add_match($rule);
}

=item $bus->remove_match($rule)

Unregister a signal match rule with the bus controller, preventing
further broadcast signals being routed to this client

=cut

sub remove_match {
    my $self = shift;
    my $rule = shift;
    
    $self->{connection}->dbus_bus_remove_match($rule);
}

sub DESTROY {
    # Keep autoloader quiet
}

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;

    croak "&Net::DBus::Binding::Bus::constant not defined" if $constname eq '_constant';

    if (!exists $Net::DBus::Binding::Bus::_constants{$constname}) {
        croak "no such method $constname, and no constant \$Net::DBus::Binding::Bus::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Net::DBus::Binding::Bus::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}

1;

=pod

=back

=head1 SEE ALSO

L<Net::DBus::Binding::Connection>, L<Net::DBus>

=head1 AUTHOR

Daniel Berrange E<lt>dan@berrange.comE<gt>

=head1 COPYRIGHT

Copyright 2004-2005 by Daniel Berrange

=cut
