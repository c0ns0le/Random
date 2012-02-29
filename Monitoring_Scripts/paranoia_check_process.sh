#!/bin/bash
shopt -s -o noclobber
shopt -s -o nounset

#Name: paranoia_check_process.sh
#Description: Bash script to check that a process is still running and restart a daemon if it is not.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.1 - 2012-02-28 - Initial version. - Jeff White
#
#####

script=${0##*/}
netcool_ticket="NOC-NETCOOL-TICKET"
netcool_alert="NOC-NETCOOL-ALERT"
pidofbin="/sbin/pidof"

function _print_stderr { # Usage: _print_stderr "Some error text"
  echo "$1" 1>&2
}

#were we called with enough args?
if [ "$#" != "2" ];then
  _print_stderr "Usage: $script process_to_check daemon_to_start"
  exit 255
else
  process_to_check="$1"
  daemon_to_start="$2"
fi

#Check if the process is running
if ! $pidofbin "$process_to_check" >/dev/null;then #If the process is not found...

  echo "Process $process_to_check was not found, starting the daemon again."
  logger -p info "Process $process_to_check was not found, starting the daemon again."

  #Start the daemon and check its status
  service "$daemon_to_start" start
  if [ "$?" = "0" ];then
    echo "Successfully started daemon $daemon_to_start"
    logger -p info "Successfully started daemon $daemon_to_start"
  else
    _print_stderr "Failed to start daemon $daemon_to_start"
    logger -p err -t $netcool_alert "Process $process_to_check is not running and daemon $daemon_to_start failed to start!"
    exit 1
  fi

  #Try to find the process again, just to be sure it exists
  if ! $pidofbin "$process_to_check">/dev/null;then #If the process does not exist...
    _print_stderr "Process $process_to_check was not found even after the daemon $daemon_to_start was started successfully."
    logger -p err -t $netcool_alert "Process $process_to_check is not running even after the daemon $daemon_to_start was started successfully."
    exit 1
  fi

else #If the process is found...
  echo "Process $process_to_check exists, leaving the daemon alone."
fi