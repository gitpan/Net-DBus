package Net::DBus::Binding::Watch;

use 5.006;
use strict;
use warnings;
use Carp;

use Net::DBus;

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;

    croak "&Net::DBus::Binding::Watch::constant not defined" if $constname eq '_constant';

    if (!exists $Net::DBus::Binding::Watch::_constants{$constname}) {
        croak "no such constant \$Net::DBus::Binding::Watch::$constname";
    }

    {
	no strict 'refs';
	*$AUTOLOAD = sub { $Net::DBus::Binding::Watch::_constants{$constname} };
    }
    goto &$AUTOLOAD;
}

1;
__END__
