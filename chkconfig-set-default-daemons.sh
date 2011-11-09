#!/bin/bash
#Description: Bash script to control startup daemons with chkconfig.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)

##### License:
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Notes:
# This was written for an environment where GlusterFS is used for home directories and the directory structure 
# looks like /home/cssd/jaw171 where /home is where the volume is mounted, cssd is the group name, and jaw171 is the user
# name.  This script is designed to figure out that it should check the directory quota of /cssd if any of '-u jaw171', 
# '-g cssd', or '-d /cssd' is given as an arguement.  See the _print_usage function for more info.
#####

##### Revision history:
# Version 0.4 - 2011-11-09 - Complete re-write. - Jeff White
#####

script="${0##*/}"
chkconfigbin="/sbin/chkconfig"
temp_dir="/tmp/.$script"
num_bad_enabled_daemons_found="0"
num_bad_enabled_daemons_disabled="0"
num_good_disabled_daemons_found="0"
num_good_disabled_daemons_enabled="0"

function _print_stderr { # Usage: _print_stderr "Some error text"
echo "$1" 1>&2
}

function _print_stderr_then_exit { # Usage: _print_stderr_then_exit "Some error text" exit_number
echo "$1" 1>&2
rm -rf "$temp_dir"
exit $2
}

function _print_stdout_then_exit { # Usage: _print_stdout_then_exit "Some error text" exit_number
echo "$1"
rm -f "$temp_dir"
exit $2
}

mkdir -p "$temp_dir"

#Determine if we are on and what the RHEL version is.
if [ -f /etc/redhat-release ];then
  if awk '{if (/5/&&!/2\./&&!/3\./&&!/4\./) { exit 0;nextfile } else { exit 1 }}' /etc/redhat-release;then
    isrhel5="1"
  elif awk '{if (/6\./&&!/2\./&&!/3\./&&!/4\./&&!/5\./) { exit 0;nextfile } else { exit 1 }}' /etc/redhat-release;then
    isrhel6="1"
  else
    _print_stderr_then_exit "ERROR - $LINENO - Unable to determine what version of RHEL this box is." 1
  fi
else
  _print_stderr_then_exit "ERROR - $LINENO - This box does not appear to be RHEL." 1
fi

if [ "$isrhel5" = "1" ];then #Add daemons you want to be enabled here!
echo "System appears to be RHEL 5."
  cat << EOF > "$temp_dir/daemons_to_be_enabled"
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
vxpbx_exchanged
EOF
elif [ "$isrhel6" = "1" ];then
echo "System appears to be RHEL 6."
  cat << EOF > "$temp_dir/daemons_to_be_enabled"
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
vxpbx_exchanged
EOF
else
  _print_stderr_then_exit "ERROR - $LINENO - This box does not appear to be RHEL 5 or 6."
fi

$chkconfigbin --list | awk '/:on/ {print $1}' > "$temp_dir/currently_enabled_daemons"
$chkconfigbin --list | awk '/0:off/&&/1:off/&&/2:off/&&/3:off/&&/4:off/&&/5:off/&&/6:off/ {print $1}' > "$temp_dir/currently_disabled_daemons"

if $chkconfigbin --list | grep "xinetd based services" > /dev/null;then
  echo "Note: Found xinetd based services, you'll have to control them manually."
fi
  
#This section disables daemons we don't want.
for each_currently_enabled_daemon in $(cat "$temp_dir/currently_enabled_daemons");do
  grep "$each_currently_enabled_daemon" "$temp_dir/daemons_to_be_enabled" > /dev/null
  if [ "$?" != "0" ];then
    num_bad_enabled_daemons_found=$(($num_bad_enabled_daemons_found + 1))
    read -p "Would you like to disable $each_currently_enabled_daemon? y or n: " user_response
    if [ "$user_response" = "y" ];then
      $num_bad_enabled_daemons_disabled=$(($num_bad_enabled_daemons_disabled + 1))
      echo "Disabling $each_currently_enabled_daemon."
      $chkconfigbin --level 0123456 $each_currently_enabled_daemon off
    else
      echo "Leaving $each_currently_enabled_daemon alone."
    fi
  fi
done

echo "Found $num_bad_enabled_daemons_found unwanted daemons which were enabled, disabled $num_bad_enabled_daemons_disabled of them."

#This section enables the daemons we do want.
for each_currently_disabled_daemon in $(cat "$temp_dir/currently_disabled_daemons");do
  grep "$each_currently_disabled_daemon" "$temp_dir/daemons_to_be_enabled" > /dev/null
  if [ "$?" = "0" ];then
    num_good_disabled_daemons_found=$(($num_good_disabled_daemons_found + 1))
    read -p "Would you like to enable $each_currently_disabled_daemon? y or n: " user_response
    if [ "$user_response" = "y" ];then
      num_good_disabled_daemons_enabled=$(($num_good_disabled_daemons_enabled + 1))
      echo "Enabling $each_currently_disabled_daemon."
      $chkconfigbin $each_currently_disabled_daemon on
    else
      echo "Leaving $each_currently_disabled_daemon alone."
    fi
  fi
done

echo "Found $num_good_disabled_daemons_found wanted daemons which were disabled, enabled $num_good_disabled_daemons_enabled of them."
rm -rf "$temp_dir"