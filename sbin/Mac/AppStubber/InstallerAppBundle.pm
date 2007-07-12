use strict;
package Mac::AppStubber::InstallerAppBundle;


=head1 NAME

Mac::AppStubber::InstallerAppBundle - Create a stub for an AppBundle

=head1 SYNOPSIS

$i=Mac::AppStubber::InstallerAppBundle->new($I<dirname>,$I<target>,%I<options>);

$i->as_symlink()

$i->install($I<inst-dir>,$I<target-base>)

=head1 DESCRIPTION

To avoid excessive automounting, App-Bundles are not linked by
symbolic links. Rhather a stub is created for the bundle, containing
all the configuration details, but not the real (big) application.

The executable (script) of the bundle stub is installed in form of a
symbolic link. The name of the original App Bundle is encoded into the
new name of this symlink.

=over 10

=item $i=Mac::AppStubber::InstallerAppBundle->new($I<dirname>,$I<target>,%I<options>);

Create instance. The created stub will refer to I<target> through the
name of its executable, allowing to find the location of the real
App-bundle. Hash I<options> contains:

=over 15

=item C<target_prefix=E<gt>>I<string>

Prefix to be cut of from the path to the target (the original
App). Thus, the name of the executable can be made shorter and
non-redundant.

=item C<exec_target=E<gt>>I<string>

Target for the symbolic link (executable of the bundle).

=back

=item $i->as_symlink()

Always returns false.

=item $i->install($I<inst-dir>,$I<target-base>)

Uses C<Mac::AppStubber::StubCreator> to build a stub for an .app bundle.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut
# Installation of an .app Bundle

# @items is a list of InstallerItems.

use Mac::AppStubber::InstallerItem;
use vars qw(@ISA);
@ISA=( 'Mac::AppStubber::InstallerItem' );

sub new
  {
    my ($class,$dirname,$target,%options)=@_;
    die "ERROR: Internal: Should not be empty" unless $dirname;
    my $self=Mac::AppStubber::InstallerItem::new($class,$dirname);
    $self->{target}=$target;
    $self->{options}=\%options;
    return $self;
  }

# AppBundles never can be replaced by symlinks --> return 0
sub as_symlink
  {
    return 0;
  }

sub install
  {
    require Mac::AppStubber::StubCreator;

    my($this,$instdir,$targetbase)=@_;

    $instdir =~ s|/(\./)+|/|g;
    $instdir =~ s|^\./||;
    $instdir =~ s|/$||;

    my $n=$instdir;

    $n.="/" if ($n && $n ne "." && $this->{dirname});
    $n.=$this->{dirname};
    $n="." unless $n;     # Ensure that empty dir works

    my $t=$targetbase;
    $t.="/" if $t;
    $t.=$this->{target};

    $this->remove_path($n) if -e $n;

    Mac::AppStubber::InfoHi "Creating stub $n from Application $t";
    Mac::AppStubber::StubCreator::create_stub
	($t,$n,$this->{options}->{exec_target},$this->{options}->{target_prefix});
  }

1;
