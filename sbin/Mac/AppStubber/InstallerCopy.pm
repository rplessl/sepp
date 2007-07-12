use strict;
package Mac::AppStubber::InstallerCopy;

=head1 NAME

Mac::AppStubber::InstallerCopy - Force Copying a part of a dir-tree

=head1 SYNOPSIS

$i=Mac::AppStubber::InstallerCopy->new($I<dirname>,$I<source>);

$i->as_symlink()

$i->install($I<inst-dir>,$I<target-base>)

=head1 DESCRIPTION

Handles part of a directory tree by copying it as installation.

=over 10

=item $i=Mac::AppStubber::InstallerCopy->new($I<dirname>,$I<source>);

Create instance, copy from I<source>.

=item $i->as_symlink()

Always returns false.

=item $i->install($I<inst-dir>,$I<target-base>)

Basically a C<cp -rf>.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

# Installation of an item by explicit copy.

# @items is a list of InstallerItems.

use Mac::AppStubber::InstallerItem;
use vars qw(@ISA);
@ISA=('Mac::AppStubber::InstallerItem');

require Mac::AppStubber::InstallerItem;

sub new
  {
    my ($class,$dirname,$source)=@_;
    die "ERROR: Internal: Should not be empty" unless $dirname;
    my $self=Mac::AppStubber::InstallerItem::new($class,$dirname);
    $self->{source}=$source;
    return $self;
  }

# Is always symlink
sub as_symlink
  {
    return 0;
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

    # To check whether the copied file/dir is identical, we could do a
    # comparison (recursive)... Better: Erase and copy again.

    
    Mac::AppStubber::InfoHi "Copying $t to $n";
    $this->make_copy($t,$n);
  }

1;
