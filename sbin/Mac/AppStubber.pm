use strict;
package Mac::AppStubber;
use vars qw/$forced $warn $error $info $noaction/;


=head1 NAME

Mac::AppStubber - Modules to install and manipulate OSX-AppBundles

=head1 SYNOPSIS

$i=Mac::AppStubber::scan_dir($I<path>,@I<scanners>)

$Mac::AppStubber::noaction

$Mac::AppStubber::force

=head1 DESCRIPTION

The AppStubber package contains tools to manage the installation of
OSX-Application directories. Rather than copying the big applications,
only Stubs and symlinks are created. Using easily configurable scanner
sequences, a set of installer instances is built, providing
information and functionality to install (stub) a directory of
OSX-Applications.

=over 10

=item $i=Mac::AppStubber::scan_dir($I<path>,@I<scanners>)

Wrapper. Scan I<path> using I<scanners>

$Mac::AppStubber::noaction

If true, don't do, but just report.

$Mac::AppStubber::force

Remove whatever is in the way if necessary

=back

=head2 Example

Create a set of scanners. The order of the scanners is important, as
the first matching scanner will terminate the search and provide the
information about what is to be installed (and how).

 my @sc=
   (

First filter out the items we don't want to install

    Mac::AppStubber::InstallerScannerFilter->new("$pack/Applications/Nonsense"),

... And the ones we want to B<copy completely>.

    Mac::AppStubber::InstallerScannerCopy->new("$pack/Applications/i.+"),

Now make sure that app-bundles are treated apropriately

    Mac::AppStubber::InstallerScannerAppBundle->new(exec_target=>"/usr/sepp/stub/macpkg-1.0-as"),

And avoid going into directories where no apps should be (e.g. examples)

    Mac::AppStubber::InstallerScannerSymlink->new("$pack/Applications/Examplefiles"),

Now, make sure that directories are scanned recursively,...

    Mac::AppStubber::InstallerScannerRecurse->new(),

... and catch what is left, making symlinks out of it.

    Mac::AppStubber::InstallerScannerDefault->new()
   );

All set. so scan the directory.

 my $i=Mac::AppStubber::scan_dir "$pack/Applications",@sc;


This time we only want to see what would happen. So set C<$noaction>
and run the installation

  $Mac::AppStubber::InstallerItem::noaction=1;
  $r->install ("inst","/usr/sepp/macosx/Applications");

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut


#our $noaction;
#our $forced;

# @keep are items of class InstallerCopy
sub scan_dir
  {
    require Mac::AppStubber::InstallerScannerRecurse;

    my ($thispath,@scanners)=@_;
    return undef unless -d $thispath;

    # Never symlink the start-directory, but only the subdirs
    my $scan=Mac::AppStubber::InstallerScannerRecurse->new(hard=>1);
    return $scan->create_installer(undef,$thispath,@scanners);
  }

#our $warn;
#our $error;
#our $info;

sub init
  {
    ($error,$warn,$info)=@_;
  }

sub Warning
  {
    &$warn;
  }

sub WarningForce
  {
    $warn->("@_ (see --force)");
  }

sub Error
  {
    &$error;
  }

sub InfoLow
  {
    if($noaction)
      {
	$info->("  @_");
      }
  }

sub InfoHi
  {
    &$info;
  }

1;
