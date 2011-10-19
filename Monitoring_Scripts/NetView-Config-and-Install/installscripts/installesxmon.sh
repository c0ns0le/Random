#!/bin/bash

#Description: Custom ESX monitoring for NetView - Installer
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.3
#Revision Date: 9-5-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

SCRIPT=${0##*/}
SNMPDCONF="/etc/snmp/snmpd.conf"

#Check the version of ESX
if [ $(awk '{if (/3.5/||/4.0/) { print "1";nextfile } else { print "0" }}' /etc/vmware-release) = "1" ];then
	echo "# Checking for supported version of ESX.....found!"
else
	echo "# Checking for supported version of ESX.....This is not a supported version of ESX, EXITING."
	exit 1
fi

./installscripts/allowsnmpdselinux.sh

#Copy the scripts from the installer to the dest.
cp ./snmpscripts/esx*.sh /usr/local/bin/ || echo "# $LINENO Error - Unable to copy esx*.sh to /usr/local/bin"
chmod +x /usr/local/bin/esx*.sh || echo "# $LINENO Error - Unable to make scripts executable in /usr/local/bin"

#Check if $SNMPDCONF has alreayd been edited with the options here and skip them if so.
if [ $(awk '{if (/^extend/&&/esxmem0/) { print "1";nextfile } else { print "0" }}' /etc/snmp/snmpd.conf) = "1" ];then
	echo "# esxmem0 already configured in $SNMPDCONF, skipping it."
else
	echo "extend .1.4 esxmem0 /usr/local/bin/esxmemory.sh" >> $SNMPDCONF || echo "# $LINENO Error - Unable to add esxmem entry to $SNMPDCONF"
fi
if [ $(awk '{if (/^extend/&&/esxmem2/) { print "1";nextfile } else { print "0" }}' /etc/snmp/snmpd.conf) = "1" ];then
	echo "# esxmem2 already configured in $SNMPDCONF, skipping it."
else
	echo "extend .1.4 esxmem2 /usr/local/bin/esxovercommitpct.sh" >> $SNMPDCONF || echo "# $LINENO Error - Unable to add esxmem entry to $SNMPDCONF"
fi
if [ $(awk '{if (/^extend/&&/esxvcpu0/) { print "1";nextfile } else { print "0" }}' /etc/snmp/snmpd.conf) = "1" ];then
	echo "# esxvcpu0 already configured in $SNMPDCONF, skipping it."
else
	echo "extend .1.4 esxvcpu0 /usr/local/bin/esxvcpu.sh" >> $SNMPDCONF || echo "# $LINENO Error - Unable to add esxvcpu entry to $SNMPDCONF"
fi
if [ $(awk '{if (/^extend/&&/esxdisk/) { print "1";nextfile } else { print "0" }}' /etc/snmp/snmpd.conf) = "1" ];then
	echo "# esxdisk already configured in $SNMPDCONF, if you want me to automatically add the datastores you'll have to remove the offending lines."
else
ls -l /vmfs/volumes | awk '$1 ~ /^l/ { print $9 }' | (while read -r DSNAME;do
SNMPINDEX=$(grep -c "esxdisk" $SNMPDCONF) #If there are 3 datastores in the conf the indexes for them will be 0, 1, and 2 but the count of how many exist is 3 so the next available index is always the count of how many datastores are currently in the conf.  Neat huh?
echo "extend .1.4 esxdisk$SNMPINDEX /usr/local/bin/esxdisk.sh $DSNAME" >> $SNMPDCONF
[ $? = 0 ] && echo  "# Added datastore $DSNAME to $SNMPDCONF" || echo "# $LINENO Error - Unable to add $DSNAME to $SNMPDCONF."
done)
fi

#Count how many datastores there are.
FINALDSNUM=$(grep -c "esxdisk" $SNMPDCONF)
NVINDEX=48

if (( $FINALDSNUM < 10 ));then
	echo "# There are $FINALDSNUM datastore(s).  The numbering of the index(es) in NetView will be:"
	for (( c=1; c<=$FINALDSNUM; c++ ));do
		echo "$NVINDEX"
		NVINDEX=$(( $NVINDEX + 1 ))
	done
else
	echo "# There are $FINALDSNUM datastores.  The numbering of the indexes in NetView will be:"
	echo "# 48.48 through 48.57 for the first ten.  Then it is 49.48 through 49.57 for the next ten.  Then it is 50.48 through 50.57 and so on in that fashion."
fi