#!/usr/sepp/bin/perl-5.8.4 -w

package Authorize;

BEGIN {
    # these variables will be automagically set when the script
    # is installed. Remove what you don't need...
    $::ISGTC_MAGIC_LIBDIR = "/usr/isgtc/lib";
    $::ISGTC_MAGIC_SYSCONFDIR = "/usr/sepp/conf";
    unshift @INC, "$::ISGTC_MAGIC_LIBDIR/perl";
}

use lib("$::ISGTC_MAGIC_LIBDIR/perl", "perl");

use strict;
use vars qw(%opt);

use Getopt::Long 2.25 qw(:config posix_default);
use Pod::Usage 1.14;

use Sys::Hostname 1.1;
use POSIX;
use IO::Socket;
use Config::Grammar 1.0;
use NetAddr::IP 3.24;

my $RCS_VERSION = '$Id: Authorize.pm 157 2005-06-06 09:56:07Z aschults $';

$|=1;

### function prototypes ###

sub main();

sub is_authorized();
sub check();
sub notify();

sub message($);

sub mygetenv();

sub checkexpiry($);
sub checknetgroup($);
sub checkuser($);
sub checkgroup($);
sub checkwarn($);
sub checkhost($); 
sub checknetwork($);

sub readcfg($);

### global variables ###

my $hostname;
my $fqhostname;
my $ip;
my %netgroups;
my $username;
my %groups;
my $timestamp;

my $allowusage;
my $continueusage;
my $warn_before_expiry = 10;

### license files ###

my $global_cfgfile  = "$::ISGTC_MAGIC_SYSCONFDIR/authorize.conf";
my $local_cfgfile  = "./license.conf";
my $global_cfg;
my $local_cfg;

### program ###

if ($0 =~ m|Authorize.pl$|) {
    main;
}

### functions ###
sub mygetenv() {
    # find out hostname
    $hostname = hostname;

    # find out fully-qualified hostname
    $fqhostname = $hostname;
    if ($fqhostname =~ /^[^.]+$/ ) {
        $fqhostname = (gethostbyname("$fqhostname"))[0];
    }

    # find out IP
    $ip = inet_ntoa(inet_aton($hostname));

    # find out netgroups
    my $cmd = "/usr/bin/nismatch host=$fqhostname netgroup.org_dir";
    if ( -f "/var/nis/NIS_COLD_START") {
       open(NISMATCH, "$cmd |") or do {
           warn "WARNING: can't execute '$cmd': $!\n";
       };
       while(my $l = <NISMATCH>) {
           $l =~ /^(\S+)\s+$fqhostname\s*$/ or do {
                warn "WARNING: unexpected output from nismatch: $l";
                next;
           };
           $netgroups{$1}=1;
       }
       close(NISMATCH);
     }

    # find out username
    $username = getpwuid($>);

    # find out unix groups
    my @grouplist = split / /, $);
    foreach my $item (@grouplist){
         $item = getgrgid $item;
         $groups{$item}=1;
    }

    # find out unix timestamp 
    $timestamp = time;
 }

sub showmessage($){
    my $message = shift;
    my $messagefunction = "SEPP::Message::$^O";
    print $messagefunction;
    eval "require $messagefunction";
    my $msg = $messagefunction->new();
    $msg->showmessage($message);
}



# check expiry date
sub checkexpiry($){
    my $datestring = shift;
    if (not defined($datestring)){return 1; exit;}
    my ($compyear, $compmonth, $compday) = split(/-/,$datestring);

    $compmonth -= 1;
    $compyear -= 1900;

    my($comptimestamp) = mktime(0, 0, 0, $compday, $compmonth, $compyear);
    if ($comptimestamp  > $timestamp){
	return 1;
    } else {
	return 0;
    }
}

# check netgroup
sub checknetgroup($){
    my $compnetgrouplist = shift;
    if (not defined($compnetgrouplist)){return 1; exit;}
    my @compnetgroups = split(/, /,$compnetgrouplist);

    foreach (@compnetgroups) {
	if (defined($netgroups{$_})) {
	    return 1;
	} else {
	    return 0;
	}
    }
}

# check user
sub checkuser($){
    my $compuserlist = shift;
    if (not defined($compuserlist)){return 1; exit;}
    my @compusers = split(/, /,$compuserlist);

    foreach (@compusers) {
	if ($username eq $_) {
	    return 1;
	} else {
	    return 0;
	}
    }
}

# check groups
sub checkgroup($){
    my $compgrouplist = shift;
    if (not defined($compgrouplist)){return 1; exit;}
    my @compgroups = split(/, /,$compgrouplist);

    foreach (@compgroups) {
	if (defined($groups{$_})) {
	    return 1;
	} else {
	    return 0;
	}
    }
}

