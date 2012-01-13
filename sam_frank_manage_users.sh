#!/bin/bash
#Description: Bash script to create a new group or user on SAM's Frank HPC cluster.
#Written By: Jeff White of The University of Pittsburgh (jaw171@pitt.edu)
#Exit codes:
#+ 1 - The script had an unexpected error
#+ 2 - Most likely a user error such as an unset variable or null string

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.8beta - 2012-01-13 - Added a delete user from porject option for Gold, added home directory chown. - Jeff White
# 0.7 - 2012-01-09 - Added Gluster quota support. - Jeff White
# 0.6 - 2012-01-05 - Added home directory creator for new users, fixed a small bug with one test. - Jeff White
# 0.5 - 2012-01-05 - Added quota option with 'edquota'. - Jeff White
# 0.4 - 2011-08-31 - Untracked changes. - Jeff White
#
#####

script="${0##*/}"
ldap_uri="ldap://sam-ldap-prod-01.cssd.pitt.edu"
temp_dir="/tmp/${script}.working"
ldif_dir=~/ldifs
ldap_bind_dn="cn=diety,dc=frank,dc=sam,dc=pitt,dc=edu"
gluster_volume_name="vol_home0"
ldapsearchbin="/usr/bin/ldapsearch"
ldapmodifybin="/usr/bin/ldapmodify"
dialogbin="/usr/bin/dialog"
awkbin="/bin/awk"
sudobin="/usr/bin/sudo"
grepbin="/bin/grep"
sedbin="/bin/sed"
edquotabin="/usr/sbin/edquota"
xfs_quotabin="/usr/sbin/xfs_quota"
gmkprojectbin="/opt/gold/2.2.0.1/bin/gmkproject"
gmkuserbin="/opt/gold/2.2.0.1/bin/gmkuser"
gdepositbin="/opt/gold/2.2.0.1/bin/gdeposit"
glsproject="/opt/gold/2.2.0.1/bin/glsproject"
gchproject="/opt/gold/2.1.12.2/bin/gchproject"
glsuser="/opt/gold/2.2.0.1/bin/glsuser"
glusterbin="/usr/sbin/gluster"

function _print_stderr { # Usage: _print_stderr "Some error text"
echo "$1" 1>&2
}
function _print-stderr-then-exit { # Usage: _print-stderr-then-exit "Some error text" exitnumber
echo "$1" 1>&2
rm -rf "$temp_dir" #Littering is bad
exit $2
}
function _print-stdout-then-exit { # Usage: _print-stdout-then-exit "Some error text" exitnumber
echo "$1"
rm -rf "$temp_dir" #Littering is bad
exit $2
}

if [ "$1" = "-h" -o "$1" = "--help" ];then # $OPTSTRING would be nicer, but meh...
  cat << EOF
Usage: $script {-h}
This script is to manage the users of the Frank HPC cluster ran by SAM and CSSD of the University of Pittsburgh.
When ran with no options this will display an ncurses-based interface to control users and groups.
WARNING: This script can be destructive, don't do silly things!
Version: 0.8beta
Author: Jeff White (jaw171@pitt.edu)
License: This script is released under version three (3) of the GNU General Public License (GPL) of the Free Software Foundation (FSF)
EOF
  exit 0
fi

shopt -s -o nounset #Unset variables are icky

mkdir -p "$temp_dir"
mkdir -p "$ldif_dir"

$dialogbin --menu "What would you like to do?" 15 70 7 \
"1" "Display information about a group" \
"2" "Display information about a user" \
"3" "Create a new group" \
"4" "Create a new user" \
"5" "Add a user to an existing group" \
"6" "Edit the disk quota for a user or group" \
"7" "Work with Gold" 2>"${temp_dir}/ans" || _print-stdout-then-exit "Bye" 0

user_response="$(cat "${temp_dir}/ans")"

