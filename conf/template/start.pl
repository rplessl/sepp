## REMOVE THIS LINE WHEN YOU HAVE EDITED THIS FILE ####################

# The start.pl file is written in Perl. Apart from standard
# Perl you can also use the additional commands provided by
# SeppStart.pm. Read 'man SeppStart' for detailed information.

# The variable $Pack contains the SEPP name of the current
# package. $PackDir is the pathname to the installation
# directory of the current package and $PackVar is the path to
# the SEPP var directory of the package if such directory
# exists.

## DO NOT put things like license server names into this file
## as its contents will be available on the SEPP web site. The
## same holds true for all other files in the SEPP directory.

# Fix the contents of some well known environment variables.
# These lines are only examples of what could be done. A
# well behaved application does not need any of these ...
# PreENV prepends the arguments to the contents of the
# environment variable and separates it with a ':'

#PreENV "PATH",                    "/usr/bin";
#PreENV "XFILESEARCHPATH",   "$PackDir/xresources/%N";
#PreENV "LD_LIBRARY_PATH",   "$PackDir/lib";

# The SetENV command (re)defines the value of an environment
# variable.

#SetENV "LM_LICENSE_FILE",   "$PackVar/license.dat";

# Here comes the heart of the start.pl script
# -------------------------------------------

# One of the two App* commands has to stand at the end of the
# script. It starts the application binary which the user
# wanted to run in the first place. The argument after the App*
# command has to point to the directory where the application
# binaries are stored.
#
# The difference between AppRun and AppExec is that AppRun uses
# system to start the application and AppExec uses exec. While
# AppRun lets the wrapper wait until the application ends,
# AppExec just execs the application, replacing the wrapper
# job.
#
# Because AppRun waits until the application terminates, it can
# then write an entry to the SEPP log, telling how long the
# application has been running and what it's exit code was.
# AppExec just logs the fact that the application is going to
# be started.

#############################################################
#
# if you are still using SEPP 1.4.x at some site you can use 
# the following compatibility code for detecting linux sytems
# and other unix systems (linux binaries compiled on debian 
# sarge)
#
# if($^O eq 'solaris') {
#        $os = 'sun4u-sun-solaris2.9';
# }
# elsif($^O eq 'darwin') {
#        $os = 'powerpc-apple-darwin7.4.1';
# }
# elsif($^O eq 'linux') {
#       $os = "ia32-linux-debian3.1";
#       chomp($uname=`/bin/uname -m`);
#       if($uname eq 'x86_64' and -d "$PackDir/amd64-linux-debian3.1") {
#               $os="amd64-linux-debian3.1";
#       }
# }
# AppRun "$PackDir/$os/bin";
#
# ### THIS IS THE NEW CODE ###################################
#
# if($^O eq 'linux') {
#    if ($OsName =~ m/^amd64.*ubuntu.*$/) {
#       ($OsName32 = $OsName)=~ s/amd64/ia32/;
#       if (! -d "$PackDir/$OsName" and -d "$PackDir/$OsName32" ) {
#          SetENV "GCONV_PATH", "/usr/lib32/gconv";
#	   SetENV "XLOCALEDIR", "/usr/lib32/locale";
#       }
#    }
# }

AppRun "$PackDir/$OsName/bin";
