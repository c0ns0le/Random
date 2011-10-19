#!/bin/bash
#Description: Bash script to control startup daemons with chkconfig.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.2
#Revision Date: 6-22-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

chkconfigbin="/sbin/chkconfig"

#Determine RHEL version
if [ -f /etc/redhat-release ];then
  isrhel5=$(awk '{if (/5/&&!/2\./&&!/3\./&&!/4\./) { print "1";nextfile } else { print "0" }}' /etc/redhat-release)
  isrhel6=$(awk '{if (/6\./&&!/2\./&&!/3\./&&!/4\./&&!/5\./) { print "1";nextfile } else { print "0" }}' /etc/redhat-release)
else
  echo "# $LINENO Error - This box does not appear to be RHEL."
  exit 0
fi

#Prep
: > /tmp/badcurservices.lst
: > /tmp/goodservices.lst
: > /tmp/curgoodservicedisabled.lst

if [ "$($chkconfigbin --list | grep -c 'xinetd based services')" != "0" ];then
  echo "Note: Found xinetd based services, you'll have to control them manually."
fi

if [ "$isrhel5" = "1" ];then
echo "System appears to be RHEL 5"
  cat << EOF > /tmp/goodservices.lst #Add good services here!
acpid
auditd
crond
dsm_om_connsvc
dsm_om_shrsvc
dataeng
irqbalance
kdump
kudzu
lvm2-monitor
microcode-ctl
multipathd
network
ntpd
sendmail
sshd
syslog
vmware-tools
xinetd
netbackup
EOF
elif [ "$isrhel6" = "1" ];then
echo "System appears to be RHEL 6"
  cat << EOF > /tmp/goodservices.lst #Add good services here!
acpid
auditd
crond
dsm_om_connsvc
dsm_om_shrsvc
dataeng
irqbalance
kdump
lvm2-monitor
microcode-ctl
multipathd
network
postfix
ntpd
rsyslog
sshd
sysstat
udev-post
vmware-tools
sendmail
xinetd
netbackup
EOF
else
  echo "# $LINENO Error - This box does not appear to be RHEL 5 or 6."
  exit 0
fi
  
#This section disables bad services on RHEL.
$chkconfigbin --list | grep ':on' | cut -f1 | while read -r eachcurrentenableddaemon;do
  grep $eachcurrentenableddaemon /tmp/goodservices.lst &> /dev/null
    if [ "$?" != "0" ];then
      echo "$eachcurrentenableddaemon" >> /tmp/badcurservices.lst
    fi
  done
if [ $(cat /tmp/badcurservices.lst | wc -l) != "0" ];then
  echo "Found $(cat /tmp/badcurservices.lst | wc -l) bad services."
  for eachbadservice in $(cat /tmp/badcurservices.lst);do
  read -p "Would you like to disable $eachbadservice? y or n: " answertodisablebadservices
    if [ "$answertodisablebadservices" = "y" ];then
      echo "Disabling $eachbadservice."
      $chkconfigbin --level 0123456 $eachbadservice off
    else
      echo "Leaving $eachbadservice alone."
    fi
  done
else 
  echo "No bad services were found."
fi

#This section enables good services on RHEL.
for eachgoodservice in $(cat /tmp/goodservices.lst);do
  $chkconfigbin --list | grep $eachgoodservice | awk '!/:on/&&!/xinetd based/ {print $1}' >> /tmp/curgoodservicedisabled.lst
done
sed '/ntpdate/d' /tmp/curgoodservicedisabled.lst > /tmp/curgoodservicedisabled.lst
if [ $(cat /tmp/curgoodservicedisabled.lst | wc -l) != "0" ];then
  echo "Found $(cat /tmp/curgoodservicedisabled.lst | wc -l) good services not enabled."
  for eachgoodcurrentservicenoton in $(cat /tmp/curgoodservicedisabled.lst);do
    read -p "Would you like to enable $eachgoodcurrentservicenoton? y or n: " answertoenablegoodservices
    if [ "$ANSWERTOENABLEGOODSERVICES" = "y" ];then
      echo "Enabling $eachgoodcurrentservicenoton."
      $chkconfigbin $eachgoodcurrentservicenoton on
    else
      echo "Leaving $eachgoodcurrentservicenoton alone."
    fi
  done
else
  echo "All good services are set to start on boot."
fi