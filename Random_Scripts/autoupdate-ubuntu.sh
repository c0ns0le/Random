#!/bin/bash
shopt -s -o noclobber
shopt -s -o nounset
# Description: Bash script to automatically update packages using aptitude.
# Written By: Jeff White (jwhite530@gmail.com)
# Version Number: 0.1
# Revision Date: 8-15-2010
# License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
# # This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

LOGDIR="/var/log/update" #No trailing slash!
LOG=autoupdate-$(date +%Y-%m-%d).log #Just the file name, no path.
LINBOXLST=( "indigo" "cyan" )
SSHUSER=backupuser
SSHPORT=22
HOLDPKGLSTDEF="linux-backports-modules-`uname -r` linux-backports-modules-headers-`cat /etc/lsb-release | awk -F'=' '/CODENAME/ { print $2 }'`-generic \
linux-backports-modules-headers-`cat /etc/lsb-release | awk -F'=' '/CODENAME/ { print $2 }'`-server linux-backports-modules-wireless-`cat /etc/lsb-release | awk -F'=' '/CODENAME/ { print $2 }'`-generic \
linux-backports-modules-wireless-`cat /etc/lsb-release | awk -F'=' '/CODENAME/ { print $2 }'`-server linux-generic linux-headers linux-headers-2.6 linux-headers-`uname -r` linux-headers-virtual \
linux-headers-server linux-headers-generic linux-headers-`uname -r | awk -F'-' '{ print $1 "-" $2 }'` linux-headers-lbm linux-headers-lbm-`uname -r` linux-image linux-image-2.6 linux-image-`uname -r` \
linux-image-386 linux-image-ec2 linux-image-generic linux-image-itanium linux-image-mckinley linux-image-rt linux-image-server linux-image-ume linux-image-virtual linux-image-xen linux-kernel-headers \
linux-kernel-headers linux-kernel-headers linux-kernel-headers-`uname -r`"
HOLDPKGLSTINDIGO="$HOLDPKGLSTDEF google-chrome-unstable firefox firefox-branding"
EMAIL=jwhite530.auto@gmail.com

# You shouldn't need to change these.
OPTSTRING=':amnh'
AUTOUPDATE=0;MANUALUPDATE=0;EMAILNOTIFY=0;LINCLIENTGO=0
TIME='date +%r'

function funcdetailstats {
  FATALERRNUM=$(grep -c "FATAL ERROR" $LOGDIR/$LOG)
  ERRNUM=$(grep -c "ERROR" $LOGDIR/$LOG)
  ERRTEXT=$(grep "ERROR" $LOGDIR/$LOG)
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo "# Hostname: $(hostname)"
  echo "# Script name: ${0##*/}"
  echo "# Script location: $(dirname $0)"
  echo "# Runtime: $(date)"
  echo "# Client list: $LINBOXLST"
}
function funcemailstats {
  if [ "$ERRNUM" = 0 ]; then # Check for fatal errors and exit if exists.
    funcdetailstats|mail -s "Backup ${0# # */} on $HOSTNAME completed successfully." $EMAIL
  elif [ "$FATALERRNUM" != 0 ]; then
    funcdetailstats|mail -s "Backup ${0# # */} on $HOSTNAME failed with a FATAL ERROR." $EMAIL
  elif [ "$ERRNUM" = 1 ]; then
    funcdetailstats|mail -s "Backup ${0# # */} on $HOSTNAME failed with 1 error." $EMAIL
  else
    funcdetailstats|mail -s "Backup ${0# # */} on $HOSTNAME failed with $ERRNUM errors." $EMAIL
  fi 
}
function funcshowstats {
  if [ "$EMAILNOTIFYOPT" = 0 ]; then
    funcdetailstats|tee -a $LOGDIR/$LOG
  elif [ "$EMAILNOTIFYOPT" = 1 ]; then
    funcdetailstats|tee -a $LOGDIR/$LOG
    funcdetailstats|funcemailstats
  fi
}

