#!/bin/bash

#Description: Custom Linux MySQL replication monitoring for NetView
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.1
#Revision Date: 8-13-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
#This script checks the "Slave_running" variable in /tmp/netview-mysqlreplmon1.log made by mysqlreplmon1.sh

SCRIPT=${0##*/}

#Were we able to do the initial mysql query correctly?
if [ ! -f /tmp/netview-mysqlreplmon2.log ];then
	echo "Error - The file /tmp/netview-mysqlreplmon2.log does not exist"
	exit 1
elif [ $(grep -c "dontparse" /tmp/netview-mysqlreplmon2.log) != 0 ];then
	echo "Error parsing /tmp/netview-mysqlreplmon2.log"
	exit 1
fi

#Slave_running
Slave_running=$(awk '$1 ~ /Slave_running/ { print $2 }' /tmp/netview-mysqlreplmon2.log)

if [ "$Slave_running" != "ON" ];then
	exit 2
fi