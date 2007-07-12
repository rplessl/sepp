use strict;
package Mac::AppStubber::InstallerItem;

=head1 NAME

Mac::AppStubber::InstallerItem - Base Class for all (stub-)installable items

=head1 SYNOPSIS

$i= Mac::AppStubber::InstallerItem->new($I<dirname>);

$i->as_symlink();

$name=$i->name([$I<New name>]);

$i->install($I<inst-dir>,$I<target-base>);

$i->remove_path($I<path>);
$i->make_symlink($I<from>,$I<to>);
$i->make_copy($I<from>,$I<to>);
$i->do_system(@I<command>);

=head1 DESCRIPTION

The C<InstallerItem> base-class provides a common interface for all
items (subdirs, links, files,...) that are to be installed as stubs in
a target directory. Furthermore, it provides the basic tools for
file/dir-manipulation.

=head2 Installer Interface 

=over 10

=item $i= Mac::AppStubber::InstallerItem->new([$I<dirname>]);

Creates a new installable object. I<dirname> can be omited. The
behaviour is then dependent on the inherited class

=item $i->as_symlink();

Checks whether the item can be installed using a symlink. Usually
returns true. Special behaviour for Directories (see C<InstallerDir>)

=item $name=$i->name([$I<New name>]);

Get/Set the name of the item

=item $i->install($I<inst-dir>,[$I<target-base>]);

Install the item into I<inst-dir>. For relative paths, I<target-base>
can be prepended, allowing symlinks to point to different location.

=back

=head2 Basic File Tools

=over 10

=item $i->remove_path($I<path>);

Basically does an C<rm -rf> to I<path>, depending on the settings of
C<$noaction> and C<$force> in the C<Mac::AppStubber> module.

=item $i->make_symlink($I<from>,$I<to>);

Create symlinks C<$force> cleans the location of symlink before
creating it.

=item $i->make_copy($I<from>,$I<to>);

Do a C<cp -rp>

=item $i->do_system(@I<command>);

Run a command using the Perl C<system> function.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

sub new
  {
    my ($class,$dirname)=@_;
    my $self={dirname=>$dirname};
    bless($self,$class);
    return $self;
  }


# Can the directory item be installed into /usr/sepp/macosx/Applications
# as symlink?
sub as_symlink
  {
    die "ERROR: Internal Problem: Needs to be overridden when inherited";
  }

sub count
  {
    return;
  }

sub name
  {
    if(defined $_[1])
      {
	$_[0]->{dirname}=$_[1];
      }
    else
      {
	return $_[0]->{dirname};
      }
  }

sub install
  {
    die "ERROR: Internal Problem: Needs to be overridden when inherited";
  }



sub remove_path
  {
    shift if(UNIVERSAL::isa($_[0],'Mac::AppStubber::InstallerItem'));
    
    die "ERROR: Internal problem: force and noaction active" 
      if $Mac::AppStubber::force && $Mac::AppStubber::noaction;
    
    my $n=$_[0];
    my $hi=$_[1];
    
    # Can be called from low-level and from high-level
    if($hi)
      {
	Mac::AppStubber::InfoHi "Removing $n";
      }
    else
      {
	Mac::AppStubber::InfoLow "Removing $n";
      }
    if($Mac::AppStubber::forced)
      {
	my @cmd=('/bin/rm','-rf',$n);
	0==do_system(@cmd)
	  or Mac::AppStubber::Error "Could not run @cmd";
      }
    else
      {
	Mac::AppStubber::WarningForce "Did not remove $n." 
	    if -e $n;
      }
  }

sub make_symlink
  {
    shift if(UNIVERSAL::isa($_[0],'Mac::AppStubber::InstallerItem'));

    my ($t,$n)=@_;

    # Leave it if it already exists
    my $cl=readlink $n;
    return if -l $n and $t eq $cl;

    Mac::AppStubber::InfoHi "Creating symlink $n --> $t";
    remove_path($n) if -e $n;

    if(not $Mac::AppStubber::noaction)
      {
	return if symlink $t,$n;

	if($Mac::AppStubber::force)
	  {
	    Mac::AppStubber::Error "Could not create symlink $n";
	  }
	else
	  {
	    Mac::AppStubber::WarningForce "Could not create symlink $n";
	  }
      }
  }

sub make_dir
  {
    shift if(UNIVERSAL::isa($_[0],'Mac::AppStubber::InstallerItem'));

    my ($n)=@_;

    remove_path($n) if -e $n;

    Mac::AppStubber::InfoLow "Creating directory $n";
    if(not $Mac::AppStubber::noaction)
      {
	return if mkdir $n,0755;

	if($Mac::AppStubber::force)
	  {
	    Mac::AppStubber::Error "Could not mkdir $n";
	  }
	else
	  {
	    Mac::AppStubber::WarningForce "Could not mkdir $n";
	  }
      }
  }

sub make_copy
  {
    shift if(UNIVERSAL::isa($_[0],'Mac::AppStubber::InstallerItem'));
    my ($t,$n)=@_;

    remove_path($n) if -e $n;

    Mac::AppStubber::InfoLow "Copying to $n from $t";
    if(not $Mac::AppStubber::noaction)
      {
	my @cmd=('/bin/cp','-rp',$t,$n);
	0==do_system(@cmd)
	  or Mac::AppStubber::Error "Could not run @cmd";

	if($Mac::AppStubber::force)
	  {
	    Mac::AppStubber::Error "Could not copy to $n from $t";
	  }
	else
	  {
	    Mac::AppStubber::WarningForce "Could not to $n from $t";
	  }
      }
  }

sub do_system
  {
    shift if(UNIVERSAL::isa($_[0],'Mac::AppStubber::InstallerItem'));
    my @cmd=@_;

    Mac::AppStubber::InfoLow "Running @cmd";
    if(not $Mac::AppStubber::noaction)
      {
	system @cmd;
	my $rv=$?;


	return $rv>>8
	  unless($rv & 255);

	if($Mac::AppStubber::forced)
	  {
	    Mac::AppStubber::Error "Could not start $cmd[0]";
	  }
	else
	  {
	    Mac::AppStubber::Warning "Could not start $cmd[0]";
	  }
      }
  }


1;
