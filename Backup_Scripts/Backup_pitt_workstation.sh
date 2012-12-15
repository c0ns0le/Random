#!/bin/bash
#Description: Bash script to back up my workstations.
#Written By: Jeff White (jwhite530@gmail.com)
# Version: 1.1
# Last change: Switched to the same type of push Backup_Scripts/Backup-Cyan.sh has

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

script=${0##*/}
bkupdir="/media/OS_Backups"
datebin="date"
rmbin="rm"
lsbin="ls"
cpbin="cp"
mvbin="mv"
awkbin="/usr/bin/gawk"
xargsbin="xargs"
sedbin="sed"
mkdirbin="mkdir"
vboxmanagebin="/usr/bin/vboxmanage"
date="$datebin +%m-%d-%Y" #The date format to go into the log.
numdailydumpfiles="8" #Number of daily policy files or MySQL dumps to keep.
numweeklydumpfiles="5" #Number of weekly policy files or MySQL dumps to keep.
nummonthlydumpfiles="13" #Number of monthly policy files or MySQL dumps to keep.
numyearlydumpfiles="5" #Number of yearly policy files or MySQL dumps to keep.
numrunlogfiles="365" #Number of script error logs to keep.

function _printerr {
echo "$1" 1>&2
}

#Linux OS configuration
cat << EOF > /tmp/exclude_linuxos
/proc
/sys
/selinux
/mnt
/afs
/dev/shm
/media
.gvfs
.cache
Cache
cache
.truecrypt*
pub
mysql
sql
VM
.VirtualBox
tmp
Data
truecrypt1
jaw171.noc.pitt.edu
/home/jaw171/mnt
EOF

if [ "$HOSTNAME" = "jaw171.noc.pitt.edu" ];then
  linclient="jaw171.noc.pitt.edu"
elif [ "$HOSTNAME" = "jaw171b" ];then
  linclient="jaw171b.noc.pitt.edu"
else
  _printerr "ERROR - $LINENO - Unexpected local hostname, exiting."
  exit 1;
fi

echo "$($time) - Backing up Linux OS on $linclient"

echo "$($time) - Starting rsync." 
sudo rsync -ahDHAX --stats --delete-after --progress --exclude-from=/tmp/exclude_linuxos -e "ssh -i /home/jaw171/.ssh/id_rsa-backupuser -o PreferredAuthentications=publickey -l backupuser -p 4422" --rsync-path="sudo rsync" / gimpy530.dyndns.org:$bkupdir/$linclient/OS/

echo "$($time) - Cleaning up."
rm /tmp/exclude_linuxos
