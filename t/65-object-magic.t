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

my $bus = Net::DBus->test;
my $service = $bus->export_service("/org/cpan/Net/Bus/test");
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

    my $reply = $bus->get_connection->send_with_reply_and_block($msg);
    is($reply->get_type, &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_RETURN);
    
    is($object->test_get_caller, ":1.1", "caller is :1.1");
}


SERIAL: {
    my $msg = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							   object_path => "/org/example/MyObject",      
							   interface => "org.example.MyObject",
							   method_name => "test_set_serial");

    my $reply = $bus->get_connection->send_with_reply_and_block($msg);

    is($reply->get_type, &Net::DBus::Binding::Message::MESSAGE_TYPE_METHOD_RETURN);
    
    is($object->test_get_serial, $msg->get_serial, "serial matches");
}

