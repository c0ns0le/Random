#!/bin/bash

#Description: Bash script to display the GlusterFS quota of a group's home directory.
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
# Version 0.1 - 2011-11-03 - Initial version. - Jeff White
#####

script="${0##*/}"
glusterbin="/usr/sbin/gluster"
awkbin="/bin/awk"
ldapsearchbin="/usr/bin/ldapsearch"
ldap_uri="ldap://sam-ldap-prod-01.cssd.pitt.edu"
volume_name="vol_home"
temp_file="/tmp/.$script-$RANDOM"

function _print_usage { #Usage: _print_usage
  cat <<EOF
Synopsis
    $script [-u user name] [-g group name] [-d directory]
    Print the quota use of a user, group, or directory.
    All quotas in GlusterFS are on directories (not users or groups).
    This script will print the quota of a group's home directory so 
    '-u jaw171' '-g cssd' and '-d /cssd' should do the same thing
    assuming jaw171 is in the group cssd and the group's home directory
    is /cssd ('/' meaning the volume itself wherever it is mounted).

    Only one option should to be specified.

    -u user name
        The user name to check.  This script will attempt to find the
	requested user's group's home directory and print that quota.

    -g group name
        The group name to check.  This script will attempt to find the
	requested group's home directory and print that quota.

    -d directory
        The explicit directory to check.
EOF
}

function _print_stderr { # Usage: _print_stderr "Some error text"
echo "$1" 1>&2
}

function _print_stderr_then_exit { # Usage: _print_stderr_then_exit "Some error text" exit_number
echo "$1" 1>&2
rm -rf "$temp_file"
exit $2
}

function _print_stdout_then_exit { # Usage: _print_stdout_then_exit "Some error text" exit_number
echo "$1"
rm -f "$temp_file"
exit $2
}

function _print_quota_stats { #Usage: _print_quota_stats
$glusterbin volume quota "$volume_name" list "$group_homedir" > "$temp_file"
if ! grep "$group_homedir" "$temp_file">/dev/null;then
  _print_stdout_then_exit "ERROR - $LINENO - No quota found.  Group home directory checked was $group_homedir." 1
else
  quota_limit=$(grep "$group_homedir" "$temp_file" | $awkbin '{print $2}')
  quota_usage=$(grep "$group_homedir" "$temp_file" | $awkbin '{print $3}')
  echo "Disk quota limit: $quota_limit"
  if [ -z "$quota_usage" ];then
    echo "Disk quota usage is null, the directory ($group_homedir) most likely doesn't exist yet."
  else
    echo "Disk quota usaged: $quota_usage"
    quota_limit_in_GB=$(echo "$quota_limit" | $awkbin '
      {
	if (/Bytes$/)
	  {printf "%.2f\n",$1/1024/1024/1024}
	else if (/KB$/)
	  {printf "%.2f\n",$1/1024/1024}
	else if (/MB$/)
	  {printf "%.2f\n",$1/1024} 
	else if (/GB$/)
	  {printf "%.2f\n", $1}
	else if (/TB$/)
	  {printf "%.2f\n",$1*1024} 
	else
	  {print "ERROR - Unable to convert limit value to GB.";exit 1}
      }')
    quota_usage_in_GB=$(echo "$quota_usage" | $awkbin '
      {
	if (/Bytes$/)
	  {printf "%.2f\n",$1/1024/1024/1024}
	else if (/KB$/)
	  {printf "%.2f\n",$1/1024/1024}
	else if (/MB$/)
	  {printf "%.2f\n",$1/1024} 
	else if (/GB$/)
	  {printf "%.2f\n", $1}
	else if (/TB$/)
	  {printf "%.2f\n",$1*1024} 
	else
	  {print "ERROR - Unable to convert usage value to GB.";exit 1}
      }')
    echo "Percentage used: $(echo "scale=2;$quota_usage_in_GB/$quota_limit_in_GB" | bc)"
  fi
fi
}

if [[ "$EUID" != "0" ]];then
  _print_stderr_then_exit "ERROR - $LINENO - You need to be root to run this, your EUID is $EUID." 1
fi

#What options were we called with?
if [[ "$#" == "0" ]];then
  _print_usage
  exit 1
fi

while getopts ":u:g:d:" option; do
  case "$option" in
    u)
      user_name=$OPTARG ;;
    g)
      group_name=$OPTARG ;;
    d)
      directory=$OPTARG ;;
    *)
      _print_usage
      exit 1 ;;
  esac
done
shift $((OPTIND - 1))

if [[ -n "$user_name" ]];then
  getent passwd "$user_name">/dev/null
  if [ "$?" != "0" ];then
    _print_stderr_then_exit "ERROR - $LINENO - The user $user_name does not appear to exist." 1
  else
    group_homedir=$($ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu" "(cn=$user_name)" | $awkbin -F'/' '/^homeDirectory/ {print "/"$3}')
    _print_quota_stats
  fi
elif [[ -n "$group_name" ]];then
  getent group "$group_name">/dev/null
  if  [ "$?" != "0" ];then
    _print_stderr_then_exit "ERROR - $LINENO - The group $group_name does not appear to exist." 1
  else
    group_homedir="/$group_name"
    _print_quota_stats
  fi
elif [[ -n "$directory" ]];then
  group_homedir="$directory"
  _print_quota_stats
else
  _print_stderr_then_exit "ERROR - $LINENO - Unable to determine what to check.  Something is broken, this is a bug." 1
fi