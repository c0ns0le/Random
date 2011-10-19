#!/bin/bash

script=${0##*/}

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
EOF

if [ -z $1 ];then
  echo "The client name must be an arguement, either Jaw171.noc.pitt.edu or Jaw171b.noc.pitt.edu"
  exit 1
fi

clientname="$1"

cd ~
mkdir -p Packages
echo "$($time) - Backing up Linux OS on $clientname"
echo "$($time) - Creating package list."
dpkg --get-selections 1> ~/Packages/$(date +%m-%d-%Y)-Installed-Packages-$clientname.log
echo "$($time) - Starting rsync." 
sudo rsync -ahDHAX --stats --delete-after --progress --exclude-from=/tmp/exclude_linuxos -e "sudo -u jaw171 ssh -l white -p 4422" --rsync-path="sudo rsync" / gimpy530.dyndns.org:/media/Data/Backup/$clientname/OS