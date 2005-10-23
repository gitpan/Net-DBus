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
# $Id: Introspector.pm,v 1.10 2005/10/17 22:28:01 dan Exp $

=pod

  name => "org.foo.bar.Object"
  interfaces => 
    "org.foo.bar.Wibble" => { 
      methods => {
        foo => {
          params => ["int32", "double", ["array", "int32"]],
          return => ["string", "byte", ["dict", "string", "variant"]]
        }
      }
    }
  }
  children => [
      introspector...
  ];

=cut

package Net::DBus::Binding::Introspector;

use 5.006;
use strict;
use warnings;
use Carp;
use XML::Grove::Builder;
use XML::Parser::PerlSAX;

use Net::DBus;
use Net::DBus::Binding::Message;

our %simple_type_map = (
  "byte" => &Net::DBus::Binding::Message::TYPE_BYTE,
  "bool" => &Net::DBus::Binding::Message::TYPE_BOOLEAN,
  "double" => &Net::DBus::Binding::Message::TYPE_DOUBLE,
  "string" => &Net::DBus::Binding::Message::TYPE_STRING,
  "int32" => &Net::DBus::Binding::Message::TYPE_INT32,
  "uint32" => &Net::DBus::Binding::Message::TYPE_UINT32,
  "int64" => &Net::DBus::Binding::Message::TYPE_INT64,
  "uint64" => &Net::DBus::Binding::Message::TYPE_UINT64,
  "object" => &Net::DBus::Binding::Message::TYPE_OBJECT_PATH,
  "variant" => &Net::DBus::Binding::Message::TYPE_VARIANT,
);

our %simple_type_rev_map = (
  &Net::DBus::Binding::Message::TYPE_BYTE => "byte",
  &Net::DBus::Binding::Message::TYPE_BOOLEAN => "bool",
  &Net::DBus::Binding::Message::TYPE_DOUBLE => "double",
  &Net::DBus::Binding::Message::TYPE_STRING => "string",
  &Net::DBus::Binding::Message::TYPE_INT32 => "int32",
  &Net::DBus::Binding::Message::TYPE_UINT32 => "uint32",
  &Net::DBus::Binding::Message::TYPE_INT64 => "int64",
  &Net::DBus::Binding::Message::TYPE_UINT64 => "uint64",
  &Net::DBus::Binding::Message::TYPE_OBJECT_PATH => "object",
  &Net::DBus::Binding::Message::TYPE_VARIANT => "variant",
);

our %magic_type_map = (
  "caller" => sub {
    my $msg = shift;

    return $msg->get_sender;
  },
  "serial" => sub {
    my $msg = shift;

    return $msg->get_serial;
  },
);

our %compound_type_map = (
  "array" => &Net::DBus::Binding::Message::TYPE_ARRAY,
  "struct" => &Net::DBus::Binding::Message::TYPE_STRUCT,
  "dict" => &Net::DBus::Binding::Message::TYPE_DICT_ENTRY,
);


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{interfaces} = {};

    bless $self, $class;

    if (defined $params{xml}) {
	$self->{object_path} = exists $params{object_path} ? $params{object_path} : undef;
	$self->_parse($params{xml});
    } elsif (defined $params{node}) {
	$self->{object_path} = exists $params{object_path} ? $params{object_path} : undef;
	$self->_parse_node($params{node});
    } else {
	$self->{object_path} = exists $params{object_path} ? $params{object_path} : die "object_path parameter is required";
	$self->{interfaces} = $params{interfaces} if exists $params{interfaces};
	$self->{children} = exists $params{children} ? $params{children} : [];
    }

    # XXX it is really a bug that these aren't included in the introspection
    # data the bus generates
    if ($self->{object_path} eq "/org/freedesktop/DBus") {
	if (!$self->has_signal("NameOwnerChanged")) {
	    $self->add_signal("NameOwnerChanged", ["string","string","string"], "org.freedesktop.DBus");
	}
	if (!$self->has_signal("NameLost")) {
	    $self->add_signal("NameLost", ["string"], "org.freedesktop.DBus");
	}
	if (!$self->has_signal("NameAcquired")) {
	    $self->add_signal("NameAcquired", ["string"], "org.freedesktop.DBus");
	}
    }
	
    
    return $self;
}

