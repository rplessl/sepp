# a sane environment for building binaries
umask 022
if ( $?DISPLAY == 1 ) then
	set odisplay=$DISPLAY
   if ( $?XAUTHORITY == 1 ) then
	    set oxauth=$XAUTHORITY
   endif
endif
set ohome=$OHOME
set opath=$OPATH
set orpath=$ORPATH
set oterm=$TERM
set ohost=$HOST
set pack=$PACK
unsetenv *
setenv LD_RUN_PATH $orpath
if ( $?odisplay == 1 ) then
	setenv DISPLAY $odisplay
   if ( $?oxauth == 1 ) then
	    setenv XAUTHORITY $oxauth
   endif
endif
setenv TERM $oterm
setenv HOME $ohome
setenv PATH $opath
setenv HOST $ohost
setenv OPENWINHOME /usr/openwin
set prompt="\n%U%m:%/%u\n%B$pack%b> "
#alias sepp-back 'rsync -avz -e ssh sparky:`pwd`/i686-debian-linux3.0 .'
#alias back-sync 'rsync -avz -e ssh sparky:`pwd`/\!:1 .'
#alias co-inst 'gcp -v /home/oetiker/data/projects/AAER-sepp_install_lib/{INSTALL,INSTALL.lib,start.pl} .'


setenv
ls -l
