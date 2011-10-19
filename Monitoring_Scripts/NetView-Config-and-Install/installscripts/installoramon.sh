#!/bin/bash

#Description: Bash script to install monitoring for Oracle processes.
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.2
#Revision Date: 9-12-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

SNMPDCONF=/etc/snmp/snmpd.conf
KNOWNORAPROCLIST=/var/local/knownoraproclist.log
SNMPINDEX="0"

cp ./snmpscripts/ora*.sh /usr/local/bin || echo "$LINENO - Error making scripts executable in $SCRIPT"
chmod +x /usr/local/bin/ora*.sh || echo "$LINENO - Error making scripts executable in $SCRIPT"

./installscripts/allowsnmpdselinux.sh

#Add entry into $SNMPDCONF for "Oracle - Rogue Process" service.
if [ "$(awk '/^extend/&&/orarogueproc0/ { print "1";nextfile }' /etc/snmp/snmpd.conf)" = "1" ];then
	echo "# orarogueproc0 already configured in $SNMPDCONF, skipping it."
else
	echo "extend .1.4 orarogueproc0 /usr/local/bin/orarogueproc.sh" >> $SNMPDCONF && echo "# Added orarogueproc0 to $SNMPDCONF." || echo "# $LINENO Error - Unable to add orarogueproc0 entry to $SNMPDCONF"
fi

#Make a list of the running processes and put them in a file.
if [ -f $KNOWNORAPROCLIST ];then
	read -p "# $LINENO Error - The file $KNOWNORAPROCLIST already exists, should I copy over it? y or n: " OVERWRITECHOICE
	case "$OVERWRITECHOICE" in
		y | Y)
		ps aux | awk '$11 ~ /^ora/ { print $11 }' | sort | uniq > $KNOWNORAPROCLIST ;;
		*)
		echo "# $LINENO - Exiting on user choice!"
		exit 0 ;;
	esac
else
	ps aux | awk '$11 ~ /^ora/ { print $11 }' | sort | uniq > $KNOWNORAPROCLIST
fi

#Add known processes to $SNMPDCONF for use with the "Oracle - Process" service.
if [ $(awk '{if (/^extend/&&/checkproc/) { print "1";nextfile } else { print "0" }}' /etc/snmp/snmpd.conf) = "1" ];then
	echo "# checkproc already configured in $SNMPDCONF, skipping it."
else
cat $KNOWNORAPROCLIST | sed -e 's/.*/\"&\"/' | (while read -r PROCNAME;do
	if [ $SNMPINDEX -lt 10 ];then
		OID=checkproc0
	else
		OID=checkproc
	fi
	echo "extend .1.4 $OID$SNMPINDEX /usr/local/bin/checkproc.sh $PROCNAME" >> $SNMPDCONF && echo "# Added process $PROCNAME to $SNMPDCONF" || echo "# $LINENO Error - Unable to add $PROCNAME to $SNMPDCONF."
	SNMPINDEX=$(( $SNMPINDEX + 1 ))
done)
fi

FINALPROCNUM=$(grep -c checkproc $SNMPDCONF)
#What will our indexes be for the "Oracle - Process" service?
if (( $FINALPROCNUM < 10 ));then
	echo "# There are $FINALPROCNUM processes(s).  The numbering of the index(es) in NetView will be:"
	for (( c=1; c<=$FINALPROCNUM; c++ ));do
		echo "$NVINDEX"
		NVINDEX=$(( $NVINDEX + 1 ))
	done
else
	echo "# There are $FINALPROCNUM datastores.  The numbering of the indexes in NetView will be:"
	echo "# 48.48 through 48.57 for the first ten.  Then it is 49.48 through 49.57 for the next ten.  Then it is 50.48 through 50.57 and so on in that fashion."
fi

FINALPROCNUM=$(grep -c checkproc $SNMPDCONF)
#Did we step over our 100 process limit?
if (( $FINALPROCNUM > 100 ));then
	echo "# $LINENO Error - There are more than 100 processes in $SNMPDCONF but the service only supports 100 of them."
fi