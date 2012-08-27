#!/bin/bash
shopt -s -o noclobber
shopt -s -o nounset
# Name: backup_chong.sh
# Description: Back up certain datastores of the Lillian Chong cluster.
# Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
# Version: 1
# Last change: Ignore rsync's exit status 24 (vanished source files)

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

script=${0##*/}
logdir="/var/log/backup_chong"
email="jaw171@pitt.edu" #E-mail used for notifications if enabled.
bkupdir="/share/backups/"
cat << EOF > /tmp/exclude_all #What to exclude from all backups
/proc
/sys
/selinux
/mnt
/afs
/tmp
/dev/shm
/media
.gvfs
.truecrypt*
EOF

#Needed binaries: If you want to trust $PATH instead, just use "foo" instead of "/path/to/foo"
rsyncbin="rsync"
sedbin="sed"
datebin="date"
xargsbin="xargs"
dirnamebin="dirname"
awkbin="/usr/bin/awk"
teebin="tee"
bcbin="bc"
grepbin="grep"
cutbin="cut"
catbin="cat"
mvbin="mv"
mkdirbin="mkdir"
rmbin="rm"
lsbin="ls"
sleepbin="sleep"
cpbin="cp"
xargsbin="xargs"

#You shouldn't need to change these
date="date +%m-%d-%Y" #The date format to go into the log.
time="date +%r" #The time format to go into the log.
startdate=$($date) #Usedn for logging
starttime=$($time) #Used for logging
btime=$($datebin -u +%s) #Used for time calculation
netcool_ticket="NOC-NETCOOL-TICKET"
netcool_alert="NOC-NETCOOL-ALERT"
OPTSTRING=":s:nvh"
PATH=/bin:/usr/bin:/sbin:/usr/sbin/:/usr/local/bin:/usr/local/sbin #Start with a known $PATH
umask 007
sourcetype=0;emailnotifyopt=0;verbosity=0;logfail=0;fatalerrnum=0;errnum=0;bytessentrcvdtotal=0;scriptcanceled=0;lockfail=0;sourcetypefail=0 #Unset variables are icky
lockdir="/tmp/${script}.lock" #This is the lock dir only is sourcetype is not specified
log="/dev/null"

function _printerr_netcoolticket {
  echo "$1" 1>&2
  logger -t "$netcool_ticket" -p err "$1"
}

function _printerr_netcoolcritalert {
  echo "$1" 1>&2
  logger -t "$netcool_alert" -p err "$1"
}

function _printerr {
  echo "$1" 1>&2
}

function _handletrap {
  scriptcanceled=1
  _printoutput
  exit 2
}

function _calctransmitteddata {
  bytessentrcvdtotal=$($awkbin -F': ' '(/bytes sent/||/bytes received/)&&(!/connection unexpectedly closed/) { SUM += $2 } END { printf "%.f\n", SUM }' $log)
  if [ "$bytessentrcvdtotal" -lt "1048576" ];then
    calcedtotalbytes=$(echo "scale=2;$bytessentrcvdtotal/1024" | $bcbin)
    unit="KB"
  elif [ "$bytessentrcvdtotal" -lt "1073741824" ];then
    calcedtotalbytes=$(echo "scale=2;$bytessentrcvdtotal/1024/1024" | $bcbin)
    unit="MB"
  elif [ "$bytessentrcvdtotal" -lt "1099511627776" ];then
    calcedtotalbytes=$(echo "scale=2;$bytessentrcvdtotal/1024/1024/1024" | $bcbin)
    unit="GB"
  elif [ "$bytessentrcvdtotal" -lt "1125899906842624" ];then
    calcedtotalbytes=$(echo "scale=2;$bytessentrcvdtotal/1024/1024/1024/1024" | $bcbin)
    unit="TB"
  fi
}

function _makeoutput {
  enddate=$($date) #Used for logging
  endtime=$($time) #Used for logging
  etime=$($datebin -u +%s) #Used for time calculation
  totalsec=$((etime - btime))
  durdays=$(($totalsec / 86400))
  durhours=$(( ($totalsec - ($durdays * 86400)) / 3600))
  durmin=$(( (($totalsec - ($durdays * 86400)) - ($durhours * 3600)) / 60))
  remsec=$(( (($totalsec - ($durdays * 86400)) - ($durhours * 3600)) - ($durmin * 60) ))
  if [ ! -w "$log" -o "$logfail" = "1" ];then
    fatalerrnum=1
    errtext="Log could not be accessed or could not be rotated: $log"
  else
    fatalerrnum=$($grepbin -c "FATAL ERROR " "$log")
    errnum=$($grepbin -c "ERROR " "$log")
    errtext=$($grepbin "ERROR " "$log")
  fi
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo "Server: $HOSTNAME"
  echo "Script name: $script"
  echo "Script location: $($dirnamebin $0)"
  if [ "$lockfail" != "1" -a "$logfail" != "1" ];then
    echo "Log: $log"
  fi
  echo "Source type: $sourcetype"
  [ "$emailnotifyopt" = "1" ] && echo "E-mail notification enabled for: $email."
  echo "Start: $startdate - $starttime"
  echo "End: $enddate - $endtime"
  echo "Duration: $durdays days, $durhours hours, $durmin minutes, $remsec seconds"
  if [ "$lockfail" != "1" -a "$logfail" != "1" ];then
    echo "Data transferred: $calcedtotalbytes $unit (excluding any transmisions that errored out and some forms of compression)"
  fi
  echo " "
  if [ "$lockfail" != "0" ]; then
    _printerr_netcoolticket "$script: Failed with a FATAL error (Cannot acquire lock, $script may already be running.  If not, remove $lockdir)."
    echo "$script: Failed with a FATAL error (Cannot acquire lock, $script may already be running.  If not, remove $lockdir)."
  elif [ "$fatalerrnum" != "0" ]; then
    _printerr_netcoolticket "$script: FATAL error: Backup $script on $HOSTNAME failed with a FATAL error."
    echo "$script: FATAL error: Backup $script on $HOSTNAME failed with a FATAL error."
    echo "$errtext"
  elif [ "$scriptcanceled" = "1" ]; then
    _printerr_netcoolticket "$script: Canceled: Backup $script on $HOSTNAME was canceled."
    echo "$script: Canceled: Backup $script on $HOSTNAME was canceled."
  elif [ "$sourcetypefail" != "0" ];then
    _printerr_netcoolticket "$script: Backup $script on $HOSTNAME failed.  Source type was not specified or invalid"
    echo "$script: Backup $script on $HOSTNAME failed.  Source type was not specified or invalid"
  elif [ "$errnum" = "0" ]; then
    logger -t "$script" "Success: Backup $script on $HOSTNAME completed successfully."
    echo "Completed successfully!"
  else
    _printerr_netcoolticket "$script: Errors: Backup $script on $HOSTNAME failed with $errnum errors."
    echo  "$script: Errors: Backup $script on $HOSTNAME failed with $errnum errors."
  fi
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

function _mailoutput {
  if [ ! -w "$log" -o "$logfail" = "1" ];then
    fatalerrnum=1
    errtext="Logs could not be accessed."
  else
    fatalerrnum=$($grepbin -c "FATAL ERROR" "$log")
    errnum=$($grepbin -c "ERROR" "$log")
    errtext=$($grepbin "ERROR" "$log")
  fi
  if [ "$lockfail" != "0" ]; then
    _makeoutput|mail -s  "FATAL error: Backup $script on $HOSTNAME failed with a FATAL error (Cannot acquire lock, $script may already be running.  If not, remove $lockdir)." $email
  elif [ "$fatalerrnum" != 0 ]; then
    _makeoutput|mail -s "FATAL error: Backup $script on $HOSTNAME failed with a FATAL error." $email
  elif [ "$scriptcanceled" = "1" ]; then
    _makeoutput|mail -s "Canceled: Backup $script on $HOSTNAME was canceled." $email
  elif [ "$sourcetypefail" != "0" ];then
    _makeoutput|mail -s "Error: Backup $script on $HOSTNAME failed.  Source type was not specified or invalid." $email
  elif [ "$errnum" = 0 ]; then
    _makeoutput|mail -s "Success: Backup $script on $HOSTNAME completed successfully." $email
  elif [ "$errnum" = 1 ]; then
    _makeoutput|mail -s "Error: Backup $script on $HOSTNAME failed with 1 error." $email
  else
    _makeoutput|mail -s "Errors: Backup $script on $HOSTNAME failed with $errnum errors." $email
  fi 
}

function _printoutput {
  if [ "$emailnotifyopt" != 1 -a "$lockfail" = "1" ]; then
    _makeoutput
  elif [ "$emailnotifyopt" = 1 -a "$lockfail" = "1" ]; then
    _makeoutput | _mailoutput
    _makeoutput
  elif [ "$emailnotifyopt" != 1 -a "$logfail" = "1" ]; then
    _makeoutput
  elif [ "$emailnotifyopt" = 1 -a "$logfail" = "1" ]; then
    _makeoutput | _mailoutput
    _makeoutput
  elif [ "$emailnotifyopt" != 1 -a "$lockfail" != "1" ]; then
    _calctransmitteddata
    _makeoutput | $teebin -a $log
  elif [ "$emailnotifyopt" = 1 -a "$lockfail" != "1" ]; then
    _calctransmitteddata
    _makeoutput | _mailoutput
    _makeoutput | $teebin -a $log
  fi
  if [ "$lockfail" != "1" ]; then
    $rmbin -rf $lockdir #Remove the lockdir when exiting, but only if this iteration of the script created it.
  fi
}

logger -t "$script" "Starting run of $script."

if [ -z .$BASH. ]; then
   _printerr "FATAL ERROR - $LINENO - Please run this script with the BASH shell.  EXITING"
  exit 192
fi

trap _handletrap 1 2 3 15 # Terminate script when receiving signal

while getopts "$OPTSTRING" opt; do
  case $opt in
    s)
      if echo "$OPTARG" | egrep '^-' >/dev/null;then
        _printerr "Invalid option, use -h for help"
        exit 1
      fi
      sourcetype="$OPTARG"
      lockdir="/tmp/${script}_${sourcetype}.lock"
      log="$logdir/${sourcetype}_$($datebin +%Y-%m-%d)-$script.log" ;;
    h)
      $catbin << EOF
