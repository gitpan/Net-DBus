=head1 NAME

DBus - Perl extension for the DBus message system

=head1 SYNOPSIS


  ####### Attaching to the bus ###########

  use Net::DBus;
 
  # Find the most appropriate bus
  my $bus = Net::DBus->find;

  # ... or explicitly go for the session bus
  my $bus = Net::DBus->session;

  # .... or explicitly go for the system bus
  my $bus = Net::DBus->system


  ######## Accessing remote services #########

  # Get the service known by 'org.freedesktop.DBus'
  my $service = $bus->get_service("org.freedesktop.DBus");

  # See if SkyPE is around
  if ($bus->has_service("com.skype.API")) { 
      my $skype = $bus->get_service("com.skype.API");
      ... do stuff with skype ...
  } else {
      print STDERR "SkyPE does not appear to be running\n";
      exit 1
  }

  
  ######### Providing services ##############

  # Register a service known as 'org.example.Jukebox'
  my $service = $bus->export_service("org.example.Jukebox");


=head1 DESCRIPTION

Net::DBus provides a Perl API for the DBus message system.
The DBus Perl interface is currently operating against
the 0.32 development version of DBus, but should work with
later versions too, providing the API changes have not been
too drastic. 

Users of this package are either typically, service providers
in which case the L<Net::DBus::Service> and L<Net::DBus::Object>
modules are of most relevance, or are client consumers, in which
case L<Net::DBus::RemoteService> and L<Net::DBus::RemoteObject>
are of most relevance.

=head1 METHODS

=over 4

=cut

package Net::DBus;

use 5.006;
use strict;
use warnings;
use Carp;



BEGIN {
    our $VERSION = '0.32.1';
    require XSLoader;
    XSLoader::load('Net::DBus', $VERSION);
}

use Net::DBus::Binding::Bus;
use Net::DBus::Binding::Message;
use Net::DBus::Binding::Value;
use Net::DBus::Service;
use Net::DBus::RemoteService;

=pod

=item my $bus = Net::DBus->find(%params);

Search for the most appropriate bus to connect to and 
return a connection to it. The heuristic used for the
search is

  - If DBUS_STARTER_BUS_TYPE is set to 'session' attach
    to the session bus

  - Else If DBUS_STARTER_BUS_TYPE is set to 'system' attach
    to the system bus

  - Else If DBUS_SESSION_BUS_ADDRESS is set attach to the
    session bus

  - Else attach to the system bus

The optional C<params> hash can contain be used to specify
connection options. The only support option at this time
is C<nomainloop> which prevents the bus from being automatically
attached to the main L<Net::DBus::Reactor> event loop.

=cut

sub find {
    my $class = shift;
    
    if ($ENV{DBUS_STARTER_BUS_TYPE} &&
	$ENV{DBUS_STARTER_BUS_TYPE} eq "session") {
	return $class->session(@_);
    } elsif ($ENV{DBUS_STARTER_BUS_TYPE} &&
	     $ENV{DBUS_STARTER_BUS_TYPE} eq "system") {
	return $class->system(@_);
    } elsif (exists $ENV{DBUS_SESSION_BUS_ADDRESS}) {
	return $class->session(@_);
    } else {
	return $class->system;
    }
}

=pod

=item my $bus = Net::DBus->system(%params);

Return a connection to the system message bus. Note that the
system message bus is locked down by default, so unless appropriate
access control rules are added in /etc/dbus/system.d/, an application
may access services, but won't be able to export services.
The optional C<params> hash can contain be used to specify
connection options. The only support option at this time
is C<nomainloop> which prevents the bus from being automatically
attached to the main L<Net::DBus::Reactor> event loop.

=cut

sub system {
    my $class = shift;
    return $class->_new(Net::DBus::Binding::Bus->new(type => &Net::DBus::Binding::Bus::SYSTEM), @_);
}

=pod

=item my $bus = Net::DBus->session(%params);

Return a connection to the session message bus. 
The optional C<params> hash can contain be used to specify
connection options. The only support option at this time
is C<nomainloop> which prevents the bus from being automatically
attached to the main L<Net::DBus::Reactor> event loop.

=cut

sub session {
    my $class = shift;
    return $class->_new(Net::DBus::Binding::Bus->new(type => &Net::DBus::Binding::Bus::SESSION), @_);
}

=pod

=item my $bus = Net::DBus->new($address, %params);

Return a connection to a specific message bus.  The C<$address>
parameter must contain the address of the message bus to connect
to. An example address for a session bus might look like 
C<unix:abstract=/tmp/dbus-PBFyyuUiVb,guid=191e0a43c3efc222e0818be556d67500>,
while one for a system bus would look like C<unix:/var/run/dbus/system_bus_socket>.
The optional C<params> hash can contain be used to specify
connection options. The only support option at this time
is C<nomainloop> which prevents the bus from being automatically
attached to the main L<Net::DBus::Reactor> event loop.

=cut

sub new {
    my $class = shift;
    my $nomainloop = shift;
    return $class->_new(Net::DBus::Binding::Bus->new(address => shift), @_);
}

sub _new {
    my $class = shift;
    my $self = {};
    
    $self->{connection} = shift;
    $self->{signals} = {};
    
    my %params = @_;
    
    bless $self, $class;

    unless ($params{nomainloop}) {
	if (exists $INC{'Net/DBus/Reactor.pm'}) {
	    my $reactor = Net::DBus::Reactor->main;
	    $reactor->manage($self->get_connection);
	}
	# ... Add support for GLib and POE
    }
    
    $self->get_connection->add_filter(sub { $self->_signal_func(@_) });
    
    return $self;
}

