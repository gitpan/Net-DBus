package Net::DBus::Binding::Bus;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;

use base qw(Net::DBus::Binding::Connection);

our $VERSION = '0.0.1';

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


sub request_name {
    my $self = shift;
    my $service_name = shift;
    
    $self->{connection}->dbus_bus_request_name($service_name);
}

sub add_match {
    my $self = shift;
    my $rule = shift;
    
    $self->{connection}->dbus_bus_add_match($rule);
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
        croak "no such constant \$Net::DBus::Binding::Bus::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Net::DBus::Binding::Bus::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}

1;

