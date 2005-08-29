package Net::DBus::RemoteService;

use 5.006;
use strict;
use warnings;
use Carp;

our $VERSION = '0.0.1';

use Net::DBus::RemoteObject;


sub new {
    my $class = shift;
    my $self = {};

    $self->{bus} = shift;
    $self->{service_name} = shift;
    $self->{objects} = {};

    bless $self, $class;

    return $self;
}

sub get_bus {
    my $self = shift;

    return $self->{bus};
}


sub get_service_name {
    my $self = shift;
    return $self->{service_name};
}

sub get_object {
    my $self = shift;
    my $object_path = shift;
    
    unless (defined $self->{objects}->{$object_path}) {
	if (@_) {
	    my $interface = shift;
	    $self->{objects}->{$object_path} = Net::DBus::RemoteObject->new($self,
									    $object_path,
									    $interface);
	} else {
	    $self->{objects}->{$object_path} = Net::DBus::RemoteObject->new($self,
									    $object_path);
	}
    }
    return $self->{objects}->{$object_path};
}

1;
 
