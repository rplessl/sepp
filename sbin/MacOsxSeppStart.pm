=head1 NAME

MacOsxSeppStart.pm - OSX Gui handling addon to StartSepp.pl 

=head1 SYNOPSIS

B<MountImage>
B<MountImageShadowed>
B<UnmountImage>

B<AppOpen>
B<AppOpen> I<Alternate Bundle-Path>
B<AppOpen> I<Bundle-Path>,I<App-Type>,I<Binary-Name>

B<AppOpenFinder>
B<AppOpenFinder> I<Alternate Bundle-Path>

B<AppOpenProxy>
B<AppOpenProxy> I<Alternate Bundle-Path>

B<$BundlePath>

=head1 DESCRIPTION

Adds support for Mac OSX GUI Applications (App-Bundles) to the wrapper
mechanisms provided by SeppStart.pm. Currently, MacOsxSeppStart.pm
needs to be included into C<META/start.pl> manually using a C<use>
statement.

=over 10

=item B<MountImages>, B<MountImageShadowed> and B<UnmountImages>

MacOsxSeppStart supports mounting HFS Image
C</usr/pack/$Pack/SEPP/disk_image.dmg> under
C</var/sepp/mount/$Pack>. Thus, it is possible to manage Applications
that depend on HFS via NFS-mounted SEPP-Packages.

B<MountImageShadowed> emulates a writable Disk-Image using a I<Shadow
File> (see: man hdiutil)

The mount command is done in the script C<osx_image_mount_root> which
is run with B<root> rights using C<sudo> (check README.macosx for the
appropriate C<sudo> settings)

=item B<AppOpen> I<Bundle-Path>, I<App-Dir>, I<Binary-Name>, I<App-Type>

Starts an application by directly running its executable. Missing
(C<undef>) parameters are reconstructed using B<$BundlePath> and the
C<Info.plist> file residing inside the bundle. Only C<MacOS> and
C<MacOSClassic> are allowed as I<App-Dir>s, setting the default 
Architecture for the binary. For C<MacOSClassic>, PEF/CFM binaries
are assumed, while C<MacOS> assumes the binary to be Mach-O. C<App-Type> 
finally can override this setting using C<PEF> or C<MachO>

=item B<AppOpenFinder> [I<Bundle-Path>]

This second method to start applications indirectly starts an
App-Bundle using the OSX C<open> command. Note, that C<open>
immediately returns and thus renders unmounting HFS-Images difficult.
Furthermore, applications opened with B<AppOpenFinder> cannot open
documents that are double-clicked on Finder since Finder sends the
apropriate C<ODOC> (open document) AppleEvent to the stub-application
(that already has terminated).

=item B<AppOpenProxy> [I<Bundle-Path>]

