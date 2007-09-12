use strict;
package Mac::AppStubber::InstallerScannerCopy;

=head1 NAME

Mac::AppStubber::InstallerScannerCopy - Force copying of an item

=head1 SYNOPSIS

$s=Mac::AppStubber::InstallerScannerCopy->new(@I<path-rexps>)

$s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

=head1 DESCRIPTION

Ensures that certain paths are not treated with symlinks but rather
copied for installation.

=over 10

=item $s=Mac::AppStubber::InstallerScannerCopy->new(@I<path-rexps>)

Create a new instance. Provide a list of regular expressions in
I<path-rexps>. When scanning a directory item, the class tries to
match the rexps.

=item $s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

Returns a I<InstallerCopy> instance, should one the I<path-rexps>
match. Otherwise C<undef> is returned, allowing other scanners to do
their work.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

use vars qw(@ISA);
@ISA =qw( Mac::AppStubber::InstallerScanner );

require Mac::AppStubber::InstallerScanner;
sub new
  {
    my $self=Mac::AppStubber::InstallerScanner::new($_[0]);
    shift;
    $self->{hard}=[@_];
    return $self;
  }

sub create_installer
  {
    require Mac::AppStubber::InstallerCopy;
    my( $this,$dirname,$path ) = @_;
    if( grep { "$path" =~ m{$_} } @{$this->{hard}} )
      {
	my $inst=Mac::AppStubber::InstallerCopy->new($dirname,$path);
	return $inst;
      }

    return undef;
  }

1;
