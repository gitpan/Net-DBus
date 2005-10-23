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
# $Id: RemoteObject.pm,v 1.17 2005/10/23 16:28:44 dan Exp $

=pod

=head1 NAME

Net::DBus::RemoteObject - access objects on the bus

=head1 SYNOPSIS

  my $service = $bus->get_service("org.freedesktop.DBus");
  my $object = $service->get_object("/org/freedesktop/DBus");
  
  print "Names on the bus {\n";
  foreach my $name (sort $object->ListNames) {
      print "  ", $name, "\n";
  }
  print "}\n";

=head1 DESCRIPTION

This module provides the API for accessing remote objects available
on the bus. It uses the autoloader to fake the presence of methods
based on the API of the remote object. There is also support for 
setting callbacks against signals, and accessing properties of the
object.

=head1 METHODS

=over 4

=cut

package Net::DBus::RemoteObject;

use 5.006;
use strict;
use warnings;
use Carp;

our $AUTOLOAD;

use Net::DBus::Binding::Message::MethodCall;
use Net::DBus::Binding::Introspector;

=pod

=item my $object = Net::DBus::RemoteObject->new($service, $object_path[, $interface]);

Creates a new handle to a remote object. The C<$service> parameter is an instance
of the L<Net::DBus::RemoteService> method, and C<$object_path> is the identifier of
an object exported by this service, for example C</org/freedesktop/DBus>. For remote
objects which implement more than one interface it is possible to specify an optional
name of an interface as the third parameter. This is only really required, however, if 
two interfaces in the object provide methods with the same name, since introspection
data can be used to automatically resolve the correct interface to call cases where
method names are unique. Rather than using this constructor directly, it is preferrable
to use the C<get_object> method on L<Net::DBus::RemoteService>, since this caches handles
to remote objects, eliminating unneccessary introspection data lookups.

=cut


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};

    $self->{service} = shift;
    $self->{object_path}  = shift;
    $self->{interface} = @_ ? shift : undef;
    $self->{introspected} = 0;
    
    bless $self, $class;

    return $self;
}

=pod

=item my $object = $object->as_interface($interface);

Casts the object to a specific interface, returning a new instance of the
L<Net::DBus::RemoteObject> specialized to the desired interface. It is only
neccessary to cast objects to a specific interface, if two interfaces
export methods or signals with the same name, or the remote object does not
support introspection.

=cut

sub as_interface {
    my $self = shift;
    my $interface = shift;
    
    die "already cast to " . $self->{interface} . "'"
	if $self->{interface};

    return $self->new($self->{service},
		      $self->{object_path},
		      $interface);
}

=pod

=item my $service = $object->get_service

Retrieves a handle for the remote service on which this object is
attached. The returned object is an instance of L<Net::DBus::RemoteService>

=cut

sub get_service {
    my $self = shift;
    return $self->{service};
}

=pod

=item my $path = $object->get_object_path

Retrieves the unique path identifier for this object within the 
service.

=cut

sub get_object_path {
    my $self = shift;
    return $self->{object_path};
}

sub _introspector {
    my $self = shift;

    unless ($self->{introspected}) {
	my $call = Net::DBus::Binding::Message::MethodCall->
	    new(service_name => $self->{service}->get_service_name(),
		object_path => $self->{object_path},
		method_name => "Introspect",
		interface => "org.freedesktop.DBus.Introspectable");
	
	my $xml = eval {
	    my $reply = $self->{service}->
		get_bus()->
		get_connection()->
		send_with_reply_and_block($call, 60 * 1000);
	    
	    my $iter = $reply->iterator;
	    return $iter->get(&Net::DBus::Binding::Message::TYPE_STRING);
	};
	if ($@) {
	    if (UNIVERSAL::isa($@, "Net::DBus::Error") &&
		$@->{name} eq "org.freedesktop.DBus.Error.ServiceUnknown") {
		die $@;
	    } else {
		# Ignore other failures, since its probably
		# just that the object doesn't implement 
		# the introspect method. Of course without
		# the introspect method we can't tell for sure
		# if this is the case..
		#warn "could not introspect object: $@";
	    }
	}
	if ($xml) {
	    $self->{introspector} = Net::DBus::Binding::Introspector->new(xml => $xml,
									  object_path => $self->{object_path});
	}
	$self->{introspected} = 1;
    }
    return $self->{introspector};
}


