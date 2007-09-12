use strict;
package osx_stubber;
use vars qw/$DIR $stubdir $libdir $error $warning $info $ReadMETA $ReadConf/;

=head1 NAME

osx_stubber - AppStubber functionality encapsulated for SEPP

=head1 SYNOPSIS

osx_stubber::init($I<DIR>,$I<error>,$I<warning>,$I<info>,$I<ReadMETA>,$I<ReadConf>)
osx_stubber::install_app_stubs($I<pack>,$I<default>,$I<forced>,$I<noaction>)
osx_stubber::install_app_libs($I<pack>,$I<default>,$I<forced>,$I<noaction>)
osx_stubber::remove_app_stubs($I<pack>,$I<noaction>)
osx_stubber::remove_app_libs($I<pack>,$I<noaction>)
osx_stubber::prefix_bundle($I<pack>,@I<bundle-paths>)

=head1 DESCRIPTION

For the Darwin/Unix part of the system, SEPP can be used in the conventional
way. Where GUI-Based applications come into play, SEPP needs to be extended.
This module provides top-level functionality that supports the various
C<seppadm> commands, based on supporting libraries (under
C</usr/sepp/sbin/Mac/). Before introducing the various commands of the 
module, the basics of the SEPP for MacOSX extensions is given:

=head2 The MacOSX Application Stub

To display/register GUI-applications in Finder without actually triggering
an automount in C</usr/pack/>, so called MacOSX App-Stubs are created from
each desired application in a SEPP package. Similar to their commandline
counterparts living in C</usr/sepp/stub>, MacOSX App-Stubs (short OSX-stubs)
are tiny C<.app> bundles that contain the necessary config
(C<Contents/Info.plist>,...) and Icons (C<.../Contents/Resources/....icns>)
required to work with an application in Finder. The executable of the bundle
has been replaced with a symlink to the package stub (in
C</usr/sepp/stub/>). Accordingly, when the application is opened, the stub
is executed and in turn C<$pack/SEPP/start.pl>. There the real application
can be started (analogously to the commandline SEPP structures). The module
C<MacOsxSeppStart.pm> contains all commands required to start OSX GUI
applications.

When called for a MacOSX installation (not necessarily on a MacOSX system),
C<seppadm> creates and manages bundle stubs inside the
C</usr/sepp/macosx/Applications> directory. The directory has two subdirs:
C<All> and C<Default> in which the stubs, rsp. symlinks to the stubs (from
C<Default> to C<all>) can be found. To furhter structure the packages, the
first package category given in C<SEPP/META> as subdirectory. E.g. the
application C<itunes-x.x.y-xy> that has category I<multimedia> indicated in
its C<META> has its corresponding stubs under

 /usr/sepp/macosx/Applications/All/itunes-x.x.y-xy/
 
and could also be accessed via the symlinks

 /usr/sepp/macosx/Applications/Default/itunes --> /usr/sepp/macosx/Applications/All/itunes-x.x.y-xy
 

To provide an applications with additional details (e.g. Preferences), the directory
C</usr/sepp/macosx/Library> is assembled from the pack var directories using symlinks.


=head2 Package Configuration file C<SEPP/META.macosx>

Since there is no clean way to distinguish between the OSX
applications/documents and Darwin CLI commands, a second configuration file
is used: C<META.macosx>

C<META.macosx> is used to supply C<seppadm> with the paths to the OSX
Application directories. The file is required in all packages supporting
Darwin and is resides besides the C<META> file in the
C</usr/pack/$Pack/SEPP> directory.

Currently, C<META.macosx> only contains the section "C<macosx binaries>" in
which a list of path/regexps for the Applications/Documents are given. An
Example:

 *** macosx binaries ***
 powerpc-apple-darwin7.4.1/Apps1.+
 powerpc-apple-darwin7.4.1/AnotherApp.app
 powerpc-apple-darwin7.4.1/README
    

=head2 Commands

=over 10

=item osx_stubber::init($I<DIR>,$I<error>,$I<warning>,$I<info>,$I<ReadMETA>,$I<ReadConf>)

Initialize the forwards. Required since SEPP warning/info facilities are not modularized
into a separate package.

=item osx_stubber::install_app_stubs($I<pack>,$I<default>,$I<forced>,$I<noaction>)

