#!/usr/bin/perl -w

use strict;
use Net::DBus;

my $bus = Net::DBus->system;

# Get a handle to the HAL service
my $hal = $bus->get_service("org.freedesktop.Hal");

# Get the device manager
my $manager = $hal->get_object("/org/freedesktop/Hal/Manager", "org.freedesktop.Hal.Manager");

# List devices
foreach my $dev (sort { $a cmp $b } @{$manager->GetAllDevices}) {
    print $dev, "\n";
}
