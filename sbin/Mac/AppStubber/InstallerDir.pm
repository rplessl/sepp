use strict;
package Mac::AppStubber::InstallerDir;


=head1 NAME

Mac::AppStubber::InstallerDir - Install a directory and its content.

=head1 SYNOPSIS

$i=Mac::AppStubber::InstallerDir->new($I<dirname>,$I<target>,$I<options>,@I<items>);

$i->as_symlink()

$i->count()

$i->item($I<number>)

$i->install($I<inst-dir>,$I<target-base>)

=head1 DESCRIPTION

Derived from C<InstallerItem>, the class manages a directory and all of its items.

=over 10

=item $i=Mac::AppStubber::InstallerDir->new($I<dirname>,$I<target>,$I<options>,@I<items>);

Create an instance, having I<items> of type I<InstallerItem> as
directory entries.  The options hash (I<options>) allows to control
whether the instance should try to determine whether the directory
can be substituted as a whole (C<hard=E<gt>1>).

=item $i->as_symlink()

Scann I<items> and find out whether any item needs to be copied. If
not, returns true, suggesting that the entire directory could be
installed through a single symlink.

=item $i->count()

How many I<items> are there?

=item $i->item($I<number>)

Get <item> I<number>.

=item $i->install($I<inst-dir>,$I<target-base>)

Perform the installation. Either symlinks the directory (see C<new()>)
or create a directory and process all I<items>.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

# Installation of a subdirectory
# Contains a list of items in the directory

# @items is a list of InstallerItems.

use Mac::AppStubber::InstallerItem;
use vars qw(@ISA);
@ISA=('Mac::AppStubber::InstallerItem');

sub new
  {
    my ($class,$dirname,$target,$options,@items)=@_;
    my $self=Mac::AppStubber::InstallerItem::new($class,$dirname);
    $self->{items}=[@items];
    $self->{target}=$target;
    $self->{options}= {};
    $self->{options}= { %$options } if $options;
    return $self;
  }

# We can substitute the enitre dir as symlink, if the
# items in the dir also would be created as symlinks:
sub as_symlink
  {
    my $self=$_[0];
    for (@{$self->{items}})
      {
	return 0 unless $_->as_symlink();
      }
    return 1;
  }

sub count
  {
    return $#{$_[0]->{items}};
  }

sub item
  {
    return $_[0]->{items}->[$_[1]];
  }

sub install
  {
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

    # Check whether we need to descend into the directory
    # and make a symlink if apropriate.
    if (not $this->{options}->{hard} and $this->as_symlink())
      {
	$this->make_symlink($t,$n);
	return;
      }

    if( -d $n )
      {
	# Directory already existed
	# --> Scan and erase all directory entries that don't 
	# exist in the set to be installed ($this->{items})

	    my @i=(map {$_->name()} @{$this->{items}});
	    Mac::AppStubber::Error "Could not read dir $n" unless opendir DIR,$n;
	    for my $d (grep { ! /^\.\.?$/ } readdir DIR)
	      {
		$this->remove_path("$n/$d")
		  unless( grep {$_ eq $d} @i )
	      }
	  }
    else
      {
	# Directory doesn't exist yet
	Mac::AppStubber::InfoHi "Creating directory $n";
	$this->make_dir($n);
      }

    # Then descend into the directory items.

    for my $i (@{$this->{items}})
      {
	$i->install($n,$targetbase);
      }
  }

1;
