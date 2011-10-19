#!/bin/bash
#Description: Bash script to monitor how often messages ar being shunted by mailman.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.1
#Revision Date: 5-18-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o nounset

shuntqdir="/var/mailman/qfiles/shunt" #Where the shunted files are held.
lastknownshuntstats="/var/tmp/mmnumshuntqfiles" #Contains the last known number of shunted messages which we will compare against the current number.
shuntingthreshold="4" #How many messages we are OK with to be shunted between interval periods.
findbin="/usr/bin/find"
bcbin="/usr/bin/bc"
wcbin="/usr/bin/wc"
sedbin="/usr/bin/sed"
loggerbin="/usr/bin/logger"

#Ensure the file exists and create it otherwise.  This file must be writable by the mailman user!
if [ ! -f $lastknownshuntstats ];then
  echo "0" > $lastknownshuntstats
fi

#Find out how many shunted messages we had/have.
numoldshuntqfiles=$(cat $lastknownshuntstats)
numcurshuntqfiles=$($findbin $shuntqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')

#How much have we grown?
numnewshuntqfiles=$(echo "$numcurshuntqfiles - $numoldshuntqfiles" | $bcbin)
if [ $numnewshuntqfiles -gt $shuntingthreshold ];then
  echo "Too many shunted messages in the last monitoring interval: $numnewshuntqfiles"
  $loggerbin -p crit "URGENT ALERT CALL SE - Too many shunted messages in the last monitoring interval: $numnewshuntqfiles"
fi

echo "$numcurshuntqfiles" > $lastknownshuntstats