#Description: Custom mdadm monitoring for NetView
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.NetServe365.com)
#Version Number: 0.1
#Revision Date: 9-11-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

#We we called with an argument?
if [ -z "$1" ]; then
        echo "# $LINENO Error - You must include an md device (e.g. /dev/md0) name as an argument - EXITING"
        exit 2
elif [ -n "$2" ]; then
        echo "# $LINENO Error - You must only include ONE name as an argument - EXITING"
        exit 2
fi

#RAID device file
MDDEVICE=$1

MDSTATFILE=/tmp/netview-mdstat-$(echo $MDDEVICE | awk -F'/' '{ print $3 }')

/sbin/mdadm --detail $MDDEVICE 1> $MDSTATFILE

#State of the array
RAIDSTATETEXT=$(awk -F' : ' '/State/ { print $2 }' $MDSTATFILE)

#Level of the array
RAIDLEVEL=$(awk -F' : ' '/Raid Level/ { print $2 }' $MDSTATFILE)

#Rebuild Status of the array
RAIDREBUILDSTATUS=$(awk -F' : ' '/Rebuild Status/ { print $2 }' $MDSTATFILE)

#Number of devices that exist in the array
TOTALDEVNUM=$(awk -F' : ' '/Total Devices/ { print $2 }' $MDSTATFILE)

#Number of RAID devices that exist in the array
RAIDDEVNUM=$(awk -F' : ' '/Raid Devices/ { print $2 }' $MDSTATFILE)

#Number of failed devices in the array
RAIDFAILDEVNUM=$(awk -F' : ' '/Failed Devices/ { print $2 }' $MDSTATFILE)

#Number of spare devices in the array
RAIDSPAREDEVNUM=$(awk -F' : ' '/Spare Devices/ { print $2 }' $MDSTATFILE)

#UUID of the array
RAIDUUID=$(awk -F' : ' '/UUID/ { print $2 }' $MDSTATFILE)

echo "$MDDEVICE"
echo "$RAIDSTATETEXT"
echo "$RAIDLEVEL"
echo "$RAIDREBUILDSTATUS"
echo "$TOTALDEVNUM"
echo "$RAIDDEVNUM"
echo "$RAIDFAILDEVNUM"
echo "$RAIDSPAREDEVNUM"
echo "$RAIDUUID"

if [ "$RAIDFAILDEVNUM" != "0" ];then
        exit 1
elif [ "$RAIDSTATETEXT" = "clean" ];then
        exit 0
else
        exit 1