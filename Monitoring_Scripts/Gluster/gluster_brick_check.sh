#!/bin/bash

#Description: Bash script to check the status of Gluster bricks.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
#Version Number: 0.1
#Revision Date: 9-16-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

script="${0##*/}"
glusterbin="/usr/sbin/gluster"
awkbin="/bin/awk"
my_hostname=$HOSTNAME

function _print_stderr { # Usage: _print_stderr "Some error text"
echo "$1" 1>&2
}

#Find each brick on this host and check it.
$glusterbin volume info vol_mainhome | grep "^Brick[0-9].*$my_hostname" | cut -d':' -f3 | while read -r each_brick;do
  grep "$each_brick" /proc/mounts >/dev/null
  if [ "$?" != "0" ];then
    _print_stderr "The Gluster brick $each_brick is not mounted!"
    logger -p crit "URGENT ALERT CALL TEIR II - The Gluster brick $each_brick is not mounted!"
    num_missing_bricks=$(($num_missing_bricks + 1))
  fi
done

if [ -z "$num_missing_bricks" ];then
  echo "All Gluster bricks on storage node $my_hostname are mounted."
else
  _print_stderr "$num_missing_bricks bricks are missing or not mounted!"
fi