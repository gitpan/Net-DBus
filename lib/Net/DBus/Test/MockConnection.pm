# -*- perl -*-
#
# Copyright (C) 2004-2005 Daniel P. Berrange
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# $Id: MockConnection.pm,v 1.1 2005/11/21 11:37:04 dan Exp $

=pod

=head1 NAME

Net::DBus::Test::MockConnection - mock connection object for unit testing

=head1 SYNOPSIS

  use Net::DBus;

  my $bus = Net::DBus->test

  # Register a service, and the objec to be tested
  use MyObject
  my $service = $bus->export_service("org.example.MyService");
  my $object = MyObject->new($service);


  # Acquire the service & do tests
  my $remote_service = $bus->get_service('org.example.MyService');
  my $remote_object = $service->get_object("/org/example/MyObjct");

  # This traverses the mock connection, eventually
  # invoking 'testSomething' on the $object above.
  $remote_object->testSomething()

=head1 DESCRIPTION

This object provides a fake implementation of the L<Net::DBus::Binding::Connection>
enabling a pure 'in-memory' message bus to be mocked up. This is intended to
facilitate creation of unit tests for services which would otherwise need to 
call out to other object on a live message bus. It is used as a companion to
the L<Net::DBus::Test::MockObject> module which is how fake objects are to be
provided on the fake bus.

=head1 METHODS

=over 4

=cut

package Net::DBus::Test::MockConnection;

use strict;
use warnings;

use Net::DBus::Binding::Message::MethodReturn;

sub new {
    my $class = shift;
    my $self = {};
    
    $self->{replies} = [];
    $self->{signals} = [];
    $self->{objects} = {};
    $self->{filters} = [];
    
    bless $self, $class;
    
    return $self;
}


sub send {
    my $self = shift;
    my $msg = shift;
    
    if ($msg->isa("Net::DBus::Binding::Message::MethodCall")) {
	$self->_call_method($msg);
    } elsif ($msg->isa("Net::DBus::Binding::Message::MethodReturn") ||
	     $msg->isa("Net::DBus::Binding::Message::Error")) {
	push @{$self->{replies}}, $msg;
    } elsif ($msg->isa("Net::DBus::Binding::Message::Signal")) {
	push @{$self->{signals}}, $msg;
    } else {
	die "unhandled type of message " . ref($msg);
    }
}


sub request_name {
    my $self = shift;
    my $name = shift;
    my $flags = shift;
    
    # XXX do we care about this for test cases? probably not...
    # ....famous last words
}

sub send_with_reply_and_block {
    my $self = shift;
    my $msg = shift;
    my $timeout = shift;
    
    $self->send($msg);
    
    if ($#{$self->{replies}} == -1) {
	die "no reply for " . $msg->get_path . "->" . $msg->get_member . " received within timeout";
    }
    
    my $reply = shift @{$self->{replies}};
    if ($#{$self->{replies}} != -1) {
	die "too many replies received";
    }

    if (ref($reply) eq "Net::DBus::Binding::Message::Error") {
	my $iter = $reply->iterator;
	my $desc = $iter->get_string;
	my $err = { name => $reply->get_error_name,
		    message => $desc };
	bless $err, "Net::DBus::Error";
	die $err;
    }
    return $reply;
}


sub dispatch {
    my $self = shift;
    
    my @signals = @{$self->{signals}};
    $self->{signals} = [];
    foreach my $msg (@signals) {
	foreach my $cb (@{$self->{filters}}) {
	    # XXX we should worry about return value...
	    &$cb($self, $msg);
	}
    }
}

sub add_filter {
    my $self = shift;
    my $cb = shift;
    
    push @{$self->{filters}}, $cb;
}

sub register_object_path {
    my $self = shift;
    my $path = shift;
    my $code = shift;
    
    $self->{objects}->{$path} = $code;
}

sub _call_method {
    my $self = shift;
    my $msg = shift;

    if (exists $self->{objects}->{$msg->get_path}) {
	my $cb = $self->{objects}->{$msg->get_path};
	&$cb($self, $msg);
    } elsif ($msg->get_path eq "/org/freedesktop/DBus") {
	if ($msg->get_member eq "GetNameOwner") {
	    my $reply = Net::DBus::Binding::Message::MethodReturn->new(call => $msg);
	    my $iter = $reply->iterator(1);
	    $iter->append(":1.1");
	    $self->send($reply);
	}
    }
}

1;

=pod

=back

=head1 BUGS

It doesn't completely replicate the API of L<Net::DBus::Binding::Connection>, 
merely enough to make the high level bindings work in a test scenario.

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Test::MockObject>, L<Net::DBus::Binding::Connection>,
L<http://www.mockobjects.com/Faq.html>

=head1 COPYRIGHT

Copyright 2005 Daniel Berrange <dan@berrange.com>

=cut
