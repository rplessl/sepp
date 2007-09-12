use strict;
package Mac::AppStubber::InstallerScanner;

=head1 NAME

Mac::AppStubber::InstallerScanner - Base class for scanning a directory

=head1 SYNOPSIS

$s=Mac::AppStubber::InstallerScanner->new()

$s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

=head1 DESCRIPTION

The C<InstallScanner> classes are used to scan through a directory
tree, packing it up into an C<InstallerItem> tree.

=over 10

=item $s=Mac::AppStubber::InstallerScanner->new()

Create a new instance.

=item $s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

Used to create a new C<InstallerItem> for I<targetpath>. The name of
the new C<InstallerItem> will be set to I<dirname>. To support
recursion, the active I<scanners> are passed on (see
C<InstallerScannerRecurse>).

C<create_installer> has the following return value conventions:

=over 15

=item undef

The scanner did not match the passed item, indicating that some other
Scanner should be found.

=item C<""> or C<0> (false)

The item matched and the scanner deliberately stated that the item
should be ignored further on.

=item Reference to C<InstallerItem>

Scanner matched and returned an instance that can install the item.

=back

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

sub new
  {
    my $self={};
    bless($self,$_[0]);
    return $self;
  }

# Default behaviour: Make a symlink.
sub create_installer
  {
    die "ERROR: Internal Problem: Should never be called!!!";
  }

1;
