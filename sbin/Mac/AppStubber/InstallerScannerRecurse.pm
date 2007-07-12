use strict;
package Mac::AppStubber::InstallerScannerRecurse;

=head1 NAME

Mac::AppStubber::InstallerScannerRecurse - Scan through a directory recursively

=head1 SYNOPSIS

$s=Mac::AppStubber::InstallerScannerRecurse->new(%I<options>)

$s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

=head1 DESCRIPTION

The C<InstallScanner> classes are used to scan through a directory
tree, packing it up into an C<InstallerItem> tree.

=over 10

=item $s=Mac::AppStubber::InstallerScannerRecurse->new(%I<options>)

Create a new instance. I<options> is passed to the created
C<InstallerItem>s.

=item $s->create_installer($I<dirname>,$I<targetpath>,@I<scanners>)

Read all items in I<targetpath>, then walk through all I<scanners> and
apply them. Aborts after a scanner returns a C<defined> value (see
C<InstallerScanner::create_installer()>). 

After all directory items have been processed, a C<InstallerDir>
instance is returned.

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
# $targetpath : Path under which the item was found in the original
#               ( common end not necessary: $targetpath !~ m/\Q$dirname\E$/ )
# $dirname : 
sub create_installer
  {
    my( $this,$dirname,$targetpath,@scanners)=@_;

    $targetpath =~ s|/(\./)+|/|g;
    $targetpath =~ s|^\./||;
    $targetpath =~ s|/$||;

    # Also traverses symbolic links to dirs
    # --> Works for var/Library/.... construction.
    return undef unless -d $targetpath;

    opendir DIR,$targetpath || Mac::AppStubber::Error "Can't open dir $targetpath";
    my @dir= grep { ! /^\.\.?$/ } readdir DIR; 
    close DIR;

    my @items;
    for my $d (@dir)
      {
	my $inst;
	# Check for each of the installers, if it can deal with the dir item.
	for my $scanner (@scanners)
	  {
	    my $newpath="$targetpath/$d";
	    $newpath=$d if $targetpath eq ".";
	    $inst=$scanner->create_installer($d,$newpath,@scanners);
	    last if defined $inst;
	  }
	# Subtle difference beween defined and condition:
	# create_installer might return: 
	#  undef --> Does not match the scanner (continue)
	#  defined --> Item was matched
	#      "",0 --> no installer provided ( skip item )
	#      Object-ref --> Installer.
	if($inst)
	  {
	    # We found a method to install the item --> OK.
	    push @items,$inst;
	  }
	elsif(not defined $inst)
	  {
	    Mac::AppStubber::Warning "$d was not covered by any scanner";
	  }
      }

    require Mac::AppStubber::InstallerDir;

    return Mac::AppStubber::InstallerDir->new
      (
       $dirname,$targetpath,
       $this->{installer_options},
       @items);
  }

1;
