#!/bin/bash

#Description: Bash script to install MySQL monitoring.
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.3
#Revision Date: 11-29-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

SCRIPT=${0##*/}
SNMPDCONF="/etc/snmp/snmpd.conf"
PATH=/bin:/usr/bin:/sbin:/usr/sbin/:/usr/local/bin:/usr/local/sbin

cp ./snmpscripts/mysql*.sh /usr/local/bin/ || echo "$LINENO - Error copying mysql*.sh in $SCRIPT"
chmod +x /usr/local/bin/mysql*.sh || echo "$LINENO - Error making MySQL scripts executable in $SCRIPT"

# if ! which perl &> /dev/null;then
#     if which yum &> /dev/null;then
# 	yum install perl || echo "$LINENO Error - Unable to install perl."
#     elif which apt-get &> /dev/null;then
# 	apt-get install perl || echo "$LINENO Error - Unable to install perl."
#     else
# 	echo "$LINENO Error - Perl is not installed and unable to find yum or apt-get to install it.  Exiting"
# 	exit 1
#     fi
# fi

./installscripts/allowsnmpdselinux.sh

while [ 1 ];do
	echo "1) Configure NetView user in MySQL."
	echo "2) Install MySQL monitoring."
	echo "q) Go back."
	read -p "Please select an option. " MYSQLCHOICE
	case "$MYSQLCHOICE" in
	1)
	read -p "What username would you like to create? (usually netview): " NEWMYSQLUSER
	stty -echo #Don't echo the password to the screen
	read -p "What password would you like to create? " NEWMYSQLPASS
	stty echo
	printf "\n"
	read -p "What username should I use to connect to MySQL to make this change? (usually root or netserve365) " CURMYSQLUSER
	stty -echo #Don't echo the password to the screen
	read -p "What password should I use to connect to MySQL to make this change? " CURMYSQLPASS
	stty echo
	printf "\n"
	echo "CREATE USER '$NEWMYSQLUSER'@'localhost' IDENTIFIED BY '$NEWMYSQLPASS';" | mysql --user="$CURMYSQLUSER" --password="$CURMYSQLPASS" && echo "Successfully created user '$NEWMYSQLUSER'" || echo "$LINENO - ERROR - Unable to create MySQL user!"
	echo "GRANT REPLICATION CLIENT ON *.* TO '$NEWMYSQLUSER'@'localhost';" | mysql --user="$CURMYSQLUSER" --password="$CURMYSQLPASS" && echo "Successfully granted privileges to user '$NEWMYSQLUSER'" || echo "$LINENO - ERROR - Unable to grant privileges to MySQL user!";;
	2)
	if [ $(grep -c mysql $SNMPDCONF) = "0" ];then
		echo "extend .1.4 mysqlstatmon0 /usr/local/bin/mysqlstatmon1.sh" >> $SNMPDCONF 
		echo "extend .1.4 mysqlreplmon0 /usr/local/bin/mysqlreplmon1.sh" >> $SNMPDCONF 
		echo "extend .1.4 mysqlreplmon1 /usr/local/bin/mysqlreplmon2.sh" >> $SNMPDCONF 
		echo "extend .1.4 mysqlreplmon2 /usr/local/bin/mysqlreplmon3.sh" >> $SNMPDCONF || echo "$LINENO - ERROR - Unable to edit $SNMPDCONF" && echo "Successfully configured $SNMPDCONF with MySQL options."
	else
		echo "$SNMPDCONF appears to already be configured for MySQL replication, skipping."
	fi
	read -p "You will have to manually edit the script to contain the proper MySQL username and password.  Press enter to do this now."
	nano -w /usr/local/bin/mysqlstatmon1.sh
	;;
	q | Q)
	break
	;;
	*)
	echo "Huh?  I only understand these options:"
	esac
done