use strict;
package Mac::AppStubber::StubCreator;

=head1 NAME

Mac::AppStubber::StubCreator - Tools to handle (create) stubs for AppBundles.

=head1 SYNOPSIS

Mac::AppStubber::StubCreator::prefix_bundle($I<info-file>,$I<organization>,$I<pack>)
Mac::AppStubber::StubCreator::create_stub($I<orig_bundle>,$I<stub_bundle>,$I<link_target>,$I<orig_base_prefix>)
Mac::AppStubber::StubCreator::create_stub_info($I<from-info>,$I<to-info>,$<exec-name>)

=head1 DESCRIPTION

Provides simple functions to do the necessary editin of the
C<Info.plist> files and the creation of AppStubs

=over 10

=item prefix_bundle($I<info-file>,$I<organization>,$I<pack>)

Modify I<info-file> inplace, prepending
C<">I<organization>C<.>I<pack>C<"> to the bundle identifier. This
identifier defines the name of the preference file(s) of the
application.

=item create_stub($I<orig_bundle>,$I<stub_bundle>,$I<link_target>,$I<orig_base_prefix>)

Create an entire app stub under I<stub_bundle>, taking configuration
and icon files from I<orig_bundle>. The name of I<orig_bundle> is
encoded into the name of the stub's executable, which actually is a
symlink to I<link_target>. Before, the path I<orig_bundle> is checked
for a prefix I<orig_base_prefix>, and the prefix is removed.

=item create_stub_info($I<from-info>,$I<to-info>,$<exec-name>)

Distill out the configuration details from an C<Info.plist> file
(I<from-finfo>) and create a new one for the stub (I<to-info>). The
name of the executable inside the C<Info.plist> file is set to
I<exec-name>.

The function returns a list of icons that need to be copied to the stub.

=back

=head1 AUTHOR

S<Anton Schultschik <aschults@ee.ethz.ch>>

=cut


use Mac::PropertyList;
use File::Path;
#use Encode; # qw/encode decode/;

my @copy_keys=qw(CFBundleVersion CFBundleShortVersionString CFBundleLongVersionString CFBundleGetInfoString CFBundleName CFBundleSignature CFBundlePackageType CFBundleIconFile CFBundleIdentifier CFBundleInfoDictionaryVersion CFBundleDocumentTypes CFBundleURLTypes LSRequiresCarbon LSBackgroundOnly LSGetAppsDiedEvents);

sub prefix_bundle
  {
    my ($f,$org,$pack)=@_;

    open F,"<$f" or Mac::AppStubber::Error "Could not open $f";
    my $txt;
    { undef $/; $txt=<F>; }
    close F;


    my $plist=Mac::PropertyList::parse_plist($txt);
    Mac::AppStubber::Error "Could not read PropertyList File $f" unless $plist;

    my $name=$plist->value("CFBundleIdentifier")->value;
    my $oname=$name;
    $pack =~ s/\./_/g;

    # Check whether we have been at work before
    if ($name =~ m/^\Q${org}\E\.([^\.]+)\.(.*)$/)
      {
	# No need to do the work twice.
	return if $2 eq $pack;

	# Different pack-name --> Reconstruct original name.
	$name=$2;
      }
    my $k="${org}.${pack}.${name}";
    $plist->value("CFBundleIdentifier")->value($k);

    if($Mac::AppStubber::noaction)
      {
	print "## Would change CFBundleName in $f from $oname to $k\n";
      }
    else
      {
	open F,">$f" or Mac::AppStubber::Error "Cannot open $f for writing";
	print F Mac::PropertyList::plist_as_string($plist);
	close F;
      }
  }


