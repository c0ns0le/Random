#!/bin/bash
#Name: configure_rhel_from_kickstart.sh
#Description: Bash script to install NOC tools and perform post-install tasks for RHEL 6.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.3 - 2011-12-19 - Finished pam_ldap.conf section, added better yum update, - Jeff White
#
# 0.2 - 2011-11-22 - Added /etc/pam_ldap.conf section, changed grub.conf review from vi to less, added yum update, added IPv6 disabler, added hostname changer. - Jeff White
#
# 0.1 - 2011-11-17 - Initial version. - Jeff White
#
#####

script="${0##*/}"
working_dir="/var/tmp"
netbackup_tar="/root/NetBackup_7.1_RHEL_x86_and_x64.tar.gz"
netcool_tar="/root/netcool-ssm-4.0.0-906-fp10-linux-x86.tar.gz"

function _print-stderr-then-exit { # Usage: _print-stderr-then-exit "Some error text" exitnumber
  echo "$1" 1>&2
  logger -p err "$1"
  exit $2
}
function _print-stdout-then-exit { # Usage: _print-stderr-then-exit "Some text" exitnumber
  echo "$1"
  exit $2
}
function _log-entry { # Usage: _log-entry priority "Some text."
logger -p $1 "$2"
}

echo "#####"
read -p "Hit enter to set the hostname and IP.  Hostname should be the FQDN."
echo "#####"
system-config-network-tui || _print-stderr-then-exit "ERROR - $LINENO - Failed to configure networking in script $script." 1

echo "#####"
echo "Setting hostname."
new_hostname=$(awk -F'=' '/^HOSTNAME/ {print $2}' /etc/sysconfig/network)
if [ -z "$new_hostname" -o "$new_hostname" == "localhost.localdomain" ];then
  echo "New hostname is blank or localhost, did you set it?"
else
  hostname "$new_hostname"
fi
echo "#####"

echo "#####"
echo "Disabling IPv6."
cp /etc/sysconfig/network{,.orig} || _print-stderr-then-exit "ERROR - $LINENO - Failed to back up /etc/sysconfig/network in script $script." 1
if ! grep "NETWORKING_IPv6" /etc/sysconfig/network >/dev/null ;then
  echo "NETWORKING_IPv6=no" >> /etc/sysconfig/network || _print-stderr-then-exit "ERROR - $LINENO - Failed to disable IPv6 in script $script." 1
fi
echo "#####"

echo "#####"
read -p "Would you like to register to Red Hat Network (RHN). y or n " rhn_y_or_n
echo "#####"
if [[ "$rhn_y_or_n" == "y" ]];then
  rhn_register || _print-stderr-then-exit "ERROR - $LINENO - Failed to register to RHN in script $script." 1
else
  echo "Skipping RHN."
fi

echo "#####"
echo "Starting NetCool installation."
echo "#####"
mkdir -p "$working_dir/netcool" || _print-stderr-then-exit "ERROR - $LINENO - Failed to create $working_dir/netcool in script $script." 1
cd "$working_dir/netcool" || _print-stderr-then-exit "ERROR - $LINENO - Failed to cd to $working_dir/netcool in script $script." 1
tar xzf "$netcool_tar" || _print-stderr-then-exit "ERROR - $LINENO - Failed to extract $netcool_tar in script $script." 1
./netcool-ssm-4.0.0-906-linux-x86.installer || _print-stderr-then-exit "ERROR - $LINENO - Failed to install NetCool in script $script." 1
sleep 2
./ssm40-fixpack10-linux-x86.run || _print-stderr-then-exit "ERROR - $LINENO - Failed to update NetCool in script $script." 1

cd "$working_dir" || _print-stderr-then-exit "ERROR - $LINENO - Failed to cd to $working_dir in script $script." 1
rm -rf "$working_dir/netcool" || _print-stderr-then-exit "ERROR - $LINENO - Failed to remove $working_dir/netcool in script $script." 1

