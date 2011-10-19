#!/bin/bash

#Description: Bash script to check the number of messages in the mail spool.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
#Version Number: 1.0
#Revision Date: 7-19-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o nounset

threshold="100"
mailspooldir="/var/spool/clientmqueue"
findbin="/usr/bin/find"
wcbin="/usr/bin/wc"
loggerbin="/usr/bin/logger"
sedbin="/usr/bin/sed"

numberofmessages=$($findbin $mailspooldir -type f -name 'q*' | $wcbin -l | $sedbin -e 's/ //g')

if [ "$numberofmessages" -ge "$threshold" ];then
  echo "The number of messages in the mail spool exceeds threshold of $threshold"
  $loggerbin -p crit "CREATE TICKET FOR SE - The number of messages in the mail spool exceeds threshold of $threshold"
fi