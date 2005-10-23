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
# $Id: Bus.pm,v 1.8 2005/10/15 13:31:42 dan Exp $

package Net::DBus::Binding::Bus;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;

use base qw(Net::DBus::Binding::Connection);

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my %params = @_;
    
    my $connection;
    if (defined $params{type}) {
	$connection = Net::DBus::Binding::Bus::_open($params{type});
    } elsif (defined $params{address}) {
	$connection = Net::DBus::Binding::Connection::_open($params{address});
	$connection->dbus_bus_register();
    } else {
	confess "either type or address parameter is required";
    }
	  
    my $self = $class->SUPER::new(%params, connection => $connection);

    bless $self, $class;

    return $self;
}


sub request_name {
    my $self = shift;
    my $service_name = shift;
    
    $self->{connection}->dbus_bus_request_name($service_name);
}

sub get_unique_name {
    my $self = shift;

    $self->{connection}->dbus_bus_get_unique_name;
}


sub add_match {
    my $self = shift;
    my $rule = shift;
    
    $self->{connection}->dbus_bus_add_match($rule);
}

sub remove_match {
    my $self = shift;
    my $rule = shift;
    
    $self->{connection}->dbus_bus_remove_match($rule);
}

sub DESTROY {
    # Keep autoloader quiet
}

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;

    croak "&Net::DBus::Binding::Bus::constant not defined" if $constname eq '_constant';

    if (!exists $Net::DBus::Binding::Bus::_constants{$constname}) {
        croak "no such method $constname, and no constant \$Net::DBus::Binding::Bus::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Net::DBus::Binding::Bus::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}

1;

