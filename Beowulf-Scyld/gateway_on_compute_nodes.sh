#!/bin/bash
#Description: Bash script to set a network gateway on compute nodes.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
#Version Number: 0.1
#Revision Date: 9-30-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

script="${0##*/}"
node_number=${NODE:=${1:?"No Node Specified"}}
bpsh_bin="/usr/bin/bpsh"

$bpsh_bin $node_number route add default gw 10.201.0.1 eth0
if [ "$?" = "0" ];then
  echo "Successfully set network gateway on $node_number."
else
  echo "ERROR: Unable to set network gateway on $node_number."
fi