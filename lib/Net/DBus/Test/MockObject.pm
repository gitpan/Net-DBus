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
# $Id: MockObject.pm,v 1.1 2005/11/21 11:37:04 dan Exp $

=pod

=head1 NAME

Net::DBus::Test::MockObject - a 'mock' object for use in test suites

=head1 SYNOPSIS

  use Net::DBus;
  use Net::DBus::Test::MockObject;

  my $bus = Net::DBus->test

  # Lets fake presence of HAL...

  # First we need to define the service 
  my $service = $bus->export_service("org.freedesktop.Hal");

  # Then create a mock object
  my $object = Net::DBus::Test::MockObject->new($service,
                                                "/org/freedesktop/Hal/Manager");

  # Fake the 'GetAllDevices' method
  $object->seed_action("org.freedesktop.Hal.Manager", 
                       "GetAllDevices",
                       reply => {
                         return => [ "/org/freedesktop/Hal/devices/computer_i8042_Aux_Port",
                                     "/org/freedesktop/Hal/devices/computer_i8042_Aux_Port_logicaldev_input",
                                     "/org/freedesktop/Hal/devices/computer_i8042_Kbd_Port",
                                     "/org/freedesktop/Hal/devices/computer_i8042_Kbd_Port_logicaldev_input"
                         ],
                       });


  # Now can test any class which calls out to 'GetAllDevices' in HAL
  ....test stuff....

=head1 DESCRIPTION

This provides an alternate for L<Net::DBus::Object> to enable bus 
objects to be quickly mocked up, thus facilitating creation of unit 
tests for services which may need to call out to objects provided
by 3rd party services on the bus. It is typically used as a companion
to the L<Net::DBus::MockBus> object, to enable complex services to
be tested without actually starting a real bus.

!!!!! WARNING !!!

This object & its APIs should be considered very experimental at
this point in time, and no guarentees about future API compatability
are provided what-so-ever. Comments & suggestions on how to evolve
this framework are, however, welcome & encouraged.

=head1 METHODS

=over 4

=cut

package Net::DBus::Test::MockObject;

use strict;
use warnings;

use Net::DBus::Binding::Message::MethodReturn;
use Net::DBus::Binding::Message::Error;

=pod

=item my $object = Net::DBus::Test::MockObject->new($service, $path, $interface);

Create a new mock object, attaching to the service defined by the C<$service>
parameter. This would be an instance of the L<Net::DBus::Service> object. The
C<$path> parameter defines the object path at which to attach this mock object,
and C<$interface> defines the interface it will support.

=cut

sub new {
    my $class = shift;
    my $self = {};
 
    $self->{service} = shift;
    $self->{object_path} = shift;
    $self->{interface} = shift;
    $self->{actions} = {};
    $self->{message} = shift;

    bless $self, $class;
   
    $self->get_service->_register_object($self);

    return $self;
}



sub get_service {
    my $self = shift;
    return $self->{service};
}

sub get_object_path {
    my $self = shift;
    return $self->{object_path};
}

sub get_last_message {
    my $self = shift;
    return $self->{message};
}

sub get_last_message_signature {
    my $self = shift;
    return $self->{message}->get_signature;
}

sub get_last_message_param {
    my $self = shift;
    my @args = $self->{message}->get_args_list;
    return $args[0];
}

sub get_last_message_param_list {
    my $self = shift;
    my @args = $self->{message}->get_args_list;
    return \@args;
}

sub seed_action {
    my $self = shift;
    my $interface = shift;
    my $method = shift;
    my %action = @_;
    
    $self->{actions}->{$method} = {} unless exists $self->{actions}->{$method};
    $self->{actions}->{$method}->{$interface} = \%action;
}

sub _dispatch {
    my $self = shift;
    my $connection = shift;
    my $message = shift;
    
    my $interface = $message->get_interface;
    my $method = $message->get_member;

    if (!exists $self->{actions}->{$method}) {
	my $error = Net::DBus::Binding::Message::Error->new(replyto => $message,
							    name => "org.freedesktop.DBus.Failed",
							    description => "no action seeded for method " . $message->get_member);
	$self->get_service->get_bus->get_connection->send($error);
	return;
    }
    
    my $action;
    if ($interface) {
	if (!exists $self->{actions}->{$method}->{$interface}) {
	    my $error = Net::DBus::Binding::Message::Error->new(replyto => $message,
								name => "org.freedesktop.DBus.Failed",
								description => "no action with correct interface seeded for method " . $message->get_member);
	    $self->get_service->get_bus->get_connection->send($error);
	    return;
	}
	$action = $self->{actions}->{$method}->{$interface};
    } else {
	my @interfaces = keys %{$self->{actions}->{$method}};
	if ($#interfaces > 0) {
	    my $error = Net::DBus::Binding::Message::Error->new(replyto => $message,
								name => "org.freedesktop.DBus.Failed",
								description => "too many actions seeded for method " . $message->get_member);
	    $self->get_service->get_bus->get_connection->send($error);
	    return;
	}
	$action = $self->{actions}->{$method}->{$interfaces[0]};
    }

    if (exists $action->{signals}) {
	my $sigs = $action->{signals};
	if (ref($sigs) ne "ARRAY") {
	    $sigs = [ $sigs ];
	}
	foreach my $sig (@{$sigs}) {
	    $self->get_service->get_bus->get_connection->send($sig);
	}
    }

    $self->{message} = $message;
    
    if (exists $action->{error}) {
	my $error = Net::DBus::Binding::Message::Error->new(replyto => $message,
							    name => $action->{error}->{name},
							    description => $action->{error}->{description});
	$self->get_service->get_bus->get_connection->send($error);
    } elsif (exists $action->{reply}) {
	my $reply = Net::DBus::Binding::Message::MethodReturn->new(call => $message);
	my $iter = $reply->iterator(1);
	foreach my $value (@{$action->{reply}->{return}}) {
	    $iter->append($value);
	}
	$self->get_service->get_bus->get_connection->send($reply);
    }
}


1;

=pod

=head1 BUGS

It doesn't completely replicate the API of L<Net::DBus::Binding::Object>, 
merely enough to make the high level bindings work in a test scenario.

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Object>, L<Net::DBus::Test::MockConnection>,
L<http://www.mockobjects.com/Faq.html>

=head1 COPYRIGHT

Copyright 2005 Daniel Berrange <dan@berrange.com>

=cut
