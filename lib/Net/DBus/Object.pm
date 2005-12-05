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
# $Id: Object.pm,v 1.19 2005/11/21 10:53:31 dan Exp $

=pod

=head1 NAME

Net::DBus::Exporter - exports methods and signals to the bus

=head1 SYNOPSIS

  # Connecting an object to the bus, under a service
  package main;

  use Net::DBus;

  # Attach to the bus
  my $bus = Net::DBus->find;

  # Acquire a service 'org.demo.Hello'
  my $service = $bus->export_service("org.demo.Hello");

  # Export our object within the service
  my $object = Demo::HelloWorld->new($service);

  ....rest of program...

  # Define a new package for the object we're going
  # to export
  package Demo::HelloWorld;

  # Specify the main interface provided by our object
  use Net::DBus::Exporter qw(org.example.demo.Greeter);

  # We're going to be a DBus object
  use base qw(Net::DBus::Object);

  # Export a 'Greeting' signal taking a stringl string parameter
  dbus_signal("Greeting", ["string"]);

  # Export 'Hello' as a method accepting a single string
  # parameter, and returning a single string value
  dbus_method("Hello", ["string"], ["string"]);

  sub new {
      my $class = shift;
      my $service = shift;
      my $self = $class->SUPER::new("/org/demo/HelloWorld", $service);
      
      bless $self, $class;
      
      return $self;
  }

  sub Hello {
    my $self = shift;
    my $name = shift;

    $self->emit_signal("Greeting", "Hello $name");
    return "Said hello to $name";
  }

  # Export 'Goodbye' as a method accepting a single string
  # parameter, and returning a single string, but put it
  # in the 'org.exaple.demo.Farewell' interface

  dbus_method("Goodbye", ["string"], ["string"], "org.example.demo.Farewell");

  sub Goodbye {
    my $self = shift;
    my $name = shift;

    $self->emit_signal("Greeting", "Goodbye $name");
    return "Said goodbye to $name";
  }
  
=head1 DESCRIPTION

This the base of all objects which are exported to the
message bus. It provides the core support for type introspection
required for objects exported to the message. When sub-classing
this object, methods can be created & tested as per normal Perl
modules. Then just as the L<Exporter> module is used to export 
methods within a script, the L<Net::DBus::Exporter> module is 
used to export methods (and signals) to the message bus.

All packages inheriting from this, will automatically have the 
interface C<org.freedesktop.DBus.Introspectable> registered
with L<Net::DBus::Exporter>, and the C<Introspect> method within
this exported.

=head1 METHODS

=over 4

=item my $object = Net::DBus::Object->new($path, $service)

This creates a new DBus object with an path of C<$path>
registered within the service C<$service>. The C<$path>
parameter should be a string complying with the usual
DBus requirements for object paths, while the C<$service>
parameter should be an instance of L<Net::DBus::Service>.
The latter is typically obtained by calling the C<export_service>
method on the L<Net::DBus> object.

=item my $service = $self->get_service

Retrieves the L<Net::DBus::Service> object within which this
object is exported.

=item my $path = $self->get_object_path

Retrieves the path under which this object is exported

=item $self->emit_signal($name, @args);

Emits a signal from the object, with a name of C<$name>. The
signal and the data types of the arguments C<@args> must have 
been registered with L<Net::DBus::Exporter> by calling the 
C<dbus_signal> method. The signal will be broadcast to all
clients on the bus.

=item $self->emit_signal_to($name, $client, @args);

Emits a signal from the object, with a name of C<$name>. The
signal and the data types of the arguments C<@args> must have 
been registered with L<Net::DBus::Exporter> by calling the 
C<dbus_signal> method. The signal will be sent only to the
client named by the C<$client> parameter.


=back

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Service>, L<Net::DBus::RemoteObject>,
L<Net::DBus::Exporter>.

=cut

package Net::DBus::Object;

use 5.006;
use strict;
use warnings;
use Carp;

our $ENABLE_INTROSPECT;

BEGIN {
    if ($ENV{DBUS_DISABLE_INTROSPECT}) {
	$ENABLE_INTROSPECT = 0;
    } else {
	$ENABLE_INTROSPECT = 1;
    }
}

use Net::DBus::Exporter "org.freedesktop.DBus.Introspectable";
use Net::DBus::Binding::Message::Error;
use Net::DBus::Binding::Message::MethodReturn;

dbus_method("Introspect", [], ["string"]);

dbus_method("Get", ["string", "string"], ["variant"], "org.freedesktop.DBus.Properties");
dbus_method("Set", ["string", "string", "variant"], [], "org.freedesktop.DBus.Properties");

