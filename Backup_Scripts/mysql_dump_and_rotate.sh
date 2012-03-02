#!/bin/bash
shopt -s -o noclobber
shopt -s -o nounset

#Name: mysql_dump_and_rotate.sh
#Description: Bash script to dump a MySQL database daily and keep weekly, monthly, and yearly dumps.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.1 - 2012-03-02 - Initial version. - Jeff White
#
#####

script=${0##*/}
bkupdir="/var/lib/mysql/backup"
log="/var/log/mysql_backup.log"
netcool_ticket="NOC-NETCOOL-TICKET"
netcool_alert="NOC-NETCOOL-ALERT"
mysqlsrv="$HOSTNAME" #The hostname of the MySQL server.
mysqluser=$(awk -F'=' '$1 ~ /user/ { print $2 }' /etc/mysql.cred)
mysqlpass=$(awk -F'=' '$1 ~ /pass/ { print $2 }' /etc/mysql.cred)
PATH=/bin:/usr/bin:/sbin:/usr/sbin/:/usr/local/bin:/usr/local/sbin #Start with a known $PATH
umask 007

date="date +%m-%d-%Y" #The date format to go into the log.
time="date +%r" #The time format to go into the log.

function _printerr_netcoolticket {
  echo "$1" 1>&2
  logger -t "$netcool_ticket" -p err "$1"
}
function _printerr_netcoolcritalert {
  echo "$1" 1>&2
  logger -t "$netcool_alert" -p err "$1"
}

exec 2>>$log #All errors go to the log from now on.

echo "$($time) - Backing up MySQL on $mysqlsrv - Start" | tee -a $log
logger -p info "$($time) - Backing up MySQL on $mysqlsrv - Start"

echo "$($time) - Checking and creating required directories." | tee -a $log
for eachmysqldir in "Temp" "Daily" "Weekly" "Monthly" "Yearly"; do
  if [ ! -d $bkupdir/$eachmysqldir ];then
    mkdir -p $bkupdir/$eachmysqldir 1>>$log
    if [ $? != 0 ];then
      _printerr_netcoolticket "$script: ERROR - $LINENO - Unable to create MySQL backup directory $eachmysqldir for $mysqlsrv in $bkupdir." 1>>$log
      exit 1
    fi
  fi
done

echo "$($time) - Getting database names and starting loop." | tee -a $log
echo 'show databases\g' | mysql --user="$mysqluser" --password="$mysqlpass" | sed '/^information_schema\|^Database\|lost+found/d' | while read -r eachdbname;do

  echo "Working on $eachdbname"
  dumpday=$(date +%F)
  dumptime=$(date +%H-%M-%S)

  echo "$($time) - Dumping the database." 1>>$log
  mysqldump --user="$mysqluser" --password="$mysqlpass" $eachdbname | gzip 1> $bkupdir/Temp/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr_netcoolticket "ERROR - $LINENO - Unable to back up MySQL database $eachdbname on $mysqlsrv."

  echo "$($time) - Checking and rotating the database dump." | tee -a $log

  #If the DB backup exists and is non-zero in size, copy the daily and move on.
  if [ -s $bkupdir/Temp/$eachdbname-on-$dumpday-at-$dumptime.sql.gz ];then
    echo "Total bytes received for database $eachdbname: $(ls $bkupdir/Temp/$eachdbname-on-$dumpday-at-$dumptime.sql.gz -l | cut -d' ' -f5)"
    mv $bkupdir/Temp/$eachdbname-on-$dumpday-at-$dumptime.sql.gz $bkupdir/Daily/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr_netcoolticket "$script: ERROR - $LINENO - Unable to copy new daily MySQL backup for $mysqlsrv."
    ls -1 -t $bkupdir/Daily/$eachdbname* | awk '{ if (NR > 30) {print}}' | xargs rm -f
    if [ "${PIPESTATUS[*]}" != "0 0 0" ];then
      _printerr_netcoolticket "$script: ERROR - $LINENO - Unable to remove old daily MySQL backup for $mysqlsrv."
    fi

    #Copy the weekly
    if [ $(date +%a) = "Sat" ];then
      cp $bkupdir/Daily/$eachdbname-on-$dumpday-at-$dumptime.sql.gz $bkupdir/Weekly/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr_netcoolticket "$script: ERROR - $LINENO - Unable to copy new weekly MySQL backup for $mysqlsrv."
      ls -1 -t $bkupdir/Weekly/$eachdbname* | awk '{ if (NR > 5) {print}}' | xargs rm -f
      if [ "${PIPESTATUS[*]}" = "0 0 0" ];then
	_printerr_netcoolticket "$script: ERROR - $LINENO - Unable to remove old weekly MySQL backup for $mysqlsrv."
      fi
    fi

    #Copy the monthly
    if [ $(date +%d) = "01" ];then
      cp $bkupdir/Daily/$eachdbname-on-$dumpday-at-$dumptime.sql.gz $bkupdir/Monthly/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr_netcoolticket "$script: ERROR - $LINENO - Unable to copy new monthly MySQL backup for $mysqlsrv."
      ls -1 -t $bkupdir/Monthly/$eachdbname* | awk '{ if (NR > 13) {print}}' | xargs rm -f
      if [ "${PIPESTATUS[*]}" = "0 0 0" ];then
	_printerr_netcoolticket "$script: ERROR - $LINENO - Unable to remove old monthly MySQL backup for $mysqlsrv."
      fi
    fi

    #Copy the yearly
    if [ $(date +%j) = "001" ];then
      cp $bkupdir/Daily/$eachdbname-on-$dumpday-at-$dumptime.sql.gz $bkupdir/Yearly/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr_netcoolticket "$script: ERROR - $LINENO - Unable to copy new yearly MySQL backup for $mysqlsrv."
      ls -1 -t $bkupdir/Yearly/$eachdbname* | awk '{ if (NR > 20) {print}}' | xargs rm -f
      if [ "${PIPESTATUS[*]}" = "0 0 0" ];then
	_printerr_netcoolticket "$script: ERROR - $LINENO - Unable to remove old yearly MySQL backup for $mysqlsrv."
      fi
    fi

  else
    _printerr_netcoolticket "$script: ERROR - $LINENO - Backup of DB $eachdbname failed (zero length backup file or it doesn't exist), keeping old backup (if one exist)."
  fi

done | tee -a $log

echo "$($time) - Securing the backup directory" | tee -a $log
chown -R root:root "$bkupdir" || _printerr_netcoolcritalert "$script: ERROR - $LINENO - Failed to secure the MySQL backup directory."
find "$bkupdir" -type f \! -perm 600 -exec chmod 600 "{}" \; || _printerr_netcoolcritalert "$script: ERROR - $LINENO - Failed to secure the MySQL backup directory."
find "$bkupdir" -type d \! -perm 700 -exec chmod 700 "{}" \; || _printerr_netcoolcritalert "$script: ERROR - $LINENO - Failed to secure the MySQL backup directory."

echo "$($time) - Backing up MySQL on $mysqlsrv - Complete" | tee -a $log
logger -p info "$($time) - Backing up MySQL on $mysqlsrv - Complete"