# check warn date
sub checkwarn($){
    my $datestring = shift;
    if (not defined($datestring)){return 1; exit;}
    my ($compyear, $compmonth, $compday) = split(/-/,$datestring);

    $compmonth -= 1;
    $compyear -= 1900;

    my($comptimestamp) = mktime(0, 0, 0, $compday, $compmonth, $compyear);
    if ($comptimestamp  > ($timestamp + $warn_before_expiry * 24 * 3600)){
        return 1;
    } else {
        return 0;
    }
}

# check host
sub checkhost($){
  my $comphostname = shift;
  if (not defined($comphostname)){return 1; exit;}
  if (($comphostname eq $hostname) || ($comphostname eq $fqhostname)) {
	return 1;
  } else {
	return 0;
  }
}

# check network
sub checknetwork($){
    my $networkstring = shift;
    if (not defined ($networkstring)){return 1;exit;}
    my ($net,$netmask) = split(/\//, $networkstring);

    my $netip = new NetAddr::IP "$ip";
    if ($netip->within(new NetAddr::IP "$net", "netmask")) {
       return 1;
   } else {
       return 0;
   }
}

# read configuaration file
sub readcfg($){
    my $RE_MODEL        = '(soft|hard|crypt)';
    my $RE_LICENSENAME  = '(\S+\s?)*';
    my $RE_USERNAME     = '\S+(,\s?\S+)*';
    my $RE_DATE         = '[0-9]{4}-[01][0-9]-[0-3][0-9]';
    my $RE_HOSTNAME     = '.*'; #'(\S+.)*\S+\s((\S+.)*\S+\s)*';
    my $RE_NET          = '\d+\.\d+\.\d+\.\d+/\d+\.\d+\.\d+\.\d+';      # 192.168.116.12/255.255.255.0
    my $RE_GROUPS       = '(\S+,\s?)*\S+';

    my $cfgfile = shift;
    my $e       = '=';
    my $parser  = Config::Grammar->new(
      {
      _sections => [ 'system', 'allow', 'continue', 'abort text', 'continue text' ],
      system => {
		 _doc => 'license model',
		 _vars => [ 'model' ],
		 model =>{
			  _doc => "definition of the licensing model",
			  _example => "soft",
			  _re => $RE_MODEL,
			  _re_error =>
			  'model must be one of soft, hard or crypt' },
		},
      allow =>{
	       _doc => 'allow starting the licenses',
	       _sections => [ "/$RE_LICENSENAME/" ],
	       "/$RE_LICENSENAME/" =>
	       {
		_doc    => "the name of the license or the license feature",
		_example => "testlicense-1.0a-rp",
		_vars   => [ 'user', 'expiry', 'host', 'net', 'group', 'netgroup','warn' ],
		user     => {
			     _doc => "an unique (unix) user name",
			     _example => "rplessl",
			     _re => $RE_USERNAME,
			     _re_error =>
			     'user must be an unix username'
			    },
		expiry => {
			   _doc => "an date yyyy-mm-dd",
			   _example => "2005-09-01",
			   _re => $RE_DATE,
			   _re_error =>
			   'expiry must be an date'
			  }, 
		warn => {
			 _doc => "an date yyyy-mm-dd",
			 _example => "2005-09-01",
			 _re => $RE_DATE,
			 _re_error =>
			 'warn must be an date'
			},
		host => {
			 _doc => "an dns hostname",
			 _example => "aeryn.ee.ethz.ch",
			 _re => $RE_HOSTNAME,
			 _re_error =>
			 'hostname must be an dns hostname with dots'
			},
		net => {
			_doc => "Default network address in IP notation added with netmask",
			_example => "10.12.33.1/255.255.255.0",
			_re => $RE_NET,
			_re_error =>
			'hosts must be given by network address and network mask'
			},
		group => {
			  _doc => "Unix groups separated with commas",
			  _example => "ifa, biwi",
			  _re => $RE_GROUPS,
			  _re_error =>
			  'groups must be a comma sparated list'
			 },
		netgroup => {
			     _doc => "nis netgroups separated with commas",
			     _example => "ifa_t, biwi_t",
			     _re => $RE_GROUPS,
			     _re_error =>
			     'groups must be a comma sparated list'
			    },
	       },
	      },
      continue =>{
		  _doc => 'allow continuing the licenses',
		  _sections => [ "/$RE_LICENSENAME/" ],
		  "/$RE_LICENSENAME/" =>
		  {
		   _doc    => "the name of the license or the license feature",
		   _example => "testlicense-1.0a-rp",
		   _vars   => [ 'user', 'expiry', 'host', 'net', 'group', 'netgroup', 'warn'],
		   user     => {
				_doc => "an unique (unix) user name",
				_example => "rplessl",
				_re => $RE_USERNAME,
				_re_error =>
				'user must be an unix username'
			       },
		   expiry => {
			      _doc => "an date yyyy-mm-dd",
			      _example => "2005-09-01",
			      _re => $RE_DATE,
			      _re_error =>
			      'expiry must be an date'
			     },
		   warn => {
			    _doc => "an date yyyy-mm-dd",
			    _example => "2005-09-01",
			    _re => $RE_DATE,
			    _re_error =>
			    'warn must be an date'
			   },
		   host     => {
			     _doc => "an dns hostname",
			     _example => "aeryn.ee.ethz.ch",
			     _re => $RE_HOSTNAME,
			     _re_error =>
			     'hostname must be an dns hostname with dots'
			    },
		   net => {
			    _doc => "Default network address in IP notation added with netmask",
			    _example => "10.12.33.1/255.255.255.0",
			    _re => $RE_NET,
			    _re_error =>
			    'hosts must be given by network address and network mask'
			   },
		   group => {
			     _doc => "Unix groups separated with commas",
			     _example => "ifa, biwi",
			     _re => $RE_GROUPS,
			     _re_error =>
			     'groups must be a comma sparated list'
			    },
		   netgroup => {
				_doc => "nis netgroups separated with commas",
				_example => "ifa_t, biwi_t",
				_re => $RE_GROUPS,
				_re_error =>
				'groups must be a comma sparated list'
			       },
		  },
		 },
      'abort text' => {
		       _doc => 'Abort Text',
		       _text => {},
		      },
      'continue text' => {
			  _doc => 'Abort Text',
			  _text => {},
			 }
     });

    if ($opt{poddoc}) {
        print $parser->makepod if $opt{poddoc};
        exit 0;
    }

    my $cfg = $parser->parse($cfgfile) or die "ERROR: $parser->{err}\n";
    return $cfg;
}


sub main(){
    # parse options
    %opt = ();
    GetOptions(
        \%opt,       'help|h',
        'man',       'version',
        'verbose|v', 'poddoc'
      )
      or pod2usage(2);
    if ($opt{help}) { pod2usage(1) }
    if ($opt{man}) { pod2usage(-exitstatus => 0, -verbose => 2) }
    if ($opt{version}) { print "$RCS_VERSION\n"; exit(0) }

    my $allow;
    $allow = is_authorized();
    notify();
    if ($allow) { return 1; } else {return 0;}
}

sub check(){
    my $allow;
    $allow = is_authorized();
    notify();
    if ($allow) { return 1; } else {return 0;}
}


sub is_authorized(){
    # get environment
    mygetenv();

    $local_cfgfile="$main::PackVar/licence.conf" if defined $main::PackVar;

    $local_cfg=undef;
    if( -e $local_cfgfile)
    {
      die "ERROR: local config file $local_cfgfile is not readable\n" unless -r $local_cfgfile;
      $local_cfg = readcfg($local_cfgfile);
    }
    
    $global_cfg=undef;
    if( -e $global_cfgfile)
    {
      # read configfile
      die "ERROR: global config file $global_cfgfile is not readable\n" unless -r $global_cfgfile;
      $global_cfg = readcfg($global_cfgfile);
    }

    # Use defaults if no local config available.
    $local_cfg=$global_cfg unless $local_cfg;

    # If no config file exists at all, don't do authorization.
    return 1 unless $local_cfg;
    
    ### Check each Rule
    foreach (keys %{$local_cfg->{'allow'}}) {
        my $expiry    = $local_cfg->{'allow'}->{$_}->{'expiry'}   ;
        my $netgroup  = $local_cfg->{'allow'}->{$_}->{'netgroup'} ;
        my $user      = $local_cfg->{'allow'}->{$_}->{'user'}     ;
        my $group     = $local_cfg->{'allow'}->{$_}->{'group'}    ;
        my $warn      = $local_cfg->{'allow'}->{$_}->{'warn'}     ;
        my $host      = $local_cfg->{'allow'}->{$_}->{'host'}     ;
        my $net       = $local_cfg->{'allow'}->{$_}->{'net'}      ;

        if ( checkexpiry($expiry) &&
             checknetgroup($netgroup) &&
             checkuser($user) &&
             checkgroup($group) &&
             checkwarn($warn) &&
             checkhost($host) &&
             checknetwork($net)){
	    $allowusage += 1;
	}
    }

    ### Check each Rule
    foreach (keys %{$local_cfg->{'continue'}}) {
        my $expiry    = $local_cfg->{'continue'}->{$_}->{'expiry'}   ;
        my $netgroup  = $local_cfg->{'continue'}->{$_}->{'netgroup'} ;
        my $user      = $local_cfg->{'continue'}->{$_}->{'user'}     ;
        my $group     = $local_cfg->{'continue'}->{$_}->{'group'}    ;
        my $warn      = $local_cfg->{'continue'}->{$_}->{'warn'}     ;
        my $host      = $local_cfg->{'continue'}->{$_}->{'host'}     ;
        my $net       = $local_cfg->{'continue'}->{$_}->{'net'}      ;

        if ( checkexpiry($expiry) && 
             checknetgroup($netgroup) &&
             checkuser($user) &&
             checkgroup($group) &&
             checkwarn($warn) &&
             checkhost($host) &&
             checknetwork($net)){
	    $continueusage += 1;
        }
    }
    if ( defined($allowusage) || defined($continueusage) ) { return 1; } else { return 0; }
}


sub notify(){
    if (not defined($allowusage)) {
	if (defined($continueusage) && $local_cfg->{'system'}->{'model'} eq 'soft'){
	    ($_ = $local_cfg->{'continue text'}->{'_text'}) =~ s/\n/ /;
	    if (not defined($_)){ ($_ = $global_cfg->{'continue text'}->{'_text'}) =~ s/\n/ /;	}
	    showmessage($_);
	} else {
	    ($_ = $local_cfg->{'abort text'}->{'_text'}) =~ s/\n/ /;
	    if (not defined($_)){ ($_ = $global_cfg->{'abort text'}->{'_text'}) =~ s/\n/ /; }
	    showmessage($_);
	}
    }
}

1

__END__

=pod

=head1 NAME

  SEPP::Authorize - An SEPP authorization extension.

=head1 SYNOPSIS

B<is_authorized()>

B<notify()>

B<check()>

=head1 DESCRIPTION

SEPP::Authorize is an SEPP extension which checks the
autorization and permissions before starting a
commercial software product.

B<is_authorized()> checks if a user/computer is authorized to
run an application in SEPP. A FALSE answer means that
the application start should not be granted.

B<notify()> informs a user about the rules by signalizing a
messagebox with the rules (sometimes a hint that this program
is allowed to evaluate).

B<check()> includes both functions is_autorized() and notify().

=head1 CONFIGFILE

=head2 Sections

There will be three sections in the config file:

=over

=item o system

select licensing model soft (only produces a warning, can continue 
to evaluate), hard (can't start if not licensed) or crypt (like hard, 
but the software is encrypted -- crypt is for future extensions).

=item o allow

cases which allows an usage of this license: the lines for each case 
are evaluated as an "AND" and each case as an "OR" for the section
allow.

=item o continue

cases which allows an continued usage of this license, an messagebox
will be displayed: the lines for each case are evaluated as an "AND" 
and each case as an "OR" for the section continue.

=back

=head2 Example Configfile

  *** system ***
  model = soft   # soft:  only produces a warning, can continue to evaluate
                 # hard:  can't start if not licensed
                 # crypt: like hard, but the software is encrypted

  *** allow ***
  + first case (e.g. some members of a group)
    user      = aschults, dws, luki
    netgroup  = biwi_t
    expiry    = 2006-12-31

  + second case (e.g. the owner of the license)
    user      = aschults
    expiry    = 2005-12-31

  + third case (e.g. default host for this license)
    host      = aeryn.ee.ethz.ch
    net       = 129.132.67.0/255.255.255.0
    expiry    = 2005-12-31
    user      = rplessl

  + forth case (e.g. a unix group)
    group     = biwi
    expiry    = 2005-12-31

  + fifth case (e.g. allow whole nis+ groups)
    netgroup  = biwi_t
    expiry    = 2006-12-31 
    warn      = 2006-10-01

  *** continue ***
  + first case (e.g. some persons of a group)
    user      = aschults, dws, luki
    netgroup  = biwi_t
    expiry    = 2006-12-31


  *** abort text ***
  The application you have started is not allowed to run on your machine.

  *** continue text ***
  The application You started is not allowed to run on your machine.
  You can continue and evaluate the application by pressing Continue.

=head2 Available Checks for the Configuration File

The available check routines for the configfile or listed below
or can be extracted by starting the I</usr/sepp/bin/perl
Authorize.pm --poddoc>.

=over

=item B<user>

an unique (unix) user name

Example: user = rplessl

=item B<expiry>

an date yyyy-mm-dd

Example: expiry = 2005-09-01

=item B<host>

an dns hostname

Example: host = aeryn.ee.ethz.ch

=item B<net>

Default network address in IP notation added with netmask

Example: net = 10.12.33.1/255.255.255.0

=item B<group>

Unix groups separated with commas

Example: group = ifa, biwi

=item B<netgroup>

nis netgroups separated with commas

Example: netgroup = ifa_t, biwi_t

=item B<warn>

an date yyyy-mm-dd

Example: warn = 2005-09-01

=back

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2005 by ETH Zurich. All rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=head1 AUTHOR

S<Roman Plessl E<lt>rplessl@ee.ethz.chE<gt>>

=head1 HISTORY

 2004-04-29 rp Initial Version

=cut

#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et
