#!/usr/bin/perl
use strict;
use warnings;
# Description: This script is used to manage users on the Frank HPC cluster of the SaM group at the University of Pittsburgh
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version
# To do: Add Gold, add Gluster quota

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Getopt::Long;
use Net::LDAP;
use Net::LDAP::LDIF;
use Net::OpenSSH;
use Term::ReadKey;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

GetOptions('h|help' => \my $helpopt,
	   'p|password-file=s' => \my $ldap_password_file,
	  ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "This script is used to manage users on the Frank HPC cluster of the SaM group at the University of Pittsburgh.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "-h | --help : Show this help\n";
  print "-p | --password-file : A file containing the LDAP password to bind with.\n";
  exit;
}

my ($ldap, $start_tls_mesg, $bind_mesg);
$| = 1;

# Connect to the LDAP server
sub do_ldap_bind {
  # In a scalar conext, returns 1 if successful, dies otherwise
  # Usage: do_ldap_bind()

  my $ldap_password;
  if ($ldap_password_file) {
    open(my $LDAP_PASSWORD_FILE, "<", $ldap_password_file) or die
      BOLD RED "Failed to open LDAP password file '$ldap_password_file': $!";
    chomp($ldap_password = <$LDAP_PASSWORD_FILE>);
    close $LDAP_PASSWORD_FILE;
  }
  else {
    print "Enter the LDAP password: ";
    ReadMode('noecho'); # don't echo
    chomp($ldap_password = <STDIN>);
    ReadMode(0);        # back to normal
  }

  $ldap = Net::LDAP->new(
    'ldap://sam-ldap-prod-01.cssd.pitt.edu',
    version => 3,
  ) or die BOLD RED "Failed to connect to the LDAP server: $@";

  $start_tls_mesg = $ldap->start_tls(
    verify => 'require',
    capath => '/etc/openldap/cacerts/'
  );

  $start_tls_mesg->code && die BOLD RED "Failed to start TLS session with the LDAP server: " . $start_tls_mesg->error;

  $bind_mesg = $ldap->bind(
    'cn=diety,dc=frank,dc=sam,dc=pitt,dc=edu',
    password => $ldap_password
  );

  $bind_mesg->code && die BOLD RED "Failed to bind with the LDAP server: " . $bind_mesg->error;

  return 1;
}

# Search for a user in LDAP
sub ldap_search_user {
  # In a scalar conext, returns the number of matches
  # Usage: ldap_search_user($user_or_uid,$do_print)
  # If the second arg is true the results of the search will be printed.

  # Were we called correctly?
  if (!$_[0]) {
    warn BOLD RED "Invalid use of subroutine ldap_search_user.";
    return;
  }
  my $user_id = $_[0];

  # Bind to LDAP if we haven't already
  do_ldap_bind if (!$ldap);

  # Were we given a number?  Must be a UID...
  my $user_search_result = $ldap->search(
    base => "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 120,
    filter => "(uidNumber=$user_id)",
    attrs => ['*']
  ) if ($user_id =~ m/^[+-]?\d+$/);

  # We didn't already search for a user by UID?  We must have been given a user name...
  $user_search_result = $ldap->search(
    base => "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 120,
    filter => "(cn=$user_id)",
    attrs => ['*']
  ) if (!$user_search_result);

  # Did we get an error?
  if ($user_search_result->code) {
    warn BOLD RED "LDAP search failed: " . $user_search_result->error;
  }

  # Get the results of the search
  my @entries = $user_search_result->entries;

  # Print the non-binary attributes that were found if we were called to do so
  if ($_[1]) {
    foreach my $entr (@entries) {
      print "DN: ", $entr->dn, "\n";
      foreach my $attr (sort $entr->attributes) {
	# skip binary we can't handle
	next if ($attr =~ /;binary$/);
      print "  $attr : " . join(" ",$entr->get_value($attr)) . "\n";
      }
    }
  }

  return scalar @entries;
}

