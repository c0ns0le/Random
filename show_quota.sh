#!/bin/bash
#Description: Bash script to display disk quota user for the user running the script.
#Written By: Jeff White of The University of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.3
#Revision Date: 10-10-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

if [ "$EUID" = "0" ];then
  :
else
  #Get the current information
  used_blocks="$(quota | awk '{if (NR==4) {print $1}}')"
  soft_limit_blocks="$(quota | awk '{if (NR==4) {print $2}}')"
  hard_limit_blocks="$(quota | awk '{if (NR==4) {print $3}}')"
fi

if ! quota | awk '/^Disk quotas/&&/none$/ {exit 1}';then #Do we have a quota set?
:
#  echo
#  echo "Your disk quota has not yet been assigned."
#  echo
elif [ "$used_blocks" -ge "$soft_limit_blocks" ];then #Are we over quota?
  echo
  echo "WARNING: You are over your disk usage quota.  Please remove files you do not need or create a ticket on CoRE."
  quota_usage=$(echo "scale=4;($used_blocks/$soft_limit_blocks)*100" | bc | sed -e 's/00$//')
  echo "You are using ${quota_usage}%" of your disk quota.
  echo
else
  quota_usage=$(echo "scale=4;($used_blocks/$soft_limit_blocks)*100" | bc | sed -e 's/00$//')
  echo
  echo "You are using ${quota_usage}%" of your disk quota.
  echo
fi

#To see the raw block counts...
#echo "You are using $used_blocks of $soft_limit_blocks blocks"