sub add_interface {
    my $self = shift;
    my $name = shift;

    $self->{interfaces}->{$name} = {
	methods => {},
	signals => {},
	props => {},
    } unless exists $self->{interfaces}->{$name};
}

sub has_method {
    my $self = shift;
    my $name = shift;
    
    my @interfaces;
    foreach my $interface (keys %{$self->{interfaces}}) {
	if (exists $self->{interfaces}->{$interface}->{methods}->{$name}) {
	    push @interfaces, $interface;
	}
    }

    return @interfaces;
}

sub has_signal {
    my $self = shift;
    my $name = shift;
        
    my @interfaces;
    foreach my $interface (keys %{$self->{interfaces}}) {
	if (exists $self->{interfaces}->{$interface}->{signals}->{$name}) {
	    push @interfaces, $interface;
	}
    }
    return @interfaces;
}


sub has_property {
    my $self = shift;
    my $name = shift;
    
    if (@_) {
	my $interface = shift;
	return () unless exists $self->{interfaces}->{$interface};
	return () unless exists $self->{interfaces}->{$interface}->{props}->{$name};
	return ($interface);
    } else {
	my @interfaces;
	foreach my $interface (keys %{$self->{interfaces}}) {
	    if (exists $self->{interfaces}->{$interface}->{props}->{$name}) {
		push @interfaces, $interface;
	    }
	}
	return @interfaces;
    }
}


sub add_method {
    my $self = shift;
    my $name = shift;
    my $params = shift;
    my $returns = shift;
    my $interface = shift;

    $self->add_interface($interface);
    $self->{interfaces}->{$interface}->{methods}->{$name} = { 
	params => $params,
	returns => $returns,
    };
}

sub add_signal {
    my $self = shift;
    my $name = shift;
    my $params = shift;
    my $interface = shift;

    $self->add_interface($interface);
    $self->{interfaces}->{$interface}->{signals}->{$name} = $params;
}


sub add_property {
    my $self = shift;
    my $name = shift;
    my $type = shift;
    my $access = shift;
    my $interface = shift;

    $self->add_interface($interface);
    $self->{interfaces}->{$interface}->{props}->{$name} = [$type, $access];
}


sub list_interfaces {
    my $self = shift;
    
    return keys %{$self->{interfaces}};
}

sub list_methods {
    my $self = shift;
    my $interface = shift;
    return keys %{$self->{interfaces}->{$interface}->{methods}};
}

sub list_signals {
    my $self = shift;
    my $interface = shift;
    return keys %{$self->{interfaces}->{$interface}->{signals}};
}

sub list_properties {
    my $self = shift;
    my $interface = shift;
    return keys %{$self->{interfaces}->{$interface}->{props}};
}

sub get_object_path {
    my $self = shift;
    return $self->{object_path};
}

sub get_method_params {
    my $self = shift;
    my $interface = shift;
    my $method = shift;
    return @{$self->{interfaces}->{$interface}->{methods}->{$method}->{params}};
}

sub get_method_returns {
    my $self = shift;
    my $interface = shift;
    my $method = shift;
    return @{$self->{interfaces}->{$interface}->{methods}->{$method}->{returns}};
}

sub get_signal_params {
    my $self = shift;
    my $interface = shift;
    my $signal = shift;
    return @{$self->{interfaces}->{$interface}->{signals}->{$signal}};
}


sub get_property_type {
    my $self = shift;
    my $interface = shift;
    my $prop = shift;
    return $self->{interfaces}->{$interface}->{props}->{$prop}->[0];
}


sub is_property_readable {
    my $self = shift;
    my $interface = shift;
    my $prop = shift;
    my $access = $self->{interfaces}->{$interface}->{props}->{$prop}->[1];
    return $access eq "readwrite" || $access eq "read" ? 1 : 0;
}


sub is_property_writable {
    my $self = shift;
    my $interface = shift;
    my $prop = shift;
    my $access = $self->{interfaces}->{$interface}->{props}->{$prop}->[1];
    return $access eq "readwrite" || $access eq "write" ? 1 : 0;
}


sub _parse {
    my $self = shift;
    my $xml = shift;

    my $grove_builder = XML::Grove::Builder->new;
    my $parser = XML::Parser::PerlSAX->new(Handler => $grove_builder);
    my $document = $parser->parse ( Source => { String => $xml } );
    
    my $root = $document->{Contents}->[0];
    $self->_parse_node($root);
}

