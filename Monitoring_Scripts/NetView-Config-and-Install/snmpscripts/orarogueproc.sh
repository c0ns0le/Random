#!/bin/bash

#Description: Bash script to check for new Oracle processes.
#Written By: Jeff White (jaw171@pitt.edu) of The University of Pittsburgh
#Version Number: 0.2
#Revision Date: 7-19-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

knownoraproclistfile="/usr/local/etc/knownoraprocs.lst" #List the known process names one per line in this file.
psbin="/bin/ps"
grepbin="/bin/grep"
awkbin="/bin/awk"
sortbin="/bin/sort"
uniqbin="/usr/bin/uniq"
mailxbin="/bin/mailx"

if [ ! -f $knownoraproclistfile ];then
  echo "ERROR - File $knownoraproclistfile does not exist."
  exit 1
fi

#Loop through each ora* process and see if it the name exists on the file of know Oracle procs.
$psbin aux | $awkbin '$11 ~ /^ora/ { print $11 }' | $sortbin | $uniqbin | while read -r eachcurrentoraprocname;do
$grepbin "$eachcurrentoraprocname" $knownoraproclistfile &>/dev/null
if [ "$?" != "0" ];then
  #Adding the process name to the file here means we only get one alert, not one every time the script runs.
  echo "Found new Oracle process $eachcurrentoraprocname on $HOSTNAME" >> $knownoraproclistfile
  echo "Found new Oracle process $eachcurrentoraprocname on $HOSTNAME" | mailx -s "New Oracle process found on $HOSTNAME" jaw171@pitt.edu
fi
done

# Check for "rogue" (unknown) Oracle processes - by jaw171 on 7-19-11
#30 * * * * /usr/local/bin/oraclerogueprocesschecker.sh  > /dev/null 2>&1
#