#!/bin/bash

#Description: Script to install and configure net-snmp.
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.NetServe365.com)
#Version Number: 0.4
#Revision Date: 9-12-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

SNMPDCONF="/etc/snmp/snmpd.conf"

./installscripts/allowsnmpdselinux.sh

function installnetsnmp { #Installs net-snmp and tools
if which rpm &>/dev/null;then
	yum install net-snmp net-snmp-utils && echo "# Successfully installed net-snmp." || echo "# $LINENO Error - Unable to install net-snmp packages with yum."
elif which apt-get &>/dev/null;then
	apt-get install snmpd snmp && echo "# Successfully installed net-snmp." || echo "# $LINENO Error - Unable to install net-snmp packages with apt-get."
else
	echo "# $LINENO Error - Unable to find yum or apt-get, you'll have to install net-snmp manually."
fi
}

function startsnmpdatboot { #Sets snmpd to start on boot.
if [ -f /sbin/chkconfig ];then
	/sbin/chkconfig --level 235 snmpd on && echo "# Successfully configured snmpd to start at boot." || echo "# $LINENO Error - Unable to configure snmpd to start on boot."
elif [ -d /etc/rc2.d -a -f /etc/init.d/snmpd ];then
	ln -s /etc/init.d/snmpd /etc/rc.d/rc3.d/S99snmpd
	ln -s /etc/init.d/snmpd /etc/rc.d/rc2.d/K99snmpd && echo "# Successfully configured snmpd to start at boot." || echo "# $LINENO Error - Unable to configure snmpd to start on boot."
elif [ -d /etc/rc.d/rc2.d -a -f /etc/init.d/snmpd ];then
	ln -s /etc/init.d/snmpd /etc/rc.d/rc3.d/S99snmpd
	ln -s /etc/init.d/snmpd /etc/rc.d/rc2.d/K99snmpd && echo "# Successfully configured snmpd to start at boot." || echo "# $LINENO Error - Unable to configure snmpd to start on boot."
else
	echo "# $LINENO Error - Unable to set snmpd to start at boot, unable to find chkconfig or SysV init directories."
fi
}

function removerocommunity { #Comments out all rocommunities in the snmpd config file.
awk 'match($0,"^rocommunity") == 0 {print $0}' $SNMPDCONF > /tmp/snmpd.conf || echo "# $LINENO Error - Unable to remove rocommunities in $SNMPDCONF."
awk '/^rocommunity/ { print "#"$0 }' $SNMPDCONF >> /tmp/snmpd.conf || echo "# $LINENO Error - Unable to remove rocommunities in $SNMPDCONF."
cp -f /tmp/snmpd.conf $SNMPDCONF && echo "# Successfully removed rocommunities in $SNMPDCONF."|| echo "# $LINENO Error - Unable to remove rocommunities in $SNMPDCONF."
}

function addrocommunity { #Adds an rocommunity to the snmpd config file.
read -p "# Enter the rocommunity name you want to add: " NEWROCOMNAME
echo "rocommunity $NEWROCOMNAME" >> $SNMPDCONF 
[ $? = 0 ] && echo "# Added $NEWROCOMNAME to $SNMPDCONF" || echo "$LINENO Error - Unable to add $NEWROCOMNAME to $SNMPDCONF."
}

function opensnmpiniptables { #Checks variables to see if iptables is installed, if the port is open, and opens it if needed.
if [ "$ISIPTABLESOPEN" = "1" ];then
	echo "# SNMP is already allowed through iptables, not making any changes."
elif [ "$ISIPTABLESINSTALLED" != "0" ];then
	echo "# iptables does not appear to be installed, not making any changes."
else
	$IPTABLESCMD -I INPUT -p udp --dport 161 -j ACCEPT && echo "# Successfully opened SNMP port in iptables." || echo "# $LINENO Error - Unable to add rule to iptables."
	/sbin/service iptables save && echo "# Successfully saved iptables configuration." || echo "# $LINENO Error - Unable to save the iptables configuration."
fi
}

if [ -f /sbin/iptables ];then #Is iptables installed?
	IPTABLESCMD="/sbin/iptables"
	ISIPTABLESINSTALLED=1
	ISIPTABLESOPEN=$($IPTABLESCMD -L | awk '{if (/dpt:snmp/) { print "1";nextfile } else { print "0" }}')
elif [ -f /usr/sbin/iptables ];then
	IPTABLESCMD="/usr/sbin/iptables"
	ISIPTABLESINSTALLED=1
	ISIPTABLESOPEN=$($IPTABLESCMD -L | awk '{if (/dpt:snmp/) { print "1";nextfile } else { print "0" }}')
else
	echo "# Unable to find iptables, it does not appear to be installed."
	ISIPTABLESINSTALLED=0
fi

if [ "$ISIPTABLESOPEN" = "1" ];then #Is the SNMP port already open?
	echo "# SNMP is successfully allowed through iptables."
elif [ "$ISIPTABLESINSTALLED" = "0" ];then
	echo "# iptables does not appear to be installed, no need to open the port for SNMP."
else
	echo "# $LINENO Warning - SNMP is currently NOT allowed through iptables."
fi

if [ -f $SNMPDCONF ];then
	CURROCOMNAME=$(awk '/^rocommunity/ { print $2 }' $SNMPDCONF)
	if [ -n "$CURROCOMNAME" ];then
		printf "# The current rocommunity(ies) is/are:\n$CURROCOMNAME\n"
	else
		echo "# I couldn't find an rocommunity in $SNMPDCONF, you should set one."
	fi
else
	echo "# $LINENO Warning - Unable to find $SNMPDCONF.  This is fine if SNMP is not yet installed."
fi

while [ 1 ];do
echo "1) Configure everything - This selects ALL options!"
echo "2) Install net-snmp"
echo "3) Add an rocommunity"
echo "4) Remove all existing rocommunity entries"
echo "5) Configure snmpd to start at boot"
echo "6) Allow SNMP through iptables [firewall]"
echo "q) Go back/quit"
read -p "Please select an option: " CHOICE
    case "$CHOICE" in
        1)
		installnetsnmp
		startsnmpdatboot
		removerocommunity
		addrocommunity
		opensnmpiniptables ;;
		2)
		installnetsnmp ;;
        3)
		addrocommunity ;;
		4)
		removerocommunity ;;
		5)
		startsnmpdatboot ;;
		6)
		opensnmpiniptables ;;
		q | Q)
		break ;;
		*)
		echo "Huh?  I only understand these options:"
    esac
done