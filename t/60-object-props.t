# -*- perl -*-
use Test::More tests => 13;

use strict;
use warnings;

BEGIN { 
    use_ok('Net::DBus::Binding::Introspector');
    use_ok('Net::DBus::Object');
};

package MyObject;

use base qw(Net::DBus::Object);
use Net::DBus::Exporter qw(org.example.MyObject);

# Typically one would use Class::MethodMaker, but I don't
# want to add a hard dependancy for the test suite.
#use Class::MethodMaker [ scalar => ["name", "email", "age" ]];

sub name {
    my $self = shift;
    $self->{name} = shift if @_;
    return $self->{name};
}

sub email {
    my $self = shift;
    $self->{email} = shift if @_;
    return $self->{email};
}

sub age {
    my $self = shift;
    $self->{age} = shift if @_;
    return $self->{age};
}

dbus_property("name", "string");
dbus_property("email", "string", "read");
dbus_property("age", "int32" ,"write");

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
    <property name="age" type="i" access="write"/>
    <property name="email" type="s" access="read"/>
    <property name="name" type="s" access="readwrite"/>
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

GET_NAME: {
    my $msg = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							   object_path => "/org/example/MyObject",      
							   interface => "org.freedesktop.DBus.Properties",
							   method_name => "Get");
    
    my $iter = $msg->iterator(1);
    $iter->append_string("org.example.MyObject");
    $iter->append_string("name");
    
    $object->name("John Doe");

    $object->_dispatch($service->get_bus->get_connection, $msg);
    my $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::MethodReturn");
    
    my ($value) = $reply->get_args_list;
    is($value, "John Doe", "name is John Doe");
}

GET_BOGUS: {
    my $msg = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							   object_path => "/org/example/MyObject",      
							   interface => "org.freedesktop.DBus.Properties",
							   method_name => "Get");
    
    my $iter = $msg->iterator(1);
    $iter->append_string("org.example.MyObject");
    $iter->append_string("bogus");
    
    $object->name("John Doe");

    $object->_dispatch($service->get_bus->get_connection, $msg);
    my $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::Error");
}

sub GET_SET_NAME: {
    my $msg1 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Get");
    
    my $iter = $msg1->iterator(1);
    $iter->append_string("org.example.MyObject");
    $iter->append_string("name");
    
    $object->name("John Doe");

    $object->_dispatch($service->get_bus->get_connection, $msg1);
    my $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::MethodReturn");
    
    my ($value) = $reply->get_args_list;
    is($value, "John Doe", "name is John Doe");

    
    my $msg2 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Set");
    
    $iter = $msg2->iterator(1);
    $iter->append_string("org.example.MyObject");
    $iter->append_string("name");
    $iter->append_variant("Jane Doe");

    $object->_dispatch($service->get_bus->get_connection, $msg2);
    $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::MethodReturn");


    $object->_dispatch($service->get_bus->get_connection, $msg1);
    $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::MethodReturn");
    
    ($value) = $reply->get_args_list;
    is($value, "Jane Doe", "name is Jane Doe");    
}


SET_AGE: {
    my $msg1 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Get");
    
    my $iter = $msg1->iterator(1);
    $iter->append_string("org.example.MyObject");
    $iter->append_string("age");
    
    
    my $msg2 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Set");
    
    $iter = $msg2->iterator(1);
    $iter->append_string("org.example.MyObject");
    $iter->append_string("age");
    $iter->append_variant(21);

    $object->_dispatch($service->get_bus->get_connection, $msg2);
    my $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::MethodReturn");


    $object->_dispatch($service->get_bus->get_connection, $msg1);
    $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::Error");

    is($object->age, 21, "age is 21");
}


GET_EMAIL: {
    my $msg1 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Get");
    
    my $iter = $msg1->iterator(1);
    $iter->append_string("org.example.MyObject");
    $iter->append_string("email");
    
    $object->email('john@example.com');
    
    my $msg2 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Set");
    
    $iter = $msg2->iterator(1);
    $iter->append_string("org.example.MyObject");
    $iter->append_string("email");
    $iter->append_variant('jane@example.com');

    $object->_dispatch($service->get_bus->get_connection, $msg2);
    my $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::Error");


    $object->_dispatch($service->get_bus->get_connection, $msg1);
    $reply = $service->get_bus->get_connection->next_message;

    isa_ok($reply, "Net::DBus::Binding::Message::MethodReturn");

    is($object->age, 21, "age is 21");

    my ($value) = $reply->get_args_list;
    is($value, 'john@example.com', 'email is john@example.com');
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
