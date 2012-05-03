BEGIN {
    require Config::Grammar;
    if($Config::Grammar::VERSION ge '1.10') {
        require Config::Grammar::Dynamic;
        @ISA = qw(Config::Grammar::Dynamic);
    }
    else {
        @ISA = qw(Config::Grammar);
    }
}

package SEPP::OSDetector;

use strict;
use vars qw($CONF $VERSION);

$VERSION = '0.12';

# this is used to push the config from seppadm to this module
sub get_conf {
   $CONF = shift;
}

# The RE contains the regexp for all posible OS descriptions
# like amd64-linux-ubuntu6.10. The rule of thumb for this is
#       CPUTYPE - OS - DISTRIBUTION(VERSION)
# 
# To save the OS evaluation result, a simple datastructure will
# be saved in the file SEPP_OS_DETECTOR. This data is stored in
# /tmp and usable till the next reboot of the computer 
# (normally, distribution updates are causing reboots)

my $RE_MATCH          = qr{[0-9a-zA-Z_.-]+};
my $SEPP_OS_DETECTOR  = '/tmp/SEPP.OS.DETECTOR';
my $CFGFILE;          ### default at = '/usr/sepp/conf/OSDetector.conf';
my $OS                = $^O;
my %DEFAULTDIR        = ( 'sepp' => '/usr/sepp', 
                          'pack' => '/usr/pack' );
my $DEFAULT_SEPP_NAME = 'sepp';
my $DEFAULT_SEPP_UID  = '65409';

sub push_conf {
    $CONF = shift;
    if ($CONF->{'sepp user'}[0]){
       $DEFAULT_SEPP_NAME = $CONF->{'sepp user'}[0];
    }
}
# the temporary file $SEPP_OS_DETECTOR should be a file created by sepp 
# or root (security reasons) ... so this this DEFAULT_SEPP information
# is necessary here

### BEGIN Tetre2 Integration ###
### if you don't manage your system with Tetre2 skip to END TETRE2 Integration

# check if the SEPP system is configured and managed by the Template Tree 2 
# (Tetre2) system, otherwise set variables to default values

# this variables are automatically replaces by Tetre2
my $_sepp_name_tetre2    = undef;
my $_sepp_uid_gid_tetre2 = undef;
my $_sepp_uid_tetre2     = undef;

if( '>#>user_name<#<' !~ m/>#>/ ) {   
   $_sepp_name_tetre2    = '>#>user_name<#<';
}
if( '>#>user_id<#<' !~ m/>#>/ ) {    
   $_sepp_uid_gid_tetre2 = '>#>user_id<#<';
}
if ($_sepp_uid_gid_tetre2 ) {
   $_sepp_uid_tetre2  = $_sepp_uid_gid_tetre2  =~ s/:[\d]*$//;
}

$DEFAULT_SEPP_NAME       = $_sepp_name_tetre2    ? $_sepp_name_tetre2 : $DEFAULT_SEPP_NAME;
$DEFAULT_SEPP_UID        = $_sepp_uid_gid_tetre2 ? $_sepp_uid_tetre2  : $DEFAULT_SEPP_UID;

# END TeTre2 Integration

