#!/bin/bash
shopt -s -o noclobber

#Description: Custom ESX disk monitoring for NetView
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.NetServe365.com)
#Version Number: 0.1
#Revision Date: 7-11-2010
#License: This script is released under version three (3) of the GPU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

DATASTORENAME=$1

#Were we called with an argument?
if [ -z "$1" ]; then
	echo "You must include a process name as an argument.  $LINENO - EXITING" #| tee -a $ERRLOG
	exit 2
elif [ -n "$2" ]; then
	echo "You must only include ONE process name as an argument.  $LINENO - EXITING" #| tee -a $ERRLOG
	exit 2
fi

#The total size of the datastore in KB
AMTKBDSTOTAL=$(vdf | awk -v dsname="$DATASTORENAME" '$0 ~ dsname {print $1}' | cut --delimiter="%" -f1)

#The amount of the datastore used in KB
AMTKBDSUSED=$(vdf | awk -v dsname="$DATASTORENAME" '$0 ~ dsname {print $2}' | cut --delimiter="%" -f1)

#The amount of the datastore not in use (free) in KB 
AMTKBDSFREE=$(vdf | awk -v dsname="$DATASTORENAME" '$0 ~ dsname {print $3}' | cut --delimiter="%" -f1)

#The percent of the datastore used
PCTDSUSED=$(vdf | awk -v dsname="$DATASTORENAME" '$0 ~ dsname {print $4}' | cut --delimiter="%" -f1)

echo $DATASTORENAME
echo $AMTKBDSTOTAL
echo $AMTKBDSUSED
echo $AMTKBDSFREE

exit $PCTDSUSED