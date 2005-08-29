# -*- perl -*-
use Test::More tests => 3;

use strict;
use warnings;

BEGIN { 
    use_ok('Net::DBus::Introspector');
    use_ok('Net::DBus::Object');
};

my $object = Net::DBus::Object->new(new DummyService(), "/org/example/Object/OtherObject");

my $introspector = $object->_introspector;

my $xml_got = $introspector->format();
    
my $xml_expect = <<EOF;
<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node name="/org/example/Object/OtherObject">
  <interface name="org.freedesktop.DBus.Introspectable">
    <method name="Introspect">
      <arg type="s" direction="out"/>
    </method>
  </interface>
</node>
EOF
    
    is($xml_got, $xml_expect, "xml data matches");


package DummyService;

sub new {
    my $class = shift;
    my $self = {};
    
    $self->{bus} = DummyBus->new();

    bless $self, $class;
    
    return $self;
}

sub get_bus {
    my $self = shift;
    return $self->{bus};
}

package DummyBus;

sub new {
    my $class = shift;
    my $self = {};
    
    $self->{connection} = DummyConnection->new();

    bless $self, $class;
    
    return $self;
}

sub get_connection {
    my $self = shift;
    return $self->{connection};
}


package DummyConnection;

sub new {
    my $class = shift;
    my $self = {};

    bless $self, $class;

    return $self;
}


sub register_object_path {
    my $self = shift;
    # nada
}
