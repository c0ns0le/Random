#!/bin/bash
shopt -s -o noclobber
shopt -s -o nounset

#Description: Custom ESX monitoring for NetView
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.NetServe365.com)
#Version Number: 0.1
#Revision Date: 7-11-2010
#License: This script is released under version three (3) of the GPU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

NUMCPUCORES=$(awk '/cores/ { print $1 }' /proc/vmware/sched/ncpus)
VPCULOAD=$(awk '/vcpus/ { print $4 }' /proc/vmware/sched/cpu-load)
TRUEVCPULOAD=$(echo "scale=3;$VPCULOAD / $NUMCPUCORES * 100" | bc | cut --delimiter="." -f1)

exit $TRUEVCPULOAD