sub _parse_node {
    my $self = shift;
    my $node = shift;

    $self->{object_path} = $node->{Attributes}->{name} if defined $node->{Attributes}->{name};
    die "no object path provided" unless defined $self->{object_path};
    $self->{children} = [];
    foreach my $child (@{$node->{Contents}}) {
	if (ref($child) eq "XML::Grove::Element" &&
	    $child->{Name} eq "interface") {
	    $self->_parse_interface($child);
	} elsif (ref($child) eq "XML::Grove::Element" &&
		 $child->{Name} eq "node") {
	    my $subcont = $child->{Contents};
	    if ($#{$subcont} == -1) {
		push @{$self->{children}}, $child->{Attributes}->{name};
	    } else {
		push @{$self->{children}}, $self->new(node => $child);
	    }
	}
    }
}

sub _parse_interface {
    my $self = shift;
    my $node = shift;
    
    my $name = $node->{Attributes}->{name};
    $self->{interfaces}->{$name} = {
	methods => {},
	signals => {},
	props => {},
    };
    
    foreach my $child (@{$node->{Contents}}) {
	if (ref($child) eq "XML::Grove::Element" &&
	    $child->{Name} eq "method") {
	    $self->_parse_method($child, $name);
	} elsif (ref($child) eq "XML::Grove::Element" &&
		 $child->{Name} eq "signal") {
	    $self->_parse_signal($child, $name);
	} elsif (ref($child) eq "XML::Grove::Element" &&
		 $child->{Name} eq "property") {
	    $self->_parse_property($child, $name);
	}
    }
}


sub _parse_method {
    my $self = shift;
    my $node = shift;
    my $interface = shift;
    
    my $name = $node->{Attributes}->{name};
    my @params;
    my @returns;
    foreach my $child (@{$node->{Contents}}) {
	if (ref($child) eq "XML::Grove::Element" &&
	    $child->{Name} eq "arg") {
	    my $type = $child->{Attributes}->{type};
	    my $direction = $child->{Attributes}->{direction};
	    
	    my @sig = split //, $type;
	    my @type = $self->_parse_type(\@sig);
	    if (!defined $direction || $direction eq "in") {
		push @params, @type;
	    } elsif ($direction eq "out") {
		push @returns, @type;
	    }
	}
    }

    $self->{interfaces}->{$interface}->{methods}->{$name} = {
	params => \@params,
	returns => \@returns,
    }
}

sub _parse_type {
    my $self = shift;
    my $sig = shift;
    
    my $root = [];
    my $current = $root;
    my @cont;
    while (my $type = shift @{$sig}) {
	if (exists $simple_type_rev_map{ord($type)}) {
	    push @{$current}, $simple_type_rev_map{ord($type)};
	    if ($current->[0] eq "array") {
		$current = pop @cont;
	    }
	} else {
	    if ($type eq "(") {
		my $new = ["struct"];
		push @{$current}, $new;
		push @cont, $current;
		$current = $new;
	    } elsif ($type eq "a") {
		my $new = ["array"];
		push @cont, $current;
		push @{$current}, $new;
		$current = $new;
	    } elsif ($type eq "{") {
		if ($current->[0] ne "array") {
		    die "dict must only occur within an array";
		}
		$current->[0] = "dict";
	    } elsif ($type eq ")") {
		die "unexpected end of struct" unless
		    $current->[0] eq "struct";
		$current = pop @cont;
		if ($current->[0] eq "array") {
		    $current = pop @cont;
		}
	    } elsif ($type eq "}") {
		die "unexpected end of dict" unless
		    $current->[0] eq "dict";
		$current = pop @cont;
		if ($current->[0] eq "array") {
		    $current = pop @cont;
		}
	    } else {
		die "unknown type sig '$type'";
	    }
	}
    }
    return @{$root};
}

sub _parse_signal {
    my $self = shift;
    my $node = shift;
    my $interface = shift;
    
    my $name = $node->{Attributes}->{name};
    my @params;
    foreach my $child (@{$node->{Contents}}) {
	if (ref($child) eq "XML::Grove::Element" &&
	    $child->{Name} eq "arg") {
	    my $type = $child->{Attributes}->{type};
	    my @sig = split //, $type;
	    my @type = $self->_parse_type(\@sig);
	    push @params, @type;
	}
    }
    
    $self->{interfaces}->{$interface}->{signals}->{$name} = 
	\@params;
}

