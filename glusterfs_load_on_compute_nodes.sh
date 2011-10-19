#!/bin/bash

#Description: Bash script to load and start glusterfs on compute nodes.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
#Based on unlicensed work by: An unknown engineer at Penguin Computing
#Version Number: 0.2
#Revision Date: 10-3-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

script="${0##*/}"
node_number=${NODE:=${1:?"No Node Specified"}}
bpsh_bin="/usr/bin/bpsh"
bpcp_bin="/usr/bin/bpcp"

function _print-stderr-then-exit { # Usage: _print-stderr-then-exit "Some error text" exitnumber
echo "$1" 1>&2
exit $2
}

echo "Starting GlusterFS mount on node $node_number."

#Load the fuse module on the compute node
$bpsh_bin $node_number modprobe fuse || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script." 1
$bpsh_bin $node_number mknod -m 666 /dev/fuse c 10 229 || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script." 1

#Copy over the GlusterFS files to the compute node
$bpsh_bin $node_number mkdir -p /usr/local/glusterfs || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script." 1
$bpcp_bin -r /usr/local/glusterfs/ $node_number:/usr/local/glusterfs/ || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script." 1

#Mount the glusterfs volume(s) on the compute node
$bpsh_bin $node_number mkdir -p /mnt/fuse/vol_mainhome || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script." 1
$bpsh_bin $node_number /usr/local/glusterfs/sbin/mount.glusterfs gfs-dev-01.cssd.pitt.edu:/vol_mainhome /mnt/fuse/vol_mainhome -o acl -o log-file=/var/log/gluster_client.log || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script." 1

echo "GlusterFS mount on node $node_number completed."