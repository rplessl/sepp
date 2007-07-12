// Author: Anton Schultschik <aschults@gmx.net>
// 
// osx_evtproxy - Launch Application and then forward/return Apple events
//                usually started from within another Application bundle
//
// Copyright (C) 2005 Anton Schultschik. All rights reserved.
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

//
// Compilation instructions: 
//    gcc -o osx_evtproxy osx_evtproxy.c -framework Carbon 


#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <string.h>
#include <stdio.h>
#include <getopt.h>
//#include <AppleEvents/AppleEvents.h>



// --> LATER ON: 	<key>LSBackgroundOnly</key><true/>
//    ... Makes app invisible.
// -->Switch on:	<key>LSGetAppDiedEvents</key><true/>
//    ... Notifiess App of child death.
ProcessSerialNumber psn;
pid_t pid=-1;
FSSpec fls;
const char * app_path=NULL;
bool verbose=false;

bool isDead(pid_t pid)
{
	if(0!=kill(pid,0))
	  {

		if(errno !=  ESRCH)
			fprintf(stderr,"Error in kill -0: %s\n",strerror(errno));
		return true;
	 }
	 return false;
}


OSErr launch_app(FSSpec *fls, const AppleEvent * firstEvent, ProcessSerialNumber *psn,
				pid_t *pid)
{
    /* Details on launching apps with an initial event:
     * http://developer.apple.com/technotes/tn/tn1002.html
     */

	OSErr err;

	LaunchParamBlockRec lp;
	bzero(&lp,sizeof(lp));

	lp.launchControlFlags= launchContinue;
	lp.launchAppSpec=fls;
	Handle h;
	if(firstEvent)
	  {
		AEDesc launchdesc;
		err = AECoerceDesc (firstEvent, typeAppParameters, &launchdesc);
		if(err) 
		  { 
			fprintf(stderr,"Error in AECoerceDesc: %d\n",err);
			return err;
		  }
		  
		h=(Handle)launchdesc.dataHandle;
		HLock((Handle)h);
		lp.launchAppParameters=((AppParametersPtr)*h);
	  }

	err=LaunchApplication(&lp);
	if(err) 
	  { 
		fprintf(stderr,"Error in LaunchApplication: %d\n",err);
	  }

	if(firstEvent) DisposeHandle((Handle)h);
	*psn=lp.launchProcessSN;

	int cnt;
	for(cnt=3;cnt>=0;cnt--) 
		{
			err=GetProcessPID(psn,pid);
			if(!err) return 0;
			sleep(1);
		}

	fprintf(stderr,"Error in GetProcessPID: %d\n",err);
	return err;
}


OSErr set_event_psn(AppleEvent *e,ProcessSerialNumber psn)
	{
		OSErr err;
		AEAddressDesc addr;
		err=AECreateDesc (typeProcessSerialNumber,&psn,sizeof(psn),&addr);
		if(err) 
		  { 
			fprintf(stderr,"Error in AECreateDesc: %d\n",err);
			return err;
		  }
				
		err=AEPutAttributeDesc (e,keyAddressAttr,&addr);
		if(err)
			{ 
				fprintf(stderr,"Error in AEPutAttributeDesc: %d\n",err);
				AEDisposeDesc(&addr);
			}
		return err;
	}


OSErr get_event_timeout(const AppleEvent *e,SInt32 * timeout)
	{
		OSErr err;
		AEDesc d;
		err=AEGetAttributeDesc (
							e,
							keyEventIDAttr,
							typeWildCard,
							&d
							);
		if(err) 
		  { 
			fprintf(stderr,"Error in AEGetAttributeDesc: %d\n",err);
			return err;
		  }		

		err=AEGetAttributeDesc (
							e,
							keyTimeoutAttr,
							typeWildCard,
							&d
							);
		if(err) 
		  { 
			fprintf(stderr,"Error in AEGetAttributeDesc: %d\n",err);
			return err;
		  }		
		
		long sz=AEGetDescDataSize(&d);
		if(sz!=sizeof(SInt32)) 
		  { 
			fprintf(stderr,"Warning: size of Desc data does not match\n");
		  }
		  
		err=AEGetDescData(&d,timeout,sizeof(SInt32));
		if(err)
		  { 
			fprintf(stderr,"Error in AEGetDescData: %d\n",err);
			return err;
		  }
		  
		return err;
	
	}

OSErr get_event_evtid(const AppleEvent *e,AEEventID * evtid)
	{
		OSErr err;
		AEDesc d;
		err=AEGetAttributeDesc (
							e,
							keyEventIDAttr,
							typeWildCard,
							&d
							);
		if(err) 
		  { 
			fprintf(stderr,"Error in AEGetAttributeDesc: %d\n",err);
			return err;
		  }		
		
		long sz=AEGetDescDataSize(&d);
		if(sz!=sizeof(AEEventID)) 
		  { 
			fprintf(stderr,"Warning: size of Attribute data does not match\n");
		  }		
		err=AEGetDescData(&d,evtid,sizeof(AEEventID));
		if(err) 
		  { 
			fprintf(stderr,"Error in AEGetDescData: %d\n",err);
			return err;
		  }		
		return err;
	}