if [ "$user_response" = "1" ];then #Display information about a group
  $dialogbin --title "Dialog menu box" --menu "What information do you have?" 11 70 2 \
  "1" "I have a group name (cn)" \
  "2" "I have a group GID (gidNumber)" 2>"${temp_dir}/ans" || _print-stdout-then-exit "Bye" 0
  user_response="$(cat "${temp_dir}/ans")"
  if [ "$user_response" = "1" ];then #I have a group name (cn)
    $dialogbin --inputbox "Enter the group name:" 8 40 2>"${temp_dir}/groupname" || _print-stdout-then-exit "Bye" 0
    $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu" "(cn=$(cat ${temp_dir}/groupname))" > "${temp_dir}/groupinfo"
    if [ -s "${temp_dir}/groupinfo" ];then
      echo
      cat "${temp_dir}/groupinfo" 
    else
      echo
      echo "No results found."
      echo
    fi
  elif [ "$user_response" = "2" ];then #I have a group GID (gidNumber)
    $dialogbin --inputbox "Enter the group GID:" 8 40 2>"${temp_dir}/gidnumber" || _print-stdout-then-exit "Bye" 0
    $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu" "(gidNumber=$(cat ${temp_dir}/gidnumber))" > "${temp_dir}/groupinfo"
    if [ -s "${temp_dir}/groupinfo" ];then #If the results file is non zero...
      echo
      cat "${temp_dir}/groupinfo" 
    else
      echo
      echo "No results found."
      echo
    fi
  else
    _print-stderr-then-exit "$LINENO - I couldn't figure out what you wanted to do.  I'm sorry, this hurts me more than it hurts you." 1
  fi

elif [ "$user_response" = "2" ];then #Display information about a user
  $dialogbin --menu "What information do you have?" 11 70 2 \
  "1" "I have a user name (cn)" \
  "2" "I have a user UID (uidNumber)" 2>"${temp_dir}/ans" || _print-stdout-then-exit "Bye" 0
  user_response="$(cat "${temp_dir}/ans")"
  if [ "$user_response" = "1" ];then #I have a user name (cn)
    $dialogbin --inputbox "Enter the user name:" 8 40 2>"${temp_dir}/username" || _print-stdout-then-exit "Bye" 0
    $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu" "(cn=$(cat ${temp_dir}/username))" > "${temp_dir}/userinfo"
    if [ -s "${temp_dir}/userinfo" ];then
      echo
      cat "${temp_dir}/userinfo" 
    else
      echo
      echo "No results found."
      echo
    fi
  elif [ "$user_response" = "2" ];then #I have a user UID (uidNumber)
    $dialogbin --inputbox "Enter the user UID:" 8 40 2>"${temp_dir}/uidnumber" || _print-stdout-then-exit "Bye" 0
    $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu" "(uidNumber=$(cat ${temp_dir}/uidnumber))" > "${temp_dir}/userinfo"
    if [ -s "${temp_dir}/userinfo" ];then #If the results file is non zero...
      echo
      cat "${temp_dir}/userinfo" 
    else
      echo
      echo "No results found."
      echo
    fi
  else
    _print-stderr-then-exit "I couldn't figure out what you wanted to do.  I'm sorry, this hurts me more than it hurts you." 1
  fi

elif [ "$user_response" = "3" ];then #Create a new group
  $dialogbin --inputbox "Enter the new group name you wish to create:" 8 40 2>"${temp_dir}/new_group_name" || _print-stdout-then-exit "Bye" 0
  new_group_name="$(cat "${temp_dir}/new_group_name")"
  #Let's make sure that the group does not already exist.
  $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu" "(cn="$new_group_name")" > "${temp_dir}/groupinfo"
  if [ -s "${temp_dir}/groupinfo" ];then #If the groupinfo file is not zero in size then ldapsearch got a result and the user already exists.
    echo
    _print-stderr-then-exit "$LINENO - The group $new_group_name already exists." 2
  fi
  #The group seems valid, let's create the correct ldif and print our output
  next_available_gid=$($ldapsearchbin -LLLx -H "$ldap_uri" -b 'ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu' gidNumber | $awkbin '/gidNumber/ { if ( $2>a ) a = $2; } END {print a+"1";}')
  cat << EOF > "${ldif_dir}/${new_group_name}.ldif"
dn: cn=$new_group_name,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu
objectClass: posixGroup
objectClass: top
cn: $new_group_name
gidNumber: $next_available_gid
EOF
  echo "I made the ldif file for creating the new group.  Check if it looks ok then you can add it to the directory with:"
  echo "$ldapmodifybin -axWZZ -H $ldap_uri -D "$ldap_bind_dn" -f ${ldif_dir}/${new_group_name}.ldif"
  echo
  cat "${ldif_dir}/${new_group_name}.ldif"
  echo
  echo "After you add the entry, try to search it by invoking this script again and make sure everything looks correct."