echo "#####"
echo "Starting NetBackup installation.  Be patient while the archive extracts."
echo "#####"
mkdir -p "$working_dir/netbackup" || _print-stderr-then-exit "ERROR - $LINENO - Failed to create $working_dir/netbackup in script $script." 1
cd "$working_dir/netbackup" || _print-stderr-then-exit "ERROR - $LINENO - Failed to cd to $working_dir/netbackup in script $script." 1
tar xzf "$netbackup_tar" || _print-stderr-then-exit "ERROR - $LINENO - Failed to extract $netbackup_tar in script $script." 1
cd "$working_dir/netbackup/NetBackup_7.1_RHEL" || _print-stderr-then-exit "ERROR - $LINENO - Failed to cd to $working_dir/netbackup/NetBackup_7.1_RHEL in script $script." 1
./install || _print-stderr-then-exit "ERROR - $LINENO - Failed to install NetBackup in script $script." 1

cat<< EOF_bp.conf >> /usr/openv/netbackup/bp.conf || _print-stderr-then-exit "ERROR - $LINENO - Failed to add NetBackup servers to /usr/openv/netbackup/bp.conf in script $script." 1
SERVER = nb-ms-01.cssd.pitt.edu
SERVER = nb-ms-02.cssd.pitt.edu
SERVER = nb-ms-03.cssd.pitt.edu
SERVER = nb-ms-04.cssd.pitt.edu
SERVER = nb-unixsnap-01.cssd.pitt.edu
SERVER = nb-winsnap-01.cssd.pitt.edu
SERVER = nb-winsnap-02.cssd.pitt.edu
EOF_bp.conf

cat<< EOF_exclude_list > /usr/openv/netbackup/exclude_list || _print-stderr-then-exit "ERROR - $LINENO - Failed to create NetBackup exclude list at /usr/openv/netbackup/exclude_list in script $script." 1
/proc
/sys
/selinux
/mnt
/media
/afs
/dev/shm
EOF_exclude_list

cd "$working_dir" || _print-stderr-then-exit "ERROR - $LINENO - Failed to cd to $working_dir in script $script." 1
rm -rf "$working_dir/netbackup" || _print-stderr-then-exit "ERROR - $LINENO - Failed to remove $working_dir/netbackup in script $script." 1

if grep -i "vmware" /var/log/dmesg >/dev/null;then
  echo "#####"
  echo "Please install VMware Tools."
  echo "#####"
elif grep -i "dell" /var/log/dmesg;then
  echo "#####"
  echo "Starting Dell Open Manage Installation."
  echo "#####"
  /usr/local/bin/dellomsa_6.4.sh || _print-stderr-then-exit "ERROR - $LINENO - Failed to run Dell OMSA script in script $script." 1
  yum install srvadmin-argtable2 srvadmin-base srvadmin-deng srvadmin-hapi srvadmin-isvc srvadmin-itunnelprovider srvadmin-iws \
srvadmin-jre srvadmin-omacore srvadmin-omcommon srvadmin-omilcore srvadmin-smcommon srvadmin-smweb srvadmin-standardAgent \
srvadmin-storage srvadmin-storageservices srvadmin-storelib srvadmin-storelib-sysfs srvadmin-sysfsutils srvadmin-webserver srvadmin-xmlsup || _print-stderr-then-exit "ERROR - $LINENO - Failed to configure network in script $script." 1
  cp /opt/dell/srvadmin/etc/omauth/omauth.el6{,.orig} || _print-stderr-then-exit "ERROR - $LINENO - Failed to install Dell OMSA in script $script." 1
  cat << EOF > /opt/dell/srvadmin/etc/omauth/omauth.el6 || _print-stderr-then-exit "ERROR - $LINENO - Failed to configure PAM for Dell OMSA in script $script." 1
#%PAM-1.0
# This file *MUST* be UNIX format. Please do not edit it with stupid editors that dont preserve line endings, or you *WILL* break OMSA.
auth      include       system-auth
account   include       system-auth
EOF
 /etc/init.d/dataeng disablesnmp || _print-stderr-then-exit "ERROR - $LINENO - Failed to disable SNMP for Dell OMSA in script $script." 1
 /opt/dell/srvadmin/sbin/srvadmin-services.sh start || _print-stderr-then-exit "ERROR - $LINENO - Failed to start Dell OMSA in script $script." 1