# Search for a group in LDAP
sub ldap_search_group {
  # In a scalar conext, returns the number of matches
  # Usage: ldap_search_user(\$group_or_gid,$do_print)
  # If the second arg is true the results of the search will be printed.

  # Were we called correctly?
  if (!$_[0]) {
    warn BOLD RED "Invalid use of subroutine ldap_search_group.";
    return;
  }
  my $group_id = $_[0];

  # Bind to LDAP if we haven't already
  do_ldap_bind if (!$ldap);

  # Were we given a number?  Must be a GID...
  my $group_search_result = $ldap->search(
    base => "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 120,
    filter => "(gidNumber=$group_id)",
    attrs => ['*']
  ) if ($group_id =~ m/^[+-]?\d+$/);

  # We didn't already search for a group by GID?  We must have been given a group name...
  $group_search_result = $ldap->search(
    base => "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 120,
    filter => "(cn=$group_id)",
    attrs => ['*']
  ) if (!$group_search_result);

  # Did we get an error?
  if ($group_search_result->code) {
    die BOLD RED "LDAP search failed: " . $group_search_result->error;
  }

  # Get the results of the search
  my @entries = $group_search_result->entries;

  # Print the non-binary attributes that were found if we were called to do so
  if ($_[1]) {
    foreach my $entr (@entries) {
      print "DN: ", $entr->dn, "\n";
      foreach my $attr (sort $entr->attributes) {
	# skip binary we can't handle
	next if ($attr =~ /;binary$/);
	print "  $attr : " . join(" ",$entr->get_value($attr)) . "\n";
      }
    }
  }

  return scalar @entries;
}

# Get the next available UID
sub get_next_uid {
  # In a scalar conext, returns the next available UID
  # Usage: get_next_uid()

  # Bind to LDAP if we haven't already
  do_ldap_bind if (!$ldap);

  my $uid_search_result = $ldap->search(
    base => "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 120,
    filter => "(uidNumber=*)",
    attrs => ['uidNumber']
  );

  # Did we get an error?
  if ($uid_search_result->code) {
    die BOLD RED "LDAP search failed: " . $uid_search_result->error;
  }

  # Get the results of the search
  my @entries = $uid_search_result->entries;

  # Did we get any results?
  if (!@entries) {
    print BOLD RED "Failed to find any existing UID!\n";
    return 0;
  }

  # Find the largest UID
  my @uids;
  foreach my $uid ($uid_search_result->all_entries) {
    push @uids, $uid->get_value('uidNumber');
  } 
  @uids = sort { $b <=> $a } @uids;
  my $next_uid = ++$uids[0];

  # Check that a duplicate local UID does not exist on the head or the login nodes
  foreach my $each_server (qw(headnode0-dev.cssd.pitt.edu headnode1-dev.cssd.pitt.edu login0-dev.cssd.pitt.edu login1-dev.cssd.pitt.edu)) {

    # Open an SSH connection
    my $ssh = Net::OpenSSH->new(
      "$each_server",
#       key_path => "/root/.ssh/id_dsa",
      timeout => 120,
      kill_ssh_on_timeout => 1,
    );
    
    # Check for an SSH error
    if ($ssh->error) {
      warn BOLD RED "ERROR: Failed to establish SSH connection to $each_server to check for duplicate UID: " . $ssh->error;
      next;
    }

    my $uid_check_passed;
    until ($uid_check_passed) {

      # Check for a duplicate UID
      if ($ssh->system("grep $next_uid /etc/passwd >/dev/null")) {
# 	print "Duplicate UID found on ${each_server}, incrementing UID.\n";
	++$next_uid;
      }
      else {
# 	print "No duplicate found on ${each_server}.\n";
	$uid_check_passed = 1;
      }

    }
  }

  return $next_uid;
}

