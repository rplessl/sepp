use strict;
package Mac::AppStubber::InstallerScannerAppBundle;

=head1 NAME

Mac::AppStubber::InstallerScannerAppBundle - Identify App bundles

=head1 SYNOPSIS

$s=Mac::AppStubber::InstallerScannerAppBundle->new(%I<options>)

$s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

=head1 DESCRIPTION

The scanner matches for C<.app> bundles, allowing special treatment
(stubbing) of applications.

=over 10

=item $s=Mac::AppStubber::InstallerScannerAppBundle->new(%I<options>)

Create a new instance. I<options> is passed along to
C<InstallerItemAppBundle::new()>

=item $s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

Upon finding a directory ending with C<.app>, an instance of
C<InstallerItemAppBundle> is returned. Otherwise <undef>.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

require Mac::AppStubber::InstallerScanner;
use vars qw(@ISA);
@ISA=( 'Mac::AppStubber::InstallerScanner' );

sub new
  {
    my $class=shift;
    my $self=Mac::AppStubber::InstallerScanner::new($class);
    $self->{installer_options}={ @_ };
    return $self;
  }

# If we find a directory, descend and produce an installer item.
sub create_installer
  {
    my( $this,$dirname,$thispath)=@_;

    # Currently limit to AppBundles in form of directories.
    # Later on maybe extend to single file (+resource fork)
    return undef unless $dirname =~ m/\.app$/;
    return undef unless -d $thispath;


    require Mac::AppStubber::InstallerAppBundle;

    my $rv=Mac::AppStubber::InstallerAppBundle->new
      (
       $dirname,
       $thispath,
       %{$this->{installer_options}}
      );
    return $rv;
  }

1;
