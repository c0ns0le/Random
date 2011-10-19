#!/bin/bash
#Description: Bash script to expire tapes.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.4
#Revision Date: 5-31-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

# # Let's say you have a list of tapes in a file called /var/tmp/tapes1.txt:
# # 2568
# # 1468
# # 1358
# # ...and so on
# # 
# # First, we need to put a 00 before each tape number:
# # cat /var/tmp/tapes1.txt | while read -r eachtape;do echo 00$eachtape;done > /var/tmp/tapes2.txt
# # 
# # The file /var/tmp/tapes2.txt is now our "to do" list.
# # 
# # Go ahead and clear out the log files from last time:
# # rm -f /var/tmp/expiretapes/*
# # 
# # Now we are ready to start expiring:
# # /usr/local/bin/expiretapes.sh /var/tmp/tapes2.txt
# # 
# # This will ask how many tapes you want to do from the list and where to start in the list.  Above 75 at a time appears to cause high CPU usage.  
# #+If you tell it to do 75 tapes start at line 0 then the script will take the first 75 rows (lines) of the file and expire them all at once.  
# #+It will create a log file at /var/tmp/expiretapes/$tapenumber with the output of that particular tape.  
# #+These files usually either end up saying that it was successful or the same failure it always gets about not being in the EMM database.
# # 
# # The script will also output the name of the main log file.  This is the one we care about.  Watch the file and wait for all tapes to be done, it takes a while and will be blank until the tapes are done.
# # tail -f /var/tmp/expiretapes/expiretapes.log.1234
# # 
# # When you see entries in that, you can verify they are all done by seeing how many lines are in the log:
# # cat /var/tmp/expiretapes/expiretapes.log.1234 | wc -l
# # 
# # If you told the script to do 75 tapes and that shows 75, then this expire run is done.
# # 
# # Now note which tapes have failed, we will deal with them later.
# # nawk '/failed/ {print $1}' /var/tmp/expiretapes/expiretapes.log.1234  >> /var/tmp/tapesfailed.txt
# #+This print out the failed tape numbers into the file tapesfailed.txt.
# # 
# # Run the script again and repeat the above process.
# # 
# # Now once you are done, we need to check on those failed tapes.  Let's get a list of tapes which are not in the scratch pool out of those failed ones.
# # cat /var/tmp/tapesfailed.txt | while read -r eachtape;do /usr/openv/netbackup/bin/admincmd/nbemmcmd -listmedia -mediaid $eachtape | nawk -v eachtape=$eachtape '/Volume Pool/&&!/Scratch/ {print eachtape ":" $0}';done
# # 
# # This will print out a list of tape numbers and what Volume Pool they are in, if they are not in the scratch pool.  If they are in a different pool then you will have to see if they are in use or not.  Sometimes when the script says a tape failed, it's because something else expired the tape before we got to it.  NetBackup then could already be using that tape so we must ensure nothing is using it before we try to expire it again.  If a failed tape is not in the in the scratch pool, investigate if it is already re-used or what happened:
# # /usr/openv/netbackup/bin/admincmd/nbemmcmd -listmedia -mediaid 004321

logdir=/var/tmp/expiretapes
mainlog=$logdir/expiretapes.log.$$
tapelist="$1" #This file should have a list of tape numbers to expire, one per line, nothing else in the file.

#Were we called with an argument?
if [ -z "$1" ]; then
  echo "Error $LINENO - You must include a file containing the tape numbers to expire as an argument. EXITING"
  exit 2
elif [ -n "$2" ]; then
  echo "Error $LINENO - You must only include ONE file as an argument. EXITING"
  exit 2
fi

if [ ! -d $logdir ];then
  mkdir -p $logdir
fi

if [ ! -f $tapelist ];then
  echo "ERROR - The file $tapelist does not exist."
  exit 1
fi

: > $mainlog

read -p "How many tapes should I expire at once in this run? " numtapestoexpire
read -p "What line number in the file should I start at? " numlinetostarton

numlinetostopon=$(($numlinetostarton+$numtapestoexpire))

echo "Expiring $numtapestoexpire tapes on lines $numlinetostarton to $(($numlinetostopon-1))."

#Loop for each tape number, put the tape number and the associated pid into a file.
nawk -v numlinetostarton=$numlinetostarton -v numlinetostopon=$numlinetostopon '(NR>=numlinetostarton)&&(NR<numlinetostopon) {print $1}' $tapelist | while read -r eachtape;do
  echo "Expiring: $eachtape"
  /usr/openv/netbackup/bin/admincmd/bpexpdate -ev $eachtape -d 0 -force 2>$logdir/$eachtape && echo "$eachtape success" 1>>$mainlog || echo "$eachtape failed" 1>>$mainlog &
done

echo "Expires are running, check the log: $mainlog"