#Description: Custom mdadm monitoring for NetView
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
#Originally written by: Jeff White (jwhite@netserve365.com) of NetServe365 (www.NetServe365.com)
#Version number: 0.2
#Revision date: 9-11-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

mdadmbin="/sbin/mdadm"
awkbin="/bin/awk"

#We we called with an argument?
if [ -z "$1" ]; then
        echo "# $LINENO Error - You must include an md device (e.g. /dev/md0) name as an argument - EXITING"
        exit 2
elif [ -n "$2" ]; then
        echo "# $LINENO Error - You must only include ONE name as an argument - EXITING"
        exit 2
fi

#RAID device file
md_device=$1

#Check the status of the array
array_status_text=$($mdadmbin --detail $md_device | $awkbin '$1 ~ /State/ {print $3}')

if [ -z "$array_status_text" ];then
  echo "Couldn't get the array state."
elif ! echo "$array_status_text" | $awkbin '{if ($1=="clean") {exit 0} else {exit 1}}' ;then
  echo "The RAID array $md_device is not in the state clean, it is in state $array_status_text!"
  logger -p crit "CREATE TICKET FOR SE - The RAID array $md_device is not in the state clean, it is in state $($awkbin '/State/ {print $3}')!"
else
  echo "The RAID array $md_device is clean."
fi