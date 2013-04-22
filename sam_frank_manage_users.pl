#!/usr/bin/perl
use strict;
use warnings;
# Description: This script is used to manage users on the Frank HPC cluster of the SaM group at the University of Pittsburgh
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 2.1
# Last change: Fixed double increment of next UID

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
	  ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "This script is used to manage users on the Frank HPC cluster of the SaM group at the University of Pittsburgh.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "-h | --help : Show this help\n";
  exit;
}

my ($ldap, $start_tls_mesg, $bind_mesg);
$| = 1;

# Connect to the LDAP server
sub do_ldap_bind {
  # In a scalar conext, returns 1 if successful, dies otherwise
  # If passed with anything it will be used as the username to authenticate with
  # otherwise it will do an anonymous bind
  # Usage: do_ldap_bind($auth_user_id)

  $ldap = Net::LDAP->new(
    "ldap://sam-ldap-prod-01.cssd.pitt.edu",
    version => 3,
#     debug => 8,
  ) or die BOLD RED "Failed to connect to the LDAP server: $@";

  $start_tls_mesg = $ldap->start_tls(
    verify => "never",
    capath => "/etc/openldap/cacerts/"
  );

  $start_tls_mesg->code && die BOLD RED "Failed to start TLS session with the LDAP server: " . $start_tls_mesg->error;

  my ($auth_user_id, $bind_mesg);
  
  if ($auth_user_id = shift) {
  
    print "Enter your password to authenticate to the LDAP server: ";
    ReadMode("noecho"); # don't echo
    chomp(my $ldap_password = <STDIN>);
    ReadMode(0); # back to normal
    print "\n";
    
    $bind_mesg = $ldap->bind(
      "cn=$auth_user_id,ou=person,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
      password => $ldap_password
    );
    
  }
  else {
  
    $bind_mesg = $ldap->bind();
  
  }

  $bind_mesg->code && die BOLD RED "Failed to bind with the LDAP server: " . $bind_mesg->error;

  return 1;
}

