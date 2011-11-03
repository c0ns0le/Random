#!/bin/bash
#Description: Bash script to check if the Gold daemon is running.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

##### Revision history
#
# Version 0.1 - 2011-03-11 - Initial version. - Jeff White
#
#####

beoservpid=$(pgrep beoserv)                                                                                                                                                         
bpmasterpid=$(pgrep bpmaster | head -1)                                                                                                                                                       
recvstatspid=$(pgrep recvstats)
golddpid=$(pgrep goldd)
glsproject="/opt/gold/2.2.0.1/bin/glsproject"

if [ -z "$beoservpid" -o -z "$bpmasterpid" -o -z "$recvstatspid" ];then
  echo "One or more of the Scyld/Beowulf processes were not found.  Assuming this is the slave headnode and skipping the goldd check."
elif [ -z "$golddpid" ];then
  echo "ERROR - $LINENO - The daemon goldd is not running.  It was not found in the process table."
  logger -p info "URGENT ALERT CALL TIER II - The daemon goldd is not running.  It was not found in the process table."
  exit 1
elif ! $glsproject>/dev/null;then
  echo "ERROR - $LINENO - The daemon goldd appears to be running but is not functional.  It was unable to print the project list."
  logger -p info "URGENT ALERT CALL TIER II - The daemon goldd appears to be running but is not functional.  It was unable to print the project list."
  exit 1
else
  echo "The daemon goldd appears to be running with a pid of $golddpid."
fi