sub new {
    my $class = shift;
    my $self = $class->_new(@_);
    
    $self->get_service->_register_object($self);

    return $self;
}

sub _new {
    my $class = shift;
    my $self = {};

    $self->{service} = shift;
    $self->{object_path} = shift;
    $self->{interface} = shift;
    $self->{introspector} = undef;
    $self->{introspected} = 0;
    $self->{callbacks} = {};

    bless $self, $class;
    
    return $self;
}


sub disconnect {
    my $self = shift;
    
    $self->get_service->_unregister_object($self);
}


sub get_service {
    my $self = shift;
    return $self->{service};
}

sub get_object_path {
    my $self = shift;
    return $self->{object_path};
}


sub emit_signal_in {
    my $self = shift;
    my $name = shift;
    my $interface = shift;
    my $destination = shift;
    my @args = @_;

    my $signal = Net::DBus::Binding::Message::Signal->new(object_path => $self->get_object_path,
							  interface => $interface, 
							  signal_name => $name);
    if ($destination) {
	$signal->set_destination($destination);
    }

    my $ins = $self->_introspector;
    if ($ins) {
	$ins->encode($signal, "signals", $name, "params", @args);
    } else {
	$signal->append_args_list(@args);
    }
    $self->get_service->get_bus->get_connection->send($signal);
    
    # Short circuit locally registered callbacks
    if (exists $self->{callbacks}->{$interface} &&
	exists $self->{callbacks}->{$interface}->{$name}) {
	my $cb = $self->{callbacks}->{$interface}->{$name};
	&$cb(@args);
    }
}

sub emit_signal_to {
    my $self = shift;
    my $name = shift;
    my $destination = shift;
    my @args = @_;

    my $intro = $self->_introspector;
    if (!$intro) {
	die "no introspection data available for '" . $self->get_object_path . 
	    "', use the emit_signal_in method instead";
    }
    my @interfaces = $intro->has_signal($name);
    if ($#interfaces == -1) {
	die "no signal with name '$name' is exported in object '" .
	    $self->get_object_path . "'\n";
    } elsif ($#interfaces > 0) {
	die "signal '$name' is exported in more than one interface of '" .
	    $self->get_object_path . "', use the emit_signal_in method instead.";
    }
    $self->emit_signal_in($name, $interfaces[0], $destination, @args);
}

sub emit_signal {
    my $self = shift;
    my $name = shift;
    my @args = @_;

    $self->emit_signal_to($name, undef, @args);
}   


sub connect_to_signal_in {
    my $self = shift;
    my $name = shift;
    my $interface = shift;
    my $code = shift;
    
    $self->{callbacks}->{$interface} = {} unless
	exists $self->{callbacks}->{$interface};
    $self->{callbacks}->{$interface}->{$name} = $code;
}

sub connect_to_signal {
    my $self = shift;
    my $name = shift;
    my $code = shift;

    my $ins = $self->_introspector;
    if (!$ins) {
	die "no introspection data available for '" . $self->get_object_path . 
	    "', use the connect_to_signal_in method instead";
    }
    my @interfaces = $ins->has_signal($name);
    
    if ($#interfaces == -1) {
	die "no signal with name '$name' is exported in object '" .
	    $self->get_object_path . "'\n";
    } elsif ($#interfaces > 0) {
	die "signal with name '$name' is exported " .
	    "in multiple interfaces of '" . $self->get_object_path . "'" .
	    "use the connect_to_signal_in method instead";
    }
    
    $self->connect_to_signal_in($name, $interfaces[0], $code);
}


sub _dispatch {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    my $reply;
    my $method_name = $message->get_member;
    my $interface = $message->get_interface;
    if ($interface eq "org.freedesktop.DBus.Introspectable") {
	if ($method_name eq "Introspect" &&
	    $self->_introspector &&
	    $ENABLE_INTROSPECT) {
	    my $xml = $self->_introspector->format;
	    $reply = Net::DBus::Binding::Message::MethodReturn->new(call => $message);
	    
	    $self->_introspector->encode($reply, "methods", $method_name, "returns", $xml);
	}
    } elsif ($interface eq "org.freedesktop.DBus.Properties") {
	if ($method_name eq "Get") {
	    $reply = $self->_dispatch_prop_read($message);
	} elsif ($method_name eq "Set") {
	    $reply = $self->_dispatch_prop_write($message);
	}
    } elsif ($self->can($method_name)) {
	my $ins = $self->_introspector;
	my @ret = eval {
	    my @args;
	    if ($ins) {
		@args = $ins->decode($message, "methods", $method_name, "params");
	    } else {
		@args = $message->get_args_list;
	    }

	    $self->$method_name(@args);
	};
	if ($@) {
	    $reply = Net::DBus::Binding::Message::Error->new(replyto => $message,
							     name => "org.freedesktop.DBus.Error.Failed",
							     description => $@);
	} else {
	    $reply = Net::DBus::Binding::Message::MethodReturn->new(call => $message);
	    if ($ins) {
		$self->_introspector->encode($reply, "methods", $method_name, "returns", @ret);
	    } else {
		$reply->append_args_list(@ret);
	    }
	}
    }
    
    if (!$reply) {
	$reply = Net::DBus::Binding::Message::Error->new(replyto => $message,
							 name => "org.freedesktop.DBus.Error.Failed",
							 description => "No such method " . ref($self) . "->" . $method_name);
    }
    
    $self->get_service->get_bus->get_connection->send($reply);
}


