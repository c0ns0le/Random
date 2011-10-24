#!/bin/bash
#Description: Bash script to rsync files between cluster headnodes.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 1.0
#Revision Date: 10-22-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

script="${0##*/}"
logfile="/var/log/beorsync.log"
lockdir="/tmp/.$script-lock"
rsyncbin="/usr/bin/rsync"
sshbin="/usr/bin/ssh"
rsyncoptions="-ah --stats --exclude netcool"
fileslist="/etc/beowulf/beorsyncfiles"
beoservpid=$(pgrep beoserv)
bpmasterpid=$(pgrep bpmaster)
recvstatspid=$(pgrep recvstats)

function _removelock_printstderr_exit { #Usage: _removelock_printstderr_exit "Some error text." exitnum
rm -rf $lockdir
logger -p crit "CREATE TICKET FOR SE - $1"
echo "$1" 1>&2
exit $2
}

function _removelock_prinstdout_exit { #Usage: _removelock_prinstdout_exit "Some error text." exitnum
rm -rf $lockdir
logger -p info "$1"
echo "$1"
exit $2
}

if mkdir "$lockdir" &> /dev/null;then
  echo "Successfully acquired lock: $lockdir" >> $logfile
  echo "$BASHPID" > $lockdir/pid
else
  echo "FATAL ERROR - $LINENO - Cannot acquire lock, $script may already be running.  If not, remove $lockdir."
  logger -p crit "CREATE TICKET FOR SE - Beorsync skipped - Cannot acquire lock, $script may already be running."
  exit 1
fi

#exec 2>> $logfile #All errors go to the log from now on.  Comment this out to print them to the screen.

echo "$script initiated." | tee -a $logfile

if [ "$HOSTNAME" = "headnode0.frank.sam.pitt.edu" ];then
  passivenode="headnode1.frank.sam.pitt.edu"
elif [ "$HOSTNAME" = "headnode1.frank.sam.pitt.edu" ];then
  passivenode="headnode0.frank.sam.pitt.edu"
else
  _removelock_printstderr_exit "ERROR - $LINENO - Unable to determine if this script is running on the active headnode." 1
fi

if ssh $passivenode : 1> /dev/null 2>>$logfile;then
  passivenodebeoservpid=$(ssh $passivenode "pgrep beoserv")
  passivenodebpmasterpid=$(ssh $passivenode "pgrep bpmaster")
  passivenoderecvstatspid=$(ssh $passivenode "pgrep recvstats")
else
  _removelock_printstderr_exit "Beorsync skipped - Unable to SSH to $passivenode." 1
fi

if [ -z "$beoservpid" -o -z "$bpmasterpid" -o -z "$recvstatspid" -o -n "$passivenodebeoservpid" -o -n "$passivenodebpmasterpid" -o -n "$passivenoderecvstatspid" ];then
  _removelock_prinstdout_exit "Beorsync skipped - A beowulf process is not running on this node or is running on $passivenode." 0
fi

cat "$fileslist" | while read -r each;do
  echo "Starting rsync of $each." | tee -a $logfile
  $rsyncbin $rsyncoptions -e "$sshbin -i /root/.ssh/id_rsa" $each $passivenode:$each | tee -a $logfile
  if [ "$?" != "0" ];then 
     _removelock_printstderr_exit "Beorsync of $each to the passive node failed, skipping any remaining files/dirs." 1
  else
    echo "$(date) - Beosync of $each to $passivenode was successful." | tee -a $logfile
    logger -p info "Beosync of $each to $passivenode was successful."
  fi
done
#We do /opt seperately since it has the need for --delete-before
 echo "Starting rsync of /opt/." 1>> $logfile
$rsyncbin $rsyncoptions --delete-before --exclude pkg -e "$sshbin -i /root/.ssh/id_rsa" /opt/ $passivenode:/opt/ | tee -a $logfile
  if [ $? != 0 ];then 
     _removelock_printstderr_exit "Beosync of /opt to $passivenode failed!" 1
  else
    echo "$(date) - Beosync of /opt/ to $passivenode was successful." | tee -a $logfile
    logger -p info "Beosync of /opt/ to $passivenode was successful."
  fi

rm -rf $lockdir
echo "$script completed." | tee -a $logfile