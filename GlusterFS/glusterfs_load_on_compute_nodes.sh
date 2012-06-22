#!/bin/bash

# Description: Bash script to load and start glusterfs on Scyld/Beowulf compute nodes.
# Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh
# Based on unlicensed work by: An unknown engineer at Penguin Computing
# Last change: Updating for GlusterFS 3.3, removing note about NFS export of /opt/glusterfs
# Version: 1.0

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
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

# Prepare what we have to move to the compute node.
cat << EOF > /tmp/.glusterfsdirs.$node_number
/usr/lib64/glusterfs/3.3.0/auth
/usr/lib64/glusterfs/3.3.0/rpc-transport
/usr/lib64/glusterfs/3.3.0/xlator/cluster
/usr/lib64/glusterfs/3.3.0/xlator/debug
/usr/lib64/glusterfs/3.3.0/xlator/encryption
/usr/lib64/glusterfs/3.3.0/xlator/features
/usr/lib64/glusterfs/3.3.0/xlator/mount
/usr/lib64/glusterfs/3.3.0/xlator/performance
/usr/lib64/glusterfs/3.3.0/xlator/protocol
/usr/lib64/glusterfs/3.3.0/xlator/system
/usr/lib64/glusterfs/3.3.0/xlator/testing/performance
/usr/libexec/glusterfs/python/syncdaemon
/usr/share/doc/glusterfs-3.3.0
/usr/libexec/glusterfs/gsyncd
/var/log/glusterfs
/sbin
/usr/sbin
EOF

