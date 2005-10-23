use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $DBUS_LIBS = `pkg-config --libs dbus-1`;
my $DBUS_CFLAGS = `pkg-config --cflags dbus-1`;

if (!defined $DBUS_LIBS || !defined DBUS_CFLAGS) {
    die "could not run 'pkg-config' to determine compiler/linker flags for dbus library: $!\n";
}
if (!$DBUS_LIBS || !$DBUS_CFLAGS) {
    die "'pkg-config' didn't report any compiler/linker flags for dbus library\n";
}

WriteMakefile(
    'NAME' => 'Net::DBus',
    'VERSION_FROM' => 'lib/Net/DBus.pm',
    'PREREQ_PM' => {
        'Test::More'  => 0,
        'Time::HiRes' => 0,
        'XML::Grove' => 0,
        'XML::Parser' => 0
    },
#    'ABSTRACT_FROM' => 'lib/Net/DBus.pm',
    'AUTHOR' => 'Daniel Berrange <dan@berrange.com>',
    'LIBS' => [$DBUS_LIBS], 
    'DEFINE' => "-DDBUS_API_SUBJECT_TO_CHANGE -DPD_DO_DEBUG=1",
    'INC' => "-Wall $DBUS_CFLAGS",
    'depend' => {
       Net-DBus.spec => '$(VERSION_FROM)',
       Makefile => '$(VERSION_FROM)',
    }
);

package MY;

sub libscan
  {
    my ($self, $path) = @_;
    ($path =~ /\~$/ || $path =~ m,/CVS/,) ? undef : $path;
  }

sub postamble {
    return '
TO_TEST_PM = $(TO_INST_PM:lib/%.pm=blib/test/%.pm)

XXXtest :: $(TO_TEST_PM)

blib/test/%.pm: blib/lib/%.pm
	@echo -n "Checking $@: "
	@perl -I blib/lib -I blib/arch -c $<
	@mkdir -p `dirname $@`
	@touch $@
';
}


__END__
