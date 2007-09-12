SHELL = /bin/sh
.SUFFIXES:
.SUFFIXES: .c .o .pl .pm .pod .html .1

FILES = `cat MANIFEST`
VER = 1.4.2
VER_CVS = v1_4_2
TAR = sepp-$(VER).tar

all:
	perl -i -p -e 's/Release: \S+/Release: $(VER)/g' sbin/seppadm
	perl -i -p -e 's/sepp-\d+\.\d+\.\d+/sepp-$(VER)/g' README
	pod2man --release=$(VER) --center=SEPP sbin/seppadm >man/man1/seppadm.1
	pod2man --release=$(VER) --center=SEPP sbin/SeppStart.pm >man/man1/SeppStart.pm.1
	cvs commit
	cvs tag -F $(VER_CVS)
	cp -rp /usr/isgtc/lib/perl/Config sbin
	(cd sepp-get && cvs up)
	cp sepp-get/sepp-get sbin
	pod2man --center=SEPP sbin/sepp-get >man/man1/sepp-get.1
	#cp conf/sepp.conf conf/sepp.conf-dist
	#cp conf/sepprc.system conf/sepprc.system-dist
	tar cvf $(TAR) $(FILES)
	compress $(TAR)
