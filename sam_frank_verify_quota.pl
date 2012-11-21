#!/usr/bin/env perl
use strict;
use warnings;
# Description: Verify filesystems quotas are correct and set them if not
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Inital version

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Getopt::Long;
Getopt::Long::Configure("bundling");
use Net::LDAP;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use Quota;
use Term::ReadKey;
use Sys::Hostname;

GetOptions('h|help' => \my $helpopt,
           'd|display' => \my $do_display,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Verify filesystems quotas are correct and set them if not.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  print "-d | --display : Display every user's quota rather than checking for mismatches\n";
  exit;
}


# Determine what our LDAP quota attribute is and which local filesystem we should use
my ($filesystem, $quota_attr);
my $hostname = hostname();
if ($hostname eq "storage0.frank.sam.pitt.edu") {
  $filesystem = "/data";
  $quota_attr = "quotaHome0";
  print "Partner node: storage4\n";
}
elsif ($hostname eq "storage4.frank.sam.pitt.edu") {
  $filesystem = "/data/home";
  $quota_attr = "quotaHome0";
  print "Partner node: storage0\n";
}
elsif ($hostname eq "headnode1.frank.sam.pitt.edu") {
  $filesystem = "/data/gscratch1";
  $quota_attr = "quotaGscratch1";
}
else {
  die "$hostname is not a known/supported storage node\n";
}

#
# Connect to LDAP
#
my $ldap_object = Net::LDAP->new(
  "sam-ldap-prod-01.cssd.pitt.edu",
  port => "389",
  verify => "none",
);

my $bind_mesg = $ldap_object->bind();

$bind_mesg->code && die "Failed to bind with the LDAP server: " . $bind_mesg->error;


#
# From LDAP, get the list of users and their quota
#

# Search LDAP
my $ldap_quota_search_result = $ldap_object->search(
  base => "ou=person,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu",
  scope => "sub",
  timelimit => 30,
  filter => "($quota_attr=*)",
  attrs => ["cn", $quota_attr],
);

$ldap_quota_search_result->code && die $ldap_quota_search_result->error;

# Get the search results
my @ldap_quota_entries = $ldap_quota_search_result->entries;

my %ldap_quota;
for my $each_entry (@ldap_quota_entries) {
  my $user_name = $each_entry->get_value("cn");
  my $quota = $each_entry->get_value($quota_attr);
  
  # We get a few null results, I don't know why....
  if (($user_name) and ($quota)) {
    $ldap_quota{$user_name} = $quota;
  }
  elsif (($user_name) and (!$quota)) {
    print BOLD RED "Missing quota: $user_name\n";
  }
}


#
# Disconnect from LDAP
#

$ldap_object->unbind;
$ldap_object->disconnect;


#
# Loop through each user and check their local quota
#

my $device = Quota::getqcarg( $filesystem );
while (my($user, $ldap_quota) = each(%ldap_quota)) {

  # Get the user's uidNumber
  my $uid_number = (getpwnam($user))[2];

  # Get the current quota
  my ($local_soft_quota, $local_hard_quota) = (Quota::query( $device,$uid_number ))[1,2];
  
  my $local_quota;
  if ((!$local_soft_quota) or (!$local_hard_quota)) {
    $local_soft_quota = 0;
    $local_hard_quota = 0;
  }
  elsif ($local_hard_quota) {
    $local_soft_quota = sprintf("%.0f", $local_soft_quota / 1024 / 1024);
    $local_hard_quota = sprintf("%.0f", $local_hard_quota / 1024 / 1024);
  }
  else {
    $local_soft_quota = "?";
    $local_hard_quota = "?";
  }
  

  # Print the each user's quota if we were asked to
  if ($do_display) {
    print "$user: $ldap_quota GB in LDAP, $local_hard_quota GB on local system\n";
  }
  else {
    # Determine if the local quota is correct
    if ($local_hard_quota eq "?") {
      print BOLD RED "Failed to find quota for $user\n";
    }
    elsif ($ldap_quota != $local_hard_quota) {
      print BOLD GREEN "$user has a quota mismatch ($ldap_quota vs $local_hard_quota).  Should I fix ${user}'s local quota? y or n: ";
      chomp(my $do_fix_quota = <STDIN>);
      
      if (($do_fix_quota eq "y" ) or ($do_fix_quota eq "Y")) {
        my $soft_qouta_kb = ($ldap_quota - 10) * 1024 * 1024;
        my $hard_quota_kb = $ldap_quota * 1024 * 1024;

        Quota::setqlim( $device, $uid_number, $soft_qouta_kb, $hard_quota_kb, 0, 0, 0, 0 );
      }
    }
  }

}