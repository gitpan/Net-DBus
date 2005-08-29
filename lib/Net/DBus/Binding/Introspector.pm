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
);

our %compound_type_map = (
  "array" => &Net::DBus::Binding::Message::TYPE_ARRAY,
  "struct" => &Net::DBus::Binding::Message::TYPE_STRUCT,
  "dict" => &Net::DBus::Binding::Message::TYPE_DICT_ENTRY,
);


our $VERSION = '0.0.1';

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    my %params = @_;

    $self->{methods} = {};
    $self->{signals} = {};
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
	$self->{interfaces} = exists $params{interfaces} ? $params{interfaces} : {};
	$self->{children} = exists $params{children} ? $params{children} : [];
    }

    foreach my $name (keys %{$self->{interfaces}}) {
	my $interface = $self->{interfaces}->{$name};
	foreach my $method (keys %{$interface->{methods}}) {
	    $self->{methods}->{$method} = $interface->{methods}->{$method};
	}
	foreach my $signal (keys %{$interface->{signals}}) {
	    $self->{signals}->{$signal} = $interface->{signals}->{$signal};
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


sub add_method {
    my $self = shift;
    my $name = shift;
    my $params = shift;
    my $returns = shift;
    my $interface = shift;

    $self->add_interface($interface);

    $self->{methods}->{$name} = { params => $params,
				  returns => $returns };
    $self->{interfaces}->{$interface}->{methods}->{$name} = $self->{methods}->{$name};
}

sub add_signal {
    my $self = shift;
    my $name = shift;
    my $params = shift;
    my $interface = shift;

    $self->add_interface($interface);

    $self->{signals}->{$name} = $params;
    $self->{interfaces}->{$interface}->{signals}->{$name} = $self->{signals}->{$name};
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
    $self->{interfaces} = {};
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
    };
    
    foreach my $child (@{$node->{Contents}}) {
	if (ref($child) eq "XML::Grove::Element" &&
	    $child->{Name} eq "method") {
	    $self->_parse_method($child, $name);
	} elsif (ref($child) eq "XML::Grove::Element" &&
		 $child->{Name} eq "signal") {
	    $self->_parse_signal($child, $name);
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
	    if ($direction eq "in") {
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
		$xml .= $indent . '      <arg type="' . $self->to_xml_type($type) . '" direction="in"/>' . "\n";
	    }
	    
	    foreach my $type (@{$method->{returns}}) {
		$xml .= $indent . '      <arg type="' . $self->to_xml_type($type) . '" direction="out"/>' . "\n";
	    }
	    	    
	    $xml .= $indent . '    </method>' . "\n";
	}
	foreach my $sname (sort { $a cmp $b } keys %{$interface->{signals}}) {
	    my $signal = $interface->{signals}->{$sname};
	    $xml .= $indent . '    <signal name="' . $sname . '">' . "\n";
	    
	    foreach my $type (@{$signal}) {
		$xml .= $indent . '      <arg type="' . $self->to_xml_type($type) . '"/>' . "\n";
	    }
	    $xml .= $indent . '    </signal>' . "\n";
	}
	    
	$xml .= $indent . '  </interface>' . "\n";
    }

    foreach my $child (@{$self->{children}}) {
	if (ref($child) eq "Net::DBus::Introspector") {
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

    die "no introspection data for $name (type: $type) in object " . $self->get_object_path . "\n" 
	unless exists $self->{$type}->{$name};

    my @types = $type eq "signals" ? 
	@{$self->{$type}->{$name}} :
	@{$self->{$type}->{$name}->{$direction}};
    
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
    
    die "no introspection data for such $name ($type)" unless exists $self->{$type}->{$name};
    
    my @types = $type eq "signals" ? 
	@{$self->{$type}->{$name}} :
	@{$self->{$type}->{$name}->{$direction}};



    my $iter = $message->iterator;
    
    if ($iter->get_arg_type() == &Net::DBus::Binding::Message::TYPE_INVALID) {
	return ();
    }
    
    # XXX validate received message against instrospection data!
    my @rawtypes = $self->convert(@types);
    my @ret;
    do {
	my $rawtype = shift @rawtypes;
	my $type = shift @types;
	push @ret, $iter->get($rawtype);
    } while ($iter->next);

    return @ret;
}
