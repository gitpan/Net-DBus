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
# $Id: Callback.pm,v 1.5 2005/10/15 13:31:42 dan Exp $

package Net::DBus::Callback;

use 5.006;
use strict;
use warnings;
use Carp qw(confess);

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