# Get the next available GID
sub get_next_gid {
  # In a scalar conext, returns the next available GID
  # Usage: get_next_gid()

  # Bind to LDAP if we haven't already
  do_ldap_bind if (!$ldap);

  my $gid_search_result = $ldap->search(
    base => "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 120,
    filter => "(gidNumber=*)",
    attrs => ['gidNumber']
  );

  # Did we get an error?
  if ($gid_search_result->code) {
    die BOLD RED "LDAP search failed: " . $gid_search_result->error;
  }

  # Get the results of the search
  my @entries = $gid_search_result->entries;

  # Did we get any results?
  if (!@entries) {
    print BOLD RED "Failed to find any existing GID!\n";
    return 0;
  }

  # Find the largest GID
  my @gids;
  foreach my $gid ($gid_search_result->all_entries) {
    push @gids, $gid->get_value('gidNumber');
  } 
  @gids = sort { $b <=> $a } @gids;
  my $next_gid = $gids[0];

  # Check that a duplicate local GID does not exist on the head or the login nodes
  foreach my $each_server (qw(headnode0-dev.cssd.pitt.edu headnode1-dev.cssd.pitt.edu login0-dev.cssd.pitt.edu login1-dev.cssd.pitt.edu)) {

    # Open an SSH connection
    my $ssh = Net::OpenSSH->new(
      "$each_server",
#       key_path => "/root/.ssh/id_dsa",
      timeout => 120,
      kill_ssh_on_timeout => 1,
    );
    
    # Check for an SSH error
    if ($ssh->error) {
      warn BOLD RED "ERROR: Failed to establish SSH connection to $each_server to check for duplicate GID: " . $ssh->error;
      next;
    }

    my $gid_check_passed;
    until ($gid_check_passed) {

      # Check for a duplicate GID
      if ($ssh->system("grep $next_gid /etc/group >/dev/null")) {
#	print "Duplicate GID found on ${each_server}, incrementing GID.\n";
	++$next_gid;
      }
      else {
# 	print "No duplicate GID found on ${each_server}.\n";
	$gid_check_passed = 1;
      }

    }
  }

  return $next_gid;
}

# Get gidNumber from a group name
sub get_gidnumber_of_group {
  # In a scalar conext, returns the GID of the group
  # Usage: get_gidnumber_of_group($group_name)

  if (!$_[0]) {
    warn BOLD RED "Invalid use of sub get_gidnumber_of_group.";
    return;
  }

  my $group_id = $_[0];

  # Bind to LDAP if we haven't already
  do_ldap_bind if (!$ldap);

  # Check if the group already exists
  if (!ldap_search_group($group_id,0)) {
    print BOLD RED "Group '$group_id' does not exist.\n";
    return 0;
  }

  my $gidnumber_search_result = $ldap->search(
    base => "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 120,
    filter => "(cn=$group_id)",
    attrs => ['gidNumber']
  );

  # Did we get an error?
  if ($gidnumber_search_result->code) {
    die BOLD RED "LDAP search failed: " . $gidnumber_search_result->error;
  }

  # Give the first gidnumber found as the return status
  foreach my $entr ($gidnumber_search_result->entries) { 
    my $gidnumber = $entr->get_value("gidNumber");
    return $gidnumber;
  }
}

