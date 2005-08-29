package Net::DBus::RemoteObject;

use 5.006;
use strict;
use warnings;
use Carp;

our $VERSION = '0.0.1';
our $AUTOLOAD;

use Net::DBus::Binding::Message::MethodCall;
use Net::DBus::Binding::Introspector;

sub new {
    my $class = shift;
    my $self = {};

    $self->{service} = shift;
    $self->{object_path}  = shift;
    $self->{interface} = @_ ? shift : undef;
    $self->{introspected} = 0;
    
    bless $self, $class;

    return $self;
}

sub as_interface {
    my $self = shift;
    my $interface = shift;
    
    die "already cast to " . $self->{interface} . "'"
	if $self->{interface};

    return $self->new($self->{service},
		      $self->{object_path},
		      $interface);
}

sub get_service {
    my $self = shift;
    return $self->{service};
}

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
		send_with_reply_and_block($call, 5000);
	    
	    my $iter = $reply->iterator;
	    return $iter->get(&Net::DBus::Binding::Message::TYPE_STRING);
	};
	# Ignore failures
	#if ($@) {
	#    warn "could not introspect object: $@";
	#}
	if ($xml) {
	    $self->{introspector} = Net::DBus::Binding::Introspector->new(xml => $xml,
									  object_path => $self->{object_path});
	}
	$self->{introspected} = 1;
    }
    return $self->{introspector};
}

sub connect_to_signal {
    my $self = shift;
    my $name = shift;
    my $code = shift;
    my $lazy_binding = shift;

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
	add_signal_receiver(sub {
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
			    $lazy_binding ? undef : $self->{service}->get_service_name(),
			    $self->{object_path});
}

sub DESTROY {
    # No op merely to stop AutoLoader trying to
    # call DESTROY on remote object
}

sub AUTOLOAD {
    my $self = shift;
    my $sub = $AUTOLOAD;
    
    (my $method = $AUTOLOAD) =~ s/.*:://;
    
    my $interface = $self->{interface};
    if (!$interface) {
	my $ins = $self->_introspector;
	if (!$ins) {
	    die "no introspection data available for '" . $self->get_object_path . 
		"', and object is not cast to any interface";
	}
	
	my @interfaces = $ins->has_method($method);
	
	if ($#interfaces == -1) {
	    die "no method with name '$method' is exported in object '" .
		$self->get_object_path . "'\n";
	} elsif ($#interfaces > 0) {
	    warn "method with name '$method' is exported " .
		"in multiple interfaces of '" . $self->get_object_path . "'" .
		"calling first interface only\n";
	}
	$interface = $interfaces[0];
    }

    my $call = Net::DBus::Binding::Message::MethodCall->
	new(service_name => $self->{service}->get_service_name(),
	    object_path => $self->{object_path},
	    method_name => $method,
	    interface => $interface);

    my $ins = $self->_introspector;
    if ($ins) {
	$ins->encode($call, "methods", $method, "params", @_);
    } else {
	$call->append_args_list(@_);
    }

    my $reply = $self->{service}->
	get_bus()->
	get_connection()->
	send_with_reply_and_block($call, 5000);
    
    my @reply;
    if ($ins) {
	@reply = $ins->decode($reply, "methods", $method, "returns");
    } else {
	@reply = $reply->get_args_list;
    }
    return wantarray ? @reply : $reply[0];
}


1;