else
 echo "Unable to determine if this box is Dell or VMware.  Whatever hardware this is, you need to install the vendor's hardware \
management tools (i.e. VMware Tools or Open Manage)."
fi

echo "#####"
echo "Starting automatic edit to grub.conf"
echo "#####"
cp /boot/grub/grub.conf{,.orig} || _print-stderr-then-exit "ERROR - $LINENO - Failed to back up original /boot/grub/grub.conf in script $script." 1
sed -e 's/ rhgb//g;s/ quiet//g;s/crashkernel=auto/crashkernel=192M@32M/g' /boot/grub/grub.conf > /var/tmp/grub.conf || _print-stderr-then-exit "ERROR - $LINENO - Failed to automatically edit grub.conf in script $script." 1

echo "#####"
read -p "Hit enter to review the new grub.conf."
echo "#####"
less /var/tmp/grub.conf || _print-stderr-then-exit "ERROR - $LINENO - Failed to review the new grub.conf in script $script." 1
echo "#####"
read -p "Should the new grub.conf be in place? y or n: " grub_y_or_n
echo "#####"
if [[ "$grub_y_or_n" == "y" ]];then
  mv /var/tmp/grub.conf /boot/grub/grub.conf || _print-stderr-then-exit "ERROR - $LINENO - Failed to put the new grub.conf in place in script $script." 1
  echo "#####"
else
  echo "#####"
  echo "Not putting the new grub.conf into place, leaving it as /var/tmp/grub.conf."
  echo "#####"
fi

echo "#####"
read -p "Hit enter to edit pam_ldap.conf to add the LDAP username and password."
cp /etc/pam_ldap.conf{,.orig} || _print-stderr-then-exit "ERROR - $LINENO - Failed to back up /etc/pam_ldap.conf in script $script." 1
cp /etc/pam_ldap.conf /var/tmp/ || _print-stderr-then-exit "ERROR - $LINENO - Failed to copy /etc/pam_ldap.conf to /var/tmp in script $script." 1
vi /var/tmp/pam_ldap.conf || _print-stderr-then-exit "ERROR - $LINENO - Failed to edit /var/tmp/pam_ldap.conf in script $script." 1
echo "#####"
read -p "Should the new pam_ldap.conf be in place? y or n: " pam_ldap_y_or_n
echo "#####"
if [[ "$pam_ldap_y_or_n" == "y" ]];then
  mv /var/tmp/pam_ldap.conf /etc/pam_ldap.conf || _print-stderr-then-exit "ERROR - $LINENO - Failed to put the new pam_ldap.conf in place in script $script." 1
else
  echo "#####"
  echo "Not putting the new pam_ldap.conf into place, leaving it as /var/tmp/pam_ldap.conf."
  echo "#####"
fi

echo "#####"
echo "Configuring default startup daemons."
echo "#####"
/usr/local/bin/chkconfig-set-default-daemons.sh || _print-stderr-then-exit "ERROR - $LINENO - Failed to check and configure startup daemons in script $script." 1

echo "#####"
echo "Setting the new root password."
passwd root
echo "#####"

echo "#####"
read -p "Would you like to install all updates now? y or n: " yumupdate_y_or_n
if [[ "$yumupdate_y_or_n" == "y" ]];then
  yum -y update || _print-stderr-then-exit "ERROR - $LINENO - Failed to run 'yum update' in script $script." 1
  echo "#####"
else
  echo "#####"
  echo "Skipping updates.  Be sure to run 'yum update' later."
  echo "#####"
fi

echo "#####"
echo "Install complete."
if grep -i vmware /var/log/dmesg >/dev/null;then
  echo "You must install VMware tools manually."
elif grep -i dell /var/log/dmesg >/dev/null;then
  echo "Ensure Dell OMSA is working by going to https://$HOSTNAME:1311"
else
  echo "You must install vendor supplied hardware management tools manually."
fi
echo "Don't forget to add this server to the AssetDB and tell Jeff White the root password."

touch /root/.firstbootconfigdone