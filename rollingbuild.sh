#!/bin/sh
#
# This script is used to Test::AutoBuild (http://www.autobuild.org)
# to perform automated builds of the DBus module

NAME=Net-DBus

set -e

make -k realclean ||:
rm -rf MANIFEST blib pm_to_blib

if [ -z "$DBUS_HOME" ]; then
  perl Makefile.PL  PREFIX=$AUTO_BUILD_ROOT
else
  perl Makefile.PL DBUS_HOME=$DBUS_HOME  PREFIX=$AUTO_BUILD_ROOT
fi

rm -f MANIFEST
make manifest
echo $NAME.spec >> MANIFEST

# Build the RPM.
make

perl -MDevel::Cover -e '' 1>/dev/null 2>&1 && USE_COVER=1 || USE_COVER=0
if [ "$USE_COVER" = "1" ]; then
  cover -delete
  HARNESS_PERL_SWITCHES=-MDevel::Cover make test
  cover
  mkdir blib/coverage
  cp -a cover_db/*.html cover_db/*.css blib/coverage
  mv blib/coverage/coverage.html blib/coverage/index.html
else
  make test
fi

make install

rm -f $NAME-*.tar.gz
make dist

if [ -f /usr/bin/rpmbuild ]; then
  rpmbuild -ta --clean $NAME-*.tar.gz
fi

# Skip debian pkg for now
exit 0

if [ -f /usr/bin/fakeroot ]; then
  fakeroot debian/rules clean
  fakeroot debian/rules DESTDIR=$HOME/packages/debian binary
fi
