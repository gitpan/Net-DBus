=pod

=head1 NAME

Net::DBus::Exporter - exports methods and signals to the bus

=head1 SYNOPSIS

  # Define a new package for the object we're going
  # to export
  package Demo::HelloWorld;

  # Specify the main interface provided by our object
  use Net::DBus::Exporter qw(org.example.demo.Greeter);

  # We're going to be a DBus object
  use base qw(Net::DBus::Object);

  # Export a 'Greeting' signal taking a stringl string parameter
  dbus_signal("Greeting", ["string"]);

  # Export 'Hello' as a method accepting a single string
  # parameter, and returning a single string value
  dbus_method("Hello", ["string"], ["string"]);

  # Export 'Goodbye' as a method accepting a single string
  # parameter, and returning a single string, but put it
  # in the 'org.exaple.demo.Farewell' interface
  dbus_method("Goodbye", ["string"], ["string"], "org.example.demo.Farewell");
  
=head1 DESCRIPTION

The C<Net::DBus::Exporter> module is used to export methods
and signals defined in an object to the message bus. Since
Perl is a loosely typed language it is not possible to automatically
determine correct type information for methods to be exported.
Thus when sub-classing L<Net::DBus::Object>, this package will
provide the type information for methods and signals.

When importing this package, an optional argument can be supplied
to specify the default interface name to associate with methods
and signals, for which an explicit interface is not specified.
Thus in the common case of objects only providing a single interface,
this removes the need to repeat the interface name against each
method exported.

=head1 SCALAR TYPES

When specifying scalar data types for parameters and return values,
the following string constants must be used to denote the data
type. When values corresponding to these types are (un)marshalled
they are represented as the Perl SCALAR data type (see L<perldata>).

=over 4

=item "string"

A UTF-8 string of characters

=item "int32"

A 32-bit signed integer

=item "uint32"

A 32-bit unsigned integer

=item "int64"

A 64-bit signed integer. NB, this type is not supported by
many builds of Perl on 32-bit platforms, so if used, your
data is liable to be truncated at 32-bits.

=item "uint64"

A 64-bit unsigned integer. NB, this type is not supported by
many builds of Perl on 32-bit platforms, so if used, your
data is liable to be truncated at 32-bits.

=item "byte"

A single 8-bit byte

=item "bool"

A boolean value

=item "double"

An IEEE double-precision floating point

=back

=head1 COMPOUND TYPES

When specifying compound data types for parameters and return
values, an array reference must be used, with the first element
being the name of the compound type. 

=over 4

=item ["array", ARRAY-TYPE]

An array of values, whose type os C<ARRAY-TYPE>. The C<ARRAY-TYPE>
can be either a scalar type name, or a nested compound type. When
values corresponding to the array type are (un)marshalled, they 
are represented as the Perl ARRAY data type (see L<perldata>). If,
for example, a method was declared to have a single parameter with
the type, ["array", "string"], then when calling the method one
would provide a array reference of strings:

    $object->hello(["John", "Doe"])

=item ["dict", KEY-TYPE, VALUE-TYPE]

A dictionary of values, more commonly known as a hash table. The
C<KEY-TYPE> is the name of the scalar data type used for the dictionary
keys. The C<VALUE-TYPE> is the name of the scalar, or compound
data type used for the dictionary values. When values corresponding
to the dict type are (un)marshalled, they are represented as the
Perl HASH data type (see L<perldata>). If, for example, a method was
declared to have a single parameter with the type ["dict", "string", "string"],
then when calling the method one would provide a hash reference 
of strings,

   $object->hello({forename => "John", surname => "Doe"});

=item ["struct", VALUE-TYPE-1, VALUE-TYPE-2]

A structure of values, best thought of as a variation on the array
type where the elements can vary. Many languages have an explicit
name associated with each value, but since Perl does not have a
native representation of structures, they are represented by the
LIST data type. If, for exaple, a method was declared to have a single
parameter with the type ["struct", "string", "string"], corresponding
to the C structure 

    struct {
      char *forename;
      char *surname;
    } name;

then, when calling the method one would provide an array refernce
with the values orded to match the structure

   $object->hello(["John", "Doe"]);

=back

=head1 METHODS

=over 4

=item dbus_method($name, $params, $returns);

=item dbus_method($name, $params, $returns, $interface);


Exports a method called C<$name>, having parameters whose types
are defined by C<$params>, and returning values whose types are
defined by C<$returns>. If the C<$interface> parameter is 
provided, then the method is associated with that interface, otherwise
the default interface for the calling package is used. The
value for the C<$params> parameter should be an array reference
with each element defining the data type of a parameter to the
method. Likewise, the C<$returns> parameter should be an array 
reference with each element defining the data type of a return
value. If it not possible to export a method which accepts a
variable number of parameters, or returns a variable number of
values.

=item dbus_signal($name, $params);

=item dbus_signal($name, $params, $interface);

Exports a signal called C<$name>, having parameters whose types
are defined by C<$params>, and returning values whose types are
defined by C<$returns>. If the C<$interface> parameter is 
provided, then the signal is associated with that interface, otherwise
the default interface for the calling package is used. The
value for the C<$params> parameter should be an array reference
with each element defining the data type of a parameter to the
signal. Signals do not have return values. It not possible to 
export a signal which has a variable number of parameters.

