#!/bin/bash

# Copyright (c) 2008-2009 OETIKER+PARTNER AG, Olten, Switzerland.
#
# Author: Roman Plessl <roman.plessl@oetiker.ch>, 2008
#
# /etc/init.d/sepp_osdetector.sh
#

### BEGIN INIT INFO
# Provides:           sepp_osdetector
# Required-Start:     autofs 
# Should-Start:       automountfix
# Required-Stop:      network
# Default-Start:      2 3 4 5
# Default-Stop:       0 1 6
# Short-Description:  set SEPP environment
# Description:        Start the SEPP environment checking script
### END INIT INFO

system=unknown
if [ -f /etc/debian_version ]; then
        system=debian
elif [ -f /etc/redhat-release ]; then
        system=redhat
elif [ -f /etc/SuSE-release ]; then
        system=suse
else
        echo "$0: Unknown system, please port and contact https://lists.oetiker.ch/op-sepp" 1>&2
        exit 1
fi


if [ $system = redhat ]; then
        . $initdir/functions
fi

if [ $system = suse ]; then
        . /etc/rc.status
        # Reset status of this service
        rc_reset
fi

if [ $system = debian ]; then
        thisscript="$0"
        if [ ! -f "$thisscript" ]; then
                echo "$0: Cannot find myself" 1>&2
                exit 1
        fi
fi

PATH=/sbin:/usr/sbin:/bin:/usr/bin
export PATH

function status()
{
        if [ -f /tmp/SEPP.OS.DETECTOR ]; then
           PLATFORM=`head -1 /tmp/SEPP.OS.DETECTOR`
           echo "Checking the status of sepp_osdetector: Detected Platform ($PLATFORM)";
        else
	   echo "Checking the status of sepp_osdetector: Platform not detected";
        fi
}

function start()
{
	# run seppadm environement which runs the OS detection of
	# SEPP::OSDetector and creates the file in the /tmp
	HOME=/tmp
	export HOME

	/usr/sepp/sbin/seppadm environment test-1.0-rp > /dev/null
}


#
# Debian/Ubuntu start/stop functions.
#
function debian()
{

case "$1" in
start)
      echo -n 'Starting SEPP environment detection:';   
      start
      echo " done."
      ;;
stop)
      echo -n 'Stopping SEPP environment:'
      echo " done."
      ;;
status)
      status
      ;;
*)
      echo "Usage: /etc/init.d/sepp_osdetector.sh {start|stop|status}" >&2
      exit 1
      ;;
esac
}

#
# RedHat start/stop functions.
#
function redhat()
{

case "$1" in
start)
      echo -n 'Starting SEPP environment detection:';
      start
      echo " done."
      ;;
stop)
      echo -n 'Stopping SEPP environment:'
      echo " done."
      ;;
status)
      status
      ;;
*)
      echo "Usage: /etc/init.d/sepp_osdetector.sh {start|stop|status}" >&2
      exit 1
      ;;
esac
}



#
# SuSE start/stop functions.
#
function suse()
{
 
case "$1" in
start)
      echo -n 'Starting SEPP environment detection:';
      start
      rc_status -v
      ;;
stop)   
      echo -n 'Stopping SEPP environment:'
      rc_status -v
      ;;
status)
      status
      rc_status -v
      ;;
*)
      echo "Usage: /etc/init.d/sepp_osdetector.sh {start|stop|status}" >&2
      exit 1
      ;;
esac
}   


RETVAL=0
if [ $system = debian ]; then
        debian "$@"
elif [ $system = redhat ]; then
        redhat "$@"
elif [ $system = suse ]; then
        suse "$@"
fi

exit $RETVAL