sub create_stub
  {
    my ($orig_bundle,$stub_bundle,$link_target,$orig_base_prefix)=@_;
    
    Mac::AppStubber::Error "Incorrect .app bundle extension in $stub_bundle"
      unless $stub_bundle =~ m/\.app$/;

    Mac::AppStubber::Error "Incorrect .app bundle extension in $orig_bundle"
      unless $orig_bundle =~ m/\.app$/;

    Mac::AppStubber::Error "$orig_bundle does not exist" 
      unless -d $orig_bundle;

    Mac::AppStubber::Error "No link target indicated" unless $link_target;

    my $e=$orig_bundle;
    
    $e =~ s|^\Q$orig_base_prefix\E/*|| if defined $orig_base_prefix;
    $e =~ s|/+|/|g;    #Eliminate // in path
    $e =~ s|^\./||;    #Eliminate starting ./
    $e =~ s|\+|\+\+|g; #Keep double ++ (should work unless $e contains // )
    $e =~ s|/|\+|g;    #Replace all / with +

    if($Mac::AppStubber::noaction)
      {
	print "## mkdir -p $stub_bundle\n";
	print "## mkdir $stub_bundle/Contents\n";
	print "## mkdir $stub_bundle/Contents/MacOS\n";
	print "## mkdir $stub_bundle/Contents/Resources\n";
	print "## symlink $link_target $stub_bundle/Contents/MacOS/$e\n";
      }
    else
      {
	mkpath $stub_bundle or Mac::AppStubber::Error "Could not mkdir -p $stub_bundle";
	mkdir "$stub_bundle/Contents",0755 or
	  Mac::AppStubber::Error "Could not mkdir $stub_bundle/Contents";
	mkdir "$stub_bundle/Contents/MacOS",0755 or
	  Mac::AppStubber::Error "Could not mkdir $stub_bundle/Contents/MacOS";
	mkdir "$stub_bundle/Contents/Resources",0755 or
	  Mac::AppStubber::Error "Could not mkdir $stub_bundle/Contents/Resources";

	symlink $link_target,"$stub_bundle/Contents/MacOS/$e" or
	  Mac::AppStubber::Error "Could not create symlink $stub_bundle/Contents/MacOS/$e";

      }
    
    my $plist_name="Info.plist";
    $plist_name="Info-macos.plist" if -f "$orig_bundle/Contents/Info-macos.plist";
    $plist_name="Info-sepp.plist" if -f "$orig_bundle/Contents/Info-sepp.plist";
    my @icons=create_stub_info ("$orig_bundle/Contents/$plist_name",
				"$stub_bundle/Contents/Info.plist",
				$e);

    for my $file (@icons)
      {
	my $pth;

	opendir DIR,"$orig_bundle/Contents/Resources" or 
	  Mac::AppStubber::Error "Could not open directory $orig_bundle/Contents/Resources";
	my @dir=readdir DIR;
	close DIR;
	
	my @try=("$file.icns", "$file.tiff", $file);
	for my $i (@try)
	  {
	    $pth="$orig_bundle/Contents/Resources/$i";
	    my $found = grep {$i eq $_} @dir;
	    last if $found;
	  }


	unless(-f $pth)
	  {
	    Mac::AppStubber::Warning "Could not find icon '$pth'";
	    next;
	  }
	
	my @cmd=('/bin/cp',$pth,"$stub_bundle/Contents/Resources/");

	Mac::AppStubber::InfoLow "Run @cmd\n";
	if(not $Mac::AppStubber::noaction)
	  {
	    system @cmd and
	      Mac::AppStubber::Error "Could not do @cmd";
	  }
      }
  }

sub create_stub_info
  {
    my ($f,$n,$e)=@_;

    open F,"<$f" or Mac::AppStubber::Error "Could not open $f";
    my $txt;
    { undef $/; $txt=<F>; }
    close F;

    #$txt=Encode::decode("UTF-16",$txt) 
    #  unless $txt =~ /<plist/;
    unless( $txt =~ /<plist/ )
      {
	$txt=`/usr/sepp/bin/recode <"$f" UTF-16..UTF-8`;
      }
    die "No proper decoding" unless $txt =~ m/<plist/;

    my $plist=Mac::PropertyList::parse_plist($txt);
    Mac::AppStubber::Error "Could not read PropertyList File $f" unless $plist;

    my $version="0";
    $version=$plist->value("CFBundleVersion")->value
      if defined $plist->value("CFBundleVersion");
    
    my $stub_plist=Mac::PropertyList::dict->new();
    
    for my $k (@copy_keys)
      {
	$stub_plist->value($k,$plist->value($k));
      }
    $stub_plist->value("CFBundleVersion",
		      Mac::PropertyList::string->new("1$version"));

    # Discovered by David Gunzinger: Makes Apple-Events go to
    # real app directly, instead of going to Stub.
    if(not $plist->value("LSRequiresCarbon"))
    {
      if(not defined $plist->value("LSPrefersCarbon") or
	 $plist->value("LSPrefersCarbon")->value() != 0 or
         $plist->value("LSPrefersCarbon")->value() eq "true"
	)
	{
	  # Addition AS: RequiresCarbon needs to overrule PrefersCarbon
      	  $stub_plist->value("LSPrefersCarbon",
  	  		     Mac::PropertyList::true->new());
	}
    }

    $stub_plist->value("CFBundleExecutable",
		      Mac::PropertyList::string->new($e));

    Mac::AppStubber::InfoLow "Construct $n\n";
    if(not $Mac::AppStubber::noaction)
      {
	open F, ">$n" || Mac::AppStubber::Error "Could not open $n for writing";
	print F Mac::PropertyList::plist_as_string($stub_plist);
	close F;
      }

    my @icons;

    push @icons, $stub_plist->value("CFBundleIconFile")->value
      if defined $stub_plist->value("CFBundleIconFile");

    return @icons unless defined $stub_plist->value("CFBundleDocumentTypes");
    for my $tp ( $stub_plist->value("CFBundleDocumentTypes")->value )
      {
	next unless defined $tp->value("CFBundleTypeIconFile");
	next unless defined $tp->value("CFBundleTypeIconFile")->value;
	push @icons, $tp->value("CFBundleTypeIconFile")->value;
      }

    return @icons;
  }


1;
