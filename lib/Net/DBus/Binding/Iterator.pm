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
# $Id: Iterator.pm,v 1.14 2005/11/21 11:39:51 dan Exp $

=pod

=head1 NAME

Net::DBus::Binding::Iterator - Reading and writing message parameters

=head1 SYNOPSIS

Creating a new message

  my $msg = new Net::DBus::Binding::Message::Signal;
  my $iterator = $msg->iterator;

  $iterator->append_boolean(1);
  $iterator->append_byte(123);


Reading from a mesage

  my $msg = ...get it from somewhere...
  my $iter = $msg->iterator();

  my $i = 0;
  while ($iter->has_next()) {
    $iter->next();
    $i++;
    if ($i == 1) {
       my $val = $iter->get_boolean();
    } elsif ($i == 2) {
       my $val = $iter->get_byte();
    }
  }

=head1 DESCRIPTION

Provides an iterator for reading or writing message
fields. This module provides a Perl API to access the
dbus_message_iter_XXX methods in the C API. The array
and dictionary types are not yet supported, and there
are bugs in the Quad support (ie it always returns -1!).

=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Iterator;


use 5.006;
use strict;
use warnings;
use Carp qw(confess);

use Net::DBus;

our $have_quads = 0;

BEGIN {
  eval "pack 'Q', 1243456";
  if ($@) {
    $have_quads = 0;
  } else {
    $have_quads = 1;
  }
}

=pod

=item $res = $iter->has_next()

Determines if there are any more fields in the message
itertor to be read. Returns a positive value if there
are more fields, zero otherwise.

=item $success = $iter->next()

Skips the iterator onto the next field in the message.
Returns a positive value if the current field pointer
was successfully advanced, zero otherwise.

=item my $val = $iter->get_boolean()

=item $iter->append_boolean($val);

Read or write a boolean value from/to the
message iterator

=item my $val = $iter->get_byte()

=item $iter->append_byte($val);

Read or write a single byte value from/to the
message iterator.

=item my $val = $iter->get_string()

=item $iter->append_string($val);

Read or write a UTF-8 string value from/to the
message iterator

=item my $val = $iter->get_int32()

=item $iter->append_int32($val);

Read or write a signed 32 bit value from/to the
message iterator

=item my $val = $iter->get_uint32()

=item $iter->append_uint32($val);

Read or write an unsigned 32 bit value from/to the
message iterator

=item my $val = $iter->get_int64()

=item $iter->append_int64($val);

Read or write a signed 64 bit value from/to the
message iterator

=item my $val = $iter->get_uint64()

=item $iter->append_uint64($val);

Read or write an unsigned 64 bit value from/to the
message iterator

=item my $val = $iter->get_double()

=item $iter->append_double($val);

Read or write a double precision floating point value 
from/to the message iterator

=cut

sub get_int64 {
    my $self = shift;
    confess "Quads not supported on this platform\n" unless $have_quads;
    return $self->_get_int64;
}

sub get_uint64 {
    my $self = shift;
    confess "Quads not supported on this platform\n" unless $have_quads;
    return $self->_get_uint64;
}

sub append_int64 {
    my $self = shift;
    confess "Quads not supported on this platform\n" unless $have_quads;
    $self->_append_int64(shift);
}

sub append_uint64 {
    my $self = shift;
    confess "Quads not supported on this platform\n" unless $have_quads;
    $self->_append_uint64(shift);
}


