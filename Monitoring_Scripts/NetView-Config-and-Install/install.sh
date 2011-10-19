#!/bin/bash

#Description: NetView installer
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.2.9
#Revision Date: 11-26-2010
#License: This script is released under version three (3) of the GPU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

SCRIPT=${0##*/}
SNMPDCONF="/etc/snmp/snmpd.conf"
PATH=/bin:/usr/bin:/sbin:/usr/sbin/:/usr/local/bin:/usr/local/sbin

#Is the script being ran as root?
if [ "$UID" != "0" ]; then
	echo "# $LINENO - This script must be ran as root.  EXITING"
	exit 2
elif [ -z .$BASH. ]; then
	echo "# $LINENO Error - Please run this script with the BASH shell.  EXITING"
	exit 192
fi

chmod +x ./installscripts/* || echo "# $LINENO Error - Unable to make install scripts executable."
chmod +x ./snmpscripts/* || echo "# $LINENO Error - Unable to make SNMP scripts executable."

#Back up $SNMPDCONF, and rotate the old backups.
if [ -f $SNMPDCONF ];then
NUMOLDBAK=$(ls | grep -c snmpd.conf.bak-`date +%m-%d-%Y`-)
while (( $NUMOLDBAK > 0 ));do
	NUMOLDBAKPLUSONE=$(( $NUMOLDBAK + 1 ))
	mv snmpd.conf.bak-$(date +%m-%d-%Y)-$NUMOLDBAK snmpd.conf.bak-$(date +%m-%d-%Y)-$NUMOLDBAKPLUSONE
	NUMOLDBAK=$(( $NUMOLDBAK - 1 ))
done

if [ -f snmpd.conf.bak-$(date +%m-%d-%Y) ]; then
	mv snmpd.conf.bak-$(date +%m-%d-%Y) snmpd.conf.bak-$(date +%m-%d-%Y)-1
fi

cp $SNMPDCONF snmpd.conf.bak-$(date +%m-%d-%Y)

#Did we back up $SNMPDCONF correctly?
if [ -f snmpd.conf.bak-$(date +%m-%d-%Y) ]; then
	echo "# Successfully backed up $SNMPDCONF."
else
	echo "# $LINENO Error - Unable to backup $SNMPDCONF.  EXITING"
	exit 1
fi

#Did we already edit $SNMPDCONF?
if grep "NetServe365" $SNMPDCONF &> /dev/null; then
	echo "# $SNMPDCONF appears to have already been edited.  That is fine, but you should check the file manually for errors (and duplicate entires) when you are done."
else
	echo "# Customizations by NetServe365" >> $SNMPDCONF || "$LINENO - Unable to edit $SNMPDCONF"
fi

#Is net-snmp installed and will it start at boot?
if which rpm &> /dev/null;then
	rpm -q net-snmp &> /dev/null && echo "# net-snmp appears to be already installed." || echo "# $LINENO Warning - net-snmp does not appear to be installed!"
	if [ $(/sbin/chkconfig --list snmpd | awk '$4 ~ /on/ { print "1"}') = "1" ];then
		echo "# snmpd is successfully set to start on boot."
	else
		echo "# $LINENO Warning - snmpd is not set to start on boot."
	fi
elif which dpkg &> /dev/null;then
	DEBSNMPDSTAT=$(dpkg -l | awk '/snmpd/ {print $1 }')
	[ "$DEBSNMPDSTAT" = "ii" ] && echo "# net-snmp appears to be already installed." || echo "# $LINENO Warning - snmpd does not appear to be installed!"
else
	echo "# $LINENO Warning - I can't find rpm or dpkg so I don't know if net-snmp is installed or if it starts at boot, you should check."
fi

else
echo "# $LINENO Warning - Unable to find $SNMPDCONF.  This is fine if SNMP is not yet installed."
fi

if [ $(/sbin/lspci | grep -i -c 'VMware') != "0" ];then
	echo "# Hardware appears to be: VMware"
elif [ $(dmesg | grep -i -c 'VMware') != "0" ];then
	echo "# Hardware appears to be: VMware"
elif [ $(/sbin/lspci | grep -i -c 'Dell') != "0" ];then
	echo "# Hardware appears to be: Dell"
elif [ $(dmesg | grep -i -c 'Dell') != "0" ];then
	echo "# Hardware appears to be: Dell"
elif [ $(/sbin/lspci | grep -i -c 'HP') != "0" ];then
	echo "# Hardware appears to be: HP"
elif [ $(dmesg | grep -i -c 'HP') != "0" ];then
	echo "# Hardware appears to be: HP"
elif [ $(/sbin/lspci | grep -i -c 'Hewlett') != "0" ];then
	echo "# Hardware appears to be: HP"
elif [ $(dmesg | grep -i -c 'Hewlett') != "0" ];then
	echo "# Hardware appears to be: HP"
fi

if [ -f /etc/vmware-release ];then
	echo "# OS version is: $(cat /etc/redhat-release) with kernel $(uname -r) and arch $(uname -m)"
elif [ -f /etc/redhat-release ];then
	echo "# OS version is: $(cat /etc/redhat-release) with kernel $(uname -r) and arch $(uname -m)"
elif [ -f /etc/issue ];then
	echo "# OS version is: $(cat /etc/issue) with kernel $(uname -r) and arch $(uname -m)"
elif [ -f /etc/debian_version ];then
	echo "# OS version is: $(cat /etc/debian_version) with kernel $(uname -r) and arch $(uname -m)"
fi

while [ 1 ];do
	printf "\n1) Install or configure SNMP\n"
	echo "2) Install NetView agent"
	echo "3) Install Dell's OMSA"
	echo "4) Install VMware ESX monitoring"
	echo "5) Install Oracle monitoring"
	echo "6) Install MySQL monitoring"
	echo "7) Install RAID Status (Linux - mdadm) monitoring"
    echo "q) Quit"
	read -p "# Please select an option: " CHOICE
    case "$CHOICE" in
        1)
        ./installscripts/configsnmp.sh ;;
		2)
        ./installscripts/nableinstaller-custom.sh ;;
		3)
		./installscripts/dellomsainstall.sh ;;
		4)
        ./installscripts/installesxmon.sh ;;
		5)
		./installscripts/installoramon.sh ;;
		6)
		./installscripts/installmysqlmon.sh ;;		
		7)
		./installscripts/installmdadmmon.sh ;;
		q | Q)
        break ;;
		*)
		echo "# Huh?  I only understand these options:"
    esac
done

if [ -f $SNMPDCONF ];then
  echo "# Restarting snmpd"
  /sbin/service snmpd restart || echo "# $LINENO Error - Unable to restart the snmpd daemon"
fi