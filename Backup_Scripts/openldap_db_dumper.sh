#!/bin/bash

#Description: Bash script to dump an OpenLDAP database to an LDIF file.
#Written By: Jeff White (jaw171@pitt.edu) of The University of Pittsburgh

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 1.0 - 2012-02-06 - Added additional error logging, minor cleanup. - Jeff White
# 0.1 - 2011-07-27 - Initial version. - Jeff White
#
#####

shopt -s -o nounset

script=${0##*/}
dumpdestdir="/var/openldap/dumps"
slapcatbin="/usr/sbin/slapcat"
datebin="/bin/date"
loggerbin="/usr/bin/logger"
xargsbin="/usr/bin/xargs"
awkbin="/bin/awk"

function _printerr { #Usage: _printerr
echo "$1" 1>&2
$loggerbin -p info -t NOC-NETCOOL-TICKET "$1"
exit 1
}

mkdir -p $dumpdestdir || _printerr "ERROR $LINENO - Failed to create OpenLDAP dump directory."

#Create the dumps.
$slapcatbin -b 'cn=config' > $dumpdestdir/config_$($datebin +%F).ldif || _printerr "ERROR $LINENO - Failed to create OpenLDAP configuration dump."
$slapcatbin -b 'dc=frank,dc=sam,dc=pitt,dc=edu' > $dumpdestdir/objects_$($datebin +%F).ldif || _printerr "ERROR $LINENO - Failed to create OpenLDAP database dump."

#Only keep the 7 newest copies of each dump.
ls -1 -t ${dumpdestdir}/config_*.ldif | $awkbin '{ if (NR > 7) {print}}' | $xargsbin rm -f
ls -1 -t ${dumpdestdir}/objects_*.ldif | $awkbin '{ if (NR > 7) {print}}' | $xargsbin rm -f