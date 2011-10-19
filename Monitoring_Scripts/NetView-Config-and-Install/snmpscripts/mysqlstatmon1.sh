#!/bin/bash

#Description: Custom Linux MySQL monitoring for NetView
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.1
#Revision Date: 9-5-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

## Here is where you need to enter the correct username and password.  Keep the quotes!
MYSQLUSER="someusernamehere"
MYSQLPASS='somepasswordhere'
## Don't change anything below here.

SCRIPT=${0##*/}

#Query the server status and create an error in the logs if it fails.
echo "show global status\g" | mysql --user="$MYSQLUSER" --password="$MYSQLPASS" > /tmp/netview-mysqlmon1.log || printf "ERROR in $SCRIPT - dontparse\n" > /tmp/netview-mysqlmon1.log
echo "show variables\g" | mysql --user="$MYSQLUSER" --password="$MYSQLPASS" > /tmp/netview-mysqlmon2.log || printf "ERROR in $SCRIPT - dontparse\n" > /tmp/netview-mysqlmon2.log
#/usr/local/bin/mysqlreport --user "$MYSQLUSER" --password "$MYSQLPASS" 1> /tmp/netview-mysqlmon3.log 2> /dev/null || printf "ERROR in $SCRIPT - dontparse\n" > /tmp/netview-mysqlmon3.log

#Query the slave status and create an error in the logs if it fails.
echo "show slave status\G" | mysql --user="$MYSQLUSER" --password="$MYSQLPASS" > /tmp/netview-mysqlreplmon1.log || printf "\nERROR in $SCRIPT - dontparse\n" > /tmp/netview-mysqlreplmon1.log
echo "show status like 'Slave_running%'\g" | mysql --user="$MYSQLUSER" --password="$MYSQLPASS" > /tmp/netview-mysqlreplmon2.log || printf "\nERROR in $SCRIPT - dontparse\n" > /tmp/netview-mysqlreplmon2.log

#Were we able to do the initial mysql query correctly?
if [ ! -f /tmp/netview-mysqlmon1.log ];then
	echo "Error - The file /tmp/netview-mysqlmon1.log does not exist"
	exit 1
elif [ $(grep -c "dontparse" /tmp/netview-mysqlmon1.log) != 0 ];then
	echo "Error parsing /tmp/netview-mysqlmon1.log"
	exit 1
elif [ ! -f /tmp/netview-mysqlmon2.log ];then
	echo "Error - The file /tmp/netview-mysqlmon2.log does not exist"
	exit 1
elif [ $(grep -c "dontparse" /tmp/netview-mysqlmon2.log) != 0 ];then
	echo "Error parsing /tmp/netview-mysqlmon2.log"
	exit 1
#elif [ ! -f /tmp/netview-mysqlmon3.log ];then
#	echo "Error - The file /tmp/netview-mysqlmon3.log does not exist"
#	exit 1
#elif [ $(grep -c "dontparse" /tmp/netview-mysqlmon3.log) != 0 ];then
#	echo "Error parsing /tmp/netview-mysqlmon3.log"
#	exit 1
elif [ ! -f /tmp/netview-mysqlreplmon1.log ];then
	echo "Error - The file /tmp/netview-mysqlreplmon1.log does not exist"
	exit 1
elif [ $(grep -c "dontparse" /tmp/netview-mysqlreplmon1.log) != 0 ];then
	echo "Error parsing /tmp/netview-mysqlreplmon1.log"
	exit 1
elif [ ! -f /tmp/netview-mysqlreplmon2.log ];then
	echo "Error - The file /tmp/netview-mysqlreplmon2.log does not exist"
	exit 1
elif [ $(grep -c "dontparse" /tmp/netview-mysqlreplmon2.log) != 0 ];then
	echo "Error parsing /tmp/netview-mysqlreplmon2.log"
	exit 1
else
	echo "Yes"
fi

#MySQL version
version=$(awk '$1 == "version" { print $2 }' /tmp/netview-mysqlmon2.log)
echo "$version"

#MySQL port
port=$(awk '$1 == "port" { print $2 }' /tmp/netview-mysqlmon2.log)
echo "$port"

#MySQL install directory (basedir)
basedir=$(awk '$1 == "basedir" { print $2 }' /tmp/netview-mysqlmon2.log)
echo "$basedir"

#MySQL data directory
datadir=$(awk '$1 == "datadir" { print $2 }' /tmp/netview-mysqlmon2.log)
echo "$datadir"

#MySQL temporary directory
tmpdir=$(awk '$1 == "tmpdir" { print $2 }' /tmp/netview-mysqlmon2.log)
echo "$tmpdir"

#MySQL socket
socket=$(awk '$1 == "socket" { print $2 }' /tmp/netview-mysqlmon2.log)
echo "$socket"

#MySQL server ID
server_id=$(awk '$1 == "server_id" { print $2 }' /tmp/netview-mysqlmon2.log)
echo "$server_id"

#Storage engine in use
storage_engine=$(awk '$1 == "storage_engine" { print $2 }' /tmp/netview-mysqlmon2.log)
echo "$storage_engine"

#Max number of connections
max_connections=$(awk '$1 == "max_connections" { print $2 }' /tmp/netview-mysqlmon2.log)
echo "$max_connections"