sub get {
    my $self = shift;    
    my $type = shift;

    if (defined $type) {
	if (ref($type)) {
	    if (ref($type) eq "ARRAY") {
		# XXX we should recursively validate types
		$type = $type->[0];
		if ($type eq &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
		    $type = &Net::DBus::Binding::Message::TYPE_ARRAY;
		}
	    } else {
		die "unsupport type reference $type";
	    }
	}

	my $actual = $self->get_arg_type;
	if ($actual != $type) {
	    # "Be strict in what you send, be leniant in what you accept"
	    #    - ie can't rely on python to send correct types, eg int32 vs uint32
	    #die "requested type '" . chr($type) . "' ($type) did not match wire type '" . chr($actual) . "' ($actual)";
	    warn "requested type '" . chr($type) . "' ($type) did not match wire type '" . chr($actual) . "' ($actual)";
	    $type = $actual;
	}
    } else {
	$type = $self->get_arg_type;
    }

	
    
    if ($type == &Net::DBus::Binding::Message::TYPE_STRING) {
	return $self->get_string;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_BOOLEAN) {
	return $self->get_boolean;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_BYTE) {
	return $self->get_byte;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_INT32) {
	return $self->get_int32;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT32) {
	return $self->get_uint32;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_INT64) {
	return $self->get_int64;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT64) {
	return $self->get_uint64;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_DOUBLE) {
	return $self->get_double;
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_ARRAY) {
	my $array_type = $self->get_element_type();
	if ($array_type == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
	    return $self->get_dict();
	} else {
	    return $self->get_array($array_type);
	}
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_STRUCT) {
	return $self->get_struct();
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_VARIANT) {
	return $self->get_variant();
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
	confess "dictionary can only occur as part of an array type";
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_INVALID) {
	confess "cannot handle Net::DBus::Binding::Message::TYPE_INVALID";
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_OBJECT_PATH) {
	return $self->get_string();
    } elsif ($type == &Net::DBus::Binding::Message::TYPE_SIGNATURE) {
	return $self->get_string();
    } else {
	confess "unknown argument type '" . chr($type) . "' ($type)";
    }
}


