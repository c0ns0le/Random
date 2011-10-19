#!/bin/bash
#Description: Bash script to check if LDAP is giving valid results.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.1
#Revision Date: 8-26-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

if [ -z "$1" ];then
  echo "Usage: $0 ldap_group_name_to_test"
  exit 0
fi

getent group $1 > /dev/null
if [ "$?" = "0" ];then
  echo "LDAP group information found, LDAP appears to be working."
else
  echo "ERROR - Failed to get LDAP group information, LDAP may be dead!"
  logger -p crit "CREATE TICKET FOR SE - Failed to get LDAP group information, LDAP (or nscd) may be dead."
fi