sub _parse_property {
    my $self = shift;
    my $node = shift;
    my $interface = shift;
    
    my $name = $node->{Attributes}->{name};
    my $access = $node->{Attributes}->{access};
    
    $self->{interfaces}->{$interface}->{props}->{$name} = 
	[ $self->_parse_type([$node->{Attributes}->{type}]),
	  $access ];
}

sub format {
    my $self = shift;
    
    my $xml = '<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"' . "\n";
    $xml .= '"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">' . "\n";
    
    return $xml . $self->to_xml("");
}

sub to_xml {
    my $self = shift;
    my $indent = shift;
    
    my $xml = '';
    $xml .= $indent . '<node name="' . $self->{object_path} . '">' . "\n";
    
    foreach my $name (sort { $a cmp $b } keys %{$self->{interfaces}}) {
	my $interface = $self->{interfaces}->{$name};
	$xml .= $indent . '  <interface name="' . $name . '">' . "\n";
	foreach my $mname (sort { $a cmp $b } keys %{$interface->{methods}}) {
	    my $method = $interface->{methods}->{$mname};
	    $xml .= $indent . '    <method name="' . $mname . '">' . "\n";
	    
	    foreach my $type (@{$method->{params}}) {
		next if ! ref($type) && exists $magic_type_map{$type};
		$xml .= $indent . '      <arg type="' . $self->to_xml_type($type) . '" direction="in"/>' . "\n";
	    }
	    
	    foreach my $type (@{$method->{returns}}) {
		next if ! ref($type) && exists $magic_type_map{$type};
		$xml .= $indent . '      <arg type="' . $self->to_xml_type($type) . '" direction="out"/>' . "\n";
	    }
	    	    
	    $xml .= $indent . '    </method>' . "\n";
	}
	foreach my $sname (sort { $a cmp $b } keys %{$interface->{signals}}) {
	    my $signal = $interface->{signals}->{$sname};
	    $xml .= $indent . '    <signal name="' . $sname . '">' . "\n";
	    
	    foreach my $type (@{$signal}) {
		next if ! ref($type) && exists $magic_type_map{$type};
		$xml .= $indent . '      <arg type="' . $self->to_xml_type($type) . '"/>' . "\n";
	    }
	    $xml .= $indent . '    </signal>' . "\n";
	}
	    
	foreach my $pname (sort { $a cmp $b } keys %{$interface->{props}}) {
	    my $type = $interface->{props}->{$pname}->[0];
	    my $access = $interface->{props}->{$pname}->[1];
	    $xml .= $indent . '    <property name="' . $pname . '" type="' . 
		$self->to_xml_type($type) . '" access="' . $access . '"/>' . "\n";
	}
	    
	$xml .= $indent . '  </interface>' . "\n";
    }

    foreach my $child (@{$self->{children}}) {
	if (ref($child) eq __PACKAGE__) {
	    $xml .= $child->to_xml($indent . "  ");
	} else {
	    $xml .= $indent . '  <node name="' . $child . '"/>' . "\n";
	}
    }
    $xml .= $indent . "</node>\n";
}


sub to_xml_type {
    my $self = shift;
    my $type = shift;

    my $sig = '';
    if (ref($type) eq "ARRAY") {
	if ($type->[0] eq "array") {
	    if ($#{$type} != 1) {
		die "array spec must contain only 1 type";
	    }
	    $sig .= chr($compound_type_map{$type->[0]});
	    $sig .= $self->to_xml_type($type->[1]);
	} elsif ($type->[0] eq "struct") {
	    $sig .= "("; 
	    for (my $i = 1 ; $i <= $#{$type} ; $i++) {
		$sig .= $self->to_xml_type($type->[$i]);
	    }
	    $sig .= ")";
	} elsif ($type->[0] eq "dict") {
	    if ($#{$type} != 2) {
		die "dict spec must contain only 2 types";
	    }
	    $sig .= chr($compound_type_map{"array"});
	    $sig .= "{";
	    $sig .= $self->to_xml_type($type->[1]);
	    $sig .= $self->to_xml_type($type->[2]);
	    $sig .= "}";
	} else {
	    die "unknown/unsupported compound type " . $type->[0] . " expecting 'array', 'struct', or 'dict'";
	}
    } else {
	die "unknown/unsupported scalar type '$type'"
	    unless exists $simple_type_map{$type};
	$sig .= chr($simple_type_map{$type});
    }
    return $sig;
}