sub get_dict {
    my $self = shift;
    
    my $iter = $self->_recurse();
    my $type = $iter->get_arg_type();
    my $dict = {};
    while ($type == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
	my $entry = $iter->get_struct();
	if ($#{$entry} != 1) {
	    confess "Dictionary entries must be structs of 2 elements. This entry has " . ($#{$entry}+1) ." elements";
	}
	
	$dict->{$entry->[0]} = $entry->[1];
	$iter->next();
	$type = $iter->get_arg_type();
    }
    return $dict;
}

sub get_array {
    my $self = shift;
    my $array_type = shift;
    
    my $iter = $self->_recurse();
    my $type = $iter->get_arg_type();
    my $array = [];
    while ($type != &Net::DBus::Binding::Message::TYPE_INVALID) {
	if ($type != $array_type) {
	    confess "Element $type not of array type $array_type";
	}

	my $value = $iter->get($type);
	push @{$array}, $value;
	$iter->next();
	$type = $iter->get_arg_type();
    }
    return $array;
}

sub get_variant {
    my $self = shift;

    my $iter = $self->_recurse();
    return $iter->get();
}

sub get_struct {
    my $self = shift;
    
    my $iter = $self->_recurse();
    my $type = $iter->get_arg_type();
    my $struct = [];
    while ($type != &Net::DBus::Binding::Message::TYPE_INVALID) {
	my $value = $iter->get($type);
	push @{$struct}, $value;
	$iter->next();
	$type = $iter->get_arg_type();
    }
    return $struct;
}

sub append {
    my $self = shift;
    my $value = shift;
    my $type = shift;
    
    if (ref($value) eq "Net::DBus::Binding::Value") {
	$type = $value->type;
	$value = $value->value;
    }

    if (!defined $type) {
	$type = $self->guess_type($value);
    }	

    if (ref($type) eq "ARRAY") {
	my $maintype = $type->[0];
	my $subtype = $type->[1];
	
	if ($maintype == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
	    $self->append_dict($value, $subtype);
	} elsif ($maintype == &Net::DBus::Binding::Message::TYPE_STRUCT) {
	    $self->append_struct($value, $subtype);
	} elsif ($maintype == &Net::DBus::Binding::Message::TYPE_ARRAY) {
	    $self->append_array($value, $subtype);
	} else {
	    confess "Unsupported compound type ", $maintype;
	}
    } else {	
	# XXX is this good idea or not
	$value = '' unless defined $value;

	if ($type == &Net::DBus::Binding::Message::TYPE_BOOLEAN) {
	    $self->append_boolean($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_BYTE) {
	    $self->append_byte($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_STRING) {
	    $self->append_string($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_INT32) {
	    $self->append_int32($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT32) {
	    $self->append_uint32($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_INT64) {
	    $self->append_int64($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_UINT64) {
	    $self->append_uint64($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_DOUBLE) {
	    $self->append_double($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_OBJECT_PATH) {
	    $self->append_string($value);
	} elsif ($type == &Net::DBus::Binding::Message::TYPE_VARIANT) {
	    $self->append_variant($value);
	} else {
	    confess "Unsupported scalar type ", $type;
	}
    }
}

sub guess_type {
    my $self = shift;
    my $value = shift;
    
    if (ref($value)) {
	if (ref($value) eq "HASH") {
	    my $key = (keys %{$value})[0];
	    my $val = $value->{$key};
	    # XXX Basically impossible to decide between DICT & STRUCT
	    return [ &Net::DBus::Binding::Message::TYPE_DICT_ENTRY,
		     [ &Net::DBus::Binding::Message::TYPE_STRING, $self->guess_type($val)] ];
	} elsif (ref($value) eq "ARRAY") {
	    return [ &Net::DBus::Binding::Message::TYPE_ARRAY,
		     [$self->guess_type($value->[0])] ];
	} else {
	    die "cannot marshall reference of type " . ref($value);
	}
    } else {
	# XXX Should we bother trying to guess integer & floating point types ?
	# I say sod it, because strongly typed languages will support introspection
	# and loosely typed languages won't care about the difference
	return &Net::DBus::Binding::Message::TYPE_STRING;
    }
}

sub get_signature {
    my $self = shift;
    my $type = shift;
    my ($sig, $t, $i);

    $sig = "";
    $i = 0;

    if (ref($type) eq "ARRAY") {
	while ($i <= $#{$type}) {
	    $t = $$type[$i];
	    
	    if (ref($t) eq "ARRAY") {
		$sig .= $self->get_signature($t);
	    } elsif ($t == &Net::DBus::Binding::Message::TYPE_DICT_ENTRY) {
		$sig .= chr (&Net::DBus::Binding::Message::TYPE_ARRAY);
		$sig .= "{" . $self->get_signature($$type[++$i]) . "}";
	    } elsif ($t == &Net::DBus::Binding::Message::TYPE_STRUCT) {
		$sig .= "(" . $self->get_signature($$type[++$i]) . ")";
	    } else {
		$sig .= chr($t);
	    }
	    
	    $i++;
	}
    } else {
	$sig .= chr ($type);
    }
    
    return $sig;
}


sub append_array {
    my $self = shift;
    my $array = shift;
    my $type = shift;

    die "array must only have one type"
	if $#{$type} > 0;

    my $sig = $self->get_signature($type);
    my $iter = $self->_open_container(&Net::DBus::Binding::Message::TYPE_ARRAY, $sig);
    
    foreach my $value (@{$array}) {
	$iter->append($value, $type->[0]);
    }

    $self->_close_container($iter);
}


sub append_struct {
    my $self = shift;
    my $struct = shift;
    my $type = shift;

    if ($#{$struct} != $#{$type}) {
	die "number of values does not match type";
    }

    my $iter = $self->_open_container(&Net::DBus::Binding::Message::TYPE_STRUCT, "");
    
    my @type = @{$type};
    foreach my $value (@{$struct}) {
	$iter->append($value, shift @type);
    }

    $self->_close_container($iter);
}

sub append_dict {
    my $self = shift;
    my $hash = shift;
    my $type = shift;

    my $sig;

    $sig  = "{";
    $sig .= $self->get_signature($type);
    $sig .= "}";

    my $iter = $self->_open_container(&Net::DBus::Binding::Message::TYPE_ARRAY, $sig);
    
    foreach my $key (keys %{$hash}) {
	my $value = $hash->{$key};
	my $entry = $iter->_open_container(&Net::DBus::Binding::Message::TYPE_DICT_ENTRY, $sig);

	$entry->append($key, $type->[0]);
	$entry->append($value, $type->[1]);
	$iter->_close_container($entry);
    }
    $self->_close_container($iter);
}


sub append_variant {
    my $self = shift;
    my $value = shift;
    
    my $type = $self->guess_type($value);
    my $sig = $self->get_signature($type);
    my $iter = $self->_open_container(&Net::DBus::Binding::Message::TYPE_VARIANT, $sig);
    $iter->append($value, $type);
    $self->_close_container($iter);
}



1;

=pod

=back

=head1 SEE ALSO

L<Net::DBus::Binding::Message>

=head1 AUTHOR

Daniel Berrange E<lt>dan@berrange.comE<gt>

=head1 COPYRIGHT

Copyright 2004 by Daniel Berrange

=cut
