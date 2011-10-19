#!/bin/bash

#Description: Custom Linux MySQL replication monitoring for NetView
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.1
#Revision Date: 8-13-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

SCRIPT=${0##*/}

#Were we able to do the initial mysql query correctly?
if [ ! -f /tmp/netview-mysqlreplmon1.log ];then
	echo "Error - The file /tmp/netview-mysqlreplmon1.log does not exist"
	exit 1
elif [ $(grep -c "dontparse" /tmp/netview-mysqlreplmon1.log) != 0 ];then
	echo "Error parsing /tmp/netview-mysqlreplmon1.log"
	exit 1
fi

#Slave_running
Slave_running=$(awk '$1 ~ /Slave_running/ { print $2 }' /tmp/netview-mysqlreplmon2.log)
echo "$Slave_running"

#Slave_IO_Running
Slave_IO_Running=$(awk -F': ' '$1 ~ /Slave_IO_Running/ { print $2 }' /tmp/netview-mysqlreplmon1.log)
echo "$Slave_IO_Running"

#Slave_SQL_Running
Slave_SQL_Running=$(awk -F': ' '$1 ~ /Slave_SQL_Running/ { print $2 }' /tmp/netview-mysqlreplmon1.log)
echo "$Slave_SQL_Running"

#Slave_IO_State
Slave_IO_State=$(awk -F': ' '$1 ~ /Slave_IO_State/ { print $2 }' /tmp/netview-mysqlreplmon1.log)
echo "$Slave_IO_State"

#Master_Host
Master_Host=$(awk -F': ' '$1 ~ /Master_Host/ { print $2 }' /tmp/netview-mysqlreplmon1.log)
echo "$Master_Host"

#Master_User
Master_User=$(awk -F': ' '$1 ~ /Master_User/ { print $2 }' /tmp/netview-mysqlreplmon1.log)
echo "$Master_User"

#Master_Port
Master_Port=$(awk -F': ' '$1 ~ /Master_Port/ { print $2 }' /tmp/netview-mysqlreplmon1.log)
echo "$Master_Port"

#Last_Errno
Last_Errno=$(awk -F': ' '$1 ~ /Last_Errno/ { print $2 }' /tmp/netview-mysqlreplmon1.log)
echo "$Last_Errno"

#Last_Error
Last_Error=$(awk -F': ' '$1 ~ /Last_Error/ { print $2 }' /tmp/netview-mysqlreplmon1.log)
echo "Error: $Last_Error"

#Seconds_Behind_Master
Seconds_Behind_Master=$(awk -F': ' '$1 ~ /Seconds_Behind_Master/ { print $2 }' /tmp/netview-mysqlreplmon1.log)
echo "$Seconds_Behind_Master"

if [ "$Slave_IO_Running" != "Yes" ];then
	exit 2
fi