sub parse_config ($)
{
    my $cfgfile = shift;
    my $parser  = Config::Grammar->new(
        {
            _sections  => [qw(General Solaris Linux Compatibility ImplEnvSettings ExplEnvSettings)],
            _mandatory => [qw(General Compatibility)],
            General => {
               _doc => 'Global configuration settings for OSDetector'
               _vars => [ qw(compat_libs_store) ],
               compat_libs_store => {
                  _doc => 'path to general compatibilty libraries',
                  _re  => ['/\S+/'],
               },
            }
            Solaris    => {
                _doc => 'All settings for SUN Solaris OS',
                _sections  => [qw(CPU Distribution)],
                _mandatory => [qw(CPU Distribution)],
                CPU        => {
                    _doc => 'CPU type as given by uname -p'
                    _sections     => ["/$RE_MATCH/"],
                    _recursive    => ["/$RE_MATCH/"],
                    "/$RE_MATCH/" => {
                        _text => {},
                        _doc  => 'sub CPU type as given by uname -i',
                    },
                },
                Distribution => {
                    _doc => 'Distribution as given by uname -r',
                    _sections     => ["/$RE_MATCH/"],
                    _recursive    => ["/$RE_MATCH/"],
                    "/$RE_MATCH/" => {
                        _text => {},
                        _doc  => ''
                    },
                },
            },
            Linux => {
                _doc => 'All settings for Linux OSes',
                _sections  => [qw(CPU Distribution)],
                _mandatory => [qw(CPU Distribution)],
                CPU        => {
                    _doc => 'CPU type as given by uname -m'
                    _sections     => ["/$RE_MATCH/"],
                    _recursive    => ["/$RE_MATCH/"],
                    "/$RE_MATCH/" => {
                        _text => {},
                        _doc  => 'sub CPU type as given by uname -m',
                    },
                },
                Distribution => {
                    _doc => 'Linux distribution based on evaled code (like lsb_release)'
                    _sections     => ["/$RE_MATCH/"],
                    _recursive    => ["/$RE_MATCH/"],
                    "/$RE_MATCH/" => {
                        _text => {},
                        _doc  => 'Linux distribution based on evaled code (like lsb_release)'
                    },
                },
            },
            Compatibility => {
                _doc => 'Compatibilty list for the running OS (e.g. running RHEL4 applications on Ubuntu 8.04). The key element is the OS identifier (CPU-OS-DISTRO)',
                _sections     => ["/$RE_MATCH/"],
                "/$RE_MATCH/" => {
                    _text => {},
                    _doc  => '',
                },
            },
            ImplEnvSettings => {
                _doc => 'Implicit environment settings with two subcases: implicit settings for the running OS and settings which are applied if a compination of running OS and origin OS matches. The conditions are evaled and can be rather complex.',
                _sections     => ["/$RE_MATCH/"],
                _recursive    => ["/$RE_MATCH/"],
                "/$RE_MATCH/" => {
                    _sections  => [qw(condition code)],
                    _mandatory => [qw(condition code)],
                    condition => {
                       _text => {},
                       _doc  => '',
                    },
                    code => {
                       _text => {},
                       _doc  => '',
                    },
                },
            },
            ExplEnvSettings => {
                _doc => 'Explicit environment settings with two subcases: explicit settings for the running OS and settings which are applied if a compination of running OS and origin OS matches. The conditions are evaled and can be rather complex.',
                _sections     => ["/$RE_MATCH/"],
                _recursive    => ["/$RE_MATCH/"],
                "/$RE_MATCH/" => {
                    _sections  => [qw(condition code)],
                    _mandatory => [qw(condition code)],
                    condition => {
                       _text => {},
                       _doc  => '',
                    },
                    code => {
                       _text => {},
                       _doc  => '',
                    },
                },
            },
    );

    my $cfg = $parser->parse($cfgfile)
      or die "ERROR: $parser->{err}\n";

    return $cfg;
}

sub evaluate_cpu ($)
{
    my $cfg = shift;

    my @valid_cpu;
    my @cpufamilies = keys %{$cfg->{$OS}->{'CPU'}};

    foreach my $cpufamily (@cpufamilies){
        if (grep { $_ =~ /_text/ } keys %{$cfg->{$OS}->{'CPU'}->{$cpufamily}}) {
            if ((eval ($cfg->{$OS}->{'CPU'}->{$cpufamily}{_text})) eq 'true') {
                unshift @valid_cpu, $cpufamily;
            }
        }
        my @cpusubfamilies = grep { $_ !~ /_text/ } keys %{$cfg->{$OS}->{'CPU'}->{$cpufamily}};
        foreach my $cpusubfamily (@cpusubfamilies){
            if (grep { $_ =~ /_text/ } keys %{$cfg->{$OS}->{'CPU'}->{$cpufamily}->{$cpusubfamily}}) {
                if ((eval ($cfg->{$OS}->{'CPU'}->{$cpufamily}->{$cpusubfamily}{_text})) eq 'true') {
                    unshift @valid_cpu, $cpusubfamily;
                }
            }
        }
    }
    return @valid_cpu;
}

sub evaluate_distro ($)
{
    my $cfg = shift;

    my @valid_distro;
    my @distros = keys %{$cfg->{$OS}->{'Distribution'}};

    foreach my $distrofamily (@distros){
        if (grep { $_ =~ /_text/ } keys %{$cfg->{$OS}->{'Distribution'}->{$distrofamily}}) {
            if ((eval ($cfg->{$OS}->{'Distribution'}->{$distrofamily}{_text})) eq 'true') {
                unshift @valid_distro, $distrofamily;
            }
        }
        my @distrosubfamilies = grep { $_ !~ /_text/ } keys %{$cfg->{$OS}->{'Distribution'}->{$distrofamily}};
        foreach my $distrosubfamily (@distrosubfamilies){
            if (grep { $_ =~ /_text/ } keys %{$cfg->{$OS}->{'Distribution'}->{$distrofamily}->{$distrosubfamily}}) {
                if ((eval ($cfg->{$OS}->{'Distribution'}->{$distrofamily}->{$distrosubfamily}{_text})) eq 'true') {
                    unshift @valid_distro, $distrosubfamily;
                }
            }
        }
    }
    return @valid_distro;
}

sub evaluate_compat ($$)
{
    my $cfg = shift;
    my $detect_distro = shift;

    my $compat_string = $cfg->{'Compatibility'}->{$detect_distro}{_text};
    my @compats = split /\s+/, $compat_string;
    unshift @compats, $detect_distro;

    return @compats;
}

sub evaluate_dirs ($;@)
{
    my $PackDir = shift;
    my @compats = @_;

    my $valid_directory;

    foreach (@compats) {
        if ( -d "$PackDir/$_") {   # also okay for symlinks on linux
            $valid_directory = $_;
            last;
        }
    }

    return $valid_directory;
}

sub exists_stored_evaluation ()
{
    if (-f "$SEPP_OS_DETECTOR") {
        my $_sepp_os_detector_uid = (stat $SEPP_OS_DETECTOR)[4];
        my @_sepp_user = getpwnam($DEFAULT_SEPP_NAME);
        my $_sepp_user_uid = $_sepp_user[2];
        if (not ($_sepp_os_detector_uid == 0 || 
                 $_sepp_os_detector_uid == $DEFAULT_SEPP_UID ||
                 $_sepp_os_detector_uid == $_sepp_user_uid)) {
           my @file_owner = getpwuid($_sepp_os_detector_uid);
           my $name = $file_owner[0];
           print STDERR "WARNING: $SEPP_OS_DETECTOR has owner $_sepp_os_detector_uid ($name)!!! \n";
           return undef;
        }
        return 'true';
    }
    else {
        return undef;
    }
}

sub get_stored_evaluation ()
{
    if (exists_stored_evaluation()) {
        open(SEPP_OS_DETECTOR, $SEPP_OS_DETECTOR);
        my @COMPATS;
        while (<SEPP_OS_DETECTOR>) {
            chomp;
            push @COMPATS, $_;
        }
        close SEPP_OS_DETECTOR;
        return @COMPATS;
    }
}

sub write_evaluation (@)
{
    my @COMPATS = @_;

    if (not defined(exists_stored_evaluation())) {
        open(SEPP_OS_DETECTOR, ">$SEPP_OS_DETECTOR");
        foreach (@COMPATS) {
            print SEPP_OS_DETECTOR "$_\n";
        }
        close SEPP_OS_DETECTOR;
        return 'true';
    }
    else {
        return undef;
    }
}

sub get_compatible_os(%) 
{
    my %DIR = @_;
    if (not exists $DIR{'sepp'}) { %DIR = %DEFAULTDIR; };
    $CFGFILE = "$DIR{'sepp'}/conf/OSDetector.conf";
    my @COMPATS;
    if (exists_stored_evaluation()){
      @COMPATS = get_stored_evaluation();
    } else {
      my $cfg     = parse_config($CFGFILE);
      my @CPU     = evaluate_cpu($cfg);   
      my @DISTRO  = evaluate_distro($cfg);
      @COMPATS = evaluate_compat($cfg, "$CPU[0]-$OS-$DISTRO[0]");
      write_evaluation(@COMPATS);
    }
    return @COMPATS;
}

sub get_existing_execdir($;%)
{
    my $PackDir = shift;
    if ($PackDir eq 'SEPP::OSDetector') {
       $PackDir = shift;
    }
    my %DIR = @_ || %DEFAULTDIR;
    my @COMPATS = get_compatible_os( %DIR );
    my $RunningOS = $COMPATS[0];
    my $OriginOS  = evaluate_dirs($PackDir, @COMPATS);
    return [$OriginOS, $RunningOS];
}

sub get_all_platform_triplets(%)
{
    my %DIR = @_;
    if (not exists $DIR{'sepp'}) { %DIR = %DEFAULTDIR; };
    $CFGFILE = "$DIR{'sepp'}/conf/OSDetector.conf";
    my $cfg      = parse_config($CFGFILE);
    my %triplets;
    for my $os (keys %{$cfg}) {
        next if $os eq 'Compatibility';

        my @valid_distro;
        my @distros = keys %{$cfg->{$os}->{'Distribution'}};
        for my $distrofamily (@distros){
           if (grep { $_ =~ /_text/ } keys %{$cfg->{$os}->{'Distribution'}->{$distrofamily}}) {
               unshift @valid_distro, $distrofamily;
           }
           my @distrosubfamilies = grep { $_ !~ /_text/ } keys %{$cfg->{$os}->{'Distribution'}->{$distrofamily}};
           for my $distrosubfamily (@distrosubfamilies){
                if (grep { $_ =~ /_text/ } keys %{$cfg->{$os}->{'Distribution'}->{$distrofamily}->{$distrosubfamily}}) {
                    unshift @valid_distro, $distrosubfamily;
                }
           }
        }

        my @valid_cpus   = evaluate_cpu($cfg);

        for my $distribution (@valid_distro) {
           for my $cpu (@valid_cpus) {
               $triplets{"$cpu-$os-$distribution"} = 1;
           }
        }
    }
    return (%triplets);
}

sub evaluate_ImplEnvSettings ($)
{
    my $cfg = shift;

    my @valid_distro;
    my @distros = keys %{$cfg->{$OS}->{'Distribution'}};

    foreach my $distrofamily (@distros){
        if (grep { $_ =~ /_text/ } keys %{$cfg->{$OS}->{'Distribution'}->{$distrofamily}}) {
            if ((eval ($cfg->{$OS}->{'Distribution'}->{$distrofamily}{_text})) eq 'true') {
                unshift @valid_distro, $distrofamily;
            }
        }
        my @distrosubfamilies = grep { $_ !~ /_text/ } keys %{$cfg->{$OS}->{'Distribution'}->{$distrofamily}};
        foreach my $distrosubfamily (@distrosubfamilies){
            if (grep { $_ =~ /_text/ } keys %{$cfg->{$OS}->{'Distribution'}->{$distrofamily}->{$distrosubfamily}}) {
                if ((eval ($cfg->{$OS}->{'Distribution'}->{$distrofamily}->{$distrosubfamily}{_text})) eq 'true') {
                    unshift @valid_distro, $distrosubfamily;
                }
            }
        }
    }
    return @valid_distro;
}

__END__

=head1 NAME

OSDetector.pm - SEPP startup module for detecting the OS or the valid EPREFIX directory

=head1 SYNOPSIS

   my $os = SEPP::OSDetector::get_existing_execdir( $PackDir [, %DIR ] ));

