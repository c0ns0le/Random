#!/bin/bash
#Description: Bash script to check if a file has been modified in X hours.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.2
#Revision Date: 5-26-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o noclobber
shopt -s -o nounset

datebin="/bin/date"
lsbin="/bin/ls"
awkbin="/usr/bin/awk"
loggerbin="/usr/bin/logger"

#File whos timestamp we are testing.
#filetotest="/var/log/noc-prddata-monitor.log"
filetotest="/usr/share/icons/hicolor/48x48/actions/presence_online.png"

#When will alerts be thrown?  6 means an alert will be thrown at 6 hours.
maxhours="2"

#Get the current hour and timestamp hour.
curhour=$($datebin +%H)
filemodhour=$($lsbin -l --time-style=+%H $filetotest | $awkbin '{print $6}')

#Get the current day and timestamp day.
curdate=$($datebin +%j)
filemoddate=$($lsbin -l --time-style=+%j $filetotest | $awkbin '{print $6}')

#Get the current year and timestamp year.
curyear=$($datebin +%Y)
filemodyear=$($lsbin -l --time-style=+%Y $filetotest | $awkbin '{print $6}')

#Handle year roll-overs and leap years.
yeardiff=$(($curyear - $filemodyear))
if [ "$(($curyear % 400))" = "0" ]; then
  curdate=$(($yeardiff*366+$curdate))
elif [ "$(($curyear % 4))" = "0" ]; then
  if [ "$(($curyear % 100))" != "0" ]; then
    curdate=$(($yeardiff*366+$curdate))
  else
    curdate=$(($yeardiff*365+$curdate))
  fi
else
  curdate=$(($yeardiff*365+$curdate))
fi

#Calculate the difference in hours if days are different.
datediff=$(($curdate-$filemoddate))
curhour=$(($datediff*24+$curhour))

#Find the difference in time.
hourdiff=$(($curhour - $filemodhour))

#Has it been too long? 
if [ "$hourdiff" -ge "$maxhours" ];then                 
  echo "CREATE TICKET - File $filetotest has not been modified in $hourdiff hours!"   
  $loggerbin -p crit "CREATE TICKET - File $filetotest has not been modified in $hourdiff hours!"    
else
  echo "File $filetotest has an acceptable timestamp."
#  $loggerbin -p info "File $filetotest has an acceptable timestamp."
fi