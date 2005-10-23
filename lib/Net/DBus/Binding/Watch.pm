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
# $Id: Watch.pm,v 1.2 2005/10/15 13:31:42 dan Exp $

package Net::DBus::Binding::Watch;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;

    croak "&Net::DBus::Binding::Watch::constant not defined" if $constname eq '_constant';

    if (!exists $Net::DBus::Binding::Watch::_constants{$constname}) {
        croak "no such constant \$Net::DBus::Binding::Watch::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Net::DBus::Binding::Watch::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}

1;
__END__
