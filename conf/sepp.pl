#!/usr/sepp/sbin/perl -w
#
# if the home is available on an already mounted directory, bind it instead
# of wasting another mountpoint ... 
#
# $Id: sepp.pl 174 2006-01-03 11:51:30Z dws $
# Tobi Oetiker, 2002-12-10
# * 30.3.2003 to added support for host(3):/usr/lunghin/pk1/pack/&
#                by just killing the (3) bit
# * 03.1.2006 ds added support for solaris
# * 03.1.2007 rp added support for different local/sepp usernames

$ENV{PATH}="/usr/bin";
my $key = $ARGV[0];

##############################################################
# if there is a  file called
# /scratch/pack/$key/mount and it belongs to user >#>user_name<#<
# we mount this into 
# /usr/pack/$key
# this is great for building sepp packages
my $build = "/scratch/pack/$key/mount";
# make sure the mount does not exist already!
if (open X, "/etc/mtab"){
        while (<X>){
                if (m|\s/usr/pack/$key\s|){
                        system "/usr/bin/logger","-p","warn","-t","sepp.pl","$key is already in mtab";
                        exit 1;
                };
        }
}
close X;
if ( -r $build 
        and (stat $build)[4] == (getpwnam '>#>user_name<#<')[2] ){
	if($^O eq 'linux') {
		print "-fstype=none,bind :/scratch/pack/$key\n";
	}
	else {
		print "localhost:/scratch/pack/$key\n";
	}
        exit 0;
}
##############################################################
# back to our regular program
##############################################################
open X, "/usr/sepp/conf/autosepp_indirect" or exit 1;
while (<X>){
        chomp;
        last if /^\Q$key\E\s/mo;
        undef $_;
}
exit 1 unless $_;
chomp;
my $target=(split /\s+/)[1];
chomp $target;
# kill host(x) 
$target =~ s/\(\d+\)//;

$local=(split /:/, $target)[1];
$local =~ s/&$/$key/;
if ( -d $local){
	if($^O eq 'linux') {
		print "-fstype=none,bind :$local\n";
	}
	else {
		print "localhost:$local\n";
	}
} else {
	if($^O eq 'linux') {
		print "-hard,nfsvers=3,tcp,rsize=8192,wsize=8192 $target\n";
	}
	else {
		print "$target\n";
	}
}
