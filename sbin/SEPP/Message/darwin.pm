package SEPP::Message::darwin;

# A SEPP module which enables a popup box with license information
# on the Darwin/MacOS X platform

use strict;

use vars qw($VERSION);
$VERSION = '1.0';

my $RCS_VERSION = '$Id: darwin.pm 156 2005-06-06 09:54:47Z aschults $';

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
    if ($0 =~ m/.app(\s?)*$/) {
	#system "osacompile -o /tmp/auth.$$.app -e 'set returnValue to display dialog \"$_\" buttons {\"ok\",\"cancel\"}'";
	#my $answer=`/tmp/auth.$$.app/Contents/MacOS/applet`;
 	my $answer=`osascript -e 'set returnValue to display dialog \"$_\" buttons {\"ok\",\"cancel\"}'`;
 	chomp $answer;
	if ($answer eq 'button returned:ok') {return 1;} else {return 0;}
    }
    else {
	my $answer = system "/usr/sepp/bin/dialog",
	    "--yesno","$_","0","0";
	return $answer;
    }


}
