#!/bin/bash
#Description: Bash script to archive the named zone files.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.2
#Revision Date: 6-16-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o nounset

datebin="/opt/sfw/bin/date"
loggerbin="/usr/bin/logger"
dirnamebin="/usr/bin/dirname"
basenamebin="/usr/bin/basename"
tarbin="/usr/sbin/tar"
gzipbin="/usr/bin/gzip"
mkdirbin="/usr/bin/mkdir"
awkbin="/usr/bin/nawk"
xargsbin="/usr/bin/xargs"
rmbin="/usr/bin/rm"
sedbin="/usr/bin/sed"
rsyncbin="/opt/sfw/bin/rsync"

dirtobebackedup="/usr/local/etc/namedb/" #The trailing slash is important to rsync...
backupdestdir="/named-back"
backupfilename="namedb"

#Sanity checking
if [ -z $BASH ]; then
  echo "DNS zone file archiver was not ran in BASH."
  $loggerbin -p crit "Create ticket for SE - DNS zone file archiver was not ran in BASH."
  exit 1
elif [ $UID != 0 ]; then
  echo "DNS zone file archiver was not ran as root."
  $loggerbin -p crit "Create ticket for SE - DNS zone file archiver was not ran as root."
  exit 1
fi

#Create our required directories
$mkdirbin -p $backupdestdir || _printgenericerror
if [ $? != 0 ];then
  echo "DNS zone file archiver failed to create destination directory."
  $loggerbin -p crit "Create ticket for SE - DNS zone file archiver failed to create destination directory."
  exit 1
fi

#Are the required directories there?
if [ ! -d $dirtobebackedup -o ! -d $backupdestdir ];then
  echo "DNS zone file archiver failed - Required directory does not exist."
  $loggerbin -p crit "Create ticket for SE - DNS zone file archiver failed - Required directory does not exist."
  exit 1
fi

#Use rsync to copy the directory, but not the logs.
$rsyncbin -a --exclude=log $dirtobebackedup ${backupdestdir}/${backupfilename}-$($datebin +%F)
if [ $? != 0 ];then
  echo "DNS zone file archiver failed to rsync."
  $loggerbin -p crit "Create ticket for SE - DNS zone file archiver failed to rsync."
  exit 1
fi

#If we got this far, everything should have gone well with the latest backup, so let's remove the oldest ones.
#+The 8 whould cause it to keep only the newest 7 files (ls print out a total space summary on line 1), or one weeks worth since we run daily.
ls -t $backupdestdir/${backupfilename}-* | $awkbin 'NR>8 {print}' | $xargsbin $rmbin -rf
if [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') != "000" ];then
  echo "DNS zone file archiver failed to remove old backups."
  $loggerbin -p crit "Create ticket for SE - DNS zone file archiver failed to remove old backups."
  exit 1
fi

echo "Success - $dirtobebackedup (except logs) copied to ${backupdestdir}/${backupfilename}-$($datebin +%F)"