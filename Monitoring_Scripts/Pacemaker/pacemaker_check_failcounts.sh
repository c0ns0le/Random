#!/bin/bash
# Name: pacemaker_check_failcounts.sh
# Description: Bash script to check the failcounts of cluster resources with Pacemaker/Corosync.
# Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
# Last change: Add version number
# Version: 1.0
 
##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

script="${0##*/}"
crm_bin="/usr/sbin/crm"
crm_resource_bin="/usr/sbin/crm_resource"
sed_bin="/bin/sed"
awk_bin="/bin/gawk"
PATH=$PATH:/usr/sbin

function _print-stderr-then-exit { # Usage: _print-stderr-then-exit "Some error text" exitnumber
  echo "$1" 1>&2
  rm -rf "${temp_dir}"
  exit $2
}
function _print-stdout-then-exit { # Usage: _print-stderr-then-exit "Some error text" exitnumber
  echo "$1" 1>&2
  rm -rf "${temp_dir}"
  exit $2
}

#Print out every resource, ignore the "Resource Group" line(s), then check the value of the failcount for each resource.
$crm_resource_bin -L | $awk_bin '!/Resource Group:/ {print $1}' | while read -r each;do
  $crm_bin resource failcount $each show $HOSTNAME | $awk_bin -F '=' '
    {if (($4==0)||($4==INFINITY)) {
      exit 0
    }
    else {
      exit $4
    }}'
  failcount="$?" #Yea, I'm abusing retval again...
  if [ "$failcount" = "0" ];then
    echo "OK: Resource $each on $HOSTNAME has a failcount of $failcount."
  elif [ "$failcount" = "1" ];then
    echo "WARNING: Resource $each on $HOSTNAME has a fail count of $failcount."
    logger -p err "CREATE TICKET FOR SE: Resource $each on $HOSTNAME has a fail count of $failcount in script $script."
  elif [ "$failcount" -gt "1" ];then
    echo "WARNING: Resource $each on $HOSTNAME has a fail count of $failcount."
    logger -p info "URGENT ALERT CALL TEIR II: Resource $each on $HOSTNAME has a fail count of $failcount in script $script."
  fi
done