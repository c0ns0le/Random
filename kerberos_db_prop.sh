#!/bin/bash
#Description: Script to replicate the Kerberos v5 database from the master node to the slave KDCs.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.1
#Revision Date: 8-05-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o nounset

script=${0##*/}

#Define our binaries.
kdb5_utilbin="/usr/kerberos/sbin/kdb5_util"
kpropbin="/usr/kerberos/sbin/kprop"
awkbin="/bin/awk"
datebin="/bin/date"
killallbin="/usr/bin/killall"
PATH=/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin

log_file="/var/log/kerberos_db_prop.log"

#The directory we shall place our DB dumps in.
db_dump_directory="/var/kerberos/krb5kdc/kerberos_db_dumps"

#The dump file name to be used in this run.  Do not change this.
dump_file_this_run="${db_dump_directory}/$($datebin +%F)_kerberos_db.dump"

#An array of the slave KDC FQDNs.
slave_kdcs=( "afsdev-04.jealwh.local" )

function print_error_and_exit {
  echo "URGENT ALERT CALL TIER II - Kerberos DB propigation failed - $1"
  logger -p crit "URGENT ALERT CALL TIER II - Kerberos DB propigation failed - $1"
  exit 1
}

#Do we have rootly powers?
if [ $UID != 0 ]; then
  print_error_and_exit "$LINENO - Script not ran as root, ran as $UID."
fi

#Create our required directories.
mkdir -p "$db_dump_directory"

echo "### Start run of $script at $($datebin +%F_%H-%M-%S) ###" >> $log_file

exec 2>>$log_file #stderr goes to to log file.

if [ ! -d "$db_dump_directory" ];then
  print_error_and_exit "$LINENO - Required directory $db_dump_directory does not exist."
fi

#Check to see if kadmin is running, if not then we may not be the master!
$killallbin -0 kadmind
if [ $? != 0 ];then
  print_error_and_exit "$LINENO - This server is not running kadmin and may not be the master!"
fi

#Check to see if a dump fle exists.
if [ -e "$dump_file_this_run" ];then
  print_error_and_exit "$LINENO - Dump file $dump_file_this_run already exists!  Will not clobber, bailing out."
fi

#Create the dump file
$kdb5_utilbin dump "$dump_file_this_run"
if [ $? != 0 ];then
  print_error_and_exit "$LINENO - Kerberos DB dump file creation failed!"
fi

#Verify this runs dump file is non-zero
if [ ! -s "$dump_file_this_run" ];then
  print_error_and_exit "$LINENO - Dump file $dump_file_this_run does not exist or is zero in size!"
fi

#Loop through each slave KDC and try to propigate the DB to them.
for each_slave_kdc in "${slave_kdcs[@]}";do
   $kpropbin -f $dump_file_this_run $each_slave_kdc
  if [ $? != 0 ];then #Did the propigation seem to work?  No?  Panic!
    logger -p crit "CRITICAL: Slave KDC $each_slave_kdc may have an inconsistent database, remove it from the load balancer!"
    print_error_and_exit "$LINENO - kprop failed to propagate the data to slave $each_slave_kdc!"
  else #Hope kprop didn't silently fail...
    echo "Kerberos DB propigation succeeded for $each_slave_kdc at $($datebin +%F_%H-%M-%S)" | tee -a $log_file
    logger -p info "Kerberos DB propigation succeeded for $each_slave_kdc."
  fi
done

#Remove old dump files.
ls -1 -t ${db_dump_directory}/*_kerberos_db.dump | $awkbin '{ if (NR > 14) {print}}' | xargs rm -f ; [ $(echo "${PIPESTATUS[*]}" | sed 's/ //g') -eq "0" ] || print_error_and_exit "$LINENO - Unable to remove old dump file in ${db_dump_directory}."

echo "### End run of $script at $($datebin +%F_%H-%M-%S) ###" >> $log_file