# Create the log directory if needed and always make sure owndership and perms are correct.
if [ ! -d $LOGDIR ];then
  mkdir $LOGDIR || echo "# ERROR - $LINENO - Unable to create log directory: $LOGDIR" | tee -a $LOGDIR/$LOG
fi
chown white:admin -R $LOGDIR || echo "# ERROR - $LINENO - Unable to change ownership on log directory: $LOGDIR" | tee -a $LOGDIR/$LOG
chmod 770 $LOGDIR || echo "# ERROR - $LINENO - Unable to change permissions on log directory: $LOGDIR" | tee -a $LOGDIR/$LOG

# Rotate any existing log files.
for LINCLIENT in "${LINBOXLST[@]}";do
  CLIENTLOG="$LINCLIENT-$LOG"
  if [ -f $LOGDIR/$CLIENTLOG ];then #Only continue if a log with this name already exists.
    NUMOLDLOG=$(ls $LOGDIR | grep -c ^$CLIENTLOG-) #Count the number of existing old logs.
    while (( $NUMOLDLOG > 0 ));do #If there are old logs remaining...
      mv $LOGDIR/$CLIENTLOG-$NUMOLDLOG $LOGDIR/$CLIENTLOG-$(( $NUMOLDLOG + 1 )) || echo "#ERROR - $LINENO - Unable to rotate old log: $LOGDIR/$CLIENTLOG." #Rename log-1 to log-2.
      NUMOLDLOG=$(( $NUMOLDLOG - 1 )) #Now there is one less old log.
    done
    mv $LOGDIR/$CLIENTLOG $LOGDIR/$CLIENTLOG-1 || echo "#ERROR - $LINENO - Unable to rotate log: $LOGDIR/$CLIENTLOG." #Rename the current log: log to log-1
  fi #Done, no log named $LOG should exist.
done
if [ -f $LOGDIR/$LOG ];then #Only continue if a log with this name already exists.
  NUMOLDLOG=$(ls $LOGDIR | grep -c ^$LOG-) #Count the number of existing old logs.
  while (( $NUMOLDLOG > 0 ));do #If there are old logs remaining...
    mv $LOGDIR/$LOG-$NUMOLDLOG $LOGDIR/$LOG-$(( $NUMOLDLOG + 1 )) || echo "#ERROR - $LINENO - Unable to rotate old log: $LOGDIR/$LOG." #Rename log-1 to log-2.
    NUMOLDLOG=$(( $NUMOLDLOG - 1 )) #Now there is one less old log.
  done
  mv $LOGDIR/$LOG $LOGDIR/$LOG-1 || echo "#ERROR - $LINENO - Unable to rotate log: $LOGDIR/$LOG." #Rename the current log: log to log-1
fi #Done, no log named $LOG should exist.

echo "# $($TIME) - Checking the sanity of script." | tee -a $LOGDIR/$LOG
if [ -z .$BASH. ]; then
  echo "# FATAL ERROR - $LINENO - Please run this script with the BASH shell.  EXITING" | tee -a $LOGDIR/$LOG
  exit 192
elif [ ! -w $LOGDIR ]; then
  echo "# FATAL ERROR - $LINENO - Log directory is not wirtable: $LOGDIR.  EXITING" | tee -a $LOGDIR/$LOG
  exit 1
fi

while getopts "$OPTSTRING" OPT; do
  case $OPT in
    a)
      if [ "$MANUALUPDATE" = "1" ];then
	echo "FATAL ERROR - $LINENO - It appears you turned manual update mode on with the -m option.  I can't be manual and automatic at the same time!  EXITING" | tee -a $LOGDIR/$LOG
	exit 1
      else
	AUTOUPDATE=1
      fi ;;
    m)
      if [ "$AUTOUPDATE" = "1" ];then
	echo "FATAL ERROR - $LINENO - It appears you turned automatic update mode on with the -a option.  I can't be manual and automatic at the same time!  EXITING" | tee -a $LOGDIR/$LOG
	exit 1
      else
	MANUALUPDATE=1
      fi ;;
    n)
      EMAILNOTIFY=1 ;;
    h)
      printf "By default this script checks for updates on remote systems via SSH and aptitude.\nThis script will NOT update any packages unless you give it the option to do so.-a : Enables automatic \
updating\n-m : Enables the manual updating\n-n : Enables E-mail notifications\n-h : Shows this help" | tee -a $LOGDIR/$LOG
      exit 0 ;;
    *)
      echo "FATAL ERROR: Invalid option $OPTARG (Use -h for help)" | tee -a $LOGDIR/$LOG
      exit 192 ;;
  esac
