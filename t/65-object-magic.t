# -*- perl -*-
use Test::More tests => 7;

use strict;
use warnings;

BEGIN { 
    use_ok('Net::DBus::Binding::Introspector');
    use_ok('Net::DBus::Object');
};

package MyObject;

use base qw(Net::DBus::Object);
use Net::DBus::Exporter qw(org.example.MyObject);

dbus_method("test_set_serial", ["serial"]);
dbus_method("test_set_caller", ["caller"]);

sub test_set_serial {
    my $self = shift;
    $self->{serial} = shift;
}

sub test_get_serial {
    my $self = shift;
    return $self->{serial};
}

sub test_set_caller {
    my $self = shift;
    $self->{caller} = shift;
}

sub test_get_caller {
    my $self = shift;
    return $self->{caller};
}

package main;

my $service = new DummyService();
my $object = MyObject->new($service, "/org/example/MyObject");

my $introspector = $object->_introspector;

my $xml_got = $introspector->format();
    
my $xml_expect = <<EOF;
<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node name="/org/example/MyObject">
  <interface name="org.example.MyObject">
    <method name="test_set_caller">
    </method>
    <method name="test_set_serial">
    </method>
  </interface>
  <interface name="org.freedesktop.DBus.Introspectable">
    <method name="Introspect">
      <arg type="s" direction="out"/>
    </method>
  </interface>
  <interface name="org.freedesktop.DBus.Properties">
    <method name="Get">
      <arg type="s" direction="in"/>
      <arg type="s" direction="in"/>
      <arg type="v" direction="out"/>
    </method>
    <method name="Set">
      <arg type="s" direction="in"/>
      <arg type="s" direction="in"/>
      <arg type="v" direction="in"/>
    </method>
  </interface>
</node>
EOF

is($xml_got, $xml_expect, "xml data matches");

CALLER: {
    my $msg = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							   object_path => "/org/example/MyObject",      
							   interface => "org.example.MyObject",
							   method_name => "test_set_caller");
    $msg->set_sender(":1.1");
    $object->_dispatch($service->get_bus->get_connection, $msg);
    my $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::MethodReturn");
    
    is($object->test_get_caller, ":1.1", "caller is :1.1");
}


SERIAL: {
    my $msg = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							   object_path => "/org/example/MyObject",      
							   interface => "org.example.MyObject",
							   method_name => "test_set_serial");
    $object->_dispatch($service->get_bus->get_connection, $msg);
    my $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::MethodReturn");
    
    is($object->test_get_serial, $msg->get_serial, "serial matches");
}



package DummyService;

sub new {
    my $class = shift;
    my $self = {};
    
    $self->{bus} = DummyBus->new();

    bless $self, $class;
    
    return $self;
}

sub _register_object {
    my $self = shift;
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

    $self->{msgs} = [];
    
    bless $self, $class;

    return $self;
}


sub send {
    my $self = shift;
    my $msg = shift;

    push @{$self->{msgs}}, $msg;
}

sub next_message {
    my $self = shift;

    return shift @{$self->{msgs}};
}

sub register_object_path {
    my $self = shift;
    # nada
}
