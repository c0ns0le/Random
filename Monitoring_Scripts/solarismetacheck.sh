#!/bin/bash
#Description: Bash script to check the status of metadevices on Solaris.
#Written By: Peter Erisson <pen@lysator.liu.se>, 2002-01-30
#+ The original awk portion came from Peter Erisson, the original bash wrapper was written by someone at the University of Pittsburgh.
#Re-written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
#Version Number: 2.0
#Revision Date: 7-19-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o nounset

awkbin="/usr/bin/nawk"
metastatbin="/usr/sbin/metastat"
catbin="/usr/bin/cat"
loggerbin="/usr/bin/logger"
mcawkfile="/usr/local/bin/metacheck.awk"

$metastatbin | $awkbin 'BEGIN { errors=0 }
/^d.*: Mirror/ { mirrorid=$1; parse=1; nmirrors=0 }
/Submirror .*: d.*/ { if (parse==1) {submirrorno=$2 ; nmirrors++; submirrorid=$3 }}
/maintenance/ { if (parse==1) {errors++; print "WARNING (needs maintenance): Mirror", mirrorid, "[ Submirror", submirrorno, submirrorid, "]" }}
/^$/ { if (parse==1 && nmirrors < 2) { print "WARNING (configuration error): Mirror", mirrorid, "contains too few submirrors" }; parse=0 }
END { if (errors > 0) {print "Total warnings: ", errors; exit errors }}' 1>/dev/null
metastatcheckexitstat=${PIPESTATUS[*]}

if ! echo "$metastatcheckexitstat" | $awkbin '{if (/^0/) {exit 0} else {exit 1}}' ;then
  echo "ERROR - Unable to get DiskSuite status."
  $loggerbin -p crit "CREATE TICKET FOR SE - Unable to get DiskSuite status."
  exit 1
elif echo "$metastatcheckexitstat" | $awkbin '{if (/0$/) {exit 0} else {exit 1}}' ;then
  echo "DISKSUITE OK - All Mirrors are Online"
  exit 0
else 
  echo "DISKSUITE CRITICAL - Mirror(s) need maintenance"
  $loggerbin -p crit "CREATE TICKET FOR SE - Mirror(s) need maintenance."
  exit 2
fi