#!/bin/bash

#Description: Bash script to check the status of a Gluster volume.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
#Based on unlicensed work by: Arie Skliarouk <skliarie@gmail.com>
#Version Number: 0.1
#Revision Date: 9-16-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

script="${0##*/}"
glusterbin="/usr/sbin/gluster"
awkbin="/bin/awk"

function _print_stderr { # Usage: _print_stderr "Some error text"
echo "$1" 1>&2
}

if [ -z "$1" ];then
  _print_stderr "ERROR: No volume name given."
  echo "Usage: $script volume_name number_of_peers"
  exit 1
elif [ -z "$2" ];then
  _print_stderr "ERROR: No expected peer number given."
  echo "Usage: $script volume_name number_of_peers"
  exit 1
fi

volume_to_check="$1"
expected_number_of_peers="$2"

#Is the volume started?
current_volume_status="$($glusterbin volume info "$volume_to_check" | $awkbin -F': ' '/^Status/ {print $2}')"
if [ "$current_volume_status" != "Started" ];then
  echo "Gluster volume status check failed for volume $volume_to_check!  Expected \"Started\" but currently is \"$current_volume_status\"."
  logger -p crit "URGENT ALERT CALL TEIR II: Gluster volume status check failed for volume $volume_to_check!  Expected \"Started\" but currently is \"$current_volume_status\"."
  exit 2
fi

#Do any of our peers show as disconnected?
$glusterbin peer status | $awkbin '/Disconnected/ {exit 1}'
if [ "$?" != "0" ];then
  echo "One or more gluster peers has the state disconnected!"
  logger -p crit "URGENT ALERT CALL TEIR II: One or more gluster peers has the state disconnected!"
  exit 2
fi

#Do we have the right number of peers?
current_number_of_peers="$($glusterbin peer status | $awkbin -F': ' '/^Number of Peers/ {print $2}')"
if [ "$current_number_of_peers" != "$expected_number_of_peers" ];then
  echo "Gluster peers are missing!  Expected $expected_number_of_peers but currently have ${current_number_of_peers}."
  logger -p crit "URGENT ALERT CALL TEIR II: Gluster peers are missing! Expected $expected_number_of_peers but currently have ${current_number_of_peers}."
  exit 2
fi

echo "Gluster volume $volume_to_check is clean."