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

    my $reply = $bus->get_connection->send_with_reply_and_block($msg);

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

    my $reply = eval {
	$bus->get_connection->send_with_reply_and_block($msg);
    };
    ok($@, "error is set");
}

sub GET_SET_NAME: {
    my $msg1 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Get");
    
    my $iter1 = $msg1->iterator(1);
    $iter1->append_string("org.example.MyObject");
    $iter1->append_string("name");
    
    $object->name("John Doe");

    my $reply1 = $bus->get_connection->send_with_reply_and_block($msg1);

    isa_ok($reply1, "Net::DBus::Binding::Message::MethodReturn");
    
    my ($value1) = $reply1->get_args_list;
    is($value1, "John Doe", "name is John Doe");

    
    my $msg2 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Set");
    
    my $iter2 = $msg2->iterator(1);
    $iter2->append_string("org.example.MyObject");
    $iter2->append_string("name");
    $iter2->append_variant("Jane Doe");

    my $reply2 = $bus->get_connection->send_with_reply_and_block($msg2);

    isa_ok($reply2, "Net::DBus::Binding::Message::MethodReturn");


    my $reply3 = $bus->get_connection->send_with_reply_and_block($msg1);

    isa_ok($reply3, "Net::DBus::Binding::Message::MethodReturn");
    
    my ($value2) = $reply3->get_args_list;
    is($value2, "Jane Doe", "name is Jane Doe");    
}


SET_AGE: {
    my $msg1 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Get");
    
    my $iter1 = $msg1->iterator(1);
    $iter1->append_string("org.example.MyObject");
    $iter1->append_string("age");
    
    
    my $msg2 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Set");
    
    my $iter2 = $msg2->iterator(1);
    $iter2->append_string("org.example.MyObject");
    $iter2->append_string("age");
    $iter2->append_variant(21);

    my $reply1 = $bus->get_connection->send_with_reply_and_block($msg2);

    isa_ok($reply1, "Net::DBus::Binding::Message::MethodReturn");


    my $reply2 = eval {
	$bus->get_connection->send_with_reply_and_block($msg1);
    };
    ok($@, "error is set");

    is($object->age, 21, "age is 21");
}


GET_EMAIL: {
    my $msg1 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Get");
    
    my $iter1 = $msg1->iterator(1);
    $iter1->append_string("org.example.MyObject");
    $iter1->append_string("email");
    
    $object->email('john@example.com');
    
    my $msg2 = Net::DBus::Binding::Message::MethodCall->new(service_name => "org.example.MyService",
							    object_path => "/org/example/MyObject",      
							    interface => "org.freedesktop.DBus.Properties",
							    method_name => "Set");
    
    my $iter2 = $msg2->iterator(1);
    $iter2->append_string("org.example.MyObject");
    $iter2->append_string("email");
    $iter2->append_variant('jane@example.com');

    my $reply1 = eval {
	$bus->get_connection->send_with_reply_and_block($msg2);
    };
    ok($@, "error is set");

    my $reply2 = $bus->get_connection->send_with_reply_and_block($msg1);

    isa_ok($reply2, "Net::DBus::Binding::Message::MethodReturn");

    is($object->age, 21, "age is 21");

    my ($value) = $reply2->get_args_list;
    is($value, 'john@example.com', 'email is john@example.com');
}