Usage: $script { -s sourcetype-n -v -h}
-s : Source type (Required, one of the following)
  home
  archive
  apps
  ltc1-root
-n : Enables E-mail notifications
-v : Enables verbosity (stderr prints to the console, stdout still goes to the log)
-h : Shows this help
EOF
      exit 0 ;;
    v)
      verbosity=1 ;;
    n)
      emailnotifyopt=1 ;;
    \?)
      _printerr "FATAL ERROR: Invalid option \"$OPTARG\" (Use -h for help)"
      exit 192 ;;
  esac
done

if $mkdirbin "$lockdir" &> /dev/null;then
  echo "$($time) - Successfully acquired lock: $lockdir"
else
  _printerr "FATAL ERROR - $LINENO - Cannot acquire lock, $script may already be running.  If not, remove $lockdir."
  lockfail=1
  _printoutput
  exit 1
fi

if [ -f "$log" ];then #Rotate logs
  numoldbak=$($lsbin $log* | $grepbin -c $log-*'[1-9]')
  while (( $numoldbak > 0 ));do
    $mvbin "$log-$numoldbak" "$log-$(( $numoldbak + 1 ))"
    if [ $? != 0 ];then
      _printerr "ERROR - $LINENO - Unable to rotate old rotation of $log."
      logfail=1
      _printoutput
      exit 1
    fi
    numoldbak=$(( $numoldbak - 1 ))
  done
  $mvbin "$log" "${log}-1"
  if [ $? != 0 ];then
    _printerr "ERROR - $LINENO - Unable to rotate $log."
    logfail=1
    _printoutput
    exit 1
  fi