Install the stubs of I<pack> into the apropriate dir. Creates a stub (or
symlink in case of documents) for the paths indicated in C<META.macosx>. The
flags $I<default> and $I<forced> are handed down from the corresponding
commandline options, $I<noaction> can be used for debuging purposes.

The command looks documents and C<.app> stubs on all indicated paths in
C<META.macosx>, and the apropriate OSX-stub structure generated in
C</usr/sepp/macosx/Applications>:

=over 15

=item *

For every C<.app> bundle (directory) an OSX-stub is generated in the
apropriate subdirectory of the C</usr/sepp/macosx/Applications>

=item *

A symbolic link is generated for every document file found.

=item *

Every non-C<.app> directory is  treated recursively, searching and
stubbing/symlinking the directory content accordingly.

=back

=item osx_stubber::install_app_libs($I<pack>,$I<default>,$I<forced>,$I<noaction>)

Scans C<$DIR->{sepp}/var/$pack/Library> for directories/files. Directories are 
replicated using C<mkdir> in the C<$DIR->{sepp}/macosx/Library>, files are 
symlinked into the appropriate place.

Most MacOSX applications look up perference files in multiple locations in a
predefined order. The C<.../macosx/Library/Preferences> directory can be
used to contain site-wide settings for specific MacOSX applications. Thus
supplying the apropriate settings in the SEPP-pack's var directory (in
C<.../Library/Preferences>) installs such global settings.

=item osx_stubber::remove_app_stubs($I<pack>,$I<noaction>)

Identifies the directory and existing symlinks belonging to a SEPP-pack and
removes them.

=item osx_stubber::remove_app_libs($I<pack>,$I<noaction>)

Searches C<.../macosx/Library> for symlinks into the pack var directories
and removes these links.

=item osx_stubber::prefix_bundle($I<pack>,@I<bundle-paths>)

Modifies the C<Info.plist> file of an application bundle: C<prefix_bundle>
adds a prefix to C<CFBundleIdentifier>. As the Cocoa preference handling
system follows this identifier, preference files will now be read/written
with a filename containing the prefix. Since the prefix contains the pack
name (and thus the version) the application's preferences become version
dependent. This is helpful when providing site-wide settings that are only
relevant for a single version of an application.

=back

    

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut

use Mac::AppStubber;
#use Pod::Usage;

# To avoid dependencies to %main::DIR and the Warning/Error functions
# in main::, forwarding variables are introduced.
 
# our $DIR;
# our $stubdir;
# our $libdir;
# our $error;
# our $warning;
# our $info;
# our $ReadMETA;

sub init
  {
    ($DIR,$error,$warning,$info,$ReadMETA,$ReadConf)=@_;
    $stubdir="$DIR->{sepp}/macosx/Applications";
    $libdir="$DIR->{sepp}/macosx/Library";

    Mac::AppStubber::init($error,$warning,$info);
  }


sub ReadMETAmacosx
{
    my ($pack)=@_;
    my(%RULES)=
    (
     'macosx binaries' =>
     {"can't find bin directory"
      => 'm|^>?>?(.+)/[^/]+| && -d "'.$DIR->{'pack'}.'/'.$pack.'/$1"'}
    );
  return $ReadConf->("$DIR->{'pack'}/$pack/SEPP/META.macosx", \%RULES);

}

sub build_filterlist
  {
    my ($meta_macosx,$pack)=@_;
    my @chooselist;
    my @hardlist;
    my @a=(1,2,3,4);
    for my $bin (@{$meta_macosx->{'macosx binaries'}})
      {
	my $direct =0;
	$direct = 1 if $bin =~ s/^>>//;
	
	my @pelem=split "/",$bin;
	my $fileregexp = pop @pelem;
	my $pp=$DIR->{"pack"};
	my $fullpath="$pp/$pack";
	push @chooselist, "$fullpath\$";
	
	my $p=$fullpath;
	for my $d (@pelem)
	  {
	    die "ERROR: Internal empty dirname encountered" unless $d;
	    $p.="/$d";
	    push @chooselist, "$p\$"
	  }
	
	my $path = join "/", @pelem;
	$fullpath.="/$path" if $path;
	push @chooselist, "$fullpath/$fileregexp\$";
	push @chooselist,"$fullpath/$fileregexp/";
	if($direct)
	  {
	    push @hardlist, "$fullpath/$fileregexp\$";
	    push @hardlist,"$fullpath/$fileregexp/";
	  }
      }
    return (\@chooselist,\@hardlist);
  }


