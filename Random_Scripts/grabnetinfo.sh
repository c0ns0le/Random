#!/bin/bash
#Description: Bash script to grab network information in intervals via cron.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.1
#Revision Date: 3-29-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

INTERFACES=( "eth0" "eth4" )
OUTDIR="/home/jaw171/interfacetstats"
DATE="date +%m-%d-%Y"
TIME="date +%H-%M-%S"

mkdir -p $OUTDIR

for EACHINTERFACE in "${INTERFACES[@]}"; do
  CURDATE=$($CURDATE)
  CURTIME=$($CURTIME)
  /sbin/ifconfig $EACHINTERFACE > $OUTDIR/$EACHINTERFACE_$CURDATE-$CURTIME
done
