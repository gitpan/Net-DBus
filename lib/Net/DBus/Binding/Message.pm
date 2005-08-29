=pod

=head1 NAME

Net::DBus::Binding::Message - Base class for messages

=head1 SYNOPSIS

Sending a message

  my $msg = new Net::DBus::Binding::Message::Signal;
  my $iterator = $msg->iterator;

  $iterator->append_byte(132);
  $iterator->append_int32(14241);

  $connection->send($msg);

=head1 DESCRIPTION

Provides a base class for the different kinds of
message that can be sent/received. Instances of
this class are never instantiated directly, rather
one of the four sub-types L<Net::DBus::Binding::Message::Signal>,
L<Net::DBus::Binding::Message::MethodCall>, L<Net::DBus::Binding::Message::MethodReturn>,
L<Net::DBus::Binding::Message::Error> should be used.

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Message;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;
use Net::DBus::Binding::Iterator;
use Net::DBus::Binding::Message::Signal;
use Net::DBus::Binding::Message::MethodCall;
use Net::DBus::Binding::Message::MethodReturn;
use Net::DBus::Binding::Message::Error;

our $VERSION = '0.0.1';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    my $self = {};

    $self->{message} = exists $params{message} ? $params{message} : 
	(Net::DBus::Binding::Message::_create(exists $params{type} ? $params{type} : confess "type parameter is required"));

    bless $self, $class;
    
    if ($class eq "Net::DBus::Binding::Message") {
	$self->_specialize;
    }

    return $self;
}

sub _specialize {
    my $self = shift;
    
    my $type = $self->get_type;
    if ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_CALL) {
	bless $self, "Net::DBus::Binding::Message::MethodCall";
    } elsif ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_RETURN) {
	bless $self, "Net::DBus::Binding::Message::MethodReturn";
    } elsif ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_ERROR) {
	bless $self, "Net::DBus::Binding::Message::Error";
    } elsif ($type == &Net::DBus::Binding::Message::MESSAGE_TYPE_SIGNAL) {
	bless $self, "Net::DBus::Binding::Message::Signal";
    } else {
	warn "Unknown message type $type\n";
    }
}

sub get_type {
    my $self = shift;

    return $self->{message}->dbus_message_get_type;
}

sub get_interface {
    my $self = shift;
    
    return $self->{message}->dbus_message_get_interface;
}

sub get_path {
    my $self = shift;
    
    return $self->{message}->dbus_message_get_path;
}

sub get_destination {
    my $self = shift;
    
    return $self->{message}->dbus_message_get_destination;
}

sub get_sender {
    my $self = shift;
    
    return $self->{message}->dbus_message_get_sender;
}

sub get_member {
    my $self = shift;
    
    return $self->{message}->dbus_message_get_member;
}


=pod

=item my $iterator = $msg->iterator;

Retrieves an iterator which can be used for reading or
writing fields of the message. The returned object is
an instance of the C<Net::DBus::Binding::Iterator> class.

=cut

sub iterator {
    my $self = shift;
    my $append = @_ ? shift : 0;
    
    if ($append) {
	return Net::DBus::Binding::Message::_iterator_append($self->{message});
    } else {
	return Net::DBus::Binding::Message::_iterator($self->{message});
    }
}

sub get_args_list {
    my $self = shift;
    
    my @ret;    
    my $iter = $self->iterator;
    if ($iter->get_arg_type() != &Net::DBus::Binding::Message::TYPE_INVALID) {
	do {
	    push @ret, $iter->get();
	} while ($iter->next);
    }

    return @ret;
}


sub append_args_list {
    my $self = shift;
    my @args = @_;
    
    my $iter = $self->iterator(1);
    foreach my $arg (@args) {
	$iter->append($arg);
    }
}


# To keep autoloader quiet
sub DESTROY {
}

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;

    croak "&Net::DBus::Binding::Message::constant not defined" if $constname eq '_constant';

    if (!exists $Net::DBus::Binding::Message::_constants{$constname}) {
        croak "no such constant \$Net::DBus::Binding::Message::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Net::DBus::Binding::Message::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}

1;

=pod

=back

=head1 SEE ALSO

L<Net::DBus::Binding::Server>, L<Net::DBus::Binding::Connection>, L<Net::DBus::Binding::Message::Signal>, L<Net::DBus::Binding::Message::MethodCall>, L<Net::DBus::Binding::Message::MethodReturn>, L<Net::DBus::Binding::Message::Error>

=head1 AUTHOR

Daniel Berrange E<lt>dan@berrange.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Daniel Berrange

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
