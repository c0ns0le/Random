#!/bin/bash
shopt -s -o noclobber
shopt -s -o nounset

#Name: afs_migrate_volumes.sh
#Description: Bash script to move volumes to new AFS file servers.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh

##### Notes
#
# Our new servers only have one partition each so we only have to care which server a volume is moved to but not which partition
#
#####

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.1 - 2012-02-13 - Initial version. - Jeff White
#
#####

vosbin="/usr/sbin/vos"
tempdir="/tmp/afs_migrate_volumes.round2"

old_fs_servers=( "afs01-i0.srv.ns.pitt.edu" "afs02-i0.srv.ns.pitt.edu" "afs03-i0.srv.ns.pitt.edu" "afs04-i0.srv.ns.pitt.edu" "afs05-i0.srv.ns.pitt.edu" "afs06-i0.srv.ns.pitt.edu" "afs07-i0.srv.ns.pitt.edu" "afs08-i0.srv.ns.pitt.edu" "afs12-i0.srv.ns.pitt.edu" "afs13-i0.srv.ns.pitt.edu" )
new_fs_servers=( "afs-fs-01.cssd.pitt.edu" "afs-fs-02.cssd.pitt.edu" "afs-fs-03.cssd.pitt.edu" )

mkdir -p $tempdir
mkdir -p /var/tmp/afsmoves

# #Get a list of the partitions of every file server
# for each_old_server in "${old_fs_servers[@]}";do
#   echo "Getting list of partitions for $each_old_server"
#   $vosbin partinfo -server $each_old_server 2>/dev/null | awk '{print $5}' | sed 's/://g' > $tempdir/allparts_${each_old_server}
# done
# 
# #Get a list a volume in each server/partition
# for each_old_server in "${old_fs_servers[@]}";do
#   sed 's/\/vicep//g' $tempdir/allparts_${each_old_server} | while read -r each_old_partition;do
#     echo "Working on server $each_old_server parition $each_old_partition"
#     $vosbin listvol -server $each_old_server -partition $each_old_partition | awk '!/^vicep/' | sed '1d' | sed -e :a -e '$d;N;2,3ba' -e 'P;D' > $tempdir/volumes_in_${each_old_partition}_on_${each_old_server}
#   done
# done

for each_new_server in "${new_fs_servers[@]}";do
  echo "Starting on $each_new_server"
  vos_pids=""
  for each_old_server in "${old_fs_servers[@]}";do
    for each_old_partition in $(sed 's/\/vicep//g' $tempdir/allparts_${each_old_server} | tail -1);do #The tail here is just so we don't do all partitions at once
      # Sort the volumes by size (smallest first), then loop just the RW volumes matching the first regex
      count=0
      while read -r volume_to_move;do
	if [ $count -ge 1 ];then #This is how many volumes *per partition* will be moved at once
	  break
	fi
	# Move the volume and background the vos process so we can do several vos moves at once
	echo "Moving volume $volume_to_move"
	$vosbin move -id $volume_to_move -fromserver $each_old_server -frompartition $each_old_partition -toserver $each_new_server -topartition a &
 	vos_pids="$vos_pids $!"
	count=$(($count+1))
	sed --in-place=.bak "/^${volume_to_move}.*RW/d" $tempdir/volumes_in_${each_old_partition}_on_${each_old_server}
      done < <(sort -n -k2 $tempdir/volumes_in_${each_old_partition}_on_${each_old_server} | awk '/^pkg\./ && / RW / {print $1}')
    done
  done
  # Wait until all vos processes are done before moving onto the next new server
  echo "Waiting for pids $vos_pids"
  wait $vos_pids
done

echo "Done!"