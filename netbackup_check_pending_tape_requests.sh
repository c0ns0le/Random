#!/bin/bash
shopt -s -o noclobber
shopt -s -o nounset
#Description: Bash script to check for pending tape requests in NetBackup.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.1 - 2012-01-13 - Initial version. - Jeff White
#
#####

script="${0##*/}"
vmoprcmdbin="/usr/openv/volmgr/bin/vmoprcmd"
bpstulistbin="/usr/openv/netbackup/bin/admincmd/bpstulist"
awkbin="/usr/bin/nawk"
loggerbin="/usr/bin/logger"

#Ok, this first attempt is broken.  For some reason when a tape is requested *all* media servers show it as needed.
#That means this loop would generate 10 alerts for a single tape if there were 10 servers.
# #This line gets us the list of servers which owns a storage unit or unit group
# $bpstulistbin | $awkbin '{print $3}' | sort -u | while read -r each_media_server;do
#   echo "Checking host $each_media_server."
#   #The awk here checks if the string <NONE> is found and prints "NONE" then exits if so.
#   #Otherwise, if a line is not blank (if NF is not set, it is a blankline ) and if also the next to last field
#   #has two or more numbers in it then print the next to last field.  These are the tape numbers.
#   $vmoprcmdbin -d pr -h $each_media_server | $awkbin '{if (/<NONE>/) {print "NONE";exit} else if (NF>1 && $(NF-1) ~ /^[0-9].*[0-9]$/) {print $(NF-1)}}' | while read -r each_tape;do
#     if [ "$each_tape" = "NONE" ];then
#       echo "No pending tape requests found for host $each_media_server."
#     elif [ -z "$each_tape" ];then
#       $loggerbin -p info "CREATE TICKET FOR SE - Script $script was unable to determine if there are any pending tape requests for host $each_media_server.  Variable \$each_tape was null."
#     else
#       echo "NetBackup is requesting tape number $each_tape on host $each_media_server.  Please put it in the appropriate drive/robot."
#       $loggerbin -p info "NetBackup is requesting tape number $each_tape on host $each_media_server.  Please put it in the appropriate drive/robot."
#     fi
#   done
# done

#This second attempt is a little better.  The output of vmoprcmd here also includes the server name requesting it but
#that has not been added to this script.
#$vmoprcmdbin -devmon pr | 
$awkbin '{if (/<NONE>/) {print "NONE";exit} else if ($2 ~ /^[0-9].*[0-9]$/) {print $2}}' /tmp/tapes3.txt | while read -r each_tape;do
  if [ "$each_tape" = "NONE" ];then
    echo "No pending tape requests found."
  elif [ -z "$each_tape" ];then
    $loggerbin -p info "CREATE TICKET FOR SE - Script $script was unable to determine if there are any pending tape requests.  Variable \$each_tape was null."
  else
    echo "NetBackup is requesting tape number $each_tape.  Please put it in the appropriate drive/robot."
    $loggerbin -p info "NetBackup is requesting tape number $each_tape.  Please put it in the appropriate drive/robot."
  fi
done