OSErr send_event(const AppleEvent * theAppleEvent,  
				AppleEvent * reply, 
				SInt32 handlerRefcon,
				ProcessSerialNumber psn) {

	OSErr err;
	AEDesc e;
	err=AEDuplicateDesc(theAppleEvent,&e);
	if(!err) {
		err=set_event_psn(&e,psn);
		if(!err) 
			{
				SInt32 timeout;
				err=get_event_timeout(theAppleEvent,&timeout);
				if(!err) 
					{
						err=AEResetTimer(reply);
						if(err && err != -1709)  // -1709 --> Invalid reply passed to fkt
							{
								fprintf(stderr,"Error in AEResetTikmer: %d\n",err);
							}		
						else
							{
								err=AESend(&e,reply,kAEWaitReply,kAENormalPriority,timeout,nil,nil);
								if(err) fprintf(stderr,"Error in AESend: %d\n",err);
							}
					}
					
			}
			
		// Cleanup the Desc... since aesend produced an error, it's still allocated.
		if(err) {
			AEDisposeDesc(&e);
		}
	}
}		


void check_process(
				   EventLoopTimerRef inTimer,
				   void * inUserData
				   )
{
	if(pid && isDead(pid))
	  {
		QuitApplicationEventLoop();
	  }
}

OSErr catch_all(const AppleEvent * theAppleEvent,
				AppleEvent * reply,
				SInt32 handlerRefcon
				)
{
	OSErr err;
	err=launch_app(&fls,theAppleEvent,&psn,&pid);
	if(err) 
	{
		fprintf(stderr,"Fatal Error: Could not start app (err=%d)\n",err);
		exit(255);
	}
	
	AEEventID evtid;
	err=get_event_evtid(theAppleEvent,&evtid);
	if(err) return err;

	if(evtid == kAEApplicationDied)
	  {
		QuitApplicationEventLoop();
		return 0;
	  }

	if(verbose) 
		{
			char e[5];
			*((AEEventID*)e)=evtid;
			e[4]='\0';
			printf("Forwarding event %s\n",e);
		}

	err=send_event(theAppleEvent,reply,handlerRefcon,psn);
	if(err) return err;

	if(evtid == kAEQuitApplication)
	  {
		QuitApplicationEventLoop();
	  }
	return 0;
}

void usage()
	  {
		printf("Usage: evtproxy [-v] <path>\n\n");
		printf("\n");
		printf("Options: -v : Verbose\n");
		printf("\n");
		printf("  Starts the app indicated by <path> and forwards all apple-events sent to\n");
		printf("  to the current app (i.e. the app that is calling evtproxy).\n");
		printf("  Add the following settings in the file Info.plist of the current bundle:\n\n");
		printf("    <key>LSBackgroundOnly</key>\n    <true/>\n");
		printf("    <key>LSGetAppDiedEvents</key>\n    <true/>\n\n");
		printf("  LSBackgroundOnly: The curren bundle is invisible in the Finder so only the\n");
		printf("    second application is visible\n");
		printf("  LSGetAppDiedEvents: Notify the current bundle (this binary) when its child\n");
		printf("    dies (i.e. the application started by evtproxy)\n\n");
		exit(1);
	  }

int main (int argc, char * const argv[]) {

	int ch;
printf("xx %d\n",optind);
	while ((ch = getopt(argc, argv, "v")) != -1) {
             switch (ch) {
             case 'v':
					 verbose=1;
                     break;
             case '?':
             default:
                     usage();
             }
     }
     argc -= optind;
     argv += optind;


	if(argc!=1) usage();

	OSErr err;
	app_path=argv[0];
	
	FSRef fl;
	err=FSPathMakeRef (app_path,&fl,NULL);
	if(err) 
	  { 
		fprintf(stderr,"Error in FSPathMakeRef: %d\nCould not find '%s'\n",err,app_path);
		exit(255);
	  }
	err=FSGetCatalogInfo (&fl,0,NULL,NULL,&fls,NULL);
	if(err) 
	  { 
		fprintf(stderr,"Error in FSGetCatalogInfo: %d\n",err);
		exit(255);
	  }
	
	err= AEInstallEventHandler (
								typeWildCard,
								typeWildCard,
								&catch_all,
								0,
								false
								);
	if(err) 
	  { 
		fprintf(stderr,"Error in AEInstallEventHandler: %d\n",err);
		exit(255);
	  }
	
	EventLoopTimerRef tr;

	check_process(tr,NULL);
	err=InstallEventLoopTimer (
						   GetMainEventLoop(),
						   13,
						   9,
						   &check_process,
						   NULL,
						   &tr
						   );
	if(err) 
	  { 
		fprintf(stderr,"Error in InstallEventLoopTimer: %d\n",err);
		exit(255);
	  }	

	RunApplicationEventLoop();
    return 0;
}