# Create a new user
sub ldap_create_user {
  # In a scalar conext, returns 1 if successful
  # Usage: ldap_create_user($user_name,$group_name)

  # Were we called correctly?
  if ((!$_[0]) or (!$_[1])) {
    warn BOLD RED "Invalid use of subroutine ldap_create_user.";
    return;
  }

  my $user_id = $_[0];
  my $group_id = $_[1];

  # Bind to LDAP if we haven't already
  do_ldap_bind if (!$ldap);

  # Check if the user already exists
  if (ldap_search_user($user_id,0)) {
    print BOLD RED "User '$user_id' already exists.\n";
    return 0;
  }

  # Get the gidNumber of the group
  my $gidnumber = get_gidnumber_of_group($group_id);

  # Get the next available numeric UID
  my $next_uid = get_next_uid;

  # Check that we have all attributes needed
  if (!$user_id) {
    warn BOLD RED "Attribute '\$user_id' is missing/unset.  Unable to add user.";
    return;
  }
  elsif (!$group_id) {
    warn BOLD RED "Attribute '\$group_id' is missing/unset.  Unable to add user.";
    return;
  }
  elsif (!$gidnumber) {
    warn BOLD RED "Attribute '\$gid_number' is missing/unset.  Unable to add user.";
    return;
  }
  elsif (!$next_uid) {
    warn BOLD RED "Attribute '\$next_uid' is missing/unset.  Unable to add user.";
    return;
  }

  # Add the user
  my $user_create_result = $ldap->add("cn=$user_id,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
    attr => [
      "cn" => ["$user_id"],
      "gidNumber" => "$gidnumber",
      "homeDirectory" => "/home/$group_id/$user_id",
      "uid" => "$user_id",
      "uidNumber" => "$next_uid",
      "loginShell" => "/bin/bash",
      "userPassword" => "{SASL}$user_id",
      "objectclass" => ["top", "posixAccount", "account"],
    ]
  );

  # Did we get an error?
  if ($user_create_result->code) {
    warn BOLD RED "LDAP user add failed: " . $user_create_result->error;
    return;
  }
  else {

    # Set the default quota
    my $hostname = `hostname`;
    my $gluster_volume = "vol_home-francis" if ($hostname =~ m/-dev/);
    $gluster_volume = "vol_home" if (!$gluster_volume);

    if (set_gluster_quota($gluster_volume, "/$group_id/$user_id", "100GB")) {
      print BOLD GREEN "Successfully set quota '100GB' on '/$group_id/$user_id'.\n";
      return 1;
    }
    else {
      print BOLD RED "Failed to to set quota '100GB' on '/$group_id/$user_id'.\n";
      return;
    }

  }
}

# Create a new group
sub ldap_create_group {
  # In a scalar conext, returns 1 if successful
  # Usage: ldap_create_group($group_name,$group_type)

  # Were we called correctly?
  if ((!$_[0]) or (!$_[1])) {
    warn BOLD RED "Invalid use of sub ldap_create_group.";
    return;
  }

  my $group_id = $_[0];

  # Bind to LDAP if we haven't already
  do_ldap_bind if (!$ldap);

  # Check if the group already exists
  if (ldap_search_group($group_id,0)) {
    print BOLD RED "Group '$group_id' already exists.\n";
    return 0;
  }

  # Get the next available numeric GID
  my $next_gid = get_next_gid;

  # Check that we have all attributes needed
  if (!$group_id) {
    die BOLD RED "Attribute '\$group_id' is missing/unset!  Unable to add user.\n";
  }

  # Add the group
  my $group_create_result = $ldap->add("cn=$group_id,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    attr => [
      "cn" => ["$group_id"],
      "gidNumber" => "$next_gid",
      "objectclass" => ["top", "posixGroup"],
    ]
  );

  # Did we get an error?
  if ($group_create_result->code) {
    die BOLD RED "LDAP group add failed: " . $group_create_result->error;
  }
  else {
    return 1;
  }
}

# Add user to a group
sub add_group_member {
  # In a scalar context returns 1 if successful
  # Usage: add_group_member($user_name,$group_name)

  # Were we called correctly?
  if ((!$_[0]) or (!$_[1])) {
    warn BOLD RED "Invalid use of sub add_group_member.";
    return;
  }

  my $user_id = $_[0];
  my $group_id = $_[1];

  # Bind to LDAP if we haven't already
  do_ldap_bind if (!$ldap);

  # Check if the user already exists
  if (!ldap_search_user($user_id,0)) {
    print BOLD RED "User '$user_id' does not exist, cannot add to group '$group_id'.\n";
    return 0;
  }

  # Check if the group already exists
  if (!ldap_search_group($group_id,0)) {
    print BOLD RED "Group '$group_id' does not exist, cannot add user '$user_id'.\n";
    return 0;
  }

  # If the member add is for a "groupOfNames" group, add the member
  my $group_member_result = $ldap->modify("cn=$group_id,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    add => {
      member => "cn=$user_id,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu"
    }
  ) if ($group_id eq "sam_frank_active_users");

  # If the member add is for a "posixGroup" group, add the member
  $group_member_result = $ldap->modify("cn=$group_id,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    add => {
      memberUid => "$user_id"
    }
  ) if (!$group_member_result);

  # Did we get an error?
  if ($group_member_result->code) {
    warn BOLD RED "LDAP group member add failed: " . $group_member_result->error;
  }
  else {
    return 1;
  }
}

