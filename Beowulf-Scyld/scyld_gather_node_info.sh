#!/bin/bash
#File Name: scyld_gather_node_info.sh
#Description: Bash script to gather system information from compute nodes.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 1.2 - 2012-03-06 - Minor cleanup. - Jeff White
# 1.1 - 2011-10-25 - Untracked changes. - Jeff White
#
#####

script="${0##*/}"
bpsh_bin="/usr/bin/bpsh"

function _print-stderr-then-exit { # Usage: _print-stderr-then-exit "Some error text" exitnumber
echo "$1" 1>&2
exit $2
}

#Were we called with an arguement?
if [ -z "$1" ];then
  _print-stderr-then-exit "Usage: $script output_file" 1
else
  output_file="$1"
fi

#How many nodes do we have?
num_nodes=$(awk '/^nodes/ {print $2}' /etc/beowulf/config)

#Prepare the output file
echo "Node,MAC #1,MAC #2,CPU Type,CPU Cores (Logical),GPU?,IB?,Scratch Disk (GB),RAM (GB),Hardware Manufacturer,Model Number,Serial Number,Ethernet IP,IB IP,BMC IP,Rack Location" >"$output_file"

#Gather the node info
node=0
while [ "$node" -lt "$num_nodes" ];do
  echo "Working on $node."
  if [ $(bpstat $node | awk '!/^Node/ {print $2}') != "up" ];then #If the node is not up, skip it.
    echo "$node,,,,,,,,,,,,,,,">>"$output_file"
    node=$(($node+1))
    continue
  fi
  #Node number
  printf "$node,">>"$output_file"
  #MAC of eth0
  bpsh n$node /sbin/ifconfig eth0 | awk '/HWaddr/ {print $5;exit}' | tr '\n' ','>>"$output_file"
  #MAC of eth1
  bpsh n$node /sbin/ifconfig eth1 | awk '/HWaddr/ {print $5;exit}' | tr '\n' ','>>"$output_file"
  #Type of CPU
  bpsh n$node awk -F': ' '/model name/ {print $2;exit}' /proc/cpuinfo | tr '\n' ','>>"$output_file"
  #Number of CPU cores
#  bpsh n$node egrep -c '^processor' /proc/cpuinfo | tr '\n' ','>>"$output_file"
  num_phys_procs=$(bpsh n$node dmidecode | grep -c 'Processor Information')
  num_siblings_proc=$(bpsh n$node awk '/siblings/ {print $3;exit}' /proc/cpuinfo)
  num_cores=$(($num_phys_procs * $num_siblings_proc))
  printf "${num_cores}," >>"$output_file"
  #GPU found?
  bpsh n$node lsmod | egrep '^nvidia' >/dev/null
  if [ "$?" = "0" ];then
    printf "1,">>"$output_file"
  else
    printf "0,">>"$output_file"
  fi
  #Infiniband found?
  bpsh n$node ifconfig -a | egrep '^ib' >/dev/null
  if [ "$?" = "0" ];then
    printf "1,">>"$output_file"
  else
    printf "0,">>"$output_file"
  fi
  #Amount of scratch disk
  if bpsh n$node df -kP | grep '/scratch'>/dev/null;then #If there is a scratch disk found...
    bpsh n$node df -kP | awk '/\/scratch/ {print $4/1024/1024;exit}' | tr '\n' ','>>"$output_file"
  else
    printf "0,">>"$output_file"
  fi
  #Amount of RAM
  bpsh n$node awk '/^MemTotal/ {print $2/1024/1024;exit}' /proc/meminfo | tr '\n' ','>>"$output_file"
  #Hardware manufacturer
  printf ",">>"$output_file"
  #Hardware model number
  printf ",">>"$output_file"
  #Serial number
  printf ",">>"$output_file"
  #Ethernet IP
  eth_ip=$(bpsh n$node ifconfig eth0 | awk '/inet addr/ {print $2}' | cut -d':' -f2)
  echo $eth_ip | tr '\n' ','>>"$output_file"
  #IB IP
  echo $eth_ip | awk -F'.' '{print $1"."$2+2"."$3"."$4}' | tr '\n' ','>>"$output_file"
  #BMC IP
  echo $eth_ip | awk -F'.' '{print $1"."$2+1"."$3"."$4}' | tr '\n' ','>>"$output_file"
  #Rack location
  echo ",">>"$output_file"
  node=$(($node+1))
done

#Print out a summary of of the cluster
echo "Nodes: $num_nodes"
echo "CPU Cores: $(awk -F ',' '{ SUM += $5 } END { printf "%.f\n", SUM }' $output_file)"
echo "RAM: $(awk -F ',' '{ SUM += $9 } END { printf "%.f\n", SUM }' $output_file)GB"
echo "Scratch Disk Space: $(awk -F ',' '{ SUM += $8 } END { printf "%.f\n", SUM }' $output_file)GB"