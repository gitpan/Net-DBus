#!/usr/bin/perl -w

use Net::DBus;
use Net::DBus::Reactor;
use Net::DBus::Service;
use Net::DBus::Object;

use Carp qw(confess cluck);

#$SIG{__WARN__} = sub { cluck $_[0] };
#$SIG{__DIE__} = sub { confess $_[0] };

package TestObject;

use base qw(Net::DBus::Object);
use Net::DBus::Exporter qw(org.designfu.TestService);

sub new {
    my $class = shift;
    my $service = shift;
    my $self = $class->SUPER::new($service, "/org/designfu/TestService/object");
				  
    
    bless $self, $class;
    
    return $self;
}

dbus_signal("hello", ["string"]);
dbus_method("emitHelloSignal", ["string"]);
sub emitHelloSignal {
    my $self = shift;
    my $name = shift;
    print "Got request to send hello signal\n";
    return $self->emit_signal("hello", "Hello " . $name);
}


package main;


my $bus = Net::DBus->find();
my $service = $bus->export_service("org.designfu.TestService");
my $object = TestObject->new($service);

Net::DBus::Reactor->main->run();