cat << EOF > /tmp/.glusterfsfiles.$node_number
/sbin/mount.glusterfs
/sbin/umount.glusterfs
/usr/lib64/glusterfs/3.3.0/xlator/mount/fuse.so
/usr/lib64/glusterfs/3.3.0/xlator/mount/fuse.so.0
/usr/lib64/glusterfs/3.3.0/xlator/mount/fuse.so.0.0.0
/usr/lib64/glusterfs/3.3.0/auth/addr.so
/usr/lib64/glusterfs/3.3.0/auth/addr.so.0
/usr/lib64/glusterfs/3.3.0/auth/addr.so.0.0.0
/usr/lib64/glusterfs/3.3.0/auth/login.so
/usr/lib64/glusterfs/3.3.0/auth/login.so.0
/usr/lib64/glusterfs/3.3.0/auth/login.so.0.0.0
/usr/lib64/glusterfs/3.3.0/rpc-transport/socket.so
/usr/lib64/glusterfs/3.3.0/rpc-transport/socket.so.0
/usr/lib64/glusterfs/3.3.0/rpc-transport/socket.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/afr.so
/usr/lib64/glusterfs/3.3.0/xlator/cluster/afr.so.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/afr.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/dht.so
/usr/lib64/glusterfs/3.3.0/xlator/cluster/dht.so.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/dht.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/distribute.so
/usr/lib64/glusterfs/3.3.0/xlator/cluster/nufa.so
/usr/lib64/glusterfs/3.3.0/xlator/cluster/nufa.so.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/nufa.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/pump.so
/usr/lib64/glusterfs/3.3.0/xlator/cluster/pump.so.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/pump.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/replicate.so
/usr/lib64/glusterfs/3.3.0/xlator/cluster/stripe.so
/usr/lib64/glusterfs/3.3.0/xlator/cluster/stripe.so.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/stripe.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/switch.so
/usr/lib64/glusterfs/3.3.0/xlator/cluster/switch.so.0
/usr/lib64/glusterfs/3.3.0/xlator/cluster/switch.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/debug/error-gen.so
/usr/lib64/glusterfs/3.3.0/xlator/debug/error-gen.so.0
/usr/lib64/glusterfs/3.3.0/xlator/debug/error-gen.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/debug/io-stats.so
/usr/lib64/glusterfs/3.3.0/xlator/debug/io-stats.so.0
/usr/lib64/glusterfs/3.3.0/xlator/debug/io-stats.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/debug/trace.so
/usr/lib64/glusterfs/3.3.0/xlator/debug/trace.so.0
/usr/lib64/glusterfs/3.3.0/xlator/debug/trace.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/encryption/rot-13.so
/usr/lib64/glusterfs/3.3.0/xlator/encryption/rot-13.so.0
/usr/lib64/glusterfs/3.3.0/xlator/encryption/rot-13.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/features/access-control.so
/usr/lib64/glusterfs/3.3.0/xlator/features/index.so
/usr/lib64/glusterfs/3.3.0/xlator/features/index.so.0
/usr/lib64/glusterfs/3.3.0/xlator/features/index.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/features/locks.so
/usr/lib64/glusterfs/3.3.0/xlator/features/locks.so.0
/usr/lib64/glusterfs/3.3.0/xlator/features/locks.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/features/mac-compat.so
/usr/lib64/glusterfs/3.3.0/xlator/features/mac-compat.so.0
/usr/lib64/glusterfs/3.3.0/xlator/features/mac-compat.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/features/marker.so
/usr/lib64/glusterfs/3.3.0/xlator/features/marker.so.0
/usr/lib64/glusterfs/3.3.0/xlator/features/marker.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/features/quiesce.so
/usr/lib64/glusterfs/3.3.0/xlator/features/quiesce.so.0
/usr/lib64/glusterfs/3.3.0/xlator/features/quiesce.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/features/quota.so
/usr/lib64/glusterfs/3.3.0/xlator/features/quota.so.0
/usr/lib64/glusterfs/3.3.0/xlator/features/quota.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/features/read-only.so
/usr/lib64/glusterfs/3.3.0/xlator/features/read-only.so.0
/usr/lib64/glusterfs/3.3.0/xlator/features/read-only.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/features/worm.so
/usr/lib64/glusterfs/3.3.0/xlator/features/worm.so.0
/usr/lib64/glusterfs/3.3.0/xlator/features/worm.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/io-cache.so
/usr/lib64/glusterfs/3.3.0/xlator/performance/io-cache.so.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/io-cache.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/io-threads.so
/usr/lib64/glusterfs/3.3.0/xlator/performance/io-threads.so.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/io-threads.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/md-cache.so
/usr/lib64/glusterfs/3.3.0/xlator/performance/md-cache.so.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/md-cache.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/quick-read.so
/usr/lib64/glusterfs/3.3.0/xlator/performance/quick-read.so.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/quick-read.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/read-ahead.so
/usr/lib64/glusterfs/3.3.0/xlator/performance/read-ahead.so.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/read-ahead.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/stat-prefetch.so
/usr/lib64/glusterfs/3.3.0/xlator/performance/write-behind.so
/usr/lib64/glusterfs/3.3.0/xlator/performance/write-behind.so.0
/usr/lib64/glusterfs/3.3.0/xlator/performance/write-behind.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/protocol/client.so
/usr/lib64/glusterfs/3.3.0/xlator/protocol/client.so.0
/usr/lib64/glusterfs/3.3.0/xlator/protocol/client.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/system/posix-acl.so
/usr/lib64/glusterfs/3.3.0/xlator/system/posix-acl.so.0
/usr/lib64/glusterfs/3.3.0/xlator/system/posix-acl.so.0.0.0
/usr/lib64/glusterfs/3.3.0/xlator/testing/performance/symlink-cache.so
/usr/lib64/glusterfs/3.3.0/xlator/testing/performance/symlink-cache.so.0
/usr/lib64/glusterfs/3.3.0/xlator/testing/performance/symlink-cache.so.0.0.0
/usr/lib64/libgfrpc.so.0
/usr/lib64/libgfrpc.so.0.0.0
/usr/lib64/libgfxdr.so.0
/usr/lib64/libgfxdr.so.0.0.0
/usr/lib64/libglusterfs.so.0
/usr/lib64/libglusterfs.so.0.0.0
/usr/libexec/glusterfs/gsyncd
/usr/libexec/glusterfs/python/syncdaemon/README.md
/usr/libexec/glusterfs/python/syncdaemon/__init__.py
/usr/libexec/glusterfs/python/syncdaemon/__init__.pyc
/usr/libexec/glusterfs/python/syncdaemon/__init__.pyo
/usr/libexec/glusterfs/python/syncdaemon/configinterface.py
/usr/libexec/glusterfs/python/syncdaemon/configinterface.pyc
/usr/libexec/glusterfs/python/syncdaemon/configinterface.pyo
/usr/libexec/glusterfs/python/syncdaemon/gconf.py
/usr/libexec/glusterfs/python/syncdaemon/gconf.pyc
/usr/libexec/glusterfs/python/syncdaemon/gconf.pyo
/usr/libexec/glusterfs/python/syncdaemon/gsyncd.py
/usr/libexec/glusterfs/python/syncdaemon/gsyncd.pyc
/usr/libexec/glusterfs/python/syncdaemon/gsyncd.pyo
/usr/libexec/glusterfs/python/syncdaemon/ipaddr.py
/usr/libexec/glusterfs/python/syncdaemon/ipaddr.pyc
/usr/libexec/glusterfs/python/syncdaemon/ipaddr.pyo
/usr/libexec/glusterfs/python/syncdaemon/libcxattr.py
/usr/libexec/glusterfs/python/syncdaemon/libcxattr.pyc
/usr/libexec/glusterfs/python/syncdaemon/libcxattr.pyo
/usr/libexec/glusterfs/python/syncdaemon/master.py
/usr/libexec/glusterfs/python/syncdaemon/master.pyc
/usr/libexec/glusterfs/python/syncdaemon/master.pyo
/usr/libexec/glusterfs/python/syncdaemon/monitor.py
/usr/libexec/glusterfs/python/syncdaemon/monitor.pyc
/usr/libexec/glusterfs/python/syncdaemon/monitor.pyo
/usr/libexec/glusterfs/python/syncdaemon/repce.py
/usr/libexec/glusterfs/python/syncdaemon/repce.pyc
/usr/libexec/glusterfs/python/syncdaemon/repce.pyo
/usr/libexec/glusterfs/python/syncdaemon/resource.py
/usr/libexec/glusterfs/python/syncdaemon/resource.pyc
/usr/libexec/glusterfs/python/syncdaemon/resource.pyo
/usr/libexec/glusterfs/python/syncdaemon/syncdutils.py
/usr/libexec/glusterfs/python/syncdaemon/syncdutils.pyc
/usr/libexec/glusterfs/python/syncdaemon/syncdutils.pyo
/usr/sbin/glusterfs
/usr/sbin/glusterfsd
EOF