# Search for a user in LDAP
sub ldap_search_user {
  # In a scalar conext, returns the number of matches
  # Usage: ldap_search_user($user_or_uid,$do_print)
  # If the second arg is true the results of the search will be printed.

  my $user_id = shift;
  my $do_print = shift;
  
  # Were we called correctly?
  unless ($user_id) {
    warn BOLD RED "Invalid use of subroutine ldap_search_user.";
    return;
  }

  # Were we given a number?  Must be a UID...
  my $user_search_result = $ldap->search(
    base => "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 30,
    filter => "(uidNumber=$user_id)",
    attrs => ['*']
  ) if ($user_id =~ m/^[+-]?\d+$/);

  # We didn't already search for a user by UID?  We must have been given a user name...
  $user_search_result = $ldap->search(
    base => "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 30,
    filter => "(cn=$user_id)",
    attrs => ['*']
  ) unless ($user_search_result);

  # Did we get an error?
  if ($user_search_result->code) {
    warn BOLD RED "LDAP search failed: " . $user_search_result->error;
  }

  # Get the results of the search
  my @entries = $user_search_result->entries;

  # Print the non-binary attributes that were found if we were called to do so
  if ($do_print) {
    foreach my $entr (@entries) {
      print "DN: ", $entr->dn, "\n";
      foreach my $attr (sort $entr->attributes) {
	# skip binary we can't handle
	next if ($attr =~ m/;binary$/);
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

  my $group_id = shift;
  my $do_print = shift;
  
  # Were we called correctly?
  unless ($group_id) {
    warn BOLD RED "Invalid use of subroutine ldap_search_group.";
    return;
  }

  # Were we given a number?  Must be a GID...
  my $group_search_result = $ldap->search(
    base => "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 30,
    filter => "(gidNumber=$group_id)",
    attrs => ['*']
  ) if ($group_id =~ m/^[+-]?\d+$/);

  # We didn't already search for a group by GID?  We must have been given a group name...
  $group_search_result = $ldap->search(
    base => "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 30,
    filter => "(cn=$group_id)",
    attrs => ['*']
  ) unless ($group_search_result);

  # Did we get an error?
  if ($group_search_result->code) {
    die BOLD RED "LDAP search failed: " . $group_search_result->error;
  }

  # Get the results of the search
  my @entries = $group_search_result->entries;

  # Print the non-binary attributes that were found if we were called to do so
  if ($do_print) {
    foreach my $entr (@entries) {
      print "DN: ", $entr->dn, "\n";
      foreach my $attr (sort $entr->attributes) {
	# skip binary we can't handle
	next if ($attr =~ m/;binary$/);
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

  my $uid_search_result = $ldap->search(
    base => "ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 30,
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
  unless (@entries) {
    print BOLD RED "Failed to find any existing UID!\n";
    return 0;
  }

  # Find the largest UID
  my @uids;
  foreach my $uid ($uid_search_result->all_entries) {
    push @uids, $uid->get_value('uidNumber');
  } 
  @uids = sort { $b <=> $a } @uids;
  my $next_uid = $uids[0];

  return ++$next_uid;
}

# Get the next available GID
sub get_next_gid {
  # In a scalar conext, returns the next available GID
  # Usage: get_next_gid()

  my $gid_search_result = $ldap->search(
    base => "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 30,
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
  unless (@entries) {
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

  return ++$next_gid;
}

# Get gidNumber from a group name
sub get_gidnumber_of_group {
  # In a scalar conext, returns the GID of the group
  # Usage: get_gidnumber_of_group($group_name)

  my $group_id = shift;
  
  unless ($group_id) {
    warn BOLD RED "Invalid use of sub get_gidnumber_of_group.";
    return;
  }

  # Check if the group already exists
  unless (ldap_search_group($group_id,0)) {
    print BOLD RED "Group '$group_id' does not exist.\n";
    return 0;
  }

  my $gidnumber_search_result = $ldap->search(
    base => "ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    scope => "sub",
    timelimit => 30,
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

  my $user_id = shift;
  my $group_id = shift;
  
  # Were we called correctly?
  unless (($user_id) and ($group_id)) {
    warn BOLD RED "Invalid use of subroutine ldap_create_user.";
    return;
  }

  # Get the gidNumber of the group
  my $gidnumber = get_gidnumber_of_group($group_id);

  # Get the next available numeric UID
  my $next_uid = get_next_uid;

  # Check that we have all attributes needed
  unless (($user_id) and ($group_id) and ($gidnumber) and ($next_uid)){
    warn BOLD RED "Attribute is missing/unset.  Unable to add user.";
    return;
  }

  # Add the user
  my $user_create_result = $ldap->add("cn=$user_id,ou=person,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
    attr => [
      "cn" => ["$user_id"],
      "gidNumber" => "$gidnumber",
      "homeDirectory" => "/home/$group_id/$user_id",
      "uid" => "$user_id",
      "uidNumber" => "$next_uid",
      "loginShell" => "/bin/bash",
      "userPassword" => "{SASL}$user_id",
      "quotaHome0" => 100,
      "objectclass" => ["top", "posixAccount", "account", "filesystemQuotas"],
    ]
  );

  # Did we get an error?
  if ($user_create_result->code) {
    warn BOLD RED "LDAP user add failed: " . $user_create_result->error;
    return;
  }
  else {
    return 1;
  }

}

# Create a new group
sub ldap_create_group {
  # In a scalar conext, returns 1 if successful
  # Usage: ldap_create_group($group_name,$group_type)

  my $group_id = shift;
  my $group_type = shift;
  
  # Were we called correctly?
  unless (($group_id) and ($group_type)) {
    warn BOLD RED "Invalid use of sub ldap_create_group.";
    return;
  }

  # Get the next available numeric GID
  my $next_gid = get_next_gid;

  # Add the group
  my $group_create_result = $ldap->add("cn=$group_id,ou=$group_type,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
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
  # In a scalar context returns 1 if successful, undef on error
  # Usage: add_group_member($user_name, $group_name, $group_type)

  my $user_id = shift;
  my $group_id = shift;
  my $group_type = shift; # We don't use this for the group "sam_frank_active_users"
  
  # Were we called correctly?
  unless (($user_id) and ($group_id) and ($group_type)) {
    warn BOLD RED "Invalid use of sub add_group_member.";
    return;
  }

  # If the member add is for a "groupOfNames" group, add the member
  my $group_member_result = $ldap->modify("cn=$group_id,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    add => {
      member => "cn=$user_id,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu"
    }
  ) if ($group_id eq "sam_frank_active_users");
  
  # Now add the user
  $group_member_result = $ldap->modify("cn=$group_id,ou=$group_type,ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu",
    add => {
      memberUid => "$user_id"
    }
  ) unless ($group_member_result);

  # Did we get an error?
  if ($group_member_result->code) {
    warn BOLD RED "LDAP group member add failed for user '$user_id' and group '$group_id': " . $group_member_result->error;
    return;
  }
  else {
    return 1;
  }
}

# Set a quota
sub set_quota {
  # In a scalar context returns 1 if successful, undef on error
  # Usage: set_quota($user_name, $quota_attribute, $quota_amount)
  # Quota type is quotaHome0, quotaHome1, quotaHome2, quotaGscratch0 or quotaGscratch1, $quota_amount must be a non-zero integer in GB
  
  my $user_id = shift;
  my $quota_attribute = shift;
  my $quota_amount = shift;
  
  unless (($user_id) and ($quota_attribute) and ($quota_amount)) {
    warn BOLD RED "Invalid use of sub set_quota.";
    return;
  }
  
  # Set the quota in LDAP
  my $ldap_quota_modify_result = $ldap->modify("cn=$user_id,ou=person,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
    replace => {
      $quota_attribute => $quota_amount
    }
  );
  
  # Did we get an error?
  if ($ldap_quota_modify_result->code) {
    warn BOLD RED "LDAP quota attribute modification failed: " . $ldap_quota_modify_result->error;
    return;
  }

  # Which server(s) do we need to connect to?
  my @storage_servers;
  if ($quota_attribute eq "quotaHome0") {
    @storage_servers = qw(s-home0a.frank.sam.pitt.edu s-home0b.frank.sam.pitt.edu);
  }
  if ($quota_attribute eq "quotaHome1") {
    @storage_servers = qw(s-home1a.frank.sam.pitt.edu s-home1b.frank.sam.pitt.edu);
  }
  if ($quota_attribute eq "quotaHome2") {
    @storage_servers = qw(s-home2a.frank.sam.pitt.edu s-home2b.frank.sam.pitt.edu);
  }
  if ($quota_attribute eq "quotaGscratch0") {
    @storage_servers = qw(login0.frank.sam.pitt.edu);
  }
  if ($quota_attribute eq "quotaGscratch1") {
    @storage_servers = qw(headnode1.frank.sam.pitt.edu);
  }
  
  # SSH the each server and set the quota
  for my $storage_server (@storage_servers) {
    # Open an SSH connection
    my $ssh_object = Net::OpenSSH->new(
      $storage_server,
    # key_path => "/root/.ssh/id_dsa",
      timeout => 30,
      kill_ssh_on_timeout => 1,
    );
    
    # Check for an SSH error
    if ($ssh_object->error) {
      warn BOLD RED "Failed to establish SSH connection to '$storage_server' to set quota: " . $ssh_object->error;
      return;
    }
    
    unless ($ssh_object->test("/usr/local/bin/quota_verifier.pl" => "--user" => $user_id)) {
      warn BOLD RED "Failed to set quota on '$storage_server'.";
      return;
    }
    
  }
  
  return 1;

}

# Add a user to CoRE
sub add_core_user {
  # In a scalar context returns 1 if successful, undef on error
  # Usage: add_core_user($username, $user_email)
  
  my $user_id = shift;
  my $user_email = shift;
  
  unless (($user_id) and ($user_email)) {
    warn BOLD RED "Invalid use of sub add_core_user.";
    return;
  }
  
  # Open an SSH connection
  my $ssh_object = Net::OpenSSH->new(
    "coco.sam.pitt.edu",
    user => "drushuser",
    key_path => "/root/.ssh/id_rsa-core",
    timeout => 30,
    kill_ssh_on_timeout => 1,
  );
  
  # Check for an SSH error
  if ($ssh_object->error) {
    warn BOLD RED "Failed to establish SSH connection to 'coco.sam.pitt.edu' to set quota: " . $ssh_object->error;
    return;
  }
  
  unless ($ssh_object->test("/home/drushuser/addcoreuser" => $user_id => $user_email)) {
    warn BOLD RED "Failed to create CoRE user '$user_id' on 'coco.sam.pitt.edu'.";
    return;
  }
  
  return 1;

}


# Display the initial choice dialog
print "1  Search for a user\n";
print "2  Search for a group\n";
print "3  Create a new user\n";
print "4  Create a new group\n";
print "5  Change a disk quota\n";
print "q  Quit\n";
print "Select an option: ";
chomp(my $user_choice = <STDIN>);

if (($user_choice eq "q") or ($user_choice eq "Q")) { # Quit

  exit;

}

elsif ($user_choice == 1) { # Display information about a user

  print "Enter user name or UID: ";
  chomp(my $user_id = <STDIN>);
  
  do_ldap_bind();

  unless (ldap_search_user($user_id,1)) {
    print BOLD RED "User '$user_id' does not exist.\n";
  }

}

elsif ($user_choice == 2) { # Display information about a group

  print "Enter group name or GID: ";
  chomp(my $group_id = <STDIN>);
  
  do_ldap_bind();

  unless (ldap_search_group($group_id,1)) {
    print BOLD RED "Group '$group_id' does not exist.\n";
  }

}

elsif ($user_choice == 3) { # Create a new user

  print "Enter the new user name: ";
  chomp(my $user_id = <STDIN>);
  
  print "Enter the user's email address: ";
  chomp(my $user_email = <STDIN>);
  
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
  unless ($group_type) {
    print BOLD RED "Unable to create group, invalid group type.\n";
    exit 1;
  }
  
  print "Enter your user name to authenticate to the LDAP server: ";
  chomp(my $auth_user_id = <STDIN>);
  
  do_ldap_bind($auth_user_id);

  # Create the user
  if (ldap_create_user($user_id, $group_id)) {
    print BOLD GREEN "Successfully added user '$user_id' to LDAP.\n";
  }
  else {
    exit 1;
  }
  
  # Add the user their primary group
  if (add_group_member($user_id, $group_id, $group_type)) {
    print BOLD GREEN "Successfully added user '$user_id' as member of their primary group '$group_id'.\n";
  }

  # Add the user the active users group
  if (add_group_member($user_id, "sam_frank_active_users", "n/a")) {
    print BOLD GREEN "Successfully added user '$user_id' as member of the active users group 'sam_frank_active_users'.\n";
  }
  
  # Set the default /home quota
  if (set_quota($user_id, "quotaHome0", "100")) {
    print BOLD GREEN "Successfully set /home quota of '$user_id' to 100GB.\n";
  }

  # Gold
  system("/bin/sh /usr/local/bin/new_gold_group_users.sh $group_id >/dev/null");
  my $gold_status = $? / 256;
  if ($gold_status == 0) {
    print BOLD GREEN "Successfully added user '$user_id' to Gold.\n";
  }
  else {
    warn BOLD RED "Failed to add '$user_id' to Gold.\n";
  }

  # CoRE
  if (add_core_user($user_id, $user_email)) {
    print "Successfully created CoRE account for user '$user_id'\n";
  }

  print "Remember: Add the new user to the SSL VPN role.\n";

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
  
  my $group_type;
  if ($group_type_choice == 1) {
    $group_type = "faculty";
  }
  elsif ($group_type_choice == 2) {
    $group_type = "software";
  }
  elsif ($group_type_choice == 3) {
    $group_type = "training";
  }
  elsif ($group_type_choice == 4) {
    $group_type = "course";
  }
  elsif ($group_type_choice == 5) {
    $group_type = "center";
  }
  else {
    print BOLD RED "Invalid selection.\n";
    exit 1;
  }
  
  print "Enter your user name to authenticate to the LDAP server: ";
  chomp(my $auth_user_id = <STDIN>);
  
  do_ldap_bind($auth_user_id);

  # Create the group
  if (ldap_create_group($group_id,$group_type)) {
    print BOLD GREEN "Successfully added group '$group_id'.\n";
  }

}

elsif ($user_choice ==5) { # Change a disk quota

  print "1  /home\n";
  print "2  /home1\n";
  print "3  /home2\n";
  print "4  /gscratch0\n";
  print "5  /gscratch1\n";
  print "Select a storage area to change: ";
  chomp(my $quota_type_choice = <STDIN>);
  
  print "Enter the user name to change: ";
  chomp(my $user_id = <STDIN>);  

  print "Enter new quota amount in GB: ";
  chomp(my $quota_amount = <STDIN>);
  
  print "Enter your user name to authenticate to the LDAP server: ";
  chomp(my $auth_user_id = <STDIN>);
  
  do_ldap_bind($auth_user_id);

  if ($quota_type_choice == 1) {
    if (set_quota($user_id, "quotaHome0", $quota_amount)) {
      print BOLD GREEN "Successfully set quota of /home to ${quota_amount}GB.\n";
    }
  }
  elsif ($quota_type_choice == 2) {
    if (set_quota($user_id, "quotaHome1", $quota_amount)) {
      print BOLD GREEN "Successfully set quota of /home1 to ${quota_amount}GB.\n";
    }
  }
  elsif ($quota_type_choice == 3) {
    if (set_quota($user_id, "quotaHome2", $quota_amount)) {
      print BOLD GREEN "Successfully set quota of /home2 to ${quota_amount}GB.\n";
    }
  }
  elsif ($quota_type_choice == 4) {
    if (set_quota($user_id, "quotaGscratch0", $quota_amount)) {
      print BOLD GREEN "Successfully set quota of /gscratch0 to ${quota_amount}GB.\n";
    }
  }
  elsif ($quota_type_choice == 5) {
    if (set_quota($user_id, "quotaGscratch1", $quota_amount)) {
      print BOLD GREEN "Successfully set quota of /gscratch1 to ${quota_amount}GB.\n";
    }
  }
  else {
    print BOLD RED "Invalid selection.\n";
    exit 1;
  }

}

else {

  warn BOLD RED "Invalid selection.";
  exit 1;

}