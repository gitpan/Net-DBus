# -*- perl -*-
use Test::More tests => 33;

use strict;
use warnings;

BEGIN { 
        use_ok('Net::DBus::Binding::Iterator');
        use_ok('Net::DBus::Binding::Message::Signal');
        use_ok('Net::DBus::Binding::Message::MethodCall');
        use_ok('Net::DBus::Binding::Message::MethodReturn');
        use_ok('Net::DBus::Binding::Message::Error');
	};


my $msg = Net::DBus::Binding::Message::Signal->new(object_path => "/foo/bar/Wizz",	
	interface => "com.blah.Example",
        signal_name => "Eeek");

my $iter = $msg->iterator(1);
$iter->append_boolean(1);
$iter->append_byte(43);
$iter->append_int16(123);
$iter->append_uint16(456);
$iter->append_int32(123);
$iter->append_uint32(456);
$iter->append_int64("12345645645");
$iter->append_uint64("12312312312");
$iter->append_int64("12345645645123456");
$iter->append_uint64("12312312312123456");
$iter->append_string("Hello world");
$iter->append_double(1.424141);

$iter->append_array(["one", "two", "three"], [&Net::DBus::Binding::Message::TYPE_STRING]);

$iter->append_dict({ "one" => "foo", "two" => "bar"}, [&Net::DBus::Binding::Message::TYPE_STRING,
						       &Net::DBus::Binding::Message::TYPE_STRING]);

$iter = $msg->iterator();
ok($iter->get_boolean() == 1, "boolean");
ok($iter->next(), "next");
ok($iter->get_byte() == 43, "byte");
ok($iter->next(), "next");

ok($iter->get_int16() == 123, "int16");
ok($iter->next(), "next");
ok($iter->get_uint16() == 456, "uint16");
ok($iter->next(), "next");

ok($iter->get_int32() == 123, "int32");
ok($iter->next(), "next");
ok($iter->get_uint32() == 456, "uint32");
ok($iter->next(), "next");

ok($iter->get_int64() == "12345645645", "int64");
ok($iter->next(), "next");
ok($iter->get_uint64() == "12312312312", "uint64");
ok($iter->next(), "next");

ok($iter->get_int64() == "12345645645123456", "int64");
ok($iter->next(), "next");
ok($iter->get_uint64() == "12312312312123456", "uint64");
ok($iter->next(), "next");

ok($iter->get_string() eq "Hello world", "string");
ok($iter->next(), "next");
# Don't test precise equality, because floating point arithmetic
# is not an exact science. (see RT #37707)
my $d = $iter->get_double();
ok($d > 1.424100 && $d < 1.424200, "double");

ok($iter->next(), "next");
is_deeply($iter->get_array(&Net::DBus::Binding::Message::TYPE_STRING), ["one", "two", "three"], "array");

ok($iter->next(), "next");
is_deeply($iter->get_dict(), {"one" => "foo", "two" => "bar"}, "dict");

ok(!$iter->next(), "next");

