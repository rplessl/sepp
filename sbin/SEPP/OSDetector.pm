package SEPP::OSDetector;

use strict;
use Config::Grammar;
use Data::Dumper;

use vars qw($VERSION);

$VERSION = 0.10;

# The RE contains the regexp for all posible OS descriptions
# like amd64-linux-ubuntu6.10. The rule of thumb for this is
#       CPUTYPE - OS - DISTRIBUTION(VERSION)
# 
# To save the OS evaluation result, a simple datastructure will
# be saved in the file SEPP_OS_DETECTOR. This data is stored in
# /tmp and usable till the next reboot of the computer 
# (normally Distribution updates are causing reboots)

my $RE_MATCH         = qr{[0-9a-zA-Z_.-]+};
my $SEPP_OS_DETECTOR = '/tmp/SEPP.OS.DETECTOR';
my $CFGFILE          ;# = '/usr/sepp/conf/OSDetector.conf';
my $OS               = $^O;

sub parse_config ($)
{
    my $cfgfile = shift;
    my $parser  = Config::Grammar->new(
        {
            _sections  => [qw(solaris linux Compatibility)],
            _mandatory => [qw(Compatibility)],
            solaris    => {
                _doc => <<DOC,
DOC
                _sections  => [qw(CPU Distribution)],
                _mandatory => [qw(CPU Distribution)],
                CPU        => {
                    _doc => <<DOC,
DOC
                    _sections     => ["/$RE_MATCH/"],
                    _recursive    => ["/$RE_MATCH/"],
                    "/$RE_MATCH/" => {
                        _text => {},
                        _doc  => <<DOC,
DOC
                    },
                },
                Distribution => {
                    _doc => <<DOC,
DOC
                    _sections     => ["/$RE_MATCH/"],
                    _recursive    => ["/$RE_MATCH/"],
                    "/$RE_MATCH/" => {
                        _text => {},
                        _doc  => <<DOC,
DOC
                    },
                },
            },
            linux => {
                _doc => <<DOC,
DOC
                _sections  => [qw(CPU Distribution)],
                _mandatory => [qw(CPU Distribution)],
                CPU        => {
                    _doc => <<DOC,
DOC
                    _sections     => ["/$RE_MATCH/"],
                    _recursive    => ["/$RE_MATCH/"],
                    "/$RE_MATCH/" => {
                        _text => {},
                        _doc  => <<DOC,
DOC
                    },
                },
                Distribution => {
                    _doc => <<DOC,
DOC
                    _sections     => ["/$RE_MATCH/"],
                    _recursive    => ["/$RE_MATCH/"],
                    "/$RE_MATCH/" => {
                        _text => {},
                        _doc  => <<DOC,
DOC
                    },
                },
            },
            Compatibility => {
                _doc => <<DOC,
DOC
                _sections     => ["/$RE_MATCH/"],
                "/$RE_MATCH/" => {
                    _text => {},
                    _doc  => <<DOC,
DOC
                },
            },
        }
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
}

sub evaluate_compat ($$)
{
    my $cfg = shift;
    my $detect_distro = shift;

    my $compat_string = $cfg->{'Compatibility'}->{$detect_distro}{_text};
    my @compats = split /\n/, $compat_string;
    unshift @compats, $detect_distro;

    return @compats;
}

sub evaluate_dirs ($;@)
{
    my $PackDir = shift;
    my @compats = shift;

    my $valid_directory;

    foreach (@compats) {
        if (-d "$PackDir/$_" ) {
            $valid_directory = $_;
            last;
        }
    }

    return $valid_directory;
}

sub exists_stored_evaluation ()
{
    if (-f "$SEPP_OS_DETECTOR") {
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

    if (!exists_stored_evaluation()) {
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
    my %DIR = @_;
    my @COMPATS = get_compatible_os( %DIR );
    return evaluate_dirs($PackDir, @COMPATS);
}

__END__

=head1 NAME

OSDetector.pm - SEPP startup Module for detecting the OS/valid EPREFIX directory

=head1 SYNOPSIS

my $os = SEPP::OSDetector::get_existing_execdir( $PackDir , %DIR );

or

my @compatibles = SEPP::OSDetector::get_compatible_os( %DIR );


=head1 DESCRIPTION

This module provides two functions for creating smart os-detection 
SEPP/start.pl wrappers. 

=over 10

=item B<SEPP::OSDetector::get_existing_execdir( $PackDir , %DIR )>

Returns the best match for I<$EPREFIX> for the running OS. That
means if there is a SEPP Package with the following directory
structure (e.g. smaba-3.0.25-mo):

`--SEPP
`--amd64-debian-linux3.1
`--i686-debian-linux3.1
`--include
`--man
`--share
`--.swat
`--template
`--var

the result of this function will be

 amd64-debian-linux3.1  on a amd64 debian system (64bit)
 i686-debian-linux3.1   on a i686 debian system  (32bit)

=item B<SEPP::OSDetector::get_compatible_os( %DIR )>

Returns a perl array with OS compatible I<$EPREFIX>. 
E.g. on a amd64 system running Ubuntu 6.10 the result will be

  amd64-linux-ubuntu6.10
  ia32-linux-ubuntu6.10
  amd64-linux-ubuntu6.06
  ia32-linux-ubuntu6.06
  amd64-debian-linux3.1
  i686-debian-linux3.1

that means, all this compiled versions are runnable on the
Ubuntu 6.10 system (i.e. GLIBC version is not newer). The 
first entry in the array is the best match, the last the
worst.

=back

=head1 BUGS

No knowns till now ... :-)

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

