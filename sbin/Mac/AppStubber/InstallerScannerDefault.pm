use strict;
package Mac::AppStubber::InstallerScannerDefault;

=head1 NAME

Mac::AppStubber::InstallerScannerDefault - Sentinel for the Scanner list

=head1 SYNOPSIS

$s=Mac::AppStubber::InstallerScannerDefault->new()

$s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

=head1 DESCRIPTION

Usually put at the end of a Scanner list, the class will always
suggest to symlink an item. As the class accepts all kind of directory
items, it never returns C<undef> or false.

=over 10

=item $s=Mac::AppStubber::InstallerScannerDefault->new()

Create a new instance.

=item $s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

Always returns a I<InstallerItemSymlink>.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut
require Mac::AppStubber::InstallerScanner;
use vars qw(@ISA);
@ISA= ('Mac::AppStubber::InstallerScanner' );


sub new
  {
    Mac::AppStubber::InstallerScanner::new(@_);
  }

# Default behaviour: Make a symlink.
sub create_installer
  {
    require Mac::AppStubber::InstallerSymlink;
    return Mac::AppStubber::InstallerSymlink->new($_[1],$_[2]);
  }

1;
