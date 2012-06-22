#!/usr/bin/perl
#Description: Perl script to check for mailing lists with more than X number of members.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
# 0.1 - 2012-03-29 - Initial version. - Jeff White
#####

use warnings; #Print warnings
use strict; #Enforce 'good' programming rules
use Sys::Syslog;
use Getopt::Long;

# How many members must a list have to generate an alert?
my $member_num_threshold = "1000";

# Where are our binaries?
my $list_lists_binary = "/usr/local/mailman/bin/list_lists";
my $list_members_binary = "/usr/local/mailman/bin/list_members";

my %lists;
our $num_large_lists;

GetOptions('h|help' => \my $helpopt,
	   'i|ignored-lists=s' => \my $ignored_lists_file,
          ) || die "Incorrect usage, use -h for help.\n";

if (($helpopt) or (!$ignored_lists_file)) {
  print "Description: Check for mailing lists with more than $member_num_threshold number of members.\n";
  print "Usage: $0 [OPTION]\n";
  print "-h, --help : Show this help.\n";
  print "-i, --ignored-lists : Required. File with a list of lists that are ignored regardless of the number of members it has.\n";
  exit;
}

# Get the list of ignored lists
open my $IGNORED_LISTS_FILE, "$ignored_lists_file" or die "Unable to open ignored lists file: $!";
my @ignored_lists = <$IGNORED_LISTS_FILE>;
close $IGNORED_LISTS_FILE;

# Loop through each list and check how many members it has
for my $each_list_name (`$list_lists_binary --bare`){
  chomp $each_list_name;

  # Get the list roster
  my @current_list_members = `$list_members_binary $each_list_name`;

  # Add the list and it's number of members to the hash
  $lists{$each_list_name} = scalar @current_list_members;

  # If the number of list members is equal to or higher than the threshold AND is not in the ignored list...
  if ((scalar @current_list_members >= $member_num_threshold) and (!grep /$each_list_name/, @ignored_lists)){
    print "List $each_list_name has " . scalar @current_list_members . " members.\n";
    $num_large_lists++;
  }
}

# Create a Netcool alert if any new large lists are found
if ($num_large_lists) {
  print "Found $num_large_lists large lists.\n";
  syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Found $num_large_lists list(s) with more than $member_num_threshold members.  Please investigate the list(s). -- $0.");
} else {
  print "No large lists found.\n";
}