# Workaround for an error mount.glusterfs was throwing...  Credit: http://www.ducea.com/2009/02/18/linux-tips-bash-completion-devfd62-no-such-file-or-directory/
$bpsh_bin $node_number ln -s /proc/self/fd /dev/fd || _print-stderr-then-exit "Failed to make /dev/fd" 1

# Load the fuse module on the compute node
$bpsh_bin $node_number modprobe fuse || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1
$bpsh_bin $node_number mknod -m 666 /dev/fuse c 10 229 || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1

# Create the GlusterFS dirs on the compute node
cat /tmp/.glusterfsdirs.$node_number | while read -r each_dir;do
  $bpsh_bin -n $node_number mkdir -p $each_dir || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1
done

# Copy over the GlusterFS files to the compute node
cat /tmp/.glusterfsfiles.$node_number | while read -r each_file;do
  $bpcp_bin $each_file $node_number:$each_file || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1
done

# Mount the glusterfs volume(s) on the compute node
$bpsh_bin $node_number mkdir -p /home || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1
$bpsh_bin $node_number /sbin/mount.glusterfs storage0-dev.cssd.pitt.edu:/vol_home -o backupvolfile-server=storage1-dev.cssd.pitt.edu /home || _print-stderr-then-exit "GlusterFS initialization failed on line $LINENO in script $script on node $node_number." 1

rm -f /tmp/.glusterfsdirs.$node_number
rm -f /tmp/.glusterfsfiles.$node_number

echo "GlusterFS mount on node $node_number completed."