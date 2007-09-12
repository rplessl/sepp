use strict;
package Mac::AppStubber::InstallerScannerSymlink;

=head1 NAME

Mac::AppStubber::InstallerScannerSymlink - Force symlinlink

=head1 SYNOPSIS

$s=Mac::AppStubber::InstallerScannerSymlink->new(@I<path-rexps>)

$s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

=head1 DESCRIPTION

Ensures that certain paths are treated with symlinks for installation.

=over 10

=item $s=Mac::AppStubber::InstallerScannerSymlink->new(@I<path-rexps>)

Create a new instance. Provide a list of regular expressions in
I<path-rexps>. When scanning a directory item, the class tries to
match the rexps.

=item $s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

Returns a I<InstallerSymlink> instance, should one the I<path-rexps>
match. Otherwise C<undef> is returned, allowing other scanners to do
their work.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

require Mac::AppStubber::InstallerScanner;
use vars qw(@ISA);
@ISA=( 'Mac::AppStubber::InstallerScanner' );


sub new
  {
    my $self=Mac::AppStubber::InstallerScanner::new($_[0]);
    shift;
    $self->{soft}=[@_];
    return $self;
  }

sub create_installer
  {
    require Mac::AppStubber::InstallerSymlink;
    my( $this,$dirname,$path ) = @_;
    if( grep { "$path" =~ m{$_} } @{$this->{soft}} )
      {
	my $inst=Mac::AppStubber::InstallerSymlink->new($dirname,$path);
	return $inst;
      }

    return undef;
  }

1;
