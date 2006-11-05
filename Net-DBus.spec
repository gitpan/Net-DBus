# Automatically generated by DBus.spec.PL

%define debug_package %{nil}
%define perlvendorarch %(perl -e 'use Config; print $Config{installvendorarch}')
%define perlvendorlib %(perl -e 'use Config; print $Config{installvendorlib}')
%define perlvendorprefix %(perl -e 'use Config; print $Config{vendorprefix}')
%define perlvendorman3 %{perlvendorprefix}/share/man/man3
%define perlversion %(perl -e 'use Config; print $Config{version}')
%define appname Net-DBus

%define _extra_release %{?extra_release:%{extra_release}}

Summary: Perl API to the DBus message system
Name: perl-%{appname}
Version: 0.33.4
Release: 1%{_extra_release}
License: GPL
Group: Applications/Internet
Source: %{appname}-%{version}.tar.gz
BuildRoot: /var/tmp/%{appname}-%{version}-root
#BuildArchitectures: noarch
Requires: perl = %{perlversion}
# For XML::Twig
Requires: perl(XML::Twig)
# For Time::HiRes
Requires: perl(Time::HiRes)
Requires: dbus >= 0.33
BuildRequires: dbus-devel >= 0.33
BuildRequires: perl(XML::Twig)

%description
Provides a Perl API to the DBus message system

%prep
%setup -q -n %{appname}-%{version}


%build
if [ -z "$DBUS_HOME" ]; then
  perl Makefile.PL PREFIX=$RPM_BUILD_ROOT/usr INSTALLDIRS=vendor
else
  perl Makefile.PL PREFIX=$RPM_BUILD_ROOT/usr INSTALLDIRS=vendor DBUS_HOME=$DBUS_HOME
fi
make

%install
rm -rf $RPM_BUILD_ROOT
make install INSTALLVENDORMAN3DIR=$RPM_BUILD_ROOT%{perlvendorman3}
find $RPM_BUILD_ROOT -name perllocal.pod -exec rm -f {} \;
find $RPM_BUILD_ROOT -name .packlist -exec rm -f {} \;

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc README CHANGES AUTHORS COPYING examples/*.pl
%{perlvendorman3}/*
%{perlvendorarch}/Net/DBus.pm
%{perlvendorarch}/Net/DBus/
%{perlvendorarch}/auto/Net/DBus

%changelog
* Fri Jan  6 2006 Daniel Berrange <berrange@localhost.localdomain> - 0.33.1-1
- Added explicit dependancies on perl-libxml-perl and perl-Time-HiRes
- Increased min required dbus version to 0.33 since we 
  need the dbus_connection_unregister_object_path method