sub encode {
    my $self = shift;
    my $message = shift;
    my $type = shift;
    my $name = shift;
    my $direction = shift;
    my @args = @_;

    my $interface = $message->get_interface;

    if ($interface) {
	die "no interface '$interface' in introspection data for object '" . $self->get_object_path . "' encoding $type '$name'\n"
	    unless exists $self->{interfaces}->{$interface};
	die "no introspection data when encoding $type '$name' in object " . $self->get_object_path . "\n" 
	    unless exists $self->{interfaces}->{$interface}->{$type}->{$name};
    } else {
	foreach my $in (keys %{$self->{interfaces}}) {
	    if (exists $self->{interfaces}->{$in}->{$type}->{$name}) {
		$interface = $in;
	    }
	}
	if (!$interface) {
	    die "no interface in introspection data for object " . $self->get_object_path . " encoding $type '$name'\n" 
	}
    }

    my @types = $type eq "signals" ? 
	@{$self->{interfaces}->{$interface}->{$type}->{$name}} :
	@{$self->{interfaces}->{$interface}->{$type}->{$name}->{$direction}};
    
    # If you don't explicitly 'return ()' from methods, Perl
    # will always return a single element representing the
    # return value of the last command executed in the method.
    # To avoid this causing a PITA for methods exported with
    # no return values, we throw away returns instead of dieing
    if ($direction eq "returns" &&
	$#types == -1 &&
	$#args != -1) {
	@args = ();
    }

    die "expected " . int(@types) . " $direction, but got " . int(@args) 
	unless $#types == $#args;
    
    my $iter = $message->iterator(1);
    foreach my $t ($self->convert(@types)) {
	$iter->append(shift @args, $t);
    }
}


sub convert {
    my $self = shift;
    my @in = @_;

    my @out;
    foreach my $in (@in) {
	if (ref($in) eq "ARRAY") {
	    my @subtype = @{$in};
	    shift @subtype;
	    my @subout = $self->convert(@subtype);
	    die "unknown compound type " . $in->[0] unless
		exists $compound_type_map{lc $in->[0]};
	    push @out, [$compound_type_map{lc $in->[0]}, \@subout];
	} elsif (exists $magic_type_map{lc $in}) {
	    push @out, $magic_type_map{lc $in};
	} else {
	    die "unknown simple type " . $in unless
		exists $simple_type_map{lc $in};
	    push @out, $simple_type_map{lc $in};
	}
    }
    return @out;
}


sub decode {
    my $self = shift;
    my $message = shift;
    my $type = shift;
    my $name = shift;
    my $direction = shift;
    my @args = @_;

    my $interface = $message->get_interface;

    if ($interface) {
	die "no interface '$interface' in introspection data for object '" . $self->get_object_path . "' decoding $type '$name'\n"
	    unless exists $self->{interfaces}->{$interface};
	die "no introspection data when encoding $type '$name' in object " . $self->get_object_path . "\n" 
	    unless exists $self->{interfaces}->{$interface}->{$type}->{$name};
    } else {
	foreach my $in (keys %{$self->{interfaces}}) {
	    if (exists $self->{interfaces}->{$in}->{$type}->{$name}) {
		$interface = $in;
	    }
	}
	if (!$interface) {
	    die "no interface in introspection data for object " . $self->get_object_path . " decoding $type '$name'\n" 
	}
    }

    my @types = $type eq "signals" ? 
	@{$self->{interfaces}->{$interface}->{$type}->{$name}} :
	@{$self->{interfaces}->{$interface}->{$type}->{$name}->{$direction}};

    # If there are no types defined, just return the
    # actual data from the message, assuming the introspection
    # data was partial.
    return $message->get_args_list 
	unless @types;

    my $iter = $message->iterator;
    
    my @rawtypes = $self->convert(@types);
    my @ret;
    do {
	my $type = shift @types;
	my $rawtype = shift @rawtypes;
	
	if (exists $magic_type_map{$type}) {
	    push @ret, &$rawtype($message);
	} else {
	    push @ret, $iter->get($rawtype);
	}
    } while ($iter->next);
    return @ret;
}
