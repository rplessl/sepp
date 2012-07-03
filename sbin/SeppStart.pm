=head1 NAME

SeppStart.pm - SEPP startup wrapper Module

=head1 SYNOPSIS

B<PreENV> I<EnvVar>B<,> I<Value>B<,> I<Value> ...

B<SetENV> I<EnvVar>B<,> I<Value>

B<ExistENV> I<EnvVar>

B<AppRun> I<BinaryPath>

B<AppExec> I<BinaryPath>

B<$Pack>, B<$PackDir>, B<$PackVar>


At startup:

B<--seppdebug>

B<--seppenv>

=head1 DESCRIPTION

This module provides a number of functions for creating SEPP/start.pl
wrappers. 

=over 10

=item B<PreENV> I<EnvVar>B<,> I<Value>B<,> I<Value> ...

Prepends the I<Value> to the current contents of I<EnvVar>,
using the ':' as a separator. C<PreENV "PATH", "/usr/sbin">

=item B<SetENV> I<EnvVar>B<,> I<Value>

Set I<EnvVar> to I<Value>

=item B<ExistENV> I<EnvVar>

Check the existance and the value in an environment variable I<EnvVar>.
Returns the value or undef iff not defined.
 
=item B<AppRun> I<BinaryPath>

Run the application specified through the contents of $0. The argument
must point to the directory where the application binaries are installed inside the pack. This
command should be used at the end of every start.pl script to launch
the actual application. It will also write an entry to the sepp syslog facility
local_4 when the application terminates. Giving details on runtime and exitcode
of the application.

The return value of this function is the exit value of the called binary

=item B<AppExec> I<BinaryPath>

Works like B<AppRun>, but the application is started via exec.
This takes less memory, but the log entry will neither contain the 
runtime nor the exitcode of the application.

=item B<$Pack>, B<$PackDir>, B<$PackVar>

These three variables can be used in the start.pl file to
to make the wrappers easily portable ... 

=item B<--seppdebug>

The optional parameter B<--seppdebug> shows the content of the runtime variables
B<$PackDir>, B<$Pack> and also the phyisical partition, where the SEPP package and
the call SEPP binary lives. 

After showing the runtime variables the startup process of AppRun or
AppExec will be interrupted.

=item B<--seppenv>                              

The optional parameter B<--seppenv> in combination with B<--seppdebug> shows the 
runtime environment for the binary startup. The binary which is linked per default
at /usr/sepp/bin. 

After showing the runtime and enviroment variables the startup process of AppRun 
or AppExec will be interrupted.

=back

=head1 BUGS

No Idea ... But if you tell me I'll fix 'em.

=head1 AUTHOR

Tobias Oetiker <oetiker@ee.ethz.ch>
Roman Plessl <roman.plessl@oetiker.ch>

=cut

BEGIN{
  $logger = '/usr/bin/logger' ;
  $logger = '/usr/bsd/logger' unless -x $logger ; # maybe it is here
  $uname = '/bin/uname';
  # note: getpwuid calls also getspnam, which is not cached by nscd
  # and is thus performance-critical (with LDAP for example)
  #($user,$home)=(getpwuid($<))[0,7];
  # make backticks work with setuid:
  my $oldpath=$ENV{PATH}; $ENV{PATH}='/bin:/usr/bin';
  $host = `$uname -n`; chomp $host;
  $ENV{PATH}=$oldpath;

  $PackDir="/usr/pack/$Pack";

  $PackVar="/usr/sepp/var/$Pack";

  # get system and user config ... this makes some information available
  # which is quite hard to come by otherwhise .... 
  
  # so to access configuration variables you have to
  # use $CF::maildomain  or something like this ... 

  do {
    package CF;
    my $sysconf = '/usr/sepp/conf/sepprc.system';

    # load some system config variables
    die "ERROR: Can't read $sysconf\n" unless -r $sysconf;
    do $sysconf;
  };
  #do {
  #    # you really should not do this if running setuid
  #    if($< eq $>) {
  #        package UCF;
  #        my $userconf = "$::home/.sepprc";  
  #        # let the user override these
  #        do $userconf if -r $userconf;
  #    }
  #};
}

# Example: PreENV "PATH", "/usr/myserver/home"
sub PreENV ($@) {
  my($envvar,@elements) = @_;
  if (defined $ENV{$envvar}) {
     $ENV{$envvar} = join ":", @elements, $ENV{$envvar};
  } else {
     $ENV{$envvar} = join ":", @elements;
  }
}

