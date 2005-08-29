package Net::DBus::Binding::Message::MethodCall;

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

    my $msg = exists $params{message} ? $params{message} :
	Net::DBus::Binding::Message::MethodCall::_create
	(
	 ($params{service_name} ? $params{service_name} : confess "service_name parameter is required"),
	 ($params{object_path} ? $params{object_path} : confess "object_path parameter is required"),
	 ($params{interface} ? $params{interface} : confess "interface parameter is required"),
	 ($params{method_name} ? $params{method_name} : confess "method_name parameter is required"));

    my $self = $class->SUPER::new(message => $msg);

    bless $self, $class;
    
    return $self;
}

1;