=pod

=item $object->connect_to_signal($name, $coderef);

Connects a callback to a signal emitted by the object. The C<$name>
parameter is the name of the signal within the object, and C<$coderef>
is a reference to an anonymous subroutine. When the signal C<$name>
is emitted by the remote object, the subroutine C<$coderef> will be
invoked, and passed the parameters from the signal.

=cut

sub connect_to_signal {
    my $self = shift;
    my $name = shift;
    my $code = shift;

    my $interface = $self->{interface};
    if (!$interface) {
	my $ins = $self->_introspector;
	if (!$ins) {
	    die "no introspection data available for '" . $self->get_object_path . 
		"', and object is not cast to any interface";
	}
	my @interfaces = $ins->has_signal($name);
	
	if ($#interfaces == -1) {
	    die "no signal with name '$name' is exported in object '" .
		$self->get_object_path . "'\n";
	} elsif ($#interfaces > 0) {
	    warn "signal with name '$name' is exported " .
		"in multiple interfaces of '" . $self->get_object_path . "'" .
		"connecting to first interface only\n";
	}
	$interface = $interfaces[0];
    }

    $self->get_service->
	get_bus()->
	_add_signal_receiver(sub {
	    my $signal = shift;
	    my $ins = $self->_introspector;
	    my @params;
	    if ($ins) {
		@params = $ins->decode($signal, "signals", $signal->get_member, "params");
	    } else {
		@params = $signal->get_args_list;
	    }
	    &$code(@params);
	},
			     $name,
			     $interface,
			     $self->{service}->get_owner_name(),
			     $self->{object_path});
}


sub DESTROY {
    # No op merely to stop AutoLoader trying to
    # call DESTROY on remote object
}

sub AUTOLOAD {
    my $self = shift;
    my $sub = $AUTOLOAD;

    (my $name = $AUTOLOAD) =~ s/.*:://;

    my $interface = $self->{interface};
    my $ins = $self->_introspector();
    if ($ins) {
	my @interfaces = $ins->has_method($name);
	
	if (@interfaces) {
	    if ($#interfaces > 0) {
		warn "method with name '$name' is exported " .
		    "in multiple interfaces of '" . $self->get_object_path . "'" .
		    "calling first interface only\n";
	    }
	    return $self->_call_method($name, $interfaces[0], @_);
	}
	@interfaces = $ins->has_property($name);
	
	if (@interfaces) {
	    if ($#interfaces > 0) {
		warn "property with name '$name' is exported " .
		    "in multiple interfaces of '" . $self->get_object_path . "'" .
		    "calling first interface only\n";
	    }
	    if (@_) {
		$self->_call_method("Set", "org.freedesktop.DBus.Properties", $interfaces[0], $name, $_[0]);
		return ();
	    } else {
		return $self->_call_method("Get", "org.freedesktop.DBus.Properties", $interfaces[0], $name);
	    }
	}
	die "no method or property with name '$name' is exported in object '" .
	    $self->get_object_path . "'\n";
    } else {
	if (!$interface) {
	    die "no introspection data available for '" . $self->get_object_path . 
		"', and object is not cast to any interface";
	}
	
	return $self->_call_method($name, $interface, @_);
    }
}


sub _call_method {
    my $self = shift;
    my $name = shift;
    my $interface = shift;

    my $call = Net::DBus::Binding::Message::MethodCall->
	new(service_name => $self->{service}->get_service_name(),
	    object_path => $self->{object_path},
	    method_name => $name,
	    interface => $interface);

    my $ins = $self->_introspector;
    if ($ins) {
	$ins->encode($call, "methods", $name, "params", @_);
    } else {
	$call->append_args_list(@_);
    }

    my $reply = $self->{service}->
	get_bus()->
	get_connection()->
	send_with_reply_and_block($call, 60 * 1000);
    
    my @reply;
    if ($ins) {
	@reply = $ins->decode($reply, "methods", $name, "returns");
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

Copright (C) 2004-2005, Daniel Berrange. 

=head1 SEE ALSO

L<Net::DBus::RemoteService>, L<Net::DBus::Object>

=cut