done

for LINCLIENT in "${LINBOXLST[@]}";do
  CLIENTLOG=/var/log/update/$LINCLIENT-$(date +%Y-%m-%d).log
  echo "# $($TIME) - Starting work on $LINCLIENT" | tee -a $LOG
  echo "# A list of packages to be updated will be in $CLIENTLOG" | tee -a $LOG
  if [ "$LINCLIENT" = "indigo" ]; then
    echo "# List of packages to be held back: $HOLDPKGLSTINDIGO" | tee -a $LOG
  else
    echo "# List of packages to be held back: $HOLDPKGLSTDEF" | tee -a $LOG
  fi
  if ssh $SSHUSER@$LINCLIENT -p $SSHPORT : &>> $LOG; then # Verify SSH works on all Linux clients
    LINCLIENTGO=1
  else 
    echo "ERROR - $LINENO - SSH to $LINCLIENT failed.  Skipping client." | tee -a $LOG
    LINCLIENTGO=0
  fi
  if [ "$LINCLIENTGO" = "1" ];then
    ssh $SSHUSER@$LINCLIENT -p $SSHPORT "{
      echo "# Setting packages to hold back on $LINCLIENT"
      if [ "$LINCLIENT" = "indigo" ]; then
	sudo aptitude hold $HOLDPKGLSTINDIGO || (echo "# ERROR - $LINENO - Unable to hold back packages on $LINCLIENT, skipping client."; exit 1)
      else
	sudo aptitude hold $HOLDPKGLSTDEF || (echo "# ERROR - $LINENO - Unable to hold back packages on $LINCLIENT, skipping client."; exit 1)
      fi
      echo "# Updating list of available packages on $LINCLIENT"
      sudo aptitude update || echo "# ERROR - $LINENO - Unable to update the list of updated packages on $LINCLIENT."
      echo "# Removing/cleaning unneeded packages on $LINCLIENT"
      sudo aptitude autoclean || echo "# ERROR - $LINENO - Unable clean/remove unneeded packages on $LINCLIENT."
    }" &>1 | tee -a $LOG
  fi
  if [ "$LINCLIENTGO" = "1" -a "$AUTOUPDATE" = "1" ];then
    ssh $SSHUSER@$LINCLIENT -p $SSHPORT "{
      echo "# Updating packages on $LINCLIENT"
      sudo aptitude -Z --show-why --show-version --allow-untrusted --assume-yes safe-upgrade || echo "# ERROR - $LINENO - Unable update packages on $LINCLIENT."
    }" | tee -a $CLIENTLOG
  elif [ "$LINCLIENTGO" = "1" -a "$MANUALUPDATE" = "1" ];then
    ssh $SSHUSER@$LINCLIENT -p $SSHPORT "{
      echo "# Updating packages on $LINCLIENT"
      sudo aptitude -Z --show-why --show-version --allow-untrusted safe-upgrade || echo "# ERROR - $LINENO - Unable update packages on $LINCLIENT."
    }" | tee -a $CLIENTLOG
  elif [ "$LINCLIENTGO" = "1" ];then
    ssh $SSHUSER@$LINCLIENT -p $SSHPORT "{
      echo "# Updating packages on $LINCLIENT"
      sudo aptitude -Z --simulate --show-why --assume-yes --show-version --allow-untrusted safe-upgrade || echo "# ERROR - $LINENO - Unable update packages on $LINCLIENT."
    }" &>1 | tee -a $CLIENTLOG
  fi
done