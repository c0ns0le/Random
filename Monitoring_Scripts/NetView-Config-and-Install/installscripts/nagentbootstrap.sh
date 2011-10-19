#!/bin/bash

#Description: NetView installer - N-able installer kickoff
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.4
#Revision Date: 9-11-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

NAGENTDLRHEL34='https://portal.netserve365.com/download/7.0.1.255/rhel3.0/N-central/nagent-rhel3.0.tar.gz'
NAGENTDLRHEL5='https://portal.netserve365.com/download/7.0.1.255/rhel5.1/N-central/nagent-rhel5.1.tar.gz'

if [ -f /etc/redhat-release ];then
ISRHEL34=$(awk '{if (/3\./||/4\./) { print "1";nextfile } else { print "0" }}' /etc/redhat-release)
ISRHEL5=$(awk '{if (/5\./) { print "1";nextfile } else { print "0" }}' /etc/redhat-release)
else
	echo "# $LINENO Error - This box does not appear to be RedHat or VMware ESX."
	exit 1
fi

if [ "$ISRHEL34" = "1" ];then
	FILE=$(echo "$NAGENTDLRHEL34" | awk -F'/' '{ print $NF }')
	if [ -f $FILE];then
		echo "# The nagent tar.gz file already exists, I'll just leave it alone."
	elif which wget &> /dev/null;then
		wget $NAGENTDLRHEL34 || echo "# $LINENO Error - Unable to download the nagent tar.gz."
	elif which curl &> /dev/null;then
		curl $NAGENTDLRHEL34 > $FILE || echo "# $LINENO Error - Unable to while download the nagent tar.gz."
	else
		echo "# $LINENO Error - Unable find wget or curl to pull down the files I need, you'll have to install the agent manually."
		exit 1
	fi
fi

if [ "$ISRHEL5" = "1" ];then
	FILE=$(echo "$NAGENTDLRHEL5" | awk -F'/' '{ print $NF }')
	if [ -f $FILE ];then
		echo "# The nagent tar.gz file already exists, I'll just leave it alone."
	elif which wget &> /dev/null;then
		wget $NAGENTDLRHEL5 || echo "# $LINENO Error - Unable to download the nagent tar.gz."
	elif which curl &> /dev/null;then
		curl $NAGENTDLRHEL5 > nagent-rhel5.1 || echo "# $LINENO Error -Unable to download the nagent tar.gz."
	else
		echo "# $LINENO Error - Unable to find wget or curl to pull down the files I need, you'll have to install the agent manually."
		exit 1
	fi
fi

if [ -f "$FILE" ];then
	tar xzf "$FILE"
	cd nagent-rhel*
	./install.sh
else
	echo "# $LINENO Error - Unable to find the nagent tar.gz, you will have to install it manually."
fi
cd ..