elif [ "$user_response" = "4" ];then #Create a new user
  next_available_uid=$($ldapsearchbin -LLLx -H "$ldap_uri" -b 'ou=people,dc=frank,dc=sam,dc=pitt,dc=edu' uidNumber | $awkbin '/uidNumber/ { if ( $2>a ) a = $2; } END {print a+"1";}')
  $dialogbin --inputbox "Enter the new user name you wish to create:" 8 40 2>"${temp_dir}/newusername" || _print-stdout-then-exit "Bye" 0
  new_user_name="$(cat "${temp_dir}/newusername")"
  $dialogbin --inputbox "Enter which group name should this user belong to (the primary group):" 8 40 2>"${temp_dir}/new_users_primary_group_name" || _print-stdout-then-exit "Bye" 0
  new_users_primary_group_name="$(cat "${temp_dir}/new_users_primary_group_name")"
  new_users_primary_group_gid=$($ldapsearchbin -LLLx -b 'ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu' "(cn=${new_users_primary_group_name})" gidNumber | $awkbin '/gidNumber/ {print $2}')
  #Let's make sure that the group actually exists and the user does not.
  $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu" "(cn="$new_user_name")" > "${temp_dir}/userinfo"
  $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu" "(cn="$new_users_primary_group_name")" > "${temp_dir}/groupinfo"
  if [ -s "${temp_dir}/userinfo" ];then #If the userinfo file is not zero in size then ldapsearch got a result and the user already exists.
    echo
    _print-stderr-then-exit "$LINENO - The user $new_user_name already exists." 2
  elif [ ! -s "${temp_dir}/groupinfo" ];then #If the groupinfo file is zero in size then ldapsearch got no result and the group does not exist yet.
    next_available_gid=$($ldapsearchbin -LLLx -H "$ldap_uri" -b 'ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu' gidNumber | $awkbin '/gidNumber/ { if ( $2>a ) a = $2; } END {print a+"1";}')
    cat << EOF > "${ldif_dir}/${new_users_primary_group_name}.ldif"
dn: cn=$new_users_primary_group_name,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu
objectClass: posixGroup
objectClass: top
cn: $new_users_primary_group_name
gidNumber: $next_available_gid
EOF
    echo
    echo "WARNING: The group entered does not exist.  I'll assume you want to create it."
    echo "I made the ldif file for creating the new group.  Check if it looks ok then you can add it to the directory with:"
    echo "$ldapmodifybin -axWZZ -H $ldap_uri -D "$ldap_bind_dn" -f ${ldif_dir}/${new_users_primary_group_name}.ldif"
    echo
    cat "${ldif_dir}/${new_users_primary_group_name}.ldif"
    echo
    new_users_primary_group_gid="$next_available_gid" #This is needed for the new user ldif below
  fi
  #The user seems valid, let's create the correct ldifs and print our output.
  cat << EOF > "${ldif_dir}/${new_user_name}.ldif" #This is the ldif to create the user
dn: cn=$new_user_name,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu
objectClass: account
objectClass: posixAccount
objectClass: top
cn: $new_user_name
gidNumber: $new_users_primary_group_gid
homeDirectory: /home/${new_users_primary_group_name}/$new_user_name
uid: $new_user_name
uidNumber: $next_available_uid
loginShell: /bin/bash
userPassword: {SASL}$new_user_name
EOF
  cat << EOF > "${ldif_dir}/${new_user_name}-active-group.ldif" #This is the ldif to add the user to the active users group
dn: cn=sam_frank_active_users,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu
changetype: modify
add: member
member: cn=${new_user_name},ou=people,dc=frank,dc=sam,dc=pitt,dc=edu
EOF
  cat << EOF > "${ldif_dir}/${new_user_name}-addto-${new_users_primary_group_name}.ldif" #This is the ldif to add the user to their primary group
