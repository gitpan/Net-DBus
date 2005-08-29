# -*- perl -*-
use Test::More tests => 21;
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
$iter->append_int32(123);
$iter->append_uint32(456);
if ($Net::DBus::Binding::Iterator::have_quads) {
  $iter->append_int64(12345645645);
  $iter->append_uint64(12312312312);
} else {
  $iter->append_boolean(1);
  $iter->append_boolean(1);
}
$iter->append_string("Hello world");
$iter->append_double(1.424141);

$iter = $msg->iterator();
ok($iter->get_boolean() == 1, "boolean");
ok($iter->next(), "next");
ok($iter->get_byte() == 43, "byte");
ok($iter->next(), "next");

ok($iter->get_int32() == 123, "int32");
ok($iter->next(), "next");
ok($iter->get_uint32() == 456, "uint32");
ok($iter->next(), "next");

if (!$Net::DBus::Binding::Iterator::have_quads) {
  ok(1, "int64 skipped");
  ok($iter->next(), "next");
  ok(1, "uint64 skipped");
  ok($iter->next(), "next");
} else {
  ok($iter->get_int64() == 12345645645, "int64");
  ok($iter->next(), "next");
  ok($iter->get_uint64() == 12312312312, "uint64");
  ok($iter->next(), "next");
}

ok($iter->get_string() eq "Hello world", "string");
ok($iter->next(), "next");
ok($iter->get_double() == 1.424141, "double");
ok(!$iter->next(), "next");

