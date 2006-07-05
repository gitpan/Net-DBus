# -*- perl -*-
use Test::More tests => 10;

use strict;
use warnings;

BEGIN {
    use_ok('Net::DBus::Binding::Introspector');
};

local $/ = undef;
my $xml = <DATA>;

my $introspector = Net::DBus::Binding::Introspector->new(object_path => "/org/freedesktop/Avahi/ServiceBrowser",
							 xml => $xml);

isa_ok($introspector, "Net::DBus::Binding::Introspector");

ok($introspector->has_interface("org.freedesktop.DBus.Introspectable"),
   "org.freedesktop.DBus.Introspectable interface present");

ok($introspector->has_interface("org.freedesktop.Avahi.ServiceBrowser"),
   "org.freedesktop.Avahi.ServiceBrowser interface present");

ok($introspector->has_method("Free"), "Free method present");
ok($introspector->has_signal("ItemNew"), "ItemNew signal present");
ok($introspector->has_signal("ItemRemove"), "ItemRemove signal present");
ok($introspector->has_signal("Failure"), "Failure signal present");
ok($introspector->has_signal("AllForNow"), "AllForNow signal present");
ok($introspector->has_signal("CacheExhausted"), "CacheExhausted signal present");


__DATA__
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<?xml-stylesheet type="text/xsl" href="introspect.xsl"?>
<!DOCTYPE node SYSTEM "introspect.dtd">

<!-- $Id: ServiceBrowser.introspect 948 2005-11-12 18:55:52Z lennart $ -->

<!--
  This file is part of avahi.
 
  avahi is free software; you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License as
  published by the Free Software Foundation; either version 2 of the
  License, or (at your option) any later version.

  avahi is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with avahi; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
  02111-1307 USA.
-->

<node>
  
  <interface name="org.freedesktop.DBus.Introspectable">
    <method name="Introspect">
      <arg name="data" type="s" direction="out" />
    </method>
  </interface>

  <interface name="org.freedesktop.Avahi.ServiceBrowser">

    <method name="Free"/>
      
    <signal name="ItemNew">
      <arg name="interface" type="i"/>
      <arg name="protocol" type="i"/>
      <arg name="name" type="s"/>
      <arg name="type" type="s"/>
      <arg name="domain" type="s"/>
      <arg name="flags" type="u"/>
    </signal>

    <signal name="ItemRemove">
      <arg name="interface" type="i"/>
      <arg name="protocol" type="i"/>
      <arg name="name" type="s"/>
      <arg name="type" type="s"/>
      <arg name="domain" type="s"/>
      <arg name="flags" type="u"/>
    </signal>

    <signal name="Failure">
      <arg name="error" type="s"/>
    </signal>

    <signal name="AllForNow"/>

    <signal name="CacheExhausted"/>

  </interface> 
</node>
