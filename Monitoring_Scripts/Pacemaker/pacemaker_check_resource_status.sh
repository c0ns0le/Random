#!/bin/bash
# Description: Bash script to ensure all resources with Pacemaker/Corosync are started.
# Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
# Last change: Changed header
# Version: 1

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

script="${0##*/}"
temp_dir="/tmp/.$script"
crm_bin="/usr/sbin/crm"
crm_resource_bin="/usr/sbin/crm_resource"
sed_bin="/bin/sed"
awk_bin="/bin/gawk"
num_resources_expected="7" #The number of resources we expect to see.
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

mkdir -p "$temp_dir"

crm_resource_output="$temp_dir/crm_resource_output"
$crm_resource_bin -L > "$crm_resource_output"

num_resources_seen=$($awk_bin '!/Resource Group:/ {print $1}' $crm_resource_output | wc -l)
if [ "$num_resources_seen" != "$num_resources_expected" ];then
  echo "ERROR: Expected to see $num_resources_expected but $num_resources_seen were found."
  logger -p error "URGENT ALERT CALL TEIR II: Expected to see $num_resources_expected resources but $num_resources_seen were found in script $script."
fi

#Print out every resource, ignore the "Resource Group" line(s), then check if each resource is in the state 'Started'.
$awk_bin '!/Resource Group:/ {print $1}' $crm_resource_output | while read -r each;do
  grep "$each" $crm_resource_output | $awk_bin '
    {if ($3=/Started/) {
      exit 0
    }
    else {
      exit 1
    }}'
  if [ "$?" = "0" ];then
    echo "OK: Resource $each has a status of 'Started'."
  else
    echo "ERROR: Resource $each is not in state 'Started'."
    logger -p error "URGENT ALERT CALL TEIR II: Resource $each is not in state 'Started' in script $script."
  fi
done