sub _dispatch_prop_read {
    my $self = shift;
    my $message = shift;
    my $method_name = shift;

    my $ins = $self->_introspector;
    
    if (!$ins) {
	return Net::DBus::Binding::Message::Error->new(replyto => $message,
						       name => "org.freedesktop.DBus.Error.Failed",
						       description => "no introspection data exported for properties");
    }
    
    my ($pinterface, $pname) = $ins->decode($message, "methods", "Get", "params");

    if (!$ins->has_property($pname, $pinterface)) {
	return Net::DBus::Binding::Message::Error->new(replyto => $message,
						       name => "org.freedesktop.DBus.Error.Failed",
						       description => "no property '$pname' exported in interface '$pinterface'");
    }
    
    if (!$ins->is_property_readable($pinterface, $pname)) {
	return Net::DBus::Binding::Message::Error->new(replyto => $message,
						       name => "org.freedesktop.DBus.Error.Failed",
						       description => "property '$pname' in interface '$pinterface' is not readable");
    }
    
    if ($self->can($pname)) {
	my $value = eval {
	    $self->$pname;
	};
	if ($@) {
	    return Net::DBus::Binding::Message::Error->new(replyto => $message,
							   name => "org.freedesktop.DBus.Error.Failed",
							   description => "error reading '$pname' in interface '$pinterface': $@");
	} else {
	    my $reply = Net::DBus::Binding::Message::MethodReturn->new(call => $message);
	    
	    $self->_introspector->encode($reply, "methods", "Get", "returns", $value);
	    return $reply;
	}
    } else {
	return Net::DBus::Binding::Message::Error->new(replyto => $message,
						       name => "org.freedesktop.DBus.Error.Failed",
						       description => "no method to read property '$pname' in interface '$pinterface'");
    }
}

sub _dispatch_prop_write {
    my $self = shift;
    my $message = shift;
    my $method_name = shift;

    my $ins = $self->_introspector;
    
    if (!$ins) {
	return Net::DBus::Binding::Message::Error->new(replyto => $message,
						       name => "org.freedesktop.DBus.Error.Failed",
						       description => "no introspection data exported for properties");
    }
    
    my ($pinterface, $pname, $pvalue) = $ins->decode($message, "methods", "Set", "params");
    
    if (!$ins->has_property($pname, $pinterface)) {
	return Net::DBus::Binding::Message::Error->new(replyto => $message,
						       name => "org.freedesktop.DBus.Error.Failed",
						       description => "no property '$pname' exported in interface '$pinterface'");
    }
    
    if (!$ins->is_property_writable($pinterface, $pname)) {
	return Net::DBus::Binding::Message::Error->new(replyto => $message,
						       name => "org.freedesktop.DBus.Error.Failed",
						       description => "property '$pname' in interface '$pinterface' is not writable");
    }
    
    if ($self->can($pname)) {
	eval {
	    $self->$pname($pvalue);
	};
	if ($@) {
	    return Net::DBus::Binding::Message::Error->new(replyto => $message,
							   name => "org.freedesktop.DBus.Error.Failed",
							   description => "error writing '$pname' in interface '$pinterface': $@");
	} else {
	    return Net::DBus::Binding::Message::MethodReturn->new(call => $message);
	}
    } else {
	return Net::DBus::Binding::Message::Error->new(replyto => $message,
						       name => "org.freedesktop.DBus.Error.Failed",
						       description => "no method to write property '$pname' in interface '$pinterface'");
    }
}

sub _introspector {
    my $self = shift;
    
    if (!$self->{introspected}) {
	$self->{introspector} = Net::DBus::Exporter::dbus_introspector($self);
	$self->{introspected} = 1;
    }
    return $self->{introspector};
}

1;
