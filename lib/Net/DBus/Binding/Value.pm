=pod

=head1 NAME

Net::DBus::Binding::Value - A strongly typed value

=head1 SYNOPSIS


=head1 DESCRIPTION



=head1 METHODS

=over 4

=cut

package Net::DBus::Binding::Value;


use 5.006;
use strict;
use warnings;
use Carp qw(confess);

use Net::DBus;

our $VERSION = '0.0.1';


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = [];
    
    $self->[0] = shift;
    $self->[1] = shift;
    
    bless $self, $class;

    return $self;
}


sub type {
    my $self = shift;
    return $self->[0];
}

sub value {
    my $self = shift;
    return $self->[1];
}

1;

=pod

=back

=head1 SEE ALSO

L<Net::DBus::Binding::Message>

=head1 AUTHOR

Daniel Berrange E<lt>dan@berrange.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Daniel Berrange

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
