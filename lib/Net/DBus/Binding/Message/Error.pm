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
# $Id: Error.pm,v 1.6 2006/02/02 16:58:27 dan Exp $

=pod

=head1 NAME

Net::DBus::Binding::Message::Error - a message encoding a method call error

=head1 SYNOPSIS

  use Net::DBus::Binding::Message::Error;

  my $error = Net::DBus::Binding::Message::Error->new(
      replyto => $method_call,
      name => "org.example.myobject.FooException",
      description => "Unable to do Foo when updating bar");

  $connection->send($error);

=head1 DESCRIPTION

This module is part of the low-level DBus binding APIs, and
should not be used by application code. No guarentees are made
about APIs under the C<Net::DBus::Binding::> namespace being
stable across releases.

This module provides a convenience constructor for creating
a message representing an error condition. 

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Message::Error;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;
use base qw(Net::DBus::Binding::Message);

=item my $error = Net::DBus::Binding::Message::Error->new(
      replyto => $method_call, name => $name, description => $description);

Creates a new message, representing an error which occurred during
the handling of the method call object passed in as the C<replyto>
parameter. The C<name> parameter is the formal name of the error
condition, while the C<description> is a short piece of text giving
more specific information on the error.

=cut

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

=item my $name = $error->get_error_name

Returns the formal name of the error, as previously passed in via
the C<name> parameter in the constructor.

=cut

sub get_error_name {
    my $self = shift;
    
    return $self->{message}->dbus_message_get_error_name;
}

1;

__END__

=back

=head1 AUTHOR

Daniel P. Berrange.

=head1 COPYRIGHT

Copyright (C) 2005-2006 Daniel P. Berrange

=head1 SEE ALSO

L<Net::DBus::Binding::Message>

=cut
