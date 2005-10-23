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
# $Id: Server.pm,v 1.3 2005/10/15 13:31:42 dan Exp $

=pod

=head1 NAME

Net::DBus::Binding::Server - A server to accept incoming connections

=head1 SYNOPSIS

Creating a new server and accepting client connections

  use Net::DBus::Binding::Server;

  my $server = Net::DBus::Binding::Server->new(address => "unix:path=/path/to/socket");

  $server->connection_callback(\&new_connection);

  sub new_connection {
      my $connection = shift;

      .. work with new connection...
  }

Managing the server and new connections in an event loop

  my $reactor = Net::DBus::Binding::Reactor->new();

  $reactor->manage($server);
  $reactor->run();

  sub new_connection {
      my $connection = shift;
	
      $reactor->manage($connection);
  }


=head1 DESCRIPTION

A server for receiving connection from client programs.
The methods defined on this module have a close
correspondance to the dbus_server_XXX methods in the C API,
so for further details on their behaviour, the C API documentation
may be of use.

=head1 METHODS

=over 

=cut

package Net::DBus::Binding::Server;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;
use Net::DBus::Binding::Connection;

=pod

=item my $server = Net::DBus::Binding::Server->new(address => "unix:path=/path/to/socket");

Creates a new server binding it to the socket specified by the
C<address> parameter.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    $self->{address} = exists $params{address} ? $params{address} : confess "address parameter is required";
    $self->{server} = Net::DBus::Binding::Server::_open($self->{address});

    bless $self, $class;

    $self->{server}->_set_owner($self);

    $self->{_callback} = sub {
	my $server = shift;
	my $rawcon = shift;
	my $con = Net::DBus::Binding::Connection->new(connection => $rawcon);

	if ($server->{connection_callback}) {
	    &{$server->{connection_callback}}($server, $con);
	}
    };

    return $self;
}

=pod

=item $status = $server->is_connected();

Returns zero if the server has been disconnected,
otherwise a positive value is returned.

=cut


sub is_connected {
    my $self = shift;
    
    return $self->{server}->dbus_server_get_is_connected();
}

=pod

=item $server->disconnect()

Closes this server to the remote host. This method
is called automatically during garbage collection (ie
in the DESTROY method) if the programmer forgets to
explicitly disconnect.

=cut

sub disconnect {
    my $self = shift;
    
    return $self->{server}->dbus_server_disconnect();
}


=pod

=item $server->set_watch_callbacks(\&add_watch, \&remove_watch, \&toggle_watch);

Register a set of callbacks for adding, removing & updating 
watches in the application's event loop. Each parameter
should be a code reference, which on each invocation, will be
supplied with two parameters, the server object and the
watch object. If you are using a C<Net::DBus::Binding::Reactor> object
as the application event loop, then the 'manage' method on
that object will call this on your behalf.

=cut


sub set_watch_callbacks {
    my $self = shift;
    my $add = shift;
    my $remove = shift;
    my $toggled = shift;

    $self->{add_watch} = $add;
    $self->{remove_watch} = $remove;
    $self->{toggled_watch} = $toggled;

    $self->{server}->_set_watch_callbacks();
}

=pod

=item $server->set_timeout_callbacks(\&add_timeout, \&remove_timeout, \&toggle_timeout);

Register a set of callbacks for adding, removing & updating 
timeouts in the application's event loop. Each parameter
should be a code reference, which on each invocation, will be
supplied with two parameters, the server object and the
timeout object. If you are using a C<Net::DBus::Binding::Reactor> object
as the application event loop, then the 'manage' method on
that object will call this on your behalf.

=cut

sub set_timeout_callbacks {
    my $self = shift;
    my $add = shift;
    my $remove = shift;
    my $toggled = shift;

    $self->{add_timeout} = $add;
    $self->{remove_timeout} = $remove;
    $self->{toggled_timeout} = $toggled;

    $self->{server}->_set_timeout_callbacks();
}

=pod

=item $server->set_connection_callback(\&handler)

Registers the handler to use for dealing with
new incoming connections from clients. The code
reference will be invoked each time a new client
connects and supplied with a single parameter
which is the C<Net::DBus::Binding::Connection> object representing
the client.

=cut

sub set_connection_callback {
    my $self = shift;
    my $callback = shift;

    $self->{connection_callback} = $callback;

    $self->{server}->_set_connection_callback();
}


1;


=pod

=back

=head1 SEE ALSO

L<Net::DBus::Binding::Connection>, L<Net::DBus::Binding::Bus>, L<Net::DBus::Binding::Message::Signal>, L<Net::DBus::Binding::Message::MethodCall>, L<Net::DBus::Binding::Message::MethodReturn>, L<Net::DBus::Binding::Message::Error>

=head1 AUTHOR

Daniel Berrange E<lt>dan@berrange.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Daniel Berrange

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
