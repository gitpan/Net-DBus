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
parameter should be an instrance of L<Net::DBus::Service>.
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
C<dbus_signal> method.

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

our $VERSION = '0.0.1';
our $ENABLE_INTROSPECT;

BEGIN {
    if ($ENV{DBUS_DISABLE_INTROSPECT}) {
	$ENABLE_INTROSPECT = 0;
    } else {
	$ENABLE_INTROSPECT = 1;
    }
}

use Net::DBus::RemoteObject;
use Net::DBus::Exporter "org.freedesktop.DBus.Introspectable";
use Net::DBus::Binding::Message::Error;
use Net::DBus::Binding::Message::MethodReturn;

dbus_method("Introspect", [], ["string"]);

sub new {
    my $class = shift;
    my $self = $class->_new(@_);
    
    $self->get_service->get_bus->get_connection->
	register_object_path($self->get_object_path,
			     sub {
				 $self->_dispatch(@_);
			     });

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
    my @args = @_;

    my $signal = Net::DBus::Binding::Message::Signal->new(object_path => $self->get_object_path,
							  interface => $interface, 
							  signal_name => $name);

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

sub emit_signal {
    my $self = shift;
    my $name = shift;
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
    $self->emit_signal_in($name, $interfaces[0], @args);
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
    
    $self->connect_to_signal_in($name, $code, $interfaces[0]);
}


sub _dispatch {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    my $reply;
    my $method_name = $message->get_member;
    if ($self->can($method_name)) {
	my $ins = $self->_introspector;
	my @args;
	if ($ins) {
	    @args = $ins->decode($message, "methods", $method_name, "params");
	} else {
	    @args = $message->get_args_list;
	}

	my @ret = eval {
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
    } elsif ($method_name eq "Introspect" &&
	     $self->_introspector &&
	     $ENABLE_INTROSPECT) {
	my $xml = $self->_introspector->format;
	$reply = Net::DBus::Binding::Message::MethodReturn->new(call => $message);
	
	$self->_introspector->encode($reply, "methods", $method_name, "returns", $xml);
    } else {
	$reply = Net::DBus::Binding::Message::Error->new(replyto => $message,
							 name => "org.freedesktop.DBus.Error.Failed",
							 description => "No such method " . ref($self) . "->" . $method_name);
    }
    
    $self->get_service->get_bus->get_connection->send($reply);
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
