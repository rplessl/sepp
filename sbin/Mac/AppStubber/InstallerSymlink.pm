use strict;
package Mac::AppStubber::InstallerSymlink;

=head1 NAME

Mac::AppStubber::InstallerSymlink - Symlink a file or directory

=head1 SYNOPSIS

$i=Mac::AppStubber::Installersymlink->new($I<dirname>,$I<target>);

$i->as_symlink()

$i->install($I<inst-dir>,$I<target-base>)

=head1 DESCRIPTION

Handles the installation of a file or directory through symlinks.

=over 10

=item $i=Mac::AppStubber::InstallerSymlink->new($I<dirname>,$I<target>);

Create instance, link to I<target>.

=item $i->as_symlink()

Always returns true.

=item $i->install($I<inst-dir>,$I<target-base>)

Basically do a C<symlink>

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

# Installation of an item as symlink. Can be File or directory

# @items is a list of InstallerItems.


require Mac::AppStubber::InstallerItem;
use vars qw(@ISA);
@ISA=('Mac::AppStubber::InstallerItem');

sub new
  {
    my ($class,$dirname,$target)=@_;
    die "ERROR: Internal: Should not be empty" unless $dirname;
    my $self=Mac::AppStubber::InstallerItem::new($class,$dirname);
    $self->{target}=$target;
    return $self;
  }

# Is always symlink
sub as_symlink
  {
    return 1;
  }

sub install
  {
    my($this,$instdir,$targetbase)=@_;


    my $t=$targetbase;
    $t.="/" if $t;
    $t.=$this->{target};

    my $n=$instdir;
    $n.="/" if $n;
    $n.=$this->{dirname};

    Mac::AppStubber::InfoHi "Creating symlink $n --> $t";
    $this->make_symlink($t,$n);
  }

1;
