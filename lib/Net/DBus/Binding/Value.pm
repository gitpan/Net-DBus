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
# $Id: Value.pm,v 1.5 2005/12/05 20:04:06 dan Exp $

=pod

=head1 NAME

Net::DBus::Binding::Value - a strongly typed data value

=head1 SYNOPSIS

  # Import the convenience functions
  use Net::DBus qw(:typing);

  # Call a method with passing an int32
  $object->doit(dint32("3"));

 
=head1 DESCRIPTION

This module provides a simple wrapper around a raw Perl value,
associating an explicit DBus type with the value. This is used
in cases where a client is communicating with a server which does
not provide introspection data, but for which the basic data types
are not sufficient. This class should not be used directly, rather
the convenience functions in L<Net::DBus> be called.

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Value;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self = [];
    
    $self->[0] = shift;
    $self->[1] = shift;
    
    bless $self, $class;

    return $self;
}


sub value {
    my $self = shift;
    return $self->[1];
}

sub type {
    my $self = shift;
    return $self->[0];
}

1;

=pod

=back

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Binding::Introspector>, L<Net::DBus::Binding::Iterator>

=head1 AUTHOR

Daniel Berrange E<lt>dan@berrange.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004-2005 by Daniel Berrange

=cut
