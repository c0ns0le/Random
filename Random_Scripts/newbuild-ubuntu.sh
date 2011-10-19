#!/bin/bash
#Description: Bash script to set up a new Ubuntu install.
#Written By: Jeff White (jwhite530@gmail.com)
#Version Number: 0.2.6
#Revision Date: 10-15-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

SCRIPT=${0##*/}
DEFPKGLST="build-essential linux-headers-`uname -r` ntpdate ntp mailutils ssmtp nfs-common snmp snmpd ia32-libs ethtool python-software-properties"
TIME='date +%r'

function sethostname {
CURHOSTNAME=$HOSTNAME
read -p "# The current hostname is $CURHOSTNAME, would you like to change it? y or n " SETHOSTNAMEANSWER
if [ "$SETHOSTNAMEANSWER" = "y" ];then
  read -p "# Please enter the new hostname (FQDN): " NEWHOSTNAME
  echo "$NEWHOSTNAME" > /etc/hostname
  HOSTNAME=$NEWHOSTNAME
elif [ "$SETHOSTNAMEANSWER" = "n" ];then
  echo "# Leaving hostname as is."
else
  echo "# Huh?  I only understand y or n."
  sethostname
fi
}

function setipinfo {
ISETH0STATIC=$(awk '/eth0/&&/static/ { print $0 }' /etc/network/interfaces | wc -l)
ISETH0DHCP=$(awk '/eth0/&&/dhcp/ { print $0 }' /etc/network/interfaces | wc -l)
if [ "$ISETH0STATIC" = "1" ];then
  read -p "# eth0 has a static IP of $(ifconfig eth0 | grep 'inet addr:'| cut -d: -f2 | awk '{ print $1 }') already, would you like to change it or other IP settings? y or n " SETETH0IPANSWERSTATIC
elif [ "$ISETH0DHCP" = "1" ];then
  read -p "# eth0 is set to DHCP, do you want to set a static IP? y or n " SETETH0IPANSWERDHCP
fi


if [ "$SETETH0IPANSWERSTATIC" = "y" ];then
  echo "# I'm not very good at reconfiguring a static IP, you'll have to do it for me.  Don't worry, I'll make a backup copy of the config file."
  cp /etc/network/interfaces /etc/network/interfaces-`date +%m-%d-%Y` || echo " #ERROR - $LINENO - Unable to make a backup of /etc/network/interfaces."
  read -p "# Press enter to edit /etc/network/interfaces."
  nano /etc/network/interfaces
  /etc/init.d/networking restart || echo "# ERROR - $LINENO - Unable to restart networking."
elif [ "$SETETH0IPANSWERDHCP" = "y" ];then
  read -p "# Enter the IP: " SETIP
  read -p "# Enter the network address: " SETNETADR
  read -p "# Enter the broadcast address: " SETBCASTADR
  read -p "# Enter the netmask (dotted decimal format): " SETNETADR
  read -p "# Enter the gateway: " SETGWADR
  read -p "# Enter the DNS name servers: " SETDNSSRV
  read -p "# Enter the DNS search suffix (usually the internal domain name): " SETDNSSRCH
  cp -f /etc/network/interfaces /etc/network/interfaces-`date +%m-%d-%Y` || echo "# ERROR - $LINENO - Unable to make a backup of /etc/network/interfaces."
  awk 'match($0,/eth0/) == 0 { print $0 }' /etc/network/interfaces > /tmp/interfaces #Prints all lines which don't contain eth0 to the temp file.
  awk '(/eth0/&&!/^#/)&&(/dhcp/||/auto/) { print "#"$0 }' /etc/network/interfaces >> /tmp/interfaces #Appends old lines to the temp file.
  echo "# Options entered by $SCRIPT" >> /tmp/interfaces
  echo "auto eth0" >> /tmp/interfaces
  echo "iface eth0 inet static" >> /tmp/interfaces
  echo "address $SETIP" >> /tmp/interfaces
  echo "network $SETNETADR" >> /tmp/interfaces
  echo "broadcast $SETBCASTADR" >> /tmp/interfaces
  echo "netmask $SETNETADR" >> /tmp/interfaces
  echo "gateway $SETGWADR" >> /tmp/interfaces
  echo "dns-nameservers $SETDNSSRV" >> /tmp/interfaces
  echo "dns-search $SETDNSSRCH" >> /tmp/interfaces
  cp -f /tmp/interfaces /etc/network/interfaces || echo "# ERROR - $LINENO - Unable to overwrite /etc/network/interfaces with /tmp/interfaces."
  /etc/init.d/networking restart || echo "# ERROR - $LINENO - Unable to restart networking."
elif [ "$SETETH0IPANSWERSTATIC" = "n" -o "$SETETH0IPANSWERDHCP" = "n" ];then
  echo "# Leaving eth0's current configuration alone."
else
  echo "# Huh?  I only understand y or n."
  setipinfo
fi
}

echo "# $($TIME) - Checking the sanity of script."
if [ -z .$BASH. ]; then
  echo "# FATAL ERROR - $LINENO - Please run this script with the BASH shell.  EXITING"
  exit 192
elif [ $UID != 0 ]; then
  echo "# FATAL ERROR - $LINENO - This script must be ran as root, your UID is $UID.  EXITING"
  exit 1
#elif [ $(grep -c "Ubuntu" /etc/issue) = 0 ]; then
#  echo "# FATAL ERROR - $LINENO - This script must be ran in Ubuntu only.  EXITING"
#  exit 1
#elif [ $(egrep -c '10.04|10.10' /etc/issue) = 0 ];then
#  echo "# WARNING - This script was designed for Ubuntu 10.04, which this box is not.  That's not a problem, just be aware of possible issues."
fi

#Backing up files, and rotate the old backups.
for EACHFILE in /etc/network/interfaces /etc/fstab /etc/timezone /etc/ssmtp/ssmtp.conf /etc/hostname;do
  if [ -f $EACHFILE ];then
    NUMOLDBAK=$(ls | grep -c $EACHFILE.bak-`date +%m-%d-%Y`-)
    while (( $NUMOLDBAK > 0 ));do
      mv $EACHFILE.bak-$(date +%m-%d-%Y)-$NUMOLDBAK $EACHFILE.bak-$(date +%m-%d-%Y)-$(( $NUMOLDBAK + 1 )) || echo "# ERROR - $LINENO - Unable to rotate old backup of $EACHFILE."
      NUMOLDBAK=$(( $NUMOLDBAK - 1 ))
    done
      if [ -f $EACHFILE.bak-$(date +%m-%d-%Y) ]; then
	mv $EACHFILE.bak-$(date +%m-%d-%Y) $EACHFILE.bak-$(date +%m-%d-%Y)-1 || echo "# ERROR - $LINENO - Unable to rotate previous backup of $EACHFILE."
      fi
    cp $EACHFILE $EACHFILE.bak-$(date +%m-%d-%Y) || echo "# ERROR - $LINENO - Unable to create backup of $EACHFILE."
  fi
done

echo "# $($TIME) - Setting up the network."
echo "# WARNING - Do not change IP settings from an SSH session!"
sethostname || echo "# ERROR - $LINENO - Unable to hostname."
setipinfo || echo "# ERROR - $LINENO - Unable to set IP settings."

echo "# $($TIME) - Updating package list."
apt-get update || echo "# ERROR - $LINENO - Unable to update package list."

echo "# $($TIME) - Installing aptitude."
apt-get install aptitude || echo "# ERROR - $LINENO - Unable to install aptitude."

echo "# $($TIME) - Updating installed packages."
aptitude -y safe-upgrade

echo "# $($TIME) - Installing additional packages."
aptitude -y -Z --show-why --show-version --allow-untrusted install $DEFPKGLST || echo "# ERROR - $LINENO - Error installing new packages."

echo "# $($TIME) - Adjusting time settings."
echo "America/New_York" 1> /etc/timezone || echo "# ERROR - $LINENO - Unable to adjust timezone"
dpkg-reconfigure --frontend noninteractive tzdata || echo "# ERROR - $LINENO - Unable to adjust timezone"

echo "# $($TIME) - Setting up mail."
if [ ! -f /etc/ssmtp/ssmtp.conf -o $(grep -c "jwhite530.auto" /etc/ssmtp/ssmtp.conf) = 0 ];then
  aptitude remove postfix sendmail || echo "# ERROR - $LINENO - Unable to remove sendmail and postfix."
  addgroup ssmtp || echo "# ERROR - $LINENO - Unable to add group ssmtp."
  addgroup white ssmtp || echo "# ERROR - $LINENO - Unable to add user 'white' to the ssmtp group."
  printf "root=jwhite530.auto@gmail.com\nmailhub=smtp.gmail.com:465\nrewriteDomain=gmail.com\nAuthUser=jwhite530.auto # (without @gmail.com)\nAuthPass=X7gV3JVv9QDJAE5LmWbwAiiDd\nFromLineOverride=YES\nUseTLS=YES\n" 1> /etc/ssmtp/ssmtp.conf
  chown root:ssmtp /etc/ssmtp/ssmtp.conf || echo "# ERROR - $LINENO - Unable to modify ownership on ssmtp.conf, email credentials may be readable by others!"
  chmod 640 /etc/ssmtp/ssmtp.conf || echo "# ERROR - $LINENO - Unable to modify permissions on ssmtp.conf, email credentials may be readable by others!"
else
  echo "# $LINENO - ssmtp.conf appears to already be set up.  I'll skip this section of the script."
fi

echo "# $($TIME) - Setting up remote NFS exports on /etc/fstab."
if grep "192.168.1.150" /etc/fstab > /dev/null;then
  echo "# $LINENO - fstab seems to already have Cyan's NFS export.  I'll skip this section of the script."
else
  mkdir /media/Data || echo "# ERROR - $LINENO - Unable to create directory /media/Data."
  chown white:white /media/Data || echo "# ERROR - $LINENO - Unable to set ownership on /media/Data."
  printf "#NFS export from Cyan\n\
192.168.1.150:/media/Data /media/Data nfs defaults 0 0\n\
#NFS export from Teal\n\
#192.168.1.156:/media/Backup /media/Data nfs defaults 0 0\n" >> /etc/fstab || echo "# ERROR - $LINENO - Unable to add Cyan's nfs export to fstab."
  mount /media/Data || echo "# ERROR - $LINENO - Unable to mount Cyan's nfs export."
fi

echo "# $($TIME) - Setting up backupuser."
if [ $(grep -c backupuser /etc/passwd) = 0 ];then
  adduser backupuser --disabled-password --shell /bin/bash || echo "# ERROR - $LINENO - Unable to create user 'backupuser'"
  addgroup backupuser ssmtp || echo "# ERROR - $LINENO - Unable to add user 'backupuser' to the ssmtp group."
  mkdir -p /home/backupuser/.ssh || echo "# ERROR - $LINENO - Unable to create .ssh directory for backupuser."
  echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA11ZcbJ9u7EqWHOENf1Smo1wCPJlkr6IRerA0VqHeff6nrEU1YIfnVWmvM0y5umUEr4/kkec4VuzOX8D6s7O3K/b0rWOlZr1Ij9VyYpOP56h/jkuyvuhHEGGpej3kCkeu7KTioNJaLfP3Sg0Oib45/ZGp2\
GmMGBB62u5pHP4zV/Ux4rDCEEbvoXWa7/QWCOvdtqEg6PvxzCaI91DVxqCK86uiKFz0h3fRf+WMrJTHBCBWuMBGoz+wMcPCIjxsZKOPSWAY4aGfg+L1WhCM3C89zqRt53nGB639KUbClnS4otmmRTBYXJd4BuA/yWPYLxPjpgXiTlFmCTG+305/tXkTyQ== \
white@cyan" > /home/backupuser/.ssh/authorized_keys
  chmod 600 /home/backupuser/.ssh/authorized_keys || echo "# ERROR - $LINENO - Unable to set permissions on SSH's authorized_keys for backupuser."
  chown backupuser:backupuser -R /home/backupuser/.ssh || echo "# ERROR - $LINENO - Unable to set ownership on .ssh directory for backupuser."
  echo "backupuser $HOSTNAME = NOPASSWD: /usr/bin/rsync,/usr/bin/aptitude" >> /etc/sudoers || echo "# ERROR - $LINENO - Unable to configure sudo privledges for 'backupuser'."
else
  echo "# $LINENO - User backupuser appears to already exist.  I'll skip this section of the script."
fi

echo "# $($TIME) - Printing system details."
echo "Hostname: $HOSTNAME"
echo "Install Date: $(last | awk '/wtmp/ { print $3,$4,$5,$6,$7 }')"
echo "Config Date: $(date +%c)"
echo "Kernel: $(uname -a)"
echo "Network information (eth0):"
echo "     Speed: $(ethtool eth0 | awk -F': ' '/Speed/ {print $2}')"
echo "     Duplex: $(ethtool eth0 | awk -F': ' '/Duplex/ {print $2}')"
echo "     IP: $(ifconfig eth0 | grep 'inet addr:'| cut -d: -f2 | awk '{ print $1 }')"
echo "     Netmask: $(ifconfig eth0 | grep 'inet addr:'| cut -d: -f4 | awk '{ print $1 }')"
echo "     Gateway: $(route -n | awk '/UG/ { print $2 }') via $(route | awk '/UG/ { print $8 }')"
echo "     DNS: $(cat /etc/resolv.conf | tr '\n' '+')"
printf "# All done, but you should reboot and run:\nsudo aptitude safe-upgrade\necho \"Test from $HOSTNAME\" | mail -s \"Test from $HOSTNAME\" jwhite530@gmail.com\n"
