#!/bin/bash
shopt -s -o nounset
# Description: Bash script to handle creating millions of files.
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1 (2012-5-16)
# Last change: Switching the script to create two sets of random data

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

function randstring() { #This function came from a password generator I found on http://legroom.net/.
  # Generate a random password
  #  $1 = number of characters; defaults to 32
  #  $2 = include special characters; 1 = yes, 0 = no; defaults to 1
  [ "$2" == "0" ] && CHAR="[:alnum:]" || CHAR="[:graph:]"
    cat /dev/urandom | tr -cd "$CHAR" | head -c ${1:-32}
    echo
}

mkdir -p /home/cssd/jaw171/gluster_test/

# Create 10MB files
start_epoch=$(date +%s)
max_num_files="10000"
file_size="10000000" #bytes
output_dir="/scratch/gluster_test/10MB_files"

echo "Starting to create 10MB files." >> /home/cssd/jaw171/gluster_test/$(hostname).log

count=0
while [ $count -lt $max_num_files ];do
  echo "Working on $count"
  if [ "$count" = "0" ];then
    dyndir="$output_dir/$(randstring 50 0)"
    mkdir -p "$dyndir"
  elif (( !($count % 1000) )) ;then #Here I create a new directory every 1000 files.
    dyndir="$output_dir/$(randstring 50 0)"
    mkdir -p "$dyndir"
  fi
  dd count=1 bs=$file_size if=/dev/urandom of=$dyndir/random.$count 2>/dev/null
  count=$((count+1))
done

end_epoch=$(date +%s)

echo "Done, took $(($end_epoch - $start_epoch)) seconds to make 10MB files." >> /home/cssd/jaw171/gluster_test/$(hostname).log


# Create 10KB files
start_epoch=$(date +%s)
max_num_files="1000000"
file_size="100000" #bytes
output_dir="/scratch/gluster_test/10KB_files"

echo "Starting to create 10KB files." >> /home/cssd/jaw171/gluster_test/$(hostname).log

count=0
while [ $count -lt $max_num_files ];do
  echo "Working on $count"
  if [ "$count" = "0" ];then
    dyndir="$output_dir/$(randstring 50 0)"
    mkdir -p "$dyndir"
  elif (( !($count % 1000) )) ;then #Here I create a new directory every 1000 files.
    dyndir="$output_dir/$(randstring 50 0)"
    mkdir -p "$dyndir"
  fi
  dd count=1 bs=$file_size if=/dev/urandom of=$dyndir/random.$count 2>/dev/null
  count=$((count+1))
done

end_epoch=$(date +%s)

echo "Done, took $(($end_epoch - $start_epoch)) seconds to make 10KB files." >> /home/cssd/jaw171/gluster_test/$(hostname).log