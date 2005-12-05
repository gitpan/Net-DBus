# -*- perl -*-

use Test::More tests => 93;

package MyObject1;

use Test::More;
use base qw(Net::DBus::Object);
use Net::DBus;
use Net::DBus::Service;

use Net::DBus::Exporter qw(org.example.MyObject);

my $bus = Net::DBus->test;
my $service = $bus->export_service("org.example.MyService");
my $obj = MyObject1->new($service, "/org/example/MyObject");

# First the full APIs
dbus_method("Everything", ["string"], ["int32"]);
dbus_method("EverythingInterface", ["string"], ["int32"], "org.example.OtherObject");

# Now add in annotations to the mix
dbus_method("EverythingAnnotate", ["string"], ["int32"], { deprecated => 1, 
							   no_return => 1 });
dbus_method("EverythingNegativeAnnotate", ["string"], ["int32"], { deprecated => 0, 
								   no_return => 0 });
dbus_method("EverythingInterfaceAnnotate", ["string"], ["int32"], "org.example.OtherObject", { deprecated => 1, 
											       no_return => 1 });
dbus_method("EverythingInterfaceNegativeAnnotate", ["string"], ["int32"], "org.example.OtherObject", { deprecated => 0, 
												       no_return => 0 });

# Now test 'defaults'
dbus_method("NoArgsReturns");
dbus_method("NoReturns", ["string"]);
dbus_method("NoArgs",[],["int32"]);
dbus_method("NoArgsReturnsInterface", "org.example.OtherObject");
dbus_method("NoReturnsInterface", ["string"], "org.example.OtherObject");
dbus_method("NoArgsInterface", [],["int32"], "org.example.OtherObject");

dbus_method("NoArgsReturnsAnnotate", { deprecated => 1 });
dbus_method("NoReturnsAnnotate", ["string"], { deprecated => 1 });
dbus_method("NoArgsAnnotate",[],["int32"], { deprecated => 1 });
dbus_method("NoArgsReturnsInterfaceAnnotate", "org.example.OtherObject", { deprecated => 1 });
dbus_method("NoReturnsInterfaceAnnotate", ["string"], "org.example.OtherObject", { deprecated => 1 });
dbus_method("NoArgsInterfaceAnnotate", [],["int32"], "org.example.OtherObject", { deprecated => 1 });



my $ins = Net::DBus::Exporter::dbus_introspector($obj);

is($ins->get_object_path, "/org/example/MyObject", "object path");
ok($ins->has_interface("org.example.MyObject"), "interface registration");
ok(!$ins->has_interface("org.example.BogusObject"), "-ve interface registration");

&check_method($ins, "Everything", ["string"], ["int32"], "org.example.MyObject", 0, 0);
&check_method($ins, "EverythingInterface", ["string"], ["int32"], "org.example.OtherObject", 0, 0);
&check_method($ins, "EverythingAnnotate", ["string"], ["int32"], "org.example.MyObject", 1, 1);
&check_method($ins, "EverythingNegativeAnnotate", ["string"], ["int32"], "org.example.MyObject", 0, 0);
&check_method($ins, "EverythingInterfaceAnnotate", ["string"], ["int32"], "org.example.OtherObject", 1, 1);
&check_method($ins, "EverythingInterfaceNegativeAnnotate", ["string"], ["int32"], "org.example.OtherObject", 0, 0);

&check_method($ins, "NoArgsReturns", [], [], "org.example.MyObject", 0, 0);
&check_method($ins, "NoReturns", ["string"], [], "org.example.MyObject", 0, 0);
&check_method($ins, "NoArgs", [], ["int32"], "org.example.MyObject", 0, 0);
&check_method($ins, "NoArgsReturnsInterface", [], [], "org.example.OtherObject", 0, 0);
&check_method($ins, "NoReturnsInterface", ["string"], [], "org.example.OtherObject", 0, 0);
&check_method($ins, "NoArgsInterface", [], ["int32"], "org.example.OtherObject", 0, 0);

&check_method($ins, "NoArgsReturnsAnnotate", [], [], "org.example.MyObject", 1, 0);
&check_method($ins, "NoReturnsAnnotate", ["string"], [], "org.example.MyObject", 1, 0);
&check_method($ins, "NoArgsAnnotate", [], ["int32"], "org.example.MyObject", 1, 0);
&check_method($ins, "NoArgsReturnsInterfaceAnnotate", [], [], "org.example.OtherObject", 1, 0);
&check_method($ins, "NoReturnsInterfaceAnnotate", ["string"], [], "org.example.OtherObject", 1, 0);
&check_method($ins, "NoArgsInterfaceAnnotate", [], ["int32"], "org.example.OtherObject", 1, 0);


sub check_method {
    my $ins = shift;
    my $name = shift;
    my $params = shift;
    my $returns = shift;
    my $interface = shift;
    my $deprecated = shift;
    my $no_return = shift;
    
    my @interfaces = $ins->has_method($name);
    is_deeply([$interface], \@interfaces, "method interface mapping");

    my @params = $ins->get_method_params($interface, $name);
    is_deeply($params, \@params, "method parameters");

    my @returns = $ins->get_method_returns($interface, $name);
    is_deeply($returns, \@returns, "method returneters");
    
    if ($deprecated) {
	ok($ins->is_method_deprecated($name, $interface), "method deprecated");
    } else {
	ok(!$ins->is_method_deprecated($name, $interface), "method deprecated");
    }


    if ($no_return) {
	ok(!$ins->does_method_reply($name, $interface), "method no reply");
    } else {
	ok($ins->does_method_reply($name, $interface), "method no reply");
    }


}