dn: cn=${new_users_primary_group_name},ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu
changetype: modify
add: memberUid
memberUid: ${new_user_name}
EOF
  echo "I made the ldif file for creating the new user.  Check if it looks ok then you can add it to the directory with:"
  echo "$ldapmodifybin -axWZZ -H $ldap_uri -D "$ldap_bind_dn" -f ${ldif_dir}/${new_user_name}.ldif"
  echo
  cat "${ldif_dir}/${new_user_name}.ldif"
  echo
  echo "You will need to add the user to the group sam_frank_active_users.  Here is the ldif for that."
  echo "$ldapmodifybin -axWZZ -H $ldap_uri -D "$ldap_bind_dn" -f ${ldif_dir}/${new_user_name}-active-group.ldif"
  echo
  cat "${ldif_dir}/${new_user_name}-active-group.ldif"
  echo
  echo "You will need to have the user be a member of their primary group.  Here is the ldif for that."
  echo "$ldapmodifybin -axWZZ -H $ldap_uri -D "$ldap_bind_dn" -f ${ldif_dir}/${new_user_name}-addto-${new_users_primary_group_name}.ldif"
  echo
  cat "${ldif_dir}/${new_user_name}-addto-${new_users_primary_group_name}.ldif"
  echo
  echo "To create the user's home directory: mkdir -p /home/${new_users_primary_group_name}/$new_user_name ; chown $new_user_name:$new_users_primary_group_name /home/${new_users_primary_group_name}/$new_user_name"
  echo
  $glusterbin volume quota $gluster_volume_name list > "${temp_dir}/gluster_quota_list"
  current_quota_limit=$($grepbin "^/$new_users_primary_group_name " "${temp_dir}/gluster_quota_list" | $awkbin '{print $2}')
  if [ ! -z "$current_quota_limit" ];then
    echo
    echo "WARNING: The user's group $new_users_primary_group_name has a quota already, a user quota may not be needed!"
    echo
  fi
  echo
  echo "To set the user's disk quota: $glusterbin volume quota $gluster_volume_name limit-usage /home/${new_users_primary_group_name}/$new_user_name 100G"
  echo
  echo "Don't forget to add the new user to the SSLVPN group 'CSSD - SSLVPN SAM Users'."
  echo "After you add the entries, try to search them by invoking this script again and make sure everything looks correct."

elif [ "$user_response" = "5" ];then #Add a user to an existing group
  $dialogbin --inputbox "Enter the username of the user:" 8 40 2>"${temp_dir}/add_member_which_username" || _print-stdout-then-exit "Bye" 0
  $dialogbin --inputbox "Enter the name of the group:" 8 40 2>"${temp_dir}/add_member_which_group" || _print-stdout-then-exit "Bye" 0
  add_member_which_username="$(cat "${temp_dir}/add_member_which_username")"
  add_member_which_group="$(cat "${temp_dir}/add_member_which_group")"
  #Let's make sure that the user and group actually exist.
  $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu" "(cn=$add_member_which_username)" > "${temp_dir}/userinfo"
  $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu" "(cn=$add_member_which_group)" > "${temp_dir}/groupinfo"
  if [ ! -s "${temp_dir}/userinfo" ];then
    echo
    _print-stderr-then-exit "$LINENO - The user $add_member_which_username was not found." 2
  elif [ ! -s "${temp_dir}/groupinfo" ];then
    echo
    _print-stderr-then-exit "$LINENO - The group $add_member_which_group was not found." 2
  fi
  #The user and group seem valid, let's create the correct ldif and print our output.
  echo "$add_member_which_group" | $awkbin '/sam_frank_active_users/||/sam_frank_admins/ {exit 1}'
  if [ "$?" = "1" ];then #One of the "groupOfNames" was entered
  cat << EOF > "${ldif_dir}/${add_member_which_username}-addto-${add_member_which_group}.ldif"
dn: cn=$add_member_which_group,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu
changetype: modify
add: member
memberUid: dn=$add_member_which_username,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu
EOF
  else #One of the posixGroups was entered
  cat << EOF > "${ldif_dir}/${add_member_which_username}-addto-${add_member_which_group}.ldif"
dn: cn=$add_member_which_group,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu
changetype: modify
add: memberUid
memberUid: $add_member_which_username
EOF
  fi
  echo "I made the ldif file for adding the user to the group.  Check if it looks ok then you can add it to the directory with:"
  echo "$ldapmodifybin -axWZZ -H $ldap_uri -D "$ldap_bind_dn" -f "${ldif_dir}/${add_member_which_username}-addto-${add_member_which_group}.ldif""
  echo
  cat "${ldif_dir}/${add_member_which_username}-addto-${add_member_which_group}.ldif"
  echo
  echo "After you add the entry, try to search it by invoking this script again and make sure everything looks correct."

