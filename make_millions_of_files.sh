#!/bin/bash
shopt -s -o nounset
#Description: Bash script to handle creating millions of files.
#Written By: Jeff White (jwhite530@gmail.com)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.1 - 2011-12-22 - Initial version. - Jeff White
#
#####

function randpass() { #This function came from a password generator I found on http://legroom.net/.
  # Generate a random password
  #  $1 = number of characters; defaults to 32
  #  $2 = include special characters; 1 = yes, 0 = no; defaults to 1
  [ "$2" == "0" ] && CHAR="[:alnum:]" || CHAR="[:graph:]"
    cat /dev/urandom | tr -cd "$CHAR" | head -c ${1:-32}
    echo
}

start_epoch=$(date +%s)
max_num_files="35000000"
file_size="5000" #bytes

count=0
while [ $count -lt $max_num_files ];do
  echo "Working on $count"
  if (( !($count % 1000) )) ;then #Here I create a new directory every 1000 files.
    dir="/local_data/35_million_5kb_files/$(randpass 50 0)"
    mkdir -p "$dir"
  elif [ $count = 0 ] ;then
    dir="/local_data/35_million_5kb_files/$(randpass 50 0)"
    mkdir -p "$dir"
  fi
  dd count=1 bs=$file_size if=/dev/urandom of=$dir/foo.$count 2>/dev/null
  count=$((count+1))
done

end_epoch=$(date +%s)

echo "Done, took $(($end_epoch - $start_epoch)) seconds."