# Display a Gluster quota
sub show_gluster_quota {
  # In a scalar context returns 1 if successful, -1 for a unset quota, undef on error
  # Usage:show_gluster_quota($gluster_volume, "/path/to/check")

  # Were we called correctly?
  if ((!$_[0]) or (!$_[1]) or ($_[1] !~ m|^/|)) {
    warn BOLD RED "Invalid use of show_gluster_quota.";
    return;
  }

  my $gluster_volume = $_[0];
  my $quota_path = $_[1];
  $quota_path =~ s|/+$||; # Remove any trailing slash

  # Determine which server to connect to
  my $storage_server;
  if ($gluster_volume eq "vol_home") {
    $storage_server = "storage1.frank.sam.pitt.edu";
  }
  elsif ($gluster_volume eq "vol_global_scratch") {
    $storage_server = "storage2.frank.sam.pitt.edu";
  }
  elsif ($gluster_volume eq "vol_home-francis") {
    $storage_server = "storage0-dev.cssd.pitt.edu";
    $gluster_volume = "vol_home";
  }
  else {
    warn BOLD RED "Failed to determine storage server name, volume '$gluster_volume' is unknown.";
    return;
  }

  # Open an SSH connection
  my $ssh = Net::OpenSSH->new(
    "$storage_server",
#       key_path => "/root/.ssh/id_dsa",
    timeout => 120,
    kill_ssh_on_timeout => 1,
  );
  
  # Check for an SSH error
  if ($ssh->error) {
    warn BOLD RED "Failed to establish SSH connection to $storage_server to get Gluster quota for '$quota_path': " . $ssh->error;
    return;
  }
  
  # Get the quota list output
  print "Be patient, this may take a while...\n";
  my ($quota_out,$quota_err) = $ssh->capture2({ timeout => 600 }, "/usr/sbin/gluster volume quota $gluster_volume list $quota_path");

  # Check if the quota feature is disabled
  if ($quota_err) {
    chomp $quota_err;
    warn BOLD RED "Failed to run gluster command to determine quota for '$quota_path': $quota_err";
    return -1;
  }

  # Check for an SSH error and that the command completed successfully
  if ($ssh->error) {
    warn BOLD RED "Failed to run gluster command to determine quota for '$quota_path': $quota_err\n" . $ssh->error;
    return;
  }

  # Check if the quota is unset or if any quota exists at all
  if ($quota_out =~ m/^$/) {
    print "No quota has been set for $quota_path.\n";
    return -1;
  }
  elsif ($quota_out =~ m/^Limit not set on any directory$/) {
    print "No quota has been set for $quota_path (or any other).\n";
    return -1;
  }

  # Get the quota limit and usage then print it
  my ($quota_limit,$quota_usage) = (split(m/\s+/, $quota_out))[6,7];

  $quota_usage = "0KB" if (!$quota_usage);

  if (($quota_limit) and ($quota_usage)) {
    print "Quota: $quota_path has $quota_usage of $quota_limit used.\n";
    return 1;
  }
  else {
    warn BOLD RED "Failed to get Gluster quota for '$quota_path'.";
    return;
  }

}

