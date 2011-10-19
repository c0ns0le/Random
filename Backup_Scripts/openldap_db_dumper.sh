#!/bin/bash

#Description: Bash script to dump the .
#Written By: Jeff White (jaw171@pitt.edu) of The University of Pittsburgh
#Version Number: 0.1
#Revision Date: 7-27-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o nounset

script=${0##*/}
dumpdestdir="/var/openldap/dumps"
slapcatbin="/usr/sbin/slapcat"
datebin="/bin/date"
mkdirbin="/bin/mkdir"
loggerbin="/usr/bin/logger"
xargsbin="/usr/bin/xargs"
rmbin="/bin/rm"
awkbin="/bin/awk"

function printerror {
echo "ERROR - Failed to create OpenLDAP dump with slapcat."
$loggerbin -p info "CREATE TICKET FOr SE - Failed to create OpenLDAP dump with slapcat."
exit 1
}

$mkdirbin -p $dumpdestdir || printerror

#Create the dumps.
$slapcatbin -b 'cn=config' > $dumpdestdir/config_$($datebin +%F).ldif || printerror
$slapcatbin -b 'dc=frank,dc=sam,dc=pitt,dc=edu' > $dumpdestdir/objects_$($datebin +%F).ldif || printerror

#Only keep the 7 newest copies of each dump.
ls -1 -t ${dumpdestdir}/config_*.ldif | $awkbin '{ if (NR > 7) {print}}' | $xargsbin $rmbin -f
ls -1 -t ${dumpdestdir}/objects_*.ldif | $awkbin '{ if (NR > 7) {print}}' | $xargsbin $rmbin -f