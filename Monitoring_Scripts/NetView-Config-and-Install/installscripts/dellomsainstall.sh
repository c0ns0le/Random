#!/bin/bash

#Description: Bash script to install Dell OMSA.
#Written By: Jeff White (jaw171@pitt.edu) of The University of Pittsburgh (www.pitt.edu)
#Version Number: 0.6
#Revision Date: 2-3-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

#If the file names change on Dell's FTP site, change them here.
OMSADLRHEL3='http://ftp.us.dell.com/sysman/OM_5.5.0_ManNode_A00.tar.gz' #Not yet implemented
OMSADLRHEL4_86='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.3.0-2075.RHEL4.i386_A00.14.tar.gz'
OMSADLRHEL4_64='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.3.0-2075.RHEL4.x86_64_A00.15.tar.gz'
OMSADLRHEL5_86='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.4.0-1266.RHEL5.i386_A00.17.tar.gz'
OMSADLRHEL5_64='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.4.0-1266.RHEL5.x86_64_A00.21.tar.gz'
OMSADLRHEL6_64='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.4.0-1266.RHEL6.x86_64_A00.14.tar.gz' 
OMSADLESX40='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.4.0-1266.ESX40.i386_A00.5.tar.gz'
OMSADLESX41='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.4.0-1266.ESX41.i386_A00.2.tar.gz'
OMSADLSLES10_86='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.4.0-1266.SLES10.i386_A00.22.tar.gz' #Not yet implemented
OMSADLSLES10_64='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.4.0-1266.SLES10.x86_64_A00.23.tar.gz' #Not yet implemented
OMSADLSLES11_86='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.4.0-1266.SLES11.i386_A00.13.tar.gz' #Not yet implemented
OMSADLSLES11_64='http://ftp.us.dell.com/sysman/OM-SrvAdmin-Dell-Web-LX-6.4.0-1266.SLES11.x86_64_A00.19.tar.gz' #Not yet implemented

SCRIPT=${0##*/}

#What OS are we on?
if [ -f /etc/vmware-release ];then
	ISESX40=$(awk '{if (/4\.0/) { print "1";nextfile } else { print "0" }}' /etc/vmware-release)
	ISESX41=$(awk '{if (/4\.1/) { print "1";nextfile } else { print "0" }}' /etc/vmware-release)
elif [ -f /etc/redhat-release ];then
	ISRHEL4=$(awk '{if (/3/&&!/2\./&&!/4\./&&!/5\./) { print "1";nextfile } else { print "0" }}' /etc/redhat-release)
	ISRHEL5=$(awk '{if (/5/&&!/2\./&&!/3\./&&!/4\./) { print "1";nextfile } else { print "0" }}' /etc/redhat-release)
	ISRHEL6=$(awk '{if (/6\./&&!/2\./&&!/3\./&&!/4\./&&!/5\./) { print "1";nextfile } else { print "0" }}' /etc/redhat-release)
else
	echo "# $LINENO Error - This box does not appear to be RedHat or VMware ESX."
	exit 0
fi

#What arch are we on?
ISARCH64=$(uname -p | awk '{if (/64/) { print "1";nextfile } else { print "0" }}')

if [ ! -d OMSA ];then
	mkdir OMSA
fi
cd OMSA

#Determine what OS and arch then download the needed tar.gz
if [ "$ISRHEL4" = "1" -a "$ISARCH64" = "0" ];then #RHEL 4, x86
	FILE=$(echo "$OMSADLRHEL4_86" | awk -F'/' '{ print $NF }')
	if [ -f "$FILE" ];then
		echo "The OMSA tar.gz file already exists, I'll just leave it alone."
	elif which wget &> /dev/null;then
		wget $OMSADLRHEL4_86 || echo "$LINENO - Error while downloading the OMSA tar.gz"
	elif which curl &> /dev/null;then
		curl $OMSADLRHEL4_86 > "$FILE" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	fi
elif [ "$ISRHEL4" = "1" -a "$ISARCH64" = "1" ];then #RHEL 4, x64
	FILE=$(echo "$OMSADLRHEL4_64" | awk -F'/' '{ print $NF }')
	if [ -f "$FILE" ];then
		echo "The OMSA tar.gz file already exists, I'll just leave it alone."
	elif which wget &> /dev/null;then
		wget "$OMSADLRHEL4_64" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	elif which curl &> /dev/null;then
		curl "$OMSADLRHEL4_64" > "$FILE" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	fi
elif [ "$ISRHEL5" = "1" -a "$ISARCH64" = "0" ];then #RHEL 5, x86
	FILE=$(echo "$OMSADLRHEL5_86" | awk -F'/' '{ print $NF }')
	if [ -f "$FILE" ];then
		echo "The OMSA tar.gz file already exists, I'll just leave it alone."
	elif which wget &> /dev/null;then
		wget "$OMSADLRHEL5_86" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	elif which curl &> /dev/null;then
		curl "$OMSADLRHEL5_86" > "$FILE" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	fi
elif [ "$ISRHEL5" = "1" -a "$ISARCH64" = "1" ];then #RHEL 5, x64
	FILE=$(echo "$OMSADLRHEL5_64" | awk -F'/' '{ print $NF }')
	if [ -f "$FILE" ];then
		echo "The OMSA tar.gz file already exists, I'll just leave it alone."
	elif which wget &> /dev/null;then
		wget "$OMSADLRHEL5_64" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	elif which curl &> /dev/null;then
		curl "$OMSADLRHEL5_64" > "$FILE" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	fi
elif [ "$ISRHEL6" = "1" -a "$ISARCH64" = "1" ];then #RHEL 6, x64
	FILE=$(echo "$OMSADLRHEL6_64" | awk -F'/' '{ print $NF }')
	if [ -f "$FILE" ];then
		echo "The OMSA tar.gz file already exists, I'll just leave it alone."
	elif which wget &> /dev/null;then
		wget "$OMSADLRHEL6_64" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	elif which curl &> /dev/null;then
		curl "$OMSADLRHEL6_64" > "$FILE" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	fi
elif [ "$ISESX40" = "1" ];then #ESX 4.0
	FILE=$(echo "$OMSADLESX40" | awk -F'/' '{ print $NF }')
	if [ -f "$FILE" ];then
		echo "The OMSA tar.gz file already exists, I'll just leave it alone."
	elif which wget &> /dev/null;then
		wget "$OMSADLESX40" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	elif which curl &> /dev/null;then
		curl "$OMSADLESX40" > "$FILE" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	fi
elif [ "$ISESX41" = "1" ];then #ESX 4.1
	FILE=$(echo "$OMSADLESX41" | awk -F'/' '{ print $NF }')
	if [ -f "$FILE" ];then
		echo "The OMSA tar.gz file already exists, I'll just leave it alone."
	elif which wget &> /dev/null;then
		wget "$OMSADLESX41" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	elif which curl &> /dev/null;then
		curl "$OMSADLESX41" > "$FILE" || echo "$LINENO - Error while downloading the OMSA tar.gz"
	fi
fi

#Ensure the file downloaded and kick off the installer.
if [ -f "$FILE" ];then
	tar xzf "$FILE"
	./setup.sh
else
	echo "# $LINENO Error - Unable to find the OMSA tar.gz, you will have to install it manually and put it in $(pwd)."
	echo "# Note that if the location or file names changed on the server, you can edit the variables at the beginning of $SCRIPT with the new location."
fi
cd ..