fi

echo "$($date) - $($time) - Starting run of $script.  Additional details at the end of the log." | $teebin -a $log
echo "$($time) - Checking sanity" 1>>$log

if [ ! -w "$logdir" ]; then
  _printerr "FATAL ERROR - $LINENO - Log directory not writable or could not be created.  EXITING"
  logfail=1
  _printoutput
  exit 1
fi

if [ "$verbosity" = "0" ];then
  exec 2>>$log #All errors go to the log from now on.
fi

echo "$($time) - Environment is sane, starting backup." | $teebin -a $log
echo "$($time) - Source type of this run is $sourcetype." | $teebin -a $log

case "$sourcetype" in
  home)
    rsync -a --delete-before --stats /raid/home /share/backups >>$log
    status=$?
    if [ $status != 0 -a $status != 24 ];then
      _printerr "ERROR - $LINENO - rsync backup of /raid/home failed."
    fi
  ;;
  archive)
    rsync -a --delete-before --stats --progress /raid/archive /share/backups/ >>$log
    status=$?
    if [ $status != 0 -a $status != 24 ];then
      _printerr "ERROR - $LINENO - rsync backup of /raid/archive failed."
    fi
  ;;
  apps)
    rsync -a --delete-before --stats /export/apps /share/backups/ >>$log
    status=$?
    if [ $status != 0 -a $status != 24 ];then
      _printerr "ERROR - $LINENO - rsync backup of /raid/apps failed."
    fi
  ;;
  ltc1-root)
    rsync -a --delete-before --one-file-system --stats / /share/backups/ltc1-root/ >>$log
    status=$?
    if [ $status != 0 -a $status != 24 ];then
      _printerr "ERROR - $LINENO - rsync backup of ltc1-root failed."
    fi
  ;;
  *)
    sourcetypefail="1"
    _printerr "ERROR - $LINENO - Source type not specified or invalid.  Use -h for help."
  ;;
esac

echo "$($time) - Cleaning up." | $teebin -a $log
$rmbin -f /tmp/exclude_all

_printoutput