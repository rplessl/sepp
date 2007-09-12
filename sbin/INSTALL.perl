#!/bin/sh
set -x
# mini-perl install in /usr/sepp/sbin, lib in /usr/sepp/sbin/perl-lib

PLATFORM=`uname -s`-`uname -m`
BUILD=/scratch/build/sepp-perl-$PLATFORM
CPAN="ftp://sunsite.cnlab-switch.ch/mirror/CPAN"
PERL_VERSION=5.8.8
PERL_DIR="perl-$PERL_VERSION"
PERL_ARCHIVE="$PERL_DIR.tar.gz"
PERL_URL="$CPAN/src/$PERL_ARCHIVE"

# ARGUMENTS
ACTION=$1

# ENVIRONMENT
unset LD_RUN_PATH
if [ `uname -s` = "SunOS" ]; then
	PATH="/usr/bin:/usr/sepp/bin:/usr/ccs/bin"
	TAR=gtar
	MAKE=gmake
elif [ `uname -s` = "Linux" ]; then
	PATH="/usr/bin:/bin:/usr/sepp/bin"
	TAR=tar
	MAKE=make
elif [ `uname -s` = "Darwin" ]; then
	PATH="/usr/bin:/bin:/usr/sepp/bin"
	PLATFORM=`uname -s`-`uname -p`
	BUILD=/scratch/build/sepp-perl-$PLATFORM
	TAR=tar
	MAKE=make
else
     echo "Don't know about Platform $PLATFORM"
     exit 1
fi

[ -d $BUILD ] || mkdir $BUILD

#### PERL ####

if [ ! $ACTION -o $ACTION = "get" ]; then
	cd $BUILD
	wget $PERL_URL
	$TAR xzvf $PERL_ARCHIVE
	rm $PERL_ARCHIVE
fi
if [ ! $ACTION -o $ACTION = "conf" ]; then
	cd $BUILD/$PERL_DIR
	#make distclean
	[ -f config.sh ] && rm config.sh
	./Configure -de \
		-Dprefix=/usr/sepp/sbin \
                -Dbin=/usr/sepp/sbin \
                -Dscriptdir=/scripts \
		-Dprivlib=/usr/sepp/sbin/perl-lib \
		-Dsitelib=/usr/sepp/sbin/perl-lib/site_perl \
		-Uinstallusrbinperl \
		-Dperladmin="support@ee.ethz.ch"
fi
if [ ! $ACTION -o $ACTION = "make" ]; then
	cd $BUILD/$PERL_DIR
	$MAKE
fi

if [ ! $ACTION -o $ACTION = "install" ]; then
	cd $BUILD/$PERL_DIR
	$MAKE install DESTDIR=$BUILD/$PERL_DIR.INST
        cd $BUILD/$PERL_DIR.INST && rm -rf scripts
        cd usr/sepp/sbin && rm -rf man perl5* a2p
        cp `/usr/sepp/bin/rsync --seppdebug 2>&1 |grep Path:|awk '{print $2}'` .
fi
