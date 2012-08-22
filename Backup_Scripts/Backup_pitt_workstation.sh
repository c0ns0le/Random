#!/bin/bash
#Description: Bash script to back up my workstations.
#Written By: Jeff White (jwhite530@gmail.com)
# Version: 1.0
# Last change: Updated for a new hostname, added my SSHFS mount point to the exclude list

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

script=${0##*/}
bkupdir="/media/Data/Backup"
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
  linclient="Jaw171.noc.pitt.edu"
elif [ "$HOSTNAME" = "jaw171b.noc.pitt.edu" ];then
  linclient="Jaw171b.noc.pitt.edu"
else
  _printerr "ERROR - $LINENO - Unexpected local hostname, exiting."
fi

echo "$($time) - Backing up Linux OS on $linclient"

echo "$($time) - Checking and creating required directories."
reqdir=( "$bkupdir/$linclient" "$bkupdir/$linclient/OS" "$bkupdir/$linclient/Packages" "$bkupdir/$linclient/Packages/Temp" "$bkupdir/$linclient/Packages/Daily" "$bkupdir/$linclient/Packages/Weekly" "$bkupdir/$linclient/Packages/Monthly" "$bkupdir/$linclient/Packages/Yearly" )
for eachreqdir in "${reqdir[@]}";do
  $mkdirbin -p "$eachreqdir" || _printerr "ERROR - $LINENO - Unable to create $eachreqdir."
done

echo "$($time) - Creating package list."
dpkg --get-selections 1> "${bkupdir}/${linclient}/Packages/Temp/$($date)-Installed-Packages-${linclient}.log"

echo "$($time) - Checking and rotating package list."
if [ -s $bkupdir/$linclient/Packages/Temp/$($date)-Installed-Packages-$linclient.log ];then #If the package dump exists and is non-zero in size, copy the daily and move on.
  $mvbin -f "$bkupdir/$linclient/Packages/Temp/$($date)-Installed-Packages-$linclient.log" "$bkupdir/$linclient/Packages/Daily/$($date)-Installed-Packages-$linclient.log" || _printerr "ERROR - $LINENO - Unable to copy new daily package list dump for $linclient."
  $lsbin -1 -t $bkupdir/$linclient/Packages/Daily/*-Installed-Packages-$linclient.log | $awkbin --assign=numdailydumpfiles=$numdailydumpfiles '{ if (NR > numdailydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] || _printerr "ERROR - $LINENO - Unable to remove old daily package dump list for $linclient."
  if [ $($datebin +%a) = "Sat" ];then #Copy the weekly
    $cpbin -f "$bkupdir/$linclient/Packages/Daily/$($date)-Installed-Packages-$linclient.log" "$bkupdir/$linclient/Packages/Weekly/$($date)-Installed-Packages-$linclient.log" || _printerr "ERROR - $LINENO - Unable to copy new weekly package list dump for $linclient."
    $lsbin -1 -t $bkupdir/$linclient/Packages/Weekly/*-Installed-Packages-$linclient.log | $awkbin --assign=numweeklydumpfiles=$numweeklydumpfiles '{ if (NR > numweeklydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] || _printerr "ERROR - $LINENO - Unable to remove old weekly package dump list for $linclient."
  fi
  if [ $($datebin +%d) = "01" ];then #Copy the monthly
    $cpbin -f "$bkupdir/$linclient/Packages/Daily/$($date)-Installed-Packages-$linclient.log" "$bkupdir/$linclient/Packages/Monthly/$($date)-Installed-Packages-$linclient.log" || _printerr "ERROR - $LINENO - Unable to copy new monthly package dump list for $linclient."
    $lsbin -1 -t $bkupdir/$linclient/Packages/Monthly/*-Installed-Packages-$linclient.log | $awkbin --assign=nummonthlydumpfiles=$nummonthlydumpfiles '{ if (NR > nummonthlydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] || _printerr "ERROR - $LINENO - Unable to remove old monthly package dump list for $linclient."
  fi
  if [ $($datebin +%j) = "001" ];then #Copy the yearly
    $cpbin -f "$bkupdir/$linclient/Packages/Daily/$($date)-Installed-Packages-$linclient.log" "$bkupdir/$linclient/Packages/Yearly/$($date)-Installed-Packages-$linclient.log" || _printerr "ERROR - $LINENO - Unable to copy new yearly package dump list for $linclient."
    $lsbin -1 -t "$bkupdir/$linclient/Packages/Yearly/*-Installed-Packages-$linclient.log" | $awkbin --assign=numyearlydumpfiles=$numyearlydumpfiles '{ if (NR > numyearlydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] || _printerr "ERROR - $LINENO - Unable to remove old yearly package dump list for $linclient."
  fi
else
  _printerr "ERROR - $LINENO - Package list of $linclient failed (zero length backup file or it doesn't exist), keeping old list (if one exist)."
fi

echo "$($time) - Starting rsync." 
sudo rsync -ahDHAX --stats --delete-after --progress --exclude-from=/tmp/exclude_linuxos -e "sudo -u jaw171 ssh -l white -p 4422" --rsync-path="sudo rsync" / gimpy530.dyndns.org:/media/Data/Backup/$linclient/OS

echo "$($time) - Cleaning up."
rm /tmp/exclude_linuxos