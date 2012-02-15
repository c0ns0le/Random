#!/bin/bash

#Description: Bash script to load and start glusterfs on Scyld/Beowulf compute nodes.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
#Based on unlicensed work by: An unknown engineer at Penguin Computing
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

# This script is designed to be used with the GlusterFS RPMs from gluster.com version 3.2.4.
# You need to NFS export /opt/glusterfs from the headnode to the compute nodes (edit /etc/export and /etc/beowulf/fstab).

##### Revision history
#
# 0.6 - 2012-01-27 - Update for GlusterFS 3.2.5, disabled Gluster mounts. - Jeff White
# 0.5 - 2011-11-03 - Converted this to a combination of an NFS export of /opt/glusterfs and a special copy of the other files.
#
#####

script="${0##*/}"
node_number=${NODE:=${1:?"No Node Specified"}}
bpsh_bin="/usr/bin/bpsh"
bpcp_bin="/usr/bin/bpcp"

function _print-stderr-then-exit { # Usage: _print-stderr-then-exit "Some error text" exitnumber
rm -f /tmp/.glusterfsdirs.$node_number
rm -f /tmp/.glusterfsfiles.$node_number
echo "$1" 1>&2
exit $2
}

echo "Starting GlusterFS mount on node $node_number."

#Prepare what we have to move to the compute node.
cat << EOF > /tmp/.glusterfsdirs.$node_number
/etc/glusterfs
/usr/sbin
/var/log/glusterfs
/etc/ld.so.conf.d
/sbin
EOF

cat << EOF > /tmp/.glusterfsfiles.$node_number
/sbin/mount.glusterfs
/etc/glusterfs/glusterd.vol
/etc/init.d/glusterd
/etc/ld.so.conf.d/glusterfs.conf
/usr/sbin/gluster
/usr/sbin/glusterd
/usr/sbin/glusterfs
/usr/sbin/glusterfsd
EOF

#Load the fuse module on the compute node
$bpsh_bin $node_number modprobe fuse || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1
$bpsh_bin $node_number mknod -m 666 /dev/fuse c 10 229 || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1

#Create the GlusterFS dirs on the compute node
cat /tmp/.glusterfsdirs.$node_number | while read -r each_dir;do
  $bpsh_bin -n $node_number mkdir -p $each_dir || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1
done

#Copy over the GlusterFS files to the compute node
cat /tmp/.glusterfsfiles.$node_number | while read -r each_file;do
  $bpcp_bin $each_file $node_number:$each_file || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1
done

#Mount the glusterfs volume(s) on the compute node
#$bpsh_bin $node_number mkdir -p /gluster/home || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1
#$bpsh_bin $node_number /sbin/mount.glusterfs storage0-dev.cssd.pitt.edu:/vol_home -o backupvolfile-server=storage1-dev.cssd.pitt.edu /gluster/home || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1

rm -f /tmp/.glusterfsdirs.$node_number
rm -f /tmp/.glusterfsfiles.$node_number

echo "GlusterFS mount on node $node_number completed."