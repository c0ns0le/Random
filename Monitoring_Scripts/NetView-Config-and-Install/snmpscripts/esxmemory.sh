#!/bin/bash
shopt -s -o noclobber
shopt -s -o nounset

#Description: Custom ESX monitoring for NetView
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.NetServe365.com)
#Version Number: 0.1
#Revision Date: 7-11-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

#Amount of physical memory managed by the host in KB
AMTKBMANAGEDMEM=$(awk '/Managed/ { print $1 }' /proc/vmware/sched/mem)

#Amount of physical memory in use by the VMKernel in KB
AMTKBPHYSMEMUSEDBYVMKERNEL=$(awk '/Kernel/ { print $1 }' /proc/vmware/sched/mem)

#Amount of physical memory which is not in use (free) in KB
AMTKBPHYSMEMFREE=$(awk '/Free/&&!/MinFree/ { print $1 }' /proc/vmware/sched/mem)

#Amount of memory allocated to all VMs on the host in KB
AMTKBMEMALLOCATEDTOVM=$(awk '/TOTAL/ { print $3 }' /proc/vmware/sched/mem)

#Amount of memory overcommitted to VMs in KB
AMTKBMEMOVERCOMMIT=$(($AMTKBMEMALLOCATEDTOVM - $AMTKBMANAGEDMEM))

#Percent of physical memory which is not in use (free)
PCTFREEPHYSMEM=$(awk '/free/ { print $4 }' /proc/vmware/sched/mem-load | cut --delimiter="." -f1)

#Figure out if we are actually overcommitted and change the variable if so.  If this is not done the amount overcommitted shows as a negative.
ISITNEG=$(( AMTKBMEMOVERCOMMIT < 0 ))
if [ "$ISITNEG" = "1" ];then
	AMTKBMEMOVERCOMMIT="Not overcommitted"
fi

echo $AMTKBMANAGEDMEM
echo $AMTKBPHYSMEMUSEDBYVMKERNEL
echo $AMTKBPHYSMEMFREE
echo $AMTKBMEMALLOCATEDTOVM
echo $AMTKBMEMOVERCOMMIT

exit $PCTFREEPHYSMEM