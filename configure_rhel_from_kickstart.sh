#!/bin/bash
# Description: Install NOC tools and perform post-install tasks for RHEL 6
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.3
# Last change: Updated for RHEL 6.3, Netbackup 7.5 and OMSA 7.0, removed exit on failure, send STDERR to a file, other changes

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

script="${0##*/}"
working_dir="/var/tmp"
netbackup_tar="/root/netbackup_7.5_rhel.tgz"
netcool_tar="/root/netcool-ssm-4.0.0-906-fp10-linux-x86.tar.gz"


function print_error {
  # Usage: print_error "Some error text"
  
  echo -e "\e[00;31m${1}\e[00m" 1>&2
  read -p "Hit enter to continue..."
}


# Send STDERR to a file in addition to the console
exec 2> >(tee /root/build.err >&2)


echo "#####"
read -p "Hit enter to set the hostname and IP.  Hostname should be the FQDN."
echo "#####"
system-config-network-tui || print_error "ERROR - $LINENO - Failed to configure networking."
if [ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
  cp /etc/sysconfig/network-scripts/ifcfg-eth0 /var/tmp/ifcfg-eth0.orig || print_error "ERROR - $LINENO - Failed to back up ifcfg-eth0."
  sed -i 's/^ONBOOT.*/ONBOOT=yes/' /etc/sysconfig/network-scripts/ifcfg-eth0 || print_error "ERROR - $LINENO - Failed to configure networking."
elif [ -f /etc/sysconfig/network-scripts/ifcfg-em1 ]; then
  /etc/sysconfig/network-scripts/ifcfg-em1 /var/tmp/ifcfg-em1.orig || print_error "ERROR - $LINENO - Failed to back up ifcfg-em0."
  sed -i 's/^ONBOOT.*/ONBOOT=yes/' /etc/sysconfig/network-scripts/ifcfg-em1 || print_error "ERROR - $LINENO - Failed to configure networking."
fi

echo "Restarting networking."
service network restart || print_error "ERROR - $LINENO - Failed to restart networking."

echo "Setting hostname."
new_hostname=$(awk -F'=' '/^HOSTNAME/ {print $2}' /etc/sysconfig/network)
hostname "$new_hostname" || print_error "ERROR - $LINENO - Failed to set hostname."


echo "#####"
echo "Disabling IPv6."
cp /etc/sysconfig/network{,.orig} || print_error "ERROR - $LINENO - Failed to back up /etc/sysconfig/network."
if ! grep "NETWORKING_IPv6" /etc/sysconfig/network >/dev/null; then
  echo "NETWORKING_IPv6=no" >> /etc/sysconfig/network || print_error "ERROR - $LINENO - Failed to disable IPv6."
fi
echo "#####"


echo "#####"
read -p "Would you like to register to Red Hat Network (RHN). y or n " rhn_y_or_n
echo "#####"
if [[ "$rhn_y_or_n" == "y" ]];then
  rhn_register || print_error "ERROR - $LINENO - Failed to register to RHN." 1
else
  echo "Skipping RHN."
fi


echo "#####"
echo "Starting NetCool installation."
echo "#####"
mkdir -p "$working_dir/netcool" || print_error "ERROR - $LINENO - Failed to create $working_dir/netcool."
cd "$working_dir/netcool" || print_error "ERROR - $LINENO - Failed to cd to $working_dir/netcool."
tar xzf "$netcool_tar" || print_error "ERROR - $LINENO - Failed to extract $netcool_tar."
./netcool-ssm-4.0.0-906-linux-x86.installer || print_error "ERROR - $LINENO - Failed to install NetCool."
sleep 2
./ssm40-fixpack10-linux-x86.run || print_error "ERROR - $LINENO - Failed to update NetCool."

cd "$working_dir" || print_error "ERROR - $LINENO - Failed to cd to $working_dir."
rm -rf "$working_dir/netcool" || print_error "ERROR - $LINENO - Failed to remove $working_dir/netcool."


echo "#####"
echo "Starting NetBackup installation.  Be patient while the archive extracts."
echo "#####"
mkdir -p "$working_dir/netbackup" || print_error "ERROR - $LINENO - Failed to create $working_dir/netbackup."
cd "$working_dir/netbackup" || print_error "ERROR - $LINENO - Failed to cd to $working_dir/netbackup."
tar xzf "$netbackup_tar" || print_error "ERROR - $LINENO - Failed to extract $netbackup_tar."
cd "$working_dir/netbackup/netbackup_7.5_rhel" || print_error "ERROR - $LINENO - Failed to cd to $working_dir/netbackup/NetBackup_7.1_RHEL."
./install || print_error "ERROR - $LINENO - Failed to install NetBackup."

cat<< EOF_bp.conf >> /usr/openv/netbackup/bp.conf || print_error "ERROR - $LINENO - Failed to add NetBackup servers to /usr/openv/netbackup/bp.conf."
SERVER = nb-ms-01.cssd.pitt.edu
SERVER = nb-ms-02.cssd.pitt.edu
SERVER = nb-ms-03.cssd.pitt.edu
SERVER = nb-ms-04.cssd.pitt.edu
SERVER = nb-unixsnap-01.cssd.pitt.edu
SERVER = nb-winsnap-01.cssd.pitt.edu
SERVER = nb-winsnap-02.cssd.pitt.edu
EOF_bp.conf

cat<< EOF_exclude_list > /usr/openv/netbackup/exclude_list || print_error "ERROR - $LINENO - Failed to create NetBackup exclude list at /usr/openv/netbackup/exclude_list."
/proc
/sys
/selinux
/mnt
/media
/afs
/dev/shm
EOF_exclude_list

cd "$working_dir" || print_error "ERROR - $LINENO - Failed to cd to $working_dir." 1
rm -rf "$working_dir/netbackup" || print_error "ERROR - $LINENO - Failed to remove $working_dir/netbackup."

if grep -i "vmware" /var/log/dmesg >/dev/null;then
  echo "#####"
  echo "Please install VMware Tools."
  echo "#####"
elif grep -i "dell" /var/log/dmesg;then
  echo "#####"
  echo "Starting Dell Open Manage Installation."
  echo "#####"
  /usr/local/bin/dellomsa_7.0.sh || print_error "ERROR - $LINENO - Failed to run Dell OMSA script."
  yum install srvadmin-argtable2 srvadmin-base srvadmin-deng srvadmin-hapi srvadmin-isvc srvadmin-itunnelprovider srvadmin-iws \
srvadmin-jre srvadmin-omacore srvadmin-omcommon srvadmin-omilcore srvadmin-smcommon srvadmin-smweb srvadmin-standardAgent \
srvadmin-storage srvadmin-storageservices srvadmin-storelib srvadmin-storelib-sysfs srvadmin-sysfsutils srvadmin-webserver srvadmin-xmlsup || print_error "ERROR - $LINENO - Failed to install Dell OMSA." 1
  cp /opt/dell/srvadmin/etc/omauth/omauth.el6{,.orig} || print_error "ERROR - $LINENO - Failed to install Dell OMSA."
  cat << EOF > /opt/dell/srvadmin/etc/omauth/omauth.el6 || print_error "ERROR - $LINENO - Failed to configure PAM for Dell OMSA."
#%PAM-1.0
# This file *MUST* be UNIX format. Please do not edit it with stupid editors that dont preserve line endings, or you *WILL* break OMSA.
auth      include       system-auth
account   include       system-auth
EOF
 /etc/init.d/dataeng disablesnmp || print_error "ERROR - $LINENO - Failed to disable SNMP for Dell OMSA."
 /opt/dell/srvadmin/sbin/srvadmin-services.sh start || print_error "ERROR - $LINENO - Failed to start Dell OMSA."
else
 echo -e "\e[01;32mUnable to determine if this box is Dell or VMware.  Whatever hardware this is, you need to install the vendor's hardware \
management tools (i.e. VMware Tools or Open Manage).\e[00m"
fi


echo "#####"
echo "Starting automatic edit to grub.conf"
echo "#####"
cp /boot/grub/grub.conf{,.orig} || print_error "ERROR - $LINENO - Failed to back up original /boot/grub/grub.conf."
sed -e 's/ rhgb//g;s/ quiet//g' /boot/grub/grub.conf > /var/tmp/grub.conf || print_error "ERROR - $LINENO - Failed to automatically edit grub.conf."


echo "#####"
read -p "Hit enter to review the new grub.conf."
echo "#####"
less /var/tmp/grub.conf || print_error "ERROR - $LINENO - Failed to review the new grub.conf."
echo "#####"
read -p "Should the new grub.conf be in place? y or n: " grub_y_or_n
echo "#####"
if [[ "$grub_y_or_n" == "y" ]];then
  mv /var/tmp/grub.conf /boot/grub/grub.conf || print_error "ERROR - $LINENO - Failed to put the new grub.conf in place."
  echo "#####"
else
  echo "#####"
  echo "Not putting the new grub.conf into place, leaving it as /var/tmp/grub.conf."
  echo "#####"
fi


echo "#####"
read -p "Hit enter to edit pam_ldap.conf to add the LDAP username and password."
cp /etc/pam_ldap.conf{,.orig} || print_error "ERROR - $LINENO - Failed to back up /etc/pam_ldap.conf." 1
cp /etc/pam_ldap.conf /var/tmp/ || print_error "ERROR - $LINENO - Failed to copy /etc/pam_ldap.conf to /var/tmp." 1
vi /var/tmp/pam_ldap.conf || print_error "ERROR - $LINENO - Failed to edit /var/tmp/pam_ldap.conf." 1
echo "#####"
read -p "Should the new pam_ldap.conf be in place? y or n: " pam_ldap_y_or_n
echo "#####"
if [[ "$pam_ldap_y_or_n" == "y" ]];then
  mv /var/tmp/pam_ldap.conf /etc/pam_ldap.conf || print_error "ERROR - $LINENO - Failed to put the new pam_ldap.conf in place." 1
else
  echo "#####"
  echo "Not putting the new pam_ldap.conf into place, leaving it as /var/tmp/pam_ldap.conf."
  echo "#####"
fi


echo "#####"
echo "Configuring default startup daemons."
echo "#####"
/usr/local/bin/chkconfig-set-default-daemons.sh || print_error "ERROR - $LINENO - Failed to check and configure startup daemons." 1


echo "#####"
echo "Setting the new root password."
passwd root
echo "#####"


echo "#####"
read -p "Would you like to install all updates now? y or n: " yumupdate_y_or_n
if [[ "$yumupdate_y_or_n" == "y" ]];then
  yum -y update || print_error "ERROR - $LINENO - Failed to run 'yum update'." 1
  echo "#####"
else
  echo "#####"
  echo -e "\e[01;32mSkipping updates.  Be sure to run 'yum update' later.\e[00m"
  echo "#####"
fi


echo "#####"
echo "Install complete."
if grep -i vmware /var/log/dmesg >/dev/null;then
  echo "Install VMware tools manually."
elif grep -i dell /var/log/dmesg >/dev/null;then
  echo "Ensure Dell OMSA is working by going to https://$HOSTNAME:1311"
else
  echo -e "\e[01;32mYou must install vendor supplied hardware management tools manually.\e[00m"
fi
echo -e "\e[01;33mPlease add this server to the AssetDB and add the root password to Authvault.\e[00m"

touch /root/.firstbootconfigdone