require Mac::AppStubber::InstallerScannerCopy;
require Mac::AppStubber::InstallerScannerFilter;
require Mac::AppStubber::InstallerScannerSymlink;
require Mac::AppStubber::InstallerScannerRecurse;
require Mac::AppStubber::InstallerScannerDefault;
require Mac::AppStubber::InstallerScannerAppBundle;

sub install_app_stubs($$$$)
  {
    my ($pack,$default,$forced,$noaction)=@_;

    my $meta=$ReadMETA->($pack);

    # No need to force the existence of META.macosx
    return unless(-f "$DIR->{'pack'}/$pack/SEPP/META.macosx");
    my $meta_macosx=ReadMETAmacosx($pack);

    # stubname will be called from the OS directly --> Link needs to go to the 
    # active sepp installation (i.e. under /usr/sepp/)
    my $stubname="/usr/sepp/stub/$pack";
    die "ERROR: stub for $pack not found. Please first install the package via seppadm."
      unless -f "$DIR->{sepp}/stub/$pack";

    my($chooselist,$hardlist)=build_filterlist($meta_macosx,$pack);

    return unless (@$chooselist) or (@$hardlist);
    my @sc=(
	    Mac::AppStubber::InstallerScannerFilter->new(1,$DIR->{"pack"} ."/$pack/SEPP"),
	    Mac::AppStubber::InstallerScannerFilter->new(0,@$chooselist),
	    Mac::AppStubber::InstallerScannerCopy->new(@$hardlist),
	    Mac::AppStubber::InstallerScannerAppBundle->new
	    (
	     exec_target=>$stubname,
	     target_prefix=>$DIR->{"pack"}."/$pack"
	    ),
	    # Mac::AppStubber::InstallerScannerSymlink->new("./inst"),
	    Mac::AppStubber::InstallerScannerRecurse->new(),
	    Mac::AppStubber::InstallerScannerDefault->new()
	   );

    my $inst=Mac::AppStubber::scan_dir($DIR->{"pack"}."/$pack",@sc);

    my $i=$inst;
    while(defined $i->count() and $i->count() == 0)
      {
	$i=$i->item(0);
      }
    
    #Make sure the installation goes straight to the directory.
    $i->name("");

    # Always overwrite the installation in "All" --> It cannot collide
    $Mac::AppStubber::forced=1;
    $Mac::AppStubber::noaction=$noaction;
    
    my $packname=$meta->{'package name'}->[0];
    
    $pack =~ m/-(\S{2,3})$/  or die "ERROR: Internal: No proper package name: $pack";
    my $author=$1;
    
    my $packname_full=join "-",
      $meta->{'package name'}->[0],
	$meta->{'package version'}->[0],
	  $author;
    
    if(UNIVERSAL::isa($i,'Mac::AppStubber::InstallerAppBundle'))
      {
	$packname.=".app";
	$packname_full.=".app";
      }
    
    $i->install("$stubdir/All/$meta->{categories}->[0]/$packname_full");
    
    if($default)
      {
	my $s="$stubdir/All/$meta->{categories}->[0]/$packname_full";
	my $t="$stubdir/Default/$meta->{categories}->[0]/$packname";
	if(-e $t)
	  {
	    if ($forced) 
	      {
		warn "WARNING: Install of $t forced. A symlink with this name does exist already";
		if($noaction)
		  {
		    warn "Would remove $t";
		    warn "Would symlink $s $t";
		  }
		else
		  {
		    unlink $t or die "ERROR: Can't unlink $t";
		    symlink $s,$t or die "ERROR: Can't symlink $s $t";
		  }
	      }
	    else
	      {
		warn "WARNING: Can't install $t. A symlink with this name does exist already";
	      }
	  }
	else
	  {
	    my $updir=$t;
	    $updir=~s|/[^/]+/?$||;
	    if(not -d $updir)
	      {
		my $cmd="/bin/mkdir -p '$updir'";
		if($noaction)
		  {
		    warn "Would do $cmd";
		  }
		else
		  {
		    system $cmd and die "ERROR: Can't exec $cmd";
		  }
	      }
	    if($noaction)
	      {
		warn "Would symlink $s $t";
	      }
	    else
	      {
		symlink $s,$t or die "ERROR: Can't symlink $s $t";
	      }
	  }
      }
  }

