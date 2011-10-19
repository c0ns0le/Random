#!/bin/bash
#Description: Bash script to set up the environment of the NetBackup live client.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
#Version Number: 0.1
#Revision Date: 10-6-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

script="${0##*/}"

function _print-stderr-then-exit { # Usage: _print-stderr-then-exit "Some error text" exitnumber
echo "$1" 1>&2
exit $2
}

if [ -f "/tmp/.start_configured" ];then
  _print-stderr-then-exit "File /tmp/.start_configured already exists, this script shouldn't be ran more than once." 1
else
  touch /tmp/.start_configured
fi
echo "Starting the network configuration utility."
system-network-config || _print-stderr-then-exit "Error on line $LINENO in script $script." 1

echo "Restarting network services."
service network restart || _print-stderr-then-exit "Error on line $LINENO in script $script." 1

mkdir -p /usr/openv/netbackup/logs/ || _print-stderr-then-exit "Error on line $LINENO in script $script." 1

mount -t tmpfs -o size=128M,mode=700 tmpfs /usr/openv/netbackup/logs/ || _print-stderr-then-exit "Error on line $LINENO in script $script." 1