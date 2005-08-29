package Net::DBus::Binding::Message::MethodReturn;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;
use Net::DBus::Binding::Message;

our @ISA = qw(Exporter Net::DBus::Binding::Message);

our $VERSION = '0.0.1';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $call = exists $params{call} ? $params{call} : confess "call parameter is required";
    
    my $msg = exists $params{message} ? $params{message} : 
	Net::DBus::Binding::Message::MethodReturn::_create($call->{message});

    my $self = $class->SUPER::new(message => $msg);

    bless $self, $class;
    
    return $self;
}

1;
