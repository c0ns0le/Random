#!/bin/bash

#Description: Bash script to check if a process running.
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.6.6
#Revision Date: 9-12-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

#Exit status codes:
##0 = The process $PROCNAME appears to be running.
##1 = The process $PROCNAME does not appear to be running.
##2 = Something went wrong with the execution of the script, you should check on that.

#We we called with an argument?
if [ -z "$1" ]; then
	echo "# $LINENO Error - You must include a process name as an argument. EXITING"
	exit 2
elif [ -n "$2" ]; then
	echo "# $LINENO Error - You must only include ONE process name as an argument. EXITING"
	exit 2
fi

#Name of the process
PROCNAME=$1
echo "PROCNAME - $PROCNAME"

#User the process is running as
USERRUNNING=$(ps aux | awk -v PROCNAME="$PROCNAME" '($11 == PROCNAME) { print $1;nextfile }')
echo "USERRUNNING - $USERRUNNING"

#Day or time the process started
PROCSTART=$(ps aux | awk -v PROCNAME="$PROCNAME" '($11 == PROCNAME) { print $9;nextfile }')
echo "PROCSTART - $PROCSTART"

#Process ID (PID) of the process
PID=$(ps aux | awk -v PROCNAME="$PROCNAME" '($11 == PROCNAME) { print $2;nextfile }')
echo "PID - $PID"

#Status of the process
ISPROCRUNNING=$(ps aux | awk -v PROCNAME="$PROCNAME" '{if ($11 == PROCNAME)&&($8 ~ /S/||/R/) { print "1";nextfile } else { print "0" }}')

if [ "$ISPROCRUNNING" = "1" ];then
	exit 0
else
	exit 1
fi

#ps aux | awk '(/processnamegoeshere/&&!/awk/)&&(/S/||/R/) { print "#\n# Yep, that process appears to be running just fine!\n#" }'