elif [ "$user_response" = "6" ];then #Edit the disk quota for a user or group
  $dialogbin --menu "What would you like to do?" 11 70 4 \
  "1" "Display the quota usage of a user" \
  "2" "Display the quota usage of a group" \
  "3" "Change the quota for a user" \
  "4" "Change the quota for a group" 2>"${temp_dir}/ans" || _print-stdout-then-exit "Bye" 0
  user_response="$(cat "${temp_dir}/ans")"
  $glusterbin volume quota $gluster_volume_name list > "${temp_dir}/gluster_quota_list"
  if [ "$user_response" = "1" -o "$user_response" = "3" ];then #Display or change the quota usage of a user
    $dialogbin --inputbox "Enter the username:" 8 40 2>"${temp_dir}/username" || _print-stdout-then-exit "Bye" 0
    username=$(cat "${temp_dir}/username")
    #Get the user's information from LDAP so we can get the home directory path
    $ldapsearchbin -LLLx -H "$ldap_uri" -b "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu" "(cn=$username)" > "${temp_dir}/userinfo"
    if [ -s "${temp_dir}/userinfo" ];then
      user_homedir=$($awkbin -F'; ' '/^homeDirectory/ {print $2}' "${temp_dir}/userinfo")
      current_quota_limit=$($grepbin "^$user_homedir" "${temp_dir}/gluster_quota_list" | $awkbin '{print $2}')
      if [ "$user_response" = "1" ];then #Display the quota usage of a user
	if [ -z "$current_quota_limit" ];then
	  echo
	  echo "User ${username}'s home directory $user_homedir has no quota limit set." 0
	  echo
	else
	  current_quota_usage=$($grepbin "^$user_homedir" "${temp_dir}/gluster_quota_list" | $awkbin '{print $3}')
	  echo
	  echo "Current quota usage of ${username}'s home directory $user_homedir is $current_quota_usage of the limit $current_quota_limit."
	  echo
	fi
      elif [ "$user_response" = "3" ];then #Change the quota usage of a user
	$dialogbin --inputbox "Enter the desired quota limit in GB:" 8 40 2>"${temp_dir}/quota_limit" || _print-stdout-then-exit "Bye" 0
	$awkbin '!/^[+-]?\d+$/ {exit 1}' ${temp_dir}/quota_limit || _print-stderr-then-exit "$LINENO - Desired quota limit entered was not a number." 2
	$glusterbin volume quota $gluster_volume_name limit-usage $user_homedir $(cat "${temp_dir}/quota_limit)GB" || _print-stderr-then-exit "$LINENO - Failed to set quota on $user_homedir." 2
      else
	_print-stderr-then-exit "$LINENO - I couldn't figure out what you wanted to do.  I'm sorry, this hurts me more than it hurts you." 1
      fi
    else
      echo
      echo "User $username does not exist or user details could not be pulled from LDAP."
      echo
    fi
  elif [ "$user_response" = "2" -o "$user_response" = "4" ];then #Display or change the quota usage of a group
    $dialogbin --inputbox "Enter the groupname:" 8 40 2>"${temp_dir}/groupname" || _print-stdout-then-exit "Bye" 0
    groupname=$(cat "${temp_dir}/groupname")
    current_quota_limit=$($grepbin "^/$groupname " "${temp_dir}/gluster_quota_list" | $awkbin '{print $2}')
      if [ "$user_response" = "2" ];then #Display the quota usage of a group
	if [ -z "$current_quota_limit" ];then
	  echo
	  echo "User ${groupname}'s home directory /$groupname has no quota limit set." 0
	  echo
	else
	  current_quota_usage=$($grepbin "^/$groupname " "${temp_dir}/gluster_quota_list" | $awkbin '{print $3}')
	  echo
	  echo "Current quota usage of ${groupname}'s home directory /$groupname is $current_quota_usage of the limit $current_quota_limit."
	  echo
	fi
      elif [ "$user_response" = "3" ];then #Change the quota usage of a group
	$dialogbin --inputbox "Enter the desired quota limit in GB:" 8 40 2>"${temp_dir}/quota_limit" || _print-stdout-then-exit "Bye" 0
	$awkbin '!/^[+-]?\d+$/ {exit 1}' ${temp_dir}/quota_limit || _print-stderr-then-exit "$LINENO - Desired quota limit entered was not a number." 2
	$glusterbin volume quota $gluster_volume_name limit-usage /$groupname $(cat "${temp_dir}/quota_limit)GB" || _print-stderr-then-exit "$LINENO - Failed to set quota on /$groupname." 2
      else
	_print-stderr-then-exit "$LINENO - I couldn't figure out what you wanted to do.  I'm sorry, this hurts me more than it hurts you." 1
      fi
  else
    _print-stderr-then-exit "$LINENO - I couldn't figure out what you wanted to do.  I'm sorry, this hurts me more than it hurts you." 1
  fi

elif [ "$user_response" = "7" ];then #Work with Gold
  $dialogbin --menu "What information do you have?" 11 70 5 \
  "1" "Search for a user or project" \
  "2" "Create a new project" \
  "3" "Create a new user and add them to a project" \
  "4" "Add an existing user to an existing project" \
  "5" "Remove a user from a project" \
  "6" "Add credits to a project" 2>"${temp_dir}/ans" || _print-stdout-then-exit "Bye" 0
  user_response="$(cat "$temp_dir/ans")"
  if [ "$user_response" = "1" ];then #Search for a user or project
    $dialogbin --inputbox "Enter the username or project name to search for:" 8 40 2>"${temp_dir}/thing_to_search_for" || _print-stdout-then-exit "Bye" 0
    if [ -s "${temp_dir}/thing_to_search_for" ];then
      $glsproject | $grepbin "$(cat "${temp_dir}/thing_to_search_for")" | $awkbin '{printf "Project: "$1"\nMembers: "$3"\n"}' > "${temp_dir}/gold_user_membership"
      if [ -s "${temp_dir}/gold_user_membership" ];then
	echo
	cat "${temp_dir}/gold_user_membership"
	echo
      else
	echo
	echo "No results found."
	echo
      fi
    else
      _print-stderr-then-exit "$LINENO - The variable thing_to_search_for is null, did you enter anything?" 2
    fi
  elif [ "$user_response" = "2" ];then #Create a new project
    $dialogbin --inputbox "Enter the name of the new project:" 8 40 2>"${temp_dir}/new_gold_project_name" || _print-stdout-then-exit "Bye" 0
    new_gold_project_name="$(cat "${temp_dir}/new_gold_project_name")"
    if $glsproject | $grepbin -e "^$new_gold_project_name" >/dev/null ;then #If the project name is found in the output of $glsproject...
      _print-stderr-then-exit "User $new_gold_project_name already exists in Gold." 2
    fi
    $sudobin -u gold $gmkprojectbin "$new_gold_project_name" && echo "Success."
  elif [ "$user_response" = "3" ];then #Create a new user and add them to a project
    $dialogbin --inputbox "Enter the user name of the new user (e.g. jaw171):" 8 40 2>"${temp_dir}/new_gold_user_uca_name" || _print-stdout-then-exit "Bye" 0
    new_gold_user_uca_name="$(cat "${temp_dir}/new_gold_user_uca_name")"
    if $glsuser | $grepbin -e "^$new_gold_user_uca_name" >/dev/null ;then #If the username is found in the output of $glsuser...
      _print-stderr-then-exit "User $new_gold_user_uca_name already exists in Gold." 2
    fi
    finger "${new_gold_user_uca_name}@pitt.edu" | $awkbin '/^Name/ {$1=""; print}' >"${temp_dir}/new_gold_user_real_name"
    if [ $(cat "${temp_dir}/new_gold_user_real_name") = " " -o ! -s "${temp_dir}/new_gold_user_real_name" ];then #If we couldn't find the real name with finger...
      $dialogbin --inputbox "Enter the real name of the new user (e.g. Dave Davidson):" 8 40 2>"${temp_dir}/new_gold_user_real_name" || _print-stdout-then-exit "Bye" 0
    fi
    finger "${new_gold_user_uca_name}@pitt.edu" | $awkbin '/^Email/ {print $2}' >"${temp_dir}/new_gold_user_email"
    if [ -s ! "${temp_dir}/new_gold_user_email" ];then #If we couldn't find the email with finger...
      $dialogbin --inputbox "Enter the email address of the new user:" 8 40 2>"${temp_dir}/new_gold_user_email" || _print-stdout-then-exit "Bye" 0
    fi
    $dialogbin --inputbox "Enter the name of the existing project:" 8 40 2>"${temp_dir}/gold_project_name" || _print-stdout-then-exit "Bye" 0
    gold_project_name=$(cat "${temp_dir}/gold_project_name")
    $glsproject | $grepbin "^$gold_project_name" >/dev/null
    if [ "$?" != "0" ];then #If the project name is not found in the output of $glsproject...
      _print-stderr-then-exit "Project $gold_project_name does not exist in Gold." 2
    fi
    $sudobin -u gold $gmkuserbin -n "$(cat "${temp_dir}/new_gold_user_real_name")" -E "$(cat "${temp_dir}/new_gold_user_email")" -p "$gold_project_name" $new_gold_user_uca_name && echo "Success."
  elif [ "$user_response" = "4" ];then #Add an existing user to an existing project
    $dialogbin --inputbox "Enter the user name of the existing user (e.g. jaw171):" 8 40 2>"${temp_dir}/existing_gold_user_uca_name" || _print-stdout-then-exit "Bye" 0
    existing_gold_user_uca_name="$(cat "${temp_dir}/existing_gold_user_uca_name")"
    if ! $glsuser | $grepbin -e "^$existing_gold_user_uca_name" >/dev/null ;then #If the username is not found in the output of $glsuser...
      _print-stderr-then-exit "User $existing_gold_user_uca_name does not exist in Gold." 2
    fi
    $dialogbin --inputbox "Enter the name of the existing project:" 8 40 2>"${temp_dir}/gold_project_name" || _print-stdout-then-exit "Bye" 0
    gold_project_name="$(cat "${temp_dir}/gold_project_name")"
    if ! $glsproject | $grepbin -e "^$gold_project_name" >/dev/null ;then #If the project name is not found in the output of $glsproject...
      _print-stderr-then-exit "Project $gold_project_name does not exist in Gold." 2
    fi
    $sudobin -u gold $gchproject --addUsers "$existing_gold_user_uca_name" -p "$gold_project_name"
  elif [ "$user_response" = "5" ];then #Remove a user from a project
    $dialogbin --inputbox "Enter the user name of the existing user (e.g. jaw171):" 8 40 2>"${temp_dir}/existing_gold_user_uca_name" || _print-stdout-then-exit "Bye" 0
    existing_gold_user_uca_name="$(cat "${temp_dir}/existing_gold_user_uca_name")"
    if ! $glsuser | $grepbin -e "^$existing_gold_user_uca_name" >/dev/null ;then #If the username is not found in the output of $glsuser...
      _print-stderr-then-exit "User $existing_gold_user_uca_name does not exist in Gold." 2
    fi
    $dialogbin --inputbox "Enter the name of the existing project:" 8 40 2>"${temp_dir}/gold_project_name" || _print-stdout-then-exit "Bye" 0
    gold_project_name="$(cat "${temp_dir}/gold_project_name")"
    if ! $glsproject | $grepbin -e "^$gold_project_name" >/dev/null ;then #If the project name is not found in the output of $glsproject...
      _print-stderr-then-exit "Project $gold_project_name does not exist in Gold." 2
    fi
    $sudobin -u gold $gchproject --delUsers "$existing_gold_user_uca_name" -p "$gold_project_name"
  elif [ "$user_response" = "6" ];then #Add credits to a project
    $dialogbin --inputbox "Enter the name of the existing project:" 8 40 2>"${temp_dir}/gold_project_name" || _print-stdout-then-exit "Bye" 0
    gold_project_name="$(cat "${temp_dir}/gold_project_name")"
    if ! $glsproject | $grepbin -e "^$gold_project_name" >/dev/null ;then #If the project name is not found in the output of $glsproject...
      _print-stderr-then-exit "User $gold_project_name does not exist in Gold." 2
    fi
    $dialogbin --inputbox "Enter the amount of credits to add:" 8 40 2>"${temp_dir}/gold_project_hours_to_add" || _print-stdout-then-exit "Bye" 0
    $sudobin -u gold $gdepositbin -p "$gold_project_name" -h "$(cat "${temp_dir}/gold_project_hours_to_add")" && echo "Success."
  else
    _print-stderr-then-exit "$LINENO - I couldn't figure out what you wanted to do.  I'm sorry, this hurts me more than it hurts you." 1
  fi
else
  _print-stderr-then-exit "$LINENO - I couldn't figure out what you wanted to do.  I'm sorry, this hurts me more than it hurts you." 1
fi

rm -rf "$temp_dir" #Littering is bad