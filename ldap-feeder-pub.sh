#!/bin/sh
# Description: Pull data from CDS and import it to OpenLDAP
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


script=${0##*/}
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
time="date +%H:%M:%S"


# Log error messages and optionally send an alert to NetCool
function syslog_error {
  # Usage: log_error("Some error text" syslog_tag")
  
  if [ -n "$2" ];then
    logger -p user.err -t "$2" "$1"
  else
    logger -p user.err "$1"
  fi
  
  echo "$1" 1>&2
}


echo "##### $(date) - Starting run of $script #####"


# Dump out the current database in an LDIF format before we make changes (Netbackup will pick this up too)
echo "$($time) - Dumping current database"
if ! slapcat -f /etc/openldap/slapd.conf > /export/ldap/pub/backup/dump-$(date +%F).ldif;then
  syslog_error "$LINENO - Failed to dump current database, exiting" "NOC-NETCOOL-TICKET"
  exit 1
fi


# Check the feed file from CDS
echo "$($time) - Checking the CDS feed file"

if [ ! -f "/export/ldap/pub/feed/oid_extract.txt" ] || [ ! -s "//export/ldap/pub/feed/oid_extract.txt" ]; then
  syslog_error "$LINENO - CDS feed file /export/ldap/pub/feed/oid_extract.txt does not exist or is empty, exiting" "NOC-NETCOOL-TICKET"
  exit 1
fi

cds_file_age=$(($(date +%s) - $(stat -c '%Y' "/export/ldap/pub/feed/oid_extract.txt"))) # seconds
if [ "$cds_file_age" -gt "172800" ];then # two days
  syslog_error "$LINENO - CDS feed file /export/ldap/pub/feed/oid_extract.txt is stale, exiting" "NOC-NETCOOL-TICKET"
  exit 1
fi


# Rotate the LDIF
if [ -f /export/ldap/pub/ldif/oid_data.ldif ];then
  mv /export/ldap/pub/ldif/oid_data.ldif /export/ldap/pub/ldif/oid_data.ldif_yesterday
fi


# Add the root and admin objects to the new LDIF
cat << EOF > /export/ldap/pub/ldif/oid_data.ldif
dn: c=US
c: US
objectclass: top
objectclass: country

dn: o=University of Pittsburgh, c=US
o: University of Pittsburgh
objectclass: organization
objectclass: top

dn: uid=jaw171, o=University of Pittsburgh, c=US
cn: jaw171
sn: jaw171
givenName: jaw171
uid: jaw171
objectClass: person
objectClass: top
objectClass: pittperson
userPassword: {SASL}jaw171

EOF

if ! scp -q cdsldap@cdsdbp.cssd.pitt.edu:/tmp/cds/oid_extract.txt /export/ldap/pub/ldif/oid_extract.txt;then
  syslog_error "$LINENO - Failed to get oid_extract.txt from CDS, exiting" "NOC-NETCOOL-TICKET"
  exit 1
fi

# Add the objects to the LDIF
cat /export/ldap/pub/feed/oid_extract.txt >> /export/ldap/pub/ldif/oid_data.ldif


# Import the new data to a temporary database
echo "$($time) - Importing new data"
rm -rf /export/ldap/pub/build
mkdir -p /export/ldap/pub/build
cp /export/ldap/pub/bdb/DB_CONFIG /export/ldap/pub/build/DB_CONFIG
if ! slapadd -c -f /etc/openldap/slapd-build.conf -l /export/ldap/pub/ldif/oid_data.ldif;then
  syslog_error "$LINENO - Error while importing new data into OpenLDAP, continuing anyway"
fi


# Stop slapd
echo "$($time) - Stopping slapd"
if ! service slapd stop;then
  syslog_error "$LINENO - Failed to stop slapd, exiting" "NOC-NETCOOL-ALERT"
  exit 1
fi

service slapd status
status=$?
if [ "$status" != "3" ];then
  syslog_error "$LINENO - Failed to stop slapd though it claimed it was stopped, exiting" "NOC-NETCOOL-ALERT"
  exit 1
fi


# Move the old production database out, move the build database in
echo "$($time) - Moving databases and changing permissions/ownership"
if [ -d "/export/ldap/pub/bdb_yesterday" ];then
  if ! rm -rf /export/ldap/pub/bdb_yesterday;then
    syslog_error "$LINENO - Failed to remove yesterday's copy of the OpenLDAP database, directory.pitt.edu is down!" "NOC-NETCOOL-ALERT"
    exit 1
  fi
fi

if ! mv /export/ldap/pub/bdb /export/ldap/pub/bdb_yesterday;then
  syslog_error "$LINENO - Failed to move the current OpenLDAP database, directory.pitt.edu is down!" "NOC-NETCOOL-ALERT"
  exit 1
fi

if ! mv /export/ldap/pub/build /export/ldap/pub/bdb;then
  syslog_error "$LINENO - Failed to move the build OpenLDAP database, directory.pitt.edu is down!" "NOC-NETCOOL-ALERT"
  exit 1
fi


# Fix permissions/ownership
echo "$($time) - Fixing permissions and ownership"
if ! chown -R ldap:ldap /export/ldap/pub/bdb;then
  syslog_error "$LINENO - Failed to change ownership on the new OpenLDAP database, directory.pitt.edu is down!" "NOC-NETCOOL-ALERT"
  exit 1
fi

find /export/ldap -type d -exec chmod 700 "{}" \;
find /export/ldap -type f -exec chmod 600 "{}" \;
chmod 701 /export/ldap/pub
chmod 701 /export/ldap
chmod 701 /export


# Start slapd
echo "$($time) - Starting slapd"
if ! service slapd start;then
  syslog_error "$LINENO - Failed to start slapd, directory.pitt.edu is down!" "NOC-NETCOOL-ALERT"
  exit 1
fi


# Test LDAP
echo "$($time) - Testing slapd"
sleep 2
if [ $(ldapsearch -LLLx -H ldap://127.0.0.1 -b "c=US" "(uidNumber=563339)" | grep -c "uidNumber=563339") = 0 ];then
  syslog_error "$LINENO - Failed to query LDAP, directory.pitt.edu is down or corrupted!" "NOC-NETCOOL-ALERT"
  exit 1
fi


# Clean up old backups
echo "$($time) - Removing old backups"
ls -1 -t /export/ldap/pub/backup/dump-*.ldif | awk '{ if (NR > 30) {print}}' | xargs rm -f


# echo "" | mail -s "Directory.pitt.edu CDS import: Success" cdsprocessstatus@cssd.pitt.edu
echo "##### $(date) - Completed run of $script #####"