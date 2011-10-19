#!/bin/bash
#Description: Bash script to print out ASM disk stats.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.1
#Revision Date: 6-1-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

if [ $USER != "grid" ];then
  echo "Error - you are not grid!"
  exit 1
fi

#Prepare the Oracle stuff.
. /pitt-local/login/.profile
oraenv +ASM4

#Print out the raw stats
/u01/app/11.2.0/grid/bin/asmcmd lsdg | egrep '^MOUNTED' > /tmp/asm.txt

#Print out the stats in the format we want
awk '{print $13":"$7":"($7-$8)}' /tmp/asm.txt > /tmp/asm2.txt

echo "Disk name:Total space:Used space" > /tmp/mailbody.txt
cat /tmp/asm2.txt >> /tmp/mailbody.txt

#Calculate the usage
echo " " >> /tmp/mailbody.txt
echo "Total space allocated: $(awk -F ':' '{ SUM += $2/1024 } END { printf "%.2f\n", SUM }' /tmp/asm2.txt) GB" >> /tmp/mailbody.txt
echo "Total space used: $(awk -F ':' '{ SUM += $3/1024 } END { printf "%.2f\n", SUM }' /tmp/asm2.txt) GB" >> /tmp/mailbody.txt

#Mail it all out
cat /tmp/mailbody.txt | mail -s "Oracle devrac SAN Stats" unix-san-stats@list.pitt.edu

rm -f /tmp/asm.txt /tmp/asm2.txt /tmp/mailbody.txt