sub install_app_libs($$$$)
  {
    my ($pack,$default,$forced,$noaction)=@_;

    my $varname="$DIR->{sepp}/var/$pack";
    return unless -d $varname;

    my $libname="$varname/Library";
    return unless (-d $libname);

    my @sc=(
 	    Mac::AppStubber::InstallerScannerRecurse->new(hard=>1),
	    Mac::AppStubber::InstallerScannerDefault->new()
	   );

    my $inst=Mac::AppStubber::scan_dir($libname,@sc);
    $inst->name("");

    $Mac::AppStubber::forced=$forced;
    $Mac::AppStubber::noaction=$noaction;
    
    $inst->install("$libdir");
  }



# Run through a directory and collect all symlinks that are pointing
# into a specified package
use vars qw/@scan_result $scan_pkg/;

# our @scan_result;
# our $scan_pkg;
sub collect_links($$)
  {

    my @scan_result=();
    my $scan_pkg=$_[1];

    open FILES,"find '$_[0]' -type l|";
    local $_;
    while (<FILES>)
      {
        chomp;
	my $f=$_;
	my $l = readlink($f);
	die "ERROR: Could not read symlink $f" unless defined $l;
	push @scan_result,$f if $l =~ m{/\Q$scan_pkg\E(\.app)?(/|$)};
      }

    return @scan_result;
  }

# Find the paths under which an application stub has been installed for a specific
# package
sub identify_app_stubs($)
  {
    my($pack)=@_;
    my @rv;
    for my $branch (qw(Default All))
      {
	next unless -d "$stubdir/$branch";
	opendir DIR,"$stubdir/$branch" or
	  die "ERROR: Could not read directory $stubdir/$branch";
	my @cat= grep {! m/^..?$/} readdir(DIR); close (DIR);
	for my $c (@cat)
	  {
	    my $cc="$stubdir/$branch/$c";
	    opendir DIR,$cc or 
	      die "ERROR: Could not read directory $cc";
	    my @pkg= grep {! m/^..?$/} readdir(DIR); close (DIR);
	    for my $p (@pkg)
	      {
		my $pp="$cc/$p";
		my $found=collect_links($pp,$pack);
		$found and push @rv, "$branch/$c/$p";
	      }
	  }
      }
    return @rv;
  }

sub remove_app_stubs($$)
  {
    my ($pack,$noaction)=@_;
    for my $rmpack (identify_app_stubs("$pack"))
      {
	$info->("Removing $stubdir/$rmpack");
	my $cmd="/bin/rm -rf '$stubdir/$rmpack'";
	if(not $noaction)
	  {
	    system $cmd and warn "WARNING: Could not do $cmd";
	  }
      }
  }

sub remove_app_libs($$)
  {
    my ($pack,$noaction)=@_;
    for my $f (collect_links("$DIR->{sepp}/macosx/Library",$pack))
      {
	$info->("Removing $f");
	if(not $noaction)
	  {
	    unlink $f
	      or warn "WARNING: Could not unlink $f";
	  }
      }
  }

sub prefix_bundle 
  {
    my $pack=shift;
    my $noaction=0;
    for my $path (@_)
      {
	$path =~ s|/+$||;
		
	unless ($path=~/\.app$/)
	  {
	    warn "WARNING: $path is not an app-bundle. Skipping.";
	    next;
	  }
	
	my $d=$path;
	
	$d=$DIR->{"pack"}."/$pack/$path"
	  unless -d $d;
	
	my $f="$d/Contents/Info.plist";
	
	unless( -d $d )
	  {
	    warn "WARNING: $d is not a directory. Skipping";
	    next;
	  }
	
	unless( -f $f)
	  {
	    warn "WARNING: $f could not be found. Skipping.";
	    next;
	  }

	$info->("Addding prefix to bundle identifier of $f");
	$Mac::AppStubber::noaction=$noaction;
	require Mac::AppStubber::StubCreator;
	Mac::AppStubber::StubCreator::prefix_bundle
	    (
	     $f,
	     "ch.ethz.ee.isg",
	     $pack
	    );
      }
  }

1;
