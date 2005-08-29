=pod

=head1 NAME

Net::DBus::Service - represents a service exported to the message bus

=head1 SYNOPSIS

  package main;

  use Net::DBus;

  # Attach to the bus
  my $bus = Net::DBus->find;

  # Acquire a service 'org.demo.Hello'
  my $service = $bus->export_service("org.demo.Hello");

  # Export our object within the service
  my $object = Demo::HelloWorld->new($service);

  ....rest of program...

=head1 DESCRIPTION

This module represents a service which is exported to the message
bus. Once a service has been exported, it is possible to create
and export objects to the bus.

=head1 SEE ALSO

L<Net::DBus>, L<Net::DBus::Object>, L<Net::DBus::RemoteService>

=cut


package Net::DBus::Service;


sub new {
    my $class = shift;
    my $self = {};

    $self->{bus} = shift;
    $self->{service_name} = shift;
    
    bless $self, $class;

    $self->get_bus->get_connection->request_name($self->get_service_name);
    
    return $self;
}

sub get_bus {
    my $self = shift;
    return $self->{bus};
}

sub get_service_name {
    my $self = shift;
    return $self->{service_name};
}

1;

