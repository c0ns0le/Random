#!/bin/bash
# Description: Control VPN connection.
# Written By: Jeff White (jwhite530@gmail.com)
# Version Number: 0.5
# Revision Date: 10-19-11
# License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
# # This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

shopt -s -o noclobber

if [ -z .$BASH. ]; then
  echo "# FATAL ERROR - $LINENO - Please run this script with the BASH shell.  EXITING"
  exit 192
fi

while [ 0 ];do
if [ $(/sbin/ifconfig | grep -c "tun0") = "0" ];then
  echo "# Connected to VPN? NO"
else
  echo "# Connected to VPN? YES"
fi
if [ $(mount | grep -ic "jaw171.noc.pitt.edu") = 0 ];then
  echo "# Remote homedir mounted? NO"
else
  echo "# Remote homedir mounted? YES"
fi

echo "1) Connect/disconnect VPN"
echo "2) RDP to Jaw171-Winbox2.noc.pitt.edu"
echo "3) SSH to Jaw171-Ububox2.noc.pitt.edu"
echo "4) Mount/unmount /home/jaw171 from Jaw171-Ububox2.noc.pitt.edu"
echo "q) Quit"
read -p "# What do you want to do? " choice
case "$choice" in
  1)
    if [ $(/sbin/ifconfig | grep -c "tun0") = "0" ];then
      sudo vpnc /etc/vpnc/pitt.conf && { ping -i 10 jaw171.noc.pitt.edu > /dev/null& }
    elif [ $(mount | grep -c "jaw171.noc.pitt.edu") = "0" ];then
      if pidof ping &> /dev/null;then
	kill $(pidof ping) && sudo vpnc-disconnect
      else
	sudo vpnc-disconnect
      fi
    elif [ $(mount | grep -c "jaw171.noc.pitt.edu") != "0" ];then
      if pidof ping &> /dev/null;then
	kill $(pidof ping) && sudo umount /media/U && sudo vpnc-disconnect
      else
	sudo umount /media/jaw171-ububox2_homedir && sudo vpnc-disconnect
      fi
    fi
    sleep 1
    if [ $(awk '$1 == "nameserver" { mcount++; if (mcount == 1){ print $2 }}' /etc/resolv.conf) != "192.168.10.1" ];then
      echo "# DNS is not correct, fixing!"
      cat << EOF > /tmp/resolv.conf
search jealwh.local
nameserver 192.168.10.1
EOF
      sudo cp /tmp/resolv.conf /etc/resolv.conf
	if [ "$?" != "0" ];then
	  echo "# Fixing DNS failed!"
	  exit 1
	fi
    fi ;;
  2)
    rdesktop jaw171.noc.pitt.edu -z -x l -a 16 -k en-us -g 1665x950 -u "pitt\jaw171" -T Jaw171-Winbox2.noc.pitt.edu& ;;
  3)
    ssh -YC jaw171@jaw171.noc.pitt.edu ;;
  4)
    if [ $(mount | grep -ic "jaw171.noc.pitt.edu") = 0 ];then
      sshfs -o allow_root,idmap=user,compression=yes jaw171@jaw171.noc.pitt.edu:/home/jaw171 /media/jaw171-ububox2_homedir
    else
      sudo umount /media/jaw171-ububox2_homedir
    fi

    ;;
  q | Q)
    break ;;
  *)
    echo "Huh?  I only understand the options below." ;;
esac
done