or

   my @compatibles = SEPP::OSDetector::get_compatible_os( [ %DIR ] );

or

   my %os_triplets = SEPP::OSDetector::get_all_platform_triplets( [ %DIR ] );

=head1 DESCRIPTION

This module provides two functions for compiling new SEPP packages 
and creating smart OS detection SEPP/start.pl wrappers. 

=over 10


=item B<SEPP::OSDetector::get_existing_execdir( $PackDir [ , %DIR ])>

[ The paramter %DIR is optional and contains the path information

  %DIR = ( 'sepp' => '/usr/sepp', 
           'pack' => '/usr/pack' ); 
]

Returns the best match for I<$EPREFIX> for the running OS. That
means if there is a SEPP Package with the following directory
structure (e.g. subversion-1.6.4-rp):

.
|-- SEPP
|-- amd64-linux-debian3.1
|-- amd64-linux-redhat4
|-- amd64-linux-ubuntu8.04
|-- build-1
|-- docs
|-- ia32-linux-debian3.1
|-- include
|-- lib
|-- man
`-- share

the result of this function will be

 amd64-linux-debian3.1   on a amd64 debian sarge system (64bit)
 amd64-linux-redhat4     on a amd64 RHEL 4 system       (64bit)
 amd64-linux-ubuntu8.04  on a amd64 ubuntu hardy system (64bit)
 ia32-linux-debian3.1    on a ia32 debian sarge system  (32bit)

=item B<SEPP::OSDetector::get_compatible_os( [ %DIR ] )>

[ The paramter %DIR is optional and contains the path information

  %DIR = ( 'sepp' => '/usr/sepp', 
           'pack' => '/usr/pack' );  
]

Returns a perl array with OS compatible I<$EPREFIX>. 
E.g. on a amd64 system running Ubuntu 8.04 the result will be

   amd64-linux-ubuntu8.04 
   ia32-linux-ubuntu8.04
   amd64-linux-ubuntu7.04
   ia32-linux-ubuntu7.04 
   amd64-linux-ubuntu6.10
   ia32-linux-ubuntu6.10 
   amd64-linux-ubuntu6.06
   ia32-linux-ubuntu6.06
   amd64-linux-debian3.1
   ia32-linux-debian3.1
   amd64-debian-linux3.1
   i686-debian-linux3.1

that means, all this compiled versions are runnable on the
Ubuntu 8.04 system (i.e. GLIBC version is not newer). The 
first entry in the array is the best match, the last the
worst.

=item B<SEPP::OSDetector::get_all_platform_triplets( [ %DIR ] )>

[ The paramter %DIR is optional and contains the path information

  %DIR = ( 'sepp' => '/usr/sepp', 
           'pack' => '/usr/pack' );  
]

Returns a perl hash with all valid cpu - os - distribution triplets
which is needed e.g. by seppadm expose.

=back

=head2 configuration file

SEPP::OSDetector.pm is using the configuration file I<OSDetector.conf>
which contains all valid CPUs, OSes and distribution. The configuration
file format is Config::Grammar. 

The "inter OS" compatibility is also kept in this file.

Structure of configuration file:

   *** MY-OS ***
   + CPU
   ++ cpu-type
   +++ cpu-sub-type

   + Distribution
   ++ distribution-type
   +++ distribution-sub-type

   *** MY-OTHER-OS ***
   ...
   
   *** Compatibility ***
   + CPU-OS-DISTRIBUTION_1
   + CPU-OS-DISTRIBUTION_2   

The name of the head sections (*** MY-OS ***) has to match with 
the result of $^O.

Each head section has two subsections: CPU and Distributions with 
their subsub- and subsubsubsections discribing the exact CPUTYPE 
or OS (relation).

For each cpu(-sub)-type and distribution(-sub)-type a blob of
executable code should be inserted which returns 'true' if the
query matches otherwise 'false'.

The Compatibility list is an sorted list of compatible 
CPU-OS-Distributions triplets to the heading triplet. 
   
Example of OSDetector.conf

   *** solaris ***
   + CPU
   ++ sparc
   {
      my $cpu = `uname -p`;
      if ($cpu =~ /sparc/) { return 'true'; } else { return 'false'; }
   }
   ...

   *** linux ***
   + CPU
   ++ ia32
   {
       my $cpu = `/bin/uname -m`;
       if ($cpu =~ /(i686|x86_64)/) { return 'true'; } else { return 'false'; }
   }
   +++ amd64
   {
       my $processor_type = `/bin/uname -m`;
       if ($processor_type =~ /x86_64/) { return 'true'; } else { return 'false'; } 
   }
   + Distribution
   ++ debian
   {
       if ( -e '/etc/debian_version' && ! -e '/etc/lsb-release' ) {
           return 'true';  } else { return 'false'; }
   }
   +++ debian4.0
   {
      if ( -e '/etc/debian_version'&& ! -e '/etc/lsb-release' ) {
         my $debian_version = `cat /etc/debian_version`;
         if ($debian_version =~ /4\.0/) { return 'true'; } else { return 'false'; }
      } else { return 'false'; }
   }
   ++ ubuntu
   {
      if ( -e '/etc/lsb-release' ) {
         my $lsbrelease =  `/bin/cat /etc/lsb-release`;
         if ($lsbrelease =~ /Ubuntu/) { return 'true'; } else { return 'false'; }
      } else { return 'false'; }
   }
   +++ ubuntu6.06
   {
      if ( -e '/etc/lsb-release' ) {
         my $lsbrelease = `/bin/cat /etc/lsb-release`;
         if ($lsbrelease =~ /Ubuntu/) {
            if ($lsbrelease =~ /6\.06/) {
              return 'true';
            } else { return 'false'; }
         } else { return 'false'; }
      } else { return 'false'; }
   }
   ...

   *** Compatibility ***
   + amd64-linux-ubuntu8.04
   ia32-linux-ubuntu8.04
   amd64-linux-ubuntu7.04
   ia32-linux-ubuntu7.04 
   amd64-linux-ubuntu6.10
   ia32-linux-ubuntu6.10 
   amd64-linux-ubuntu6.06
   ia32-linux-ubuntu6.06
   amd64-linux-debian3.1
   ia32-linux-debian3.1
   amd64-debian-linux3.1
   i686-debian-linux3.1

   + ia32-linux-ubuntu8.04
   ia32-linux-ubuntu7.04
   ia32-linux-ubuntu6.10
   ia32-linux-ubuntu6.06
   ia32-linux-debian3.1
   i686-debian-linux3.1
   ...


=over 10

=item 

=head1 BUGS

No knowns are listed in the op-sepp trac:

  http://oss.oetiker.ch/op-sepp/report/1

=head1 AUTHOR

Roman Plessl <roman.plessl@oetiker.ch>

=cut


# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle)
# indent-tabs-mode: nil
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et