=back

=head1 EXAMPLES

=over 4

=item No paramters, no return values

A method which simply prints "Hello World" each time its called

   sub Hello {
       my $self = shift;
       print "Hello World\n";
   }

   dbus_method("Hello", [], []);

=item One string parameter, returning an boolean value

A method which accepts a process name, issues the killall
command on it, and returns a boolean value to indicate whether
it was successful.

   sub KillAll {
       my $self = shift;
       my $processname = shift;
       my $ret  = system("killall $processname");
       return $ret == 0 ? 1 : 0;
   }

   dbus_method("KillAll", ["string"], ["bool"]);

=item One list of strings parameter, returning a dictionary

A method which accepts a list of files names, stats them, and
returns a dictionary containing the last modification times.

    sub LastModified {
       my $self = shift;
       my $files = shift;

       my %mods;
       foreach my $file (@{$files}) {
          $mods{$file} = (stat $file)[9];
       }
       return \%mods;
    }

    dbus_method("LastModified", ["array", "string"], ["dict", "string", "int32"]);

=back

=head1 SEE ALSO

L<Net::DBus::Object>

=head1 AUTHORS

Daniel P, Berrange L<dan@berrange.com>

=cut

package Net::DBus::Exporter;

use vars qw(@ISA @EXPORT %dbus_exports %dbus_introspectors);

use warnings;
#use strict;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(dbus_method dbus_signal);


sub import {
    my $class = shift;

    my $caller = caller;
    if (exists $dbus_exports{$caller}) {
	warn "$caller is already registered with Net::DBus::Exporter";
	return;
    }

    $dbus_exports{$caller} = {
	methods => {},
	signals => {},
    };
    die "usage: use Net::DBus::Exporter 'interface-name';" unless @_;

    my $interface = shift;
    die "interface name '$interface' is not valid." .
	"Names must consist of tokens using the characters a-z, A-Z, 0-9, _, " .
	"with at least two tokens, separated by '.'\n"
	unless $interface =~ /^[a-zA-Z]\w*(\.[a-zA-Z]\w*)+$/;
    $dbus_exports{$caller}->{interface} = $interface;

    $class->export_to_level(1, "", @EXPORT);
}

sub dbus_introspector {
    my $object = shift;
    my $class = shift;

    $class = ref($object) unless $class;
    die "no introspection data available for '" . 
	$object->get_object_path . 
	"' and object is not cast to any interface" unless $class;
    
    if (!exists $dbus_exports{$class}) {
	# If this class has not been exported, lets look
	# at the parent class & return its introspection
        # data instead.
	if (defined (*{"${class}::ISA"})) {
	    my @isa = @{"${class}::ISA"};
	    foreach my $parent (@isa) {
		# We don't recurse to Net::DBus::Object
		# since we need to give sub-classes the
		# choice of not supporting introspection
		next if $parent eq "Net::DBus::Object";

		my $ins = &dbus_introspector($object, $parent);
		if ($ins) {
		    return $ins;
		}
	    }
	}
	return undef;
    }

    unless (exists $dbus_introspectors{$class}) {
	my $is = Net::DBus::Binding::Introspector->new(object_path => $object->get_object_path);
	
	&_dbus_introspector_add(ref($object), $is);
	$dbus_introspectors{$class} = $is;
    }
    
    return $dbus_introspectors{$class};
}

sub _dbus_introspector_add {
    my $class = shift;
    my $introspector = shift;

    my $exports = $dbus_exports{$class};
    if ($exports) {
	foreach my $method (keys %{$exports->{methods}}) {
	    my ($params, $returns, $interface) = @{$exports->{methods}->{$method}};
	    $introspector->add_method($method, $params, $returns, $interface);
	}
	foreach my $signal (keys %{$exports->{signals}}) {
	    my ($params, $interface) = @{$exports->{signals}->{$signal}};
	    $introspector->add_signal($signal, $params, $interface);
	}
    }
    

    if (defined (*{"${class}::ISA"})) {
	my @isa = @{"${class}::ISA"};
	foreach my $parent (@isa) {
	    &_dbus_introspector_add($parent, $introspector);
	}
    }
}

sub dbus_method {
    my $name = shift;
    my $params = shift;
    my $returns = shift;

    $params = [] unless defined $params;
    $returns = [] unless defined $returns;
    
    my $caller = caller;
    my $is = $dbus_exports{$caller};

    my $interface;
    if (@_) {
	$interface = shift;
    } elsif (!exists $is->{interface}) {
	die "interface not specified & not default interface defined";
    } else {
	$interface = $is->{interface};
    }
	
    $is->{methods}->{$name} = [$params, $returns, $interface];
}


sub dbus_signal {
    my $name = shift;
    my $params = shift;
    
    $params = [] unless defined $params;

    my $caller = caller;
    my $is = $dbus_exports{$caller};
    
    my $interface;
    if (@_) {
	$interface = shift;
    } elsif (!exists $is->{interface}) {
	die "interface not specified & not default interface defined";
    } else {
	$interface = $is->{interface};
    }
	
    $is->{signals}->{$name} = [$params, $interface];
}

1;