Opens an applications via the C<osx_evtproxy> binary. The stub application
stays open (running C<osx_evtproxy>) and thus forwards any AppleEvent
(e.g. Finder open document events) to the real application. This ensures
that the application properly reacts to user actions in Finder. 
(check the source code C<osx_evtproxy.c> for details.

As there are now two applications (stub and real application) coexisting,
the stub has to be hidden from the user to avoid confusion. This can be
achieved by adding additional flags to the stub's C<Info.plist> file. To
avoid hiding both stub and real application, do not modify the application's
C<Info.plist>. Instead copy C<Info.plist> to C<Info-sepp.plist> in the same
directory and add the following lines to C<Info-sepp.plist>:

 <key>LSBackgroundOnly</key>
 <true/>
 <key>LSGetAppDiedEvents</key>
 <true/>

=item B<LocalStart>

Runs the file C<$pack/SEPP/local_start.pl> as user C<install>. The user
C<install> is in group C<admin> and thus can modify larger parts of the
system. Again C<sudo> is used to provide the exended rights when calling the
script C<osx_local_start_local>.

The purpose of this facility is to allow a package e.g. to install missing
fonts on the system or to provide additional files e.g. in
C</Library/Application Support>. Preferrably, symlinks should be used so 
the origin of the modifications is clear (i.e. by looking at the link
target)

=back

=head1 BUGS



=head1 AUTHOR

Anton Schultschik <aschults@ee.ethz.ch>

=cut

use Encode; # qw/encode decode/;

BEGIN{
  my @p=split "/",$0;
  $BundlePath=pop @p;

  # Restore "/" to paths
  $BundlePath=~ s|\+|/|g;
  # And also "+" signs in the original dir/file names
  $BundlePath=~ s|//|\+|g;

  # Path to the binary with which CFM/PEF apps are started
  $cfmlaunch="/System/Library/Frameworks/Carbon.framework/Versions/Current/Support/LaunchCFMApp";
}

# the sudo gateway is usually activated via TeTre2 feature. If You don't use
# TeTre2, make sure that osx_image_mount.pl can be sudo-run by everyone.
sub MountImage
  {
    system "/usr/sepp/sbin/osx_image_mount","-r",$Pack
      or return 1;
  }

sub MountImageShadowed
  {
    system "/usr/sepp/sbin/osx_image_mount","-s",$Pack
      or return 1;
  }

sub UnmountImage
  {
      system "/usr/sepp/sbin/osx_image_mount","-u",$Pack
	  or return 1;
  }

sub LocalStart
    {
	system "/usr/bin/sudo","-u","install","/usr/sepp/sbin/osx_local_start_local",$Pack,@_
	    or return 1;
    } 


# Instead of loading the Property-list module and wasting mem, just do it by hand
# (we only need a tiny, specific portion)
sub read_executable_name
  {
    my($bundle)=@_;

    my $infopath="$bundle/Contents/Info.plist";
    $infopath= "$bundle/Contents/Info-macos.plist"
        if -f "$bundle/Contents/Info-macos.plist";
    
    unless(open FH, "<$infopath")
      {
	warn "WARNING: Could not open $infopath";
	return undef;
      }
    local $/=undef;
    my $info=<FH>;
    close FH;

    $info=Encode::decode("UTF-16",$info) 
      unless $info =~ /<plist/;

    die "No proper decoding" unless $info =~ m/<plist/;
    

    # Just make sure no comments are interfering.
    $info=~s{<!--.*-->}{}msg;

    $info =~ m{<key>CFBundleExecutable</key>\s*<string>([^<>]+)</string>}xms;
    # Might be empty if not found --> (Currently) Unsupported format here
    return $1;
  }

sub AppOpen
  {
    my($bundle,$appdir,$binary,$type)=@_;
    
    # Allow relative (to $PackDir) and absolute paths.
    $bundle="$PackDir/$BundlePath"
      unless $bundle =~ m|^/|;

    $binary=$binary || read_executable_name($bundle);

    # Only set a type if it wasn't specified.
    unless($appdir)
      {
        $appdir="MacOSClassic" if -f "$bundle/Contents/MacOSClassic/$binary";

        # New Mach-O binaries are prefered.
        $appdir="MacOS" if -f "$bundle/Contents/MacOS/$binary";
      }


    # Only set a type if it wasn't specified.
    unless($type)
      {
	$type="PEF";  # if $appdir eq "MacOSClassic";

	# New Mach-O binaries are prefered.
	$type="MachO" 
            if $appdir eq "MacOS" and -x "$bundle/Contents/MacOS/$binary";
      }

    die "No valid App-Type: $type" unless 
       $type eq "PEF" or $type eq "MachO";


    my $b="$bundle/Contents/$appdir/$binary";

    if($type eq "MachO")
      {
	die "ERROR: OpenApp for $type Started with bad binary $b"
	  unless -x $b;

	my($starttime)=time;	

	# new-style (Mach-O or executable scripts) --> direct execute.
        system {$b} ($b,@ARGV);
	my $rv=$?;
	my $exitval = ($rv >> 8);

	system $logger,'-p','local4.info','-t', 
	  "$user\@$host.".$CF::seppdomain, 
	    "$pack:$BundlePath:".(time - $starttime).":".$rv;

	warn "Warning: Could exec binary (retval=$rv): $b"
	  if ($rv & 255);

	return $exitval;

      }
    elsif($type eq "PEF")
      {
	die "ERROR: OpenApp for $type Started with bad binary $b"
	  unless -f $b;

	# For classic CFM/PEF apps we need to use the apropriate tool.
	system $cfmlaunch,$b,@ARGV;
	my $rv=$?;
	my $exitval = ($rv >> 8);

	system $logger,'-p','local4.info','-t', 
	  "$user\@$host.".$CF::seppdomain, 
	    "$pack:$BundlePath:".(time - $starttime).":".$rv;

	warn "Warning: Could not start CFM for binary (retval=$rv): $b"
	  if ($rv & 255);

	return $exitval;

      }
    else
      {
	warn "WARNING: Type $type is not supported";
	return 1;
      }
  }

sub AppOpenFinder
  {
    my($bundle)=@_;

    $bundle="$PackDir/$BundlePath"
      unless $bundle;

    system $logger,,'-p','local4.info',
      '-t',"$user\@$host.$CF::seppdomain","$pack:$BundlePath:?:?";
    
    system "/usr/bin/open",$bundle,@ARGV;
    my $rv=$?;
    my $exitval = ($rv >> 8);
    
    warn "Warning: Could not open $bundle ($rv)"
      if ($rv & 255);
    
    return $exitval;
  }

sub AppOpenProxy
  {
    my($bundle)=@_;

    $bundle="$PackDir/$BundlePath"
      unless $bundle;

    my($starttime)=time;	
            chomp($uname=`/usr/bin/uname -m`);
	    if($uname eq 'i386') {
		$evproxy="/usr/sepp/sbin/osx_evtproxy.x86";
	    } else {
		$evproxy="/usr/sepp/sbin/osx_evtproxy";
	    }
    system($evproxy,$bundle);
    my $rv=$?;
    my $exitval = ($rv >> 8);

    system $logger,'-p','local4.info','-t', 
	  "$user\@$host.".$CF::seppdomain, 
	    "$pack:$BundlePath:".(time - $starttime).":".$rv;

    warn "Warning: Could exec osx_evtproxy '$bundle' (retval=$rv): $b"
      if ($rv & 255);

    return $exitval;
  }

1;

# vi: sw=4