=pod

=item my $connection = $bus->connection;

Return a handle to the underlying, low level connection object
associated with this bus. The returned object will be an instance
of the L<Net::DBus::Binding::Bus> class. This method is not intended
for use by (most!) application developers, so if you don't understand
what this is for, then you don't need to be calling it!

=cut

sub get_connection {
    my $self = shift;
    return $self->{connection};
}

=pod

=item my $service = $bus->get_service($name);

Retrieves a handle for the remote service identified by the
service name C<$name>. The returned object will be an instance
of the L<Net::DBus::RemoteService> class.

=cut

sub get_service {
    my $self = shift;
    my $name = shift;
    
    return Net::DBus::RemoteService->new($self, $name);
}

=pod

=item my $bool = $bus->has_service($name);

Returns a true value if the bus has an active service
with a name of C<$name>. Returns a false value, if it
does not. NB services can disappear from the bus at
any time, so be prepared to handle failure at a later
time, even if this method returns true.

=cut

sub has_service {
    my $self = shift;
    my $name = shift;
    
    my $dbus = $self->get_service("org.freedesktop.DBus");
    my $bus = $dbus->get_object("/org/freedesktop/DBus");
    my $services = $bus->ListNames;
    
    foreach (@{$services}) {
	return 1 if $_ eq $name;
    }
    return 0;
}


=pod

=item my $service = $bus->export_service($name);

Registers a service with the bus, returning a handle to
the service. The returned object is an instance of the
L<Net::DBus::Service> class.

=cut

sub export_service {
    my $self = shift;
    my $name = shift;
    return Net::DBus::Service->new($self, $name);
}

sub add_signal_receiver {
    my $self = shift;
    my $receiver = shift;
    my $signal_name = shift;
    my $interface = shift;
    my $service = shift;
    my $path = shift;

    my $rule = $self->_match_rule($signal_name, $interface, $service, $path);

    $self->{receivers}->{$rule} = [] unless $self->{receivers}->{$rule};
    push @{$self->{receivers}->{$rule}}, $receiver;
    
    $self->{connection}->add_match($rule);
}

sub remove_signal_receiver {
    my $self = shift;
    my $receiver = shift;
    my $signal_name = shift;
    my $interface = shift;
    my $service = shift;
    my $path = shift;
    
    my $rule = $self->_match_rule($signal_name, $interface, $service, $path);

    my @receivers;
    foreach (@{$self->{receivers}->{$rule}}) {
	if ($_ eq $receiver) {
	    $self->{connection}->remove_match($rule);
	} else {
	    push @receivers, $_;
	}
    }
    $self->{receivers}->{$rule} = \@receivers;
}


sub _match_rule {
    my $self = shift;
    my $signal_name = shift;
    my $interface = shift;
    my $service = shift;
    my $path = shift;

    my $rule = "type='signal'";
    if ($interface) {
	$rule .= ",interface='$interface'";
    }
    if ($service) {
	if ($service !~ /^:/ &&
	    $service ne "org.freedesktop.DBus") {
	    my $bus_service = $self->get_service("org.freedesktop.DBus");
	    my $bus_object = $bus_service->get_object('/org/freedesktop/DBus',
						      'org.freedesktop.DBus');
	    $service = $bus_object->GetNameOwner($service);
	}
	$rule .= ",sender='$service'";
    }
    if ($path) {
	$rule .= ",path='$path'";
    }
    if ($signal_name) {
	$rule .= ",member='$signal_name'";
    }
    return $rule;
}


sub _rule_matches {
    my $self = shift;
    my $rule = shift;
    my $member = shift;
    my $interface = shift;
    my $sender = shift;
    my $path = shift;
    
    my %bits;
    map { 
	if (/^(\w+)='(.*)'$/) {
	    $bits{$1} = $2;
	}
    } split /,/, $rule;
    
    if (exists $bits{member} &&
	$bits{member} ne $member) {
	return 0;
    }
    if (exists $bits{interface} &&
	$bits{interface} ne $interface) {
	return 0;
    }
    if (exists $bits{sender} &&
	$bits{sender} ne $sender) {
	return 0;
    }
    if (exists $bits{path} &&
	$bits{path} ne $path) {
	return 0;
    }
    return 1;
}

sub _signal_func {
    my $self = shift;
    my $connection = shift;
    my $message = shift;

    return 0 unless $message->isa("Net::DBus::Binding::Message::Signal");

    my $interface = $message->get_interface;
    my $sender = $message->get_sender;
    my $path = $message->get_path;
    my $member = $message->get_member;

    my $handled = 0;
    foreach my $rule (grep { $self->_rule_matches($_, $member, $interface, $sender, $path) }
		      keys %{$self->{receivers}}) {
	foreach my $callback (@{$self->{receivers}->{$rule}}) {
	    &$callback($message);
            $handled = 1;
	}
    }

    return $handled;
}

1;
__END__

=pod

=back

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::RemoteService>, L<Net::DBus::Service>, 
L<Net::DBus::RemoteObject>, L<Net::DBus::Object>, 
L<Net::DBus::Exporter>, L<Net::DBus::Dumper>, L<Net::DBus::Reactor>,
L<dbus-monitor(1)>, L<dbus-daemon-1(1)>, L<dbus-send(1)>, L<http://dbus.freedesktop.org>,

=head1 AUTHOR

Daniel Berrange <dan@berrange.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Daniel Berrange

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
