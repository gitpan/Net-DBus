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
# $Id: Signal.pm,v 1.6 2006/02/02 16:58:27 dan Exp $

=pod

=head1 NAME

Net::DBus::Binding::Message::Signal - a message encoding a signal

=head1 SYNOPSIS

  use Net::DBus::Binding::Message::Signal;

  my $signal = Net::DBus::Binding::Message::Signal->new(
      object_path => "/org/example/myobject",
      interface => "org.example.myobject",
      signal_name => "foo_changed");

  $connection->send($signal);

=head1 DESCRIPTION

This module is part of the low-level DBus binding APIs, and
should not be used by application code. No guarentees are made
about APIs under the C<Net::DBus::Binding::> namespace being
stable across releases.

This module provides a convenience constructor for creating
a message representing a signal. 

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Message::Signal;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;
use base qw(Net::DBus::Binding::Message);


=item my $signal = Net::DBus::Binding::Message::Signal->new(
      object_path => $path, interface => $interface, signal_name => $name);

Creates a new message, representing a signal [to be] emitted by 
the object located under the path given by the C<object_path>
parameter. The name of the signal is given by the C<signal_name>
parameter, and is scoped to the interface given by the
C<interface> parameter.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;

    my $msg = exists $params{message} ? $params{message} :
	Net::DBus::Binding::Message::Signal::_create
	(
	 ($params{object_path} ? $params{object_path} : confess "object_path parameter is required"),
	 ($params{interface} ? $params{interface} : confess "interface parameter is required"),
	 ($params{signal_name} ? $params{signal_name} : confess "signal_name parameter is required"));

    my $self = $class->SUPER::new(message => $msg);

    bless $self, $class;
    
    return $self;
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
