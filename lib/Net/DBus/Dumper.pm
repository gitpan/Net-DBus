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
# $Id: Dumper.pm,v 1.9 2006/01/27 15:34:23 dan Exp $

=pod

=head1 NAME

Net::DBus::Dumper - Stringify Net::DBus objects suitable for printing

=head1 SYNOPSIS

  use Net::DBus::Dumper;

  use Net::DBus;

  # Dump out info about the bus
  my $bus = Net::DBus->find;
  print dbus_dump($bus);

  # Dump out info about a service
  my $service = $bus->get_service("org.freedesktop.DBus");
  print dbus_dump($service);

  # Dump out info about an object
  my $object = $service->get_object("/org/freedesktop/DBus");
  print dbus_dump($object);

=head1 DESCRIPTION

This module serves as a debugging aid, providing a means to stringify
a DBus related object in a form suitable for printing out. It can 
stringify any of the Net::DBus:* objects, generating the following
information for each

=over 4

=item Net::DBus

A list of services registered with the bus

=item Net::DBus::Service
=item Net::DBus::RemoteService

The service name

=item Net::DBus::Object
=item Net::DBus::RemoteObject

The list of all exported methods, and signals, along with their
parameter and return types.

=back

=head1 METHODS

=over 4

=cut

package Net::DBus::Dumper;

use strict;
use warnings;

use Exporter;

use vars qw(@EXPORT);

@EXPORT = qw(dbus_dump);


=item my @data = dbus_dump($object);

Generates a stringified representation of an object. The object
passed in as the parameter must be an instance of one of L<Net::DBus>, 
L<Net::DBus::RemoteService>, L<Net::DBus::Service>,
L<Net::DBus::RemoteObject>, L<Net::DBus::Object>. The stringified
representation will be returned as a list of strings, with newlines
in appropriate places, such that it can be passed string to the C<print>
method.

=cut

sub dbus_dump {
    my $object = shift;
    
    my $ref = ref($object);
    die "object '$object' is not a reference" unless defined $ref;
    
    if ($object->isa("Net::DBus::Object") ||
	$object->isa("Net::DBus::RemoteObject")) {
	return &_dbus_dump_introspector($object->_introspector);
    } elsif ($object->isa("Net::DBus::RemoteService") ||
	     $object->isa("Net::DBus::Service")) {
	return &_dbus_dump_service($object);
    } elsif ($object->isa("Net::DBus")) {
	return &_dbus_dump_bus($object);
    }
}


sub _dbus_dump_introspector {
    my $ins = shift;
    
    my @data;
    push @data, "Object: ", $ins->get_object_path, "\n";
    foreach my $interface ($ins->list_interfaces) {
	push @data, "  Interface: ", $interface, "\n";
	foreach my $method ($ins->list_methods($interface)) {
	    push @data, "    Method: ", $method, "\n";
	    foreach my $param ($ins->get_method_params($interface, $method)) {
		push @data, &_dbus_dump_types("      > ", $param);
	    }
	    foreach my $param ($ins->get_method_returns($interface, $method)) {
		push @data, &_dbus_dump_types("      < ", $param);
	    }
	}
	foreach my $signal ($ins->list_signals($interface)) {
	    push @data, "    Signal: ", $signal, "\n";
	    foreach my $param ($ins->get_signal_params($interface, $signal)) {
		push @data, &_dbus_dump_types("      > ", $param);
	    }
	}
    }
    return @data;
}

sub _dbus_dump_types {
    my $indent = shift;
    my $type = shift;
    
    my @data;
    if (ref($type)) {
	push @data, $indent, $type->[0], "\n";
	for (my $i = 1 ; $i <= $#{$type} ; $i++) {
	    push @data, &_dbus_dump_types($indent . "  ", $type->[$i]);
	}
    } else {
	push @data, $indent, $type, "\n";
    }
    return @data;
}


sub _dbus_dump_service {
    my $service = shift;
    
    my @data;
    push @data, "Service: ", $service->get_service_name, "\n";

    my $exp = $service->get_object("/org/cpan/Net/DBus/Exporter");
    my $exports = eval {
	$exp->ListObjects();
    };
    if ($@) {
	push @data, "  Could not lookup list of exported object\n";
    } else {
	foreach (@{$exports}) {
	    push @data, "  Object: $_\n";
	}
    }
    return @data;
}

sub _dbus_dump_bus {
    my $bus = shift;
    
    my @data;
    push @data, "Bus: \n";
    
    
    my $dbus = $bus->get_service("org.freedesktop.DBus");
    my $obj = $dbus->get_object("/org/freedesktop/DBus");
    my $names = $obj->ListNames();
    
    foreach (sort { $a cmp $b } @{$names}) {
	push @data, "  Service: ", $_, "\n";
    }
    return @data;
}

1;

=pod

=back

=head1 BUGS

It should print out a list of object paths registered against a
service, but this only currently works for service implemented
in Perl

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::RemoteService>, L<Net::DBus::Service>, 
L<Net::DBus::RemoteObject>, L<Net::DBus::Object>, L<Data::Dumper>.

=head1 COPYRIGHT

Copyright 2005 Daniel Berrange <dan@berrange.com>

=cut
