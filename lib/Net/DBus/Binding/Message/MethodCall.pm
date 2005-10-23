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
# $Id: MethodCall.pm,v 1.3 2005/10/15 13:31:42 dan Exp $

package Net::DBus::Binding::Message::MethodCall;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;
use base qw(Exporter Net::DBus::Binding::Message);

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