# Set a Gluster quota
sub set_gluster_quota {
  # In a scalar context returns 1 if successful, undef on error
  # Usage:set_gluster_quota($gluster_volume, "/path/to/set", $quota_limit)

  # Were we called correctly?
  if ((!$_[0]) or (!$_[1]) or ($_[1] !~ m|^/|) or (!$_[2])) {
    warn BOLD RED "Invalid use of set_gluster_quota.";
    return;
  }

  my $gluster_volume = $_[0];
  my $quota_path = $_[1];
  my $quota_limit = $_[2];
  $quota_path =~ s|/+$||; # Remove any trailing slash

  # Determine which server to connect to
  my $storage_server;
  if ($gluster_volume eq "vol_home") {
    $storage_server = "storage1.frank.sam.pitt.edu";
  }
  elsif ($gluster_volume eq "vol_global_scratch") {
    $storage_server = "storage2.frank.sam.pitt.edu";
  }
  elsif ($gluster_volume eq "vol_home-francis") {
    $storage_server = "storage0-dev.cssd.pitt.edu";
    $gluster_volume = "vol_home";
  }
  else {
    warn BOLD RED "Failed to determine storage server name, volume '$gluster_volume' is unknown.";
    return;
  }

  # Open an SSH connection
  my $ssh = Net::OpenSSH->new(
    "$storage_server",
#       key_path => "/root/.ssh/id_dsa",
    timeout => 120,
    kill_ssh_on_timeout => 1,
  );
  
  # Check for an SSH error
  if ($ssh->error) {
    warn BOLD RED "Failed to establish SSH connection to $storage_server to get Gluster quota for '$quota_path': " . $ssh->error;
    return;
  }

  # Get the quota set output
  my ($quota_out,$quota_err) = $ssh->capture2({ timeout => 60 }, "/usr/sbin/gluster volume quota $gluster_volume limit-usage $quota_path $quota_limit");

  # Check for an SSH error and that the command completed successfully
  if ($ssh->error) {
    warn BOLD RED "Failed to run gluster command to set quota for '$quota_path': $quota_err\n" . $ssh->error;
    return;
  }
  else {
    return 1;
  }

}

# Display the initial choice dialog
print "1  Search for a user\n";
print "2  Search for a group\n";
print "3  Create a new user\n";
print "4  Create a new group\n";
print "5  Add a user to an existing group\n";
print "6  Work with disk quotas\n";
print "q  Quit\n";
print "Select an option: ";
chomp(my $user_choice = <STDIN>);

if ($user_choice == 1) { # Display information about a user

  print "Enter user name or UID: ";
  chomp(my $user_id = <STDIN>);

  if (!ldap_search_user($user_id,1)) {
    print BOLD RED "User '$user_id' does not exist.\n";
  }

}

elsif ($user_choice == 2) { # Display information about a group

  print "Enter group name or GID: ";
  chomp(my $group_id = <STDIN>);

  if (!ldap_search_group($group_id,1)) {
    print BOLD RED "Group '$group_id' does not exist.\n";
  }

}

