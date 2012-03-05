#!/bin/bash
shopt -s -o nounset
#Description: Bash script to test GlusterFS performance.
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
# 0.1 - 2011-12-26 - Initial version. - Jeff White
#
#####

localdir="/local_data/35000_10MB_files"
remotedir_fuse="/vol_home0_fuse/35000_10MB_files"
remotedir_gnfs=""
remotedir_knfs=""

#GlusterFS FUSE - Push the data from a single client to the volume.
start_epoch=$(date +%s)
rsync -ah --stats $localdir/ $remotedir_fuse/
end_epoch=$(date +%s)
echo "GlusterFS FUSE - Push the data from a single client to the volume.  Done, took $(($end_epoch - $start_epoch)) seconds."

#GlusterFS FUSE - Delete the data on a single client’s local storage.
# start_epoch=$(date +%s)
# rm -rf $localdir
# end_epoch=$(date +%s)
# echo "GlusterFS FUSE - Delete the data on a single client’s local storage.  Done, took $(($end_epoch - $start_epoch)) seconds."

#GlusterFS FUSE - Pull the data from a single client from the volume.
# start_epoch=$(date +%s)
# rsync -ah --stats $remotedir_fuse/ $localdir/
# end_epoch=$(date +%s)
# echo "GlusterFS FUSE - Pull the data from a single client from the volume.  Done, took $(($end_epoch - $start_epoch)) seconds."

#GlusterFS - Delete the data from the volume from a single client.
# start_epoch=$(date +%s)
# rm -rf $remotedir_fuse
# end_epoch=$(date +%s)
# echo "GlusterFS FUSE - Delete the data from the volume from a single client.  Done, took $(($end_epoch - $start_epoch)) seconds."