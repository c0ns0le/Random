#!/bin/bash

#Description: Custom Linux mdadm monitoring for NetView - Installer
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.1
#Revision Date: 9-6-2010
#License: This script is released under version three (3) of the GPU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

SCRIPT=${0##*/}
SNMPDCONF="/etc/snmp/snmpd.conf"

if ! which sudo &>/dev/null;then
	echo "# $LINENO Error - Unable to find the sudo command on this system, impossible configure mdadm monitoring without it.  EXITING"
	exit 1
fi

./installscripts/allowsnmpdselinux.sh

cp ./snmpscripts/mdadmstat.sh /usr/local/bin/ || echo "# $LINENO Error - Unable to copy mdadmstat.sh to /usr/local/bin."
chmod +x /usr/local/bin/mdadmstat.sh || echo "# $LINENO Error - Unable to make scripts executable in /usr/local/bin."

if [ $(grep -c "mdadmstat" $SNMPDCONF) = 0 ];then
  find /dev -name md[0-9]* 2>/dev/null | (while read -r MDNAME;do
SNMPINDEX=$(grep -c "mdadmstat" $SNMPDCONF) #If there are 3 mds in the conf the indexes for them will be 0, 1, and 2 but the count of how many exist is 3 so the next available index is always the count of how many mds are currently in the conf.  Neat huh?
echo "extend .1.4 mdadmstat$SNMPINDEX /usr/local/bin/mdadmstat.sh $MDNAME" >> $SNMPDCONF
[ $? = 0 ] && echo  "# Added $MDNAME to $SNMPDCONF" || echo "# $LINENO Error - Unable to add $MDNAME to $SNMPDCONF."
done)
else
  echo "# $SNMPDCONF appears to already have mdadm monitoring configured, I'll skip this section."
fi

#Count how many md devices there are.
FINALMDNUM=$(grep -c "mdadmstat" $SNMPDCONF)
NVINDEX=48

if (( $FINALMDNUM < 10 ));then
	echo "# There is/are $FINALMDNUM md device(s).  The numbering of the index(es) in NetView will be:"
	for (( c=1; c<=$FINALMDNUM; c++ ));do
		echo "$NVINDEX"
		NVINDEX=$(( $NVINDEX + 1 ))
	done
else
	echo "# There are $FINALMDNUM datastores.  The numbering of the indexes in NetView will be:"
	echo "# 48.48 through 48.57 for the first ten.  Then it is 49.48 through 49.57 for the next ten.  Then it is 50.48 through 50.57 and so on in that fashion."
fi