elsif ($user_choice == 3) { # Create a new user

  print "Enter a user name: ";
  chomp(my $user_id = <STDIN>);
  
  print "Enter a group name: ";
  chomp(my $group_id = <STDIN>);

  # Check if the group already exists
  if (!ldap_search_group($group_id,0)) {
    print "Group '$group_id' does not exist.\n";
    print "Do you want to create it? y or n: ";
    chomp(my $user_choice = <STDIN>);

    if (($user_choice eq "y") or ($user_choice eq "Y")) {

      # Get the group type
      print "1  Faculty\n";
      print "2  Software\n";
      print "3  Training\n";
      print "4  Course\n";
      print "5  Center\n";
      print "Select a group type: ";
      chomp(my $group_type_choice = <STDIN>);
      my $group_type = "faculty" if ($group_type_choice == 1);
      $group_type = "software" if ($group_type_choice == 2);
      $group_type = "training" if ($group_type_choice == 3);
      $group_type = "course" if ($group_type_choice == 4);
      $group_type = "center" if ($group_type_choice == 5);
      if (!$group_type) {
	print BOLD RED "Unable to create group, invalid group type.\n";
	exit 1;
      }

      # Create the group
      if (ldap_create_group($group_id,$group_type)) {
	print BOLD GREEN "Successfully added group '$group_id'.\n";
      }
      else {
	exit 1;
      }

    }
    else {
      print BOLD RED "Failed to create user, group doesn't exist.\n";
      exit 1;
    }
  }

  # Create the user
  if (ldap_create_user($user_id,$group_id)) {
    print BOLD GREEN "Successfully added user '$user_id'.\n";
    print "Remember: Add the new user to the SSL VPN role.\n";
  }
  else {
    exit 1;
  }

  # Add the user their primary group
  if (add_group_member($user_id,$group_id)) {
    print BOLD GREEN "Successfully added user '$user_id' as member of their primary group '$group_id'.\n";
  }

  # Add the user the active users group
  if (add_group_member($user_id,"sam_frank_active_users")) {
    print BOLD GREEN "Successfully added user '$user_id' as member of the active users group 'sam_frank_active_users'.\n";
  }

}

elsif ($user_choice == 4) { # Create a new group

  print "Enter a group name: ";
  chomp(my $group_id = <STDIN>);
  
  # Get the group type
  print "1  Faculty\n";
  print "2  Software\n";
  print "3  Training\n";
  print "4  Course\n";
  print "5  Center\n";
  print "Select a group type: ";
  chomp(my $group_type_choice = <STDIN>);
  my $group_type = "faculty" if ($group_type_choice == 1);
  $group_type = "software" if ($group_type_choice == 2);
  $group_type = "training" if ($group_type_choice == 3);
  $group_type = "course" if ($group_type_choice == 4);
  $group_type = "center" if ($group_type_choice == 5);
  if (!$group_type) {
    print BOLD RED "Unable to create group, invalid group type.\n";
    exit 1;
  }

  # Create the group
  if (ldap_create_group($group_id,$group_type)) {
    print BOLD GREEN "Successfully added group '$group_id'.\n";
  }

}

elsif ($user_choice == 5) { # Add a user to an existing group

  print "Enter a user name: ";
  chomp(my $user_id = <STDIN>);
  
  print "Enter a group name: ";
  chomp(my $group_id = <STDIN>);

  # Add the user to the group
  if (add_group_member($user_id,$group_id)) {
    print BOLD GREEN "Successfully added user '$user_id' as member of  group '$group_id'.\n";
  }

}

