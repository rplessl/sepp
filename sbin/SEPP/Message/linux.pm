package SEPP::Message::linux;

# A SEPP module which enables a popup box with license information
# on the Linux platform

use strict;

use vars qw($VERSION);
$VERSION = '1.0';

my $RCS_VERSION = '$Id: linux.pm 153 2005-06-06 08:11:12Z aschults $';

### PROTOTYPES ###
sub new($);
sub showmessage($);

### CONSTRUCTOR ###
sub new($) {
    my $proto = shift;
    my $class = ref($proto) || $proto;
  
    my $self = {};
    bless($self, $class);

    return $self;
}

### NOTIFY ###
sub showmessage($){
    shift;
    my $answer = system "/usr/sepp/bin/dialog",
	"--yesno","$_","0","0";
    return $answer;
}