sub SetENV ($$) {
  $ENV{$_[0]}=$_[1];
}

sub ExistENV ($@) {
   my ( $envvar,@elements ) = @_;
   if ( defined $ENV{$envvar} ) {
      # get all the entries into a list
      my @list = split ":", $ENV{$envvar};
      # remove possible trailing / in element
      @elements = grep s/(.*?)\/?$/$1/, @elements;
      # try to find the element in the list (incl. possible trailing /)
      $exists = grep /^@elements\/?$/, @list;
      return $exists;
   }
   else {
      return undef;
   }
}
    
# get information from name of package
sub NamAlyse ($$) {
  my $pack = $_[0];
  $pack =~ s|^/usr/pack/([^/]+).*|$1|;
  my $bin = $_[1];
  $bin =~ s|^.*/||;
  $bin =~ s|-([a-z]+)$||; my $maint = $1;
  $bin =~ s|-([^-]+)$||; my $vers = $1;
  return($pack,$bin,$maint,$vers);
}



sub RemoveAlert ($){
    my $pack = shift @_;
    if (-f "/usr/pack/$pack/SEPP/REMOVABLE") {
	open (REM, "</usr/pack/$pack/SEPP/REMOVABLE");
	print "\a\n __PENDING PACKAGE REMOVAL_____________________________________________________\n|\n";
	select(undef,undef,undef,0.1);
	while (<REM>) {
	    select(undef,undef,undef,0.1);
	    print "\a| $_";
	}
	close REM;
	select(undef,undef,undef,0.1);
	print "\a ______________________________________________________________________________\a\a\a\a\a\a\a\n\n";
    }
}

sub DebugCheck ($$$) {
	my($pack,$bin,$path) = @_;
	return unless grep {$_ eq '--seppdebug'} @ARGV;

        my $df        = '/bin/df';
        my $grep      = '/bin/grep';
        my $awk       = '/usr/bin/awk';
        my $partition = `$df -P $path | $grep -v Mounted | $awk '{print \$1}'`;

	print STDERR "
SEPP Debug Report for $0

Path:       $path/$bin
Package:    $pack
Partition:  $partition

";
	exit 1 unless grep {$_ eq '--seppenv'} @ARGV;

print "Env:        
";

map {printf "            %10s = '%s'\n", $_, $ENV{$_};} keys %ENV;
	exit 1;
}

# Start the application refered in $0 with the arguments from @ARGV
# run the application with system and write a syslog entrz after the
# application terminates

sub FindBin ($$$$) {
  my($path,$bin,$maint,$vers)=@_;
  if (not -x "$path/$bin-$vers-$maint") {
    if (not -x "$path/$bin-$vers") {
      if (not -x "$path/$bin-$maint") {
	if (not -x "$path/$bin") {
	  die "$bin: Command not found (SEPP Setup Error).\n";
	} else {
	  return "$bin";
	}
      } else {
	return "$bin-$maint";
      }
    } else {
      return "$bin-$vers";
    }
  } else {
    return "$bin-$vers-$maint";
  }
}

sub AppRun ($) {
  my $path = $_[0];
  PreENV "PATH", $_[0];
  my($pack,$bin,$maint,$vers)=NamAlyse($path,$0);
  RemoveAlert($pack);
  my($starttime)=time;
  $bin = FindBin $path,$bin,$maint,$vers;
  DebugCheck $pack,$bin,$path;
  system "$bin", @ARGV;
  my $exitval = ($? >> 8);
  my $user = $ENV{LOGNAME} || $ENV{USER} || "uid:$>";
  system $logger,'-p','local3.info','-t', 
  "$user\@$host.".$CF::seppdomain, 
  "$pack:$bin:".(time - $starttime).":".$?;
  exit $exitval unless $exitval == 0;
}

# Start the application refered in $0 with the arguments from @ARGV
# run the application with exec and write a syslog entry before the
# application starts. This is for daeomons and othe rlong running
# programms

sub AppExec ($) {
  my $path = $_[0];
  PreENV "PATH", $_[0];
  my($pack,$bin,$maint,$vers)=NamAlyse($path,$0);
  RemoveAlert($pack);
  $bin = FindBin $path,$bin,$maint,$vers;
  DebugCheck $pack,$bin,$path;
  my $user = $ENV{LOGNAME} || $ENV{USER} || "uid:$>";
  system $logger,,'-p','local3.info',
  '-t',"$user\@$host.$CF::seppdomain","$pack:$bin:?:?";
  exec  "$bin", @ARGV;
}


1;

# vi: sw=4
