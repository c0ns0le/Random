#!/bin/bash

#Description: Bash script to allow snmpd through SELinux.
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.netserve365.com)
#Version Number: 0.2
#Revision Date: 9-11-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

SCRIPT=${0##*/}
PATH=/bin:/usr/bin:/sbin:/usr/sbin/:/usr/local/bin:/usr/local/sbin

function getsnmpdbool {
if which getsebool &> /dev/null;then
  SNMPDBOOL=$(getsebool snmpd_disable_trans | awk -F'-> ' '{ print $2 }')
else
  echo "# $LINENO Error - Unable to find command getsebool, you'll have to allow snmpd through SELinux manually!"
  exit 1
fi
}

function setsnmpdbool {
if which setsebool;then
	setsebool -P snmpd_disable_trans 1
else
  echo "# $LINENO Error - Unable to find command setsebool, you'll have to allow snmpd through SELinux manually!"
fi
}

if which sestatus;then
  ENABLED=$(sestatus | awk '/SELinux status/ { print $3 }')
else
  echo "# $LINENO Error - Unable to find command sestatus, you'll have to allow snmpd through SELinux manually!  (If it is enabled and enforcing)"
  exit 1
fi

if which sestatus;then
  ENFORCINGCURRENT=$(sestatus | awk '/Current mode/ { print $3 }')
else
  echo "# $LINENO Error - Unable to find command sestatus, you'll have to allow snmpd through SELinux manually!  (If it is enabled and enforcing)"
  exit 1
fi

if which sestatus;then
  ENFORCINGCONFIG=$(sestatus | awk '/Mode from config file/ { print $5 }')
else
  echo "# $LINENO Error - Unable to find command sestatus, you'll have to allow snmpd through SELinux manually!  (If it is enabled and enforcing)"
  exit 1
fi

if [ "$ENFORCINGCURRENT" = "enforcing" -o "$ENFORCINGCONFIG" = "enforcing" ];then
	ENFORCINGATALL=1
else
	ENFORCINGATALL=0
fi

getsnmpdbool

if [ "$ENABLED" = "disabled" ];then
  echo "# SELinux is not enabled, not making any changes."
elif [ "$ENFORCINGATALL" = "0" ];then
  echo "# SELinux is not enforcing, not making any changes."
elif [ "$SNMPDBOOL" = "on" ];then
  echo "# snmpd is already allowed through SELinux, not making any changes."
elif [ "$ENABLED" = "enabled" -a "$ENFORCINGATALL" = "1" -a "$SNMPDBOOL" = "off" ];then
  echo "# Allowing snmpd through SELinux."
  setsnmpdbool
  getsnmpdbool
  if [ "$SNMPDBOOL" = "on" ];then #...and tell us if it did not.
	echo "# snmpd is successfully allowed through SELinux."
  else
	echo "# $LINENO Error - Unable to allow snmpd through SELinux, you'll have to allow snmpd through SELinux manually!"
  fi
else
  echo "# $LINENO Error - Unable to determine if snmpd is allowed through SELinux, you will have to check manually!"
fi