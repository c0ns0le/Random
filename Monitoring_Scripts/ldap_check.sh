#!/bin/bash
#Description: Bash script to check if LDAP is giving valid results.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

#####
#
# Version 0.3 - 2011-11-03 - Switched the alert from 'ticket' to 'call'. - Jeff White
#
# Version 0.2 - 2011-11-02 - Added a timeout to the getent command. - Jeff White
#
#####

if [ -z "$1" ];then
  echo "Usage: $0 ldap_group_name_to_test"
  exit 0
fi

/usr/local/bin/timeout 30 getent group $1 > /dev/null
if [ "$?" = "0" ];then
  echo "LDAP group information found, LDAP appears to be working."
else
  echo "ERROR - Failed to get LDAP group information, LDAP may be dead!"
  logger -p crit "URGENT ALERT CALL TIER II - Failed to get LDAP group information, LDAP (or nscd) may be dead."
fi