package Net::DBus::Binding::Message::Error;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;
use Net::DBus::Binding::Message;

our @ISA = qw(Net::DBus::Binding::Message);

our $VERSION = '0.0.1';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $replyto = exists $params{replyto} ? $params{replyto} : confess "replyto parameter is required";

    my $msg = exists $params{message} ? $params{message} : 
	Net::DBus::Binding::Message::Error::_create
	(
	 $replyto->{message},
	 ($params{name} ? $params{name} : confess "name parameter is required"),
	 ($params{description} ? $params{description} : confess "description parameter is required"));

    my $self = $class->SUPER::new(message => $msg);

    bless $self, $class;
    
    return $self;
}

1;
