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
# $Id: Error.pm,v 1.4 2005/11/21 10:54:48 dan Exp $

package Net::DBus::Binding::Message::Error;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;
use base qw(Net::DBus::Binding::Message);

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


sub get_error_name {
    my $self = shift;
    
    return $self->{message}->dbus_message_get_error_name;
}

1;
