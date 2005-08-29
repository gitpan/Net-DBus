package Net::DBus::Callback;

use 5.006;
use strict;
use warnings;
use Carp qw(confess);

our $VERSION = '0.0.1';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    $self->{object} = $params{object} ? $params{object} : undef;
    $self->{method} = $params{method} ? $params{method} : confess "method parameter is required";
    $self->{args} = $params{args} ? $params{args} : [];

    bless $self, $class;

    return $self;
}


sub invoke {
    my $self = shift;
    
    if ($self->{object}) {
	my $obj = $self->{object};
	my $method = $self->{method};

	$obj->$method(@{$self->{args}}, @_);
    } else {
	my $method = $self->{method};

	&$method(@{$self->{args}}, @_);
    }
}

1;
