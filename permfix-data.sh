#!/bin/bash
# Description: Fix permissons on my datastore
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.0
# Last change: Updated for new directory names

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

publicdirs=( "TV" "Frets on Fire" "Movie" "Music" "Video Game Emulators" "Ebooks" "Education and Certifications" "Video" "Code" )

privatedirs=( "Apps" "Operating Systems" "Pictures" "Stuffs" "Temp" "VHS" "Torrent_Deluge" )

if [ "$HOSTNAME" = "cyan" ];then
  prefixdir="/media/Data"
elif [ "$HOSTNAME" = "teal" ];then
  prefixdir="/media/Backup"
else
  echo "ERROR - $LINENO - Could not determine if this host is cyan or teal!"
  exit 1
fi

for eachpublicdir in "${publicdirs[@]}";do
  find "$prefixdir/$eachpublicdir" -type f \! -perm 664 -exec chmod 664 "{}" \;
  find "$prefixdir/$eachpublicdir" -type d \! -perm 775 -exec chmod 775 "{}" \;
  sudo chown -R white:myself "$prefixdir/$eachpublicdir"
done

for eachprivatedir in "${privatedirs[@]}";do
  find "$prefixdir/$eachprivatedir" -type f \! -perm 660 -exec chmod 660 "{}" \;
  find "$prefixdir/$eachprivatedir" -type d \! -perm 770 -exec chmod 770 "{}" \;
  sudo chown -R white:myself "$prefixdir/$eachprivatedir"
done

find $prefixdir/Code -type f \! -perm 755 -exec chmod 755 "{}" \;

sudo chown -R white:myself /media/VM
find /media/VM -type d \! -perm 770 -exec chmod 770 "{}" \;
find /media/VM -type f \! -perm 660 -exec chmod 660 "{}" \;