elsif ($user_choice == 6) { # Work with disk quotas

  print "1  vol_home (Frank)\n";
  print "2  vol_global_scratch (Frank)\n";
  print "3  vol_home (Francis)\n";
  print "q  quit\n";
  print "Select an option: ";
  chomp(my $gluster_volume_choice = <STDIN>);
  my $gluster_volume;
  if ($gluster_volume_choice == 1) { # vol_home (Frank)
    $gluster_volume = "vol_home";
  }
  elsif ($gluster_volume_choice == 2) { # vol_global_scratch (Frank)
    $gluster_volume = "vol_global_scratch";
  }
  elsif ($gluster_volume_choice == 3) { # vol_home (Francis)
    $gluster_volume = "vol_home-francis";
  }
  elsif (($gluster_volume_choice eq "q") or ($gluster_volume_choice eq "Q")) { # Quit
    exit;
  }
  else {
    warn BOLD RED "Invalid selection.";
    exit 1;
  }

  print "1  User quota\n";
  print "2  Group quota\n";
  print "q  Quit\n";
  print "Select an option: ";
  chomp(my $user_choice = <STDIN>);

  if ($user_choice == 1) { # User quota
    print "Enter a user name: ";
    chomp(my $user_id = <STDIN>);

    # Check if the user exists
    if (!ldap_search_user($user_id,0)) {
      print BOLD RED "User '$user_id' does not exist.\n";
      exit 1;
    }

    # Search for the user in LDAP
    my $user_search_result = $ldap->search(
      base => "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
      scope => "sub",
      timelimit => 120,
      filter => "(uid=$user_id)",
      attrs => ['gidNumber']
    );

    # Did we get an error?
    if ($user_search_result->code) {
      die BOLD RED "Unable to determine group name for user '$user_id', LDAP search for user failed: " . $user_search_result->error;
    }

    # Get the results of the search
    my @gid_entries = $user_search_result->entries;
    my $primary_gid = $gid_entries[0]->get_value("gidNumber");
    if (!$primary_gid) {
      die BOLD RED "Unable to determine group name for user '$user_id', unable to get primary GID from LDAP.\n";
    }

    # Get the group name from the GID
    my $gid_search_result = $ldap->search(
      base => "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
      scope => "sub",
      timelimit => 120,
      filter => "(gidNumber=$primary_gid)",
      attrs => ['cn']
    );

    # Did we get an error?
    if ($user_search_result->code) {
      warn BOLD RED "Unable to determine group name for user '$user_id', LDAP search of primary GID failed: " . $user_search_result->error;
    }

    # Get the results of the search
    my @group_entries = $gid_search_result->entries;
    my $group_id = $group_entries[0]->get_value("cn");
    if (!$group_id) {
      warn BOLD RED "Unable to determine group name for user '$user_id', unable to get primary GID from LDAP.";
    }

    # Get the current quota
    if (!show_gluster_quota($gluster_volume, "/$group_id/$user_id")) {
      exit 1;
    }

    # Change the quota if we were told to
    print "Would you like to change/set the quota? y or n: ";
    chomp(my $user_set_quota_choice = <STDIN>);

    if (($user_set_quota_choice eq "y") or ($user_set_quota_choice eq "Y")) {
      print "Enter the new quota (e.g. 100GB or 250MB): ";
      chomp(my $new_quota = <STDIN>);
      if (set_gluster_quota($gluster_volume, "/$group_id/$user_id", $new_quota)) {
	print BOLD GREEN "Successfully set quota '$new_quota' on '/$group_id/$user_id'.\n";
      }
    }
    elsif (($user_set_quota_choice eq "n") or ($user_set_quota_choice eq "N")) {
      print "Leaving quota alone.\n";
    }
    else {
      warn BOLD RED "Invalid selection.";
      exit 1;
    }
  }

  elsif ($user_choice == 2) { # Group quota
    print "Enter a group name: ";
    chomp(my $group_id = <STDIN>);

    # Check if the group exists
    if (!ldap_search_group($group_id,0)) {
      print BOLD RED "Group '$group_id' does not exist.\n";
      exit 1;
    }

    # Get the current quota
    if (!show_gluster_quota($gluster_volume, "/$group_id")) {
      exit 1;
    }

    # Change the quota if we were told to
    print "Would you like to change/set the quota? y or n: ";
    chomp(my $user_set_quota_choice = <STDIN>);

    if (($user_set_quota_choice eq "y") or ($user_set_quota_choice eq "Y")) {
      print "Enter the new quota (e.g. 100GB or 250MB): ";
      chomp(my $new_quota = <STDIN>);
      if (set_gluster_quota($gluster_volume, "/$group_id", $new_quota)) {
	print BOLD GREEN "Successfully set quota '$new_quota' on '/$group_id'.\n";
      }
    }
    elsif (($user_set_quota_choice eq "n") or ($user_set_quota_choice eq "N")) {
      print "Leaving quota alone.\n";
    }
    else {
      warn BOLD RED "Invalid selection.";
      exit 1;
    }

  }

  elsif (($user_choice eq "q") or ($user_choice eq "Q")) { # Quit
    exit;
  }

  else {
    warn "Invalid selection.";
    exit 1;
  }

}

elsif (($user_choice eq "q") or ($user_choice eq "Q")) { # Quit

  exit;

}

else {

  warn BOLD RED "Invalid selection.";
  exit 1;

}