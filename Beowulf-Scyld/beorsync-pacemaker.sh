#!/bin/bash
#Description: Bash script to rsync files between cluster headnodes, the pacemaker-aware version.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.1
#Revision Date: 10-22-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

script="${0##*/}"
log_file="/var/log/beorsync-pacemaker.log"
lock_dir="/tmp/.$script-lock"
rsync_bin="/usr/bin/rsync"
ssh_bin="/usr/bin/ssh"
crm_mon_bin="/usr/sbin/crm_mon"
rsync_options="-ah --stats --exclude netcool"
required_resource="daemon_beowulf"

function _removelock_printstderr_exit { #Usage: _removelock_printstderr_exit "Some error text." errornum
rm -rf $lock_dir
logger -p crit "CREATE TICKET FOR SE - $1"
echo "$1" 1>&2
exit $2
}

function _removelock_printstdout_exit { #Usage: _removelock_prinstdout_exit "Some error text." errornum
rm -rf $lock_dir
logger -p info "$1"
echo "$1"
exit $2
}

if mkdir "$lock_dir" &> /dev/null;then
  echo "Successfully acquired lock: $lock_dir" >> $log_file
  echo "$BASHPID" > $lock_dir/pid
else
  echo "FATAL ERROR - $LINENO - Cannot acquire lock, $script may already be running.  If not, remove $lock_dir."
  logger -p crit "CREATE TICKET FOR SE - Beorsync skipped - Cannot acquire lock, $script may already be running."
  exit 1
fi

#exec 2>> $log_file #All errors go to the log from now on.  Comment this out to print them to the screen.

echo "$script initiated." | tee -a $log_file

if [ "$HOSTNAME" = "headnode0-dev.cssd.pitt.edu" ];then
  passive_node="headnode1-dev.cssd.pitt.edu"
elif [ "$HOSTNAME" = "headnode1-dev.cssd.pitt.edu" ];then
  passive_node="headnode0-dev.cssd.pitt.edu"
else
  _removelock_printstderr_exit "ERROR - $LINENO - Beorsync failed: Unable to determine if this script is running on the active headnode."
fi

if ! $crm_mon_bin -1 | grep "$required_resource" >/dev/null;then
  _removelock_printstderr_exit "ERROR - $LINENO - Beorsync failed: Unable to find the status of required resource $required_resource." 1
elif ! $crm_mon_bin -1 | grep "$required_resource" | grep "Started" >/dev/null;then
  _removelock_printstderr_exit "ERROR - $LINENO - Beorsync failed: Required resource $required_resource is not in the state 'Started'." 1
elif ! $crm_mon_bin -1 | grep "$required_resource" | grep "$HOSTNAME" >/dev/null;then
  _removelock_printstdout_exit "ERROR - $LINENO - Beorsync skipped: Required resource $required_resource is not owned by this node." 0
fi

cat << EOF >$lock_dir/files_list
/etc/hosts
/etc/fstab
/etc/resolv.conf
/etc/ntp.conf
/root/
/etc/crontab
/var/spool/cron/
/etc/beowulf/
/etc/passwd
/etc/shadow
/etc/group
/etc/syslog.conf
/etc/ldap.conf
/etc/openldap/
/etc/gshadow
/etc/nsswitch.conf
/etc/exports
/etc/services
/etc/ha.d/
/etc/corosync/
/etc/httpd/
/usr/local/bin/
/etc/ld.so.conf.d/
EOF
#/var/spool/torque/
#/etc/rc.d/init.d/pbs_server
#/etc/rc.d/init.d/pbs_server.failover
#/etc/rc.d/init.d/moab

cat "$lock_dir/files_list" | while read -r each;do
  echo "Starting rsync of $each." | tee -a $log_file
  $rsync_bin $rsync_options -e "$ssh_bin -i /root/.ssh/id_rsa" $each $passive_node:$each | tee -a $log_file
  if [ "$?" != "0" ];then 
     _removelock_printstderr_exit "Beorsync of $each to the passive node failed, skipping any remaining files/dirs."
  else
    echo "$(date) - Beosync of $each to $passive_node was successful." | tee -a $log_file
    logger -p info "Beosync of $each to $passive_node was successful."
  fi
done

#We do /opt seperately since it has the need for --delete-before
echo "Starting rsync of /opt/." 1>> $log_file
$rsync_bin $rsync_options --delete-before --exclude pkg -e "$ssh_bin -i /root/.ssh/id_rsa" /opt/ $passive_node:/opt/ | tee -a $log_file
  if [ "$?" != "0" ];then 
     _removelock_printstderr_exit "Beosync of /opt to $passive_node failed!"
  else
    echo "$(date) - Beosync of /opt/ to $passive_node was successful." | tee -a $log_file
    logger -p info "Beosync of /opt/ to $passive_node was successful."
  fi

rm -rf $lock_dir
echo "$script completed." | tee -a $log_file