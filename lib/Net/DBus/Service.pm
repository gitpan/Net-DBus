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
# $Id: Service.pm,v 1.9 2005/10/15 15:39:35 dan Exp $

=pod

=head1 NAME

Net::DBus::Service - represents a service exported to the message bus

=head1 SYNOPSIS

  package main;

  use Net::DBus;

  # Attach to the bus
  my $bus = Net::DBus->find;

  # Acquire a service 'org.demo.Hello'
  my $service = $bus->export_service("org.demo.Hello");

  # Export our object within the service
  my $object = Demo::HelloWorld->new($service);

  ....rest of program...

=head1 DESCRIPTION

This module represents a service which is exported to the message
bus. Once a service has been exported, it is possible to create
and export objects to the bus.

=head1 METHODS

=over 4

=cut


package Net::DBus::Service;

=pod

=item my $service = Net::DBus::Service->new($bus, $name);

Create a new service, attaching to the bus provided in
the C<$bus> parameter, which should be an instance of
the L<Net::DBus> object. The C<$name> parameter is the
qualified service name. It is not usually neccessary to
use this constructor, since services can be created via
the C<export_service> method on the L<Net::DBus> object.

=cut

sub new {
    my $class = shift;
    my $self = {};

    $self->{bus} = shift;
    $self->{service_name} = shift;
    $self->{objects} = {};
    
    bless $self, $class;

    $self->get_bus->get_connection->request_name($self->get_service_name);

    my $exp = Net::DBus::Service::Exporter->new($self);
    $self->{exporter} = $exp;

    return $self;
}

=pod

=item my $bus = $service->get_bus;

Retrieves the L<Net::DBus> object to which this service is
attached.

=cut

sub get_bus {
    my $self = shift;
    return $self->{bus};
}

=pod

=item my $name = $service-.get_service_name

Retrieves the qualified name by which this service is 
known on the bus.

=cut

sub get_service_name {
    my $self = shift;
    return $self->{service_name};
}


sub _register_object {
    my $self = shift;
    my $object = shift;
    
    $self->get_bus->get_connection->
	register_object_path($object->get_object_path,
			     sub {
				 $object->_dispatch(@_);
			     });
    
    if ($self->{exporter}) {
	$self->{exporter}->register($object->get_object_path);
    }
}


sub _unregister_object {
    my $self = shift;
    my $object = shift;

    $self->get_bus->get_connection->
	unregister_object_path($object->get_object_path);
    
    if ($self->{exporter}) {
	$self->{exporter}->unregister($object->get_object_path);
    }
}

1;

package Net::DBus::Service::Exporter;

use base qw(Net::DBus::Object);
use strict;
use Net::DBus::Exporter qw(org.cpan.Net.DBus.Exporter);

dbus_method("ListObjects", [], [["array", "string"]]);
dbus_signal("ObjectRegistered", ["string"]);
dbus_signal("ObjectUnregistered", ["string"]);

sub new {
    my $class = shift;
    my $service = shift;
    my $self = $class->SUPER::new($service, "/org/cpan/Net/DBus/Exporter");
    
    $self->{objects} = {"/org/cpan/Net/DBus/Exporter" => 1};
    
    bless $self, $class;

    return $self;
}

sub register {
    my $self = shift;
    my $path = shift;
    
    $self->{objects}->{$path} = 1;
    
    $self->emit_signal("ObjectRegistered", $path);
}

sub unregister {
    my $self = shift;
    my $path = shift;
    
    delete $self->{objects}->{$path};
    
    $self->emit_signal("ObjectUnregistered", $path);
}


sub ListObjects {
    my $self = shift;
    
    my @objs = sort { $a cmp $b } keys %{$self->{objects}};
    return \@objs;
}

=pod

=back

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Object>, L<Net::DBus::RemoteService>

=cut
