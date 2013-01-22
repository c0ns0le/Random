#!/usr/bin/perl
use warnings;
use strict;

# Description: Check for Mailmn mailing lists with more than X number of members.
# Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
# Version: 1.2
# Last change: Log the list name found, not the number of large lists found

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Sys::Syslog qw(:DEFAULT setlogsock);
use Getopt::Long;

# How many members must a list have to generate an alert?
my $member_num_threshold = "1000";

# Where are our binaries?
my $list_lists_binary = "/usr/local/mailman/bin/list_lists";
my $list_members_binary = "/usr/local/mailman/bin/list_members";
my $ignored_lists_file = "/usr/local/etc/known_big_lists.txt";

GetOptions('h|help' => \my $helpopt,
	   'i|ignored-lists=s' => \$ignored_lists_file,
          ) || die "Incorrect usage, use -h for help.\n";

if (($helpopt) or (!$ignored_lists_file)) {
  print "Description: Check for mailing lists with more than X number of members.\n";
  print "Usage: $0 [OPTION]\n";
  print "-h | --help : Show this help.\n";
  print "-i | --ignored-lists /path/to/file.txt : File arg with a list of lists that are ignored. (Default: /usr/local/etc/known_big_lists.txt)\n";
  exit;
}

# Prepare for syslog()
setlogsock("unix");
openlog($0, "nonul,pid", "user") or warn "Unable to open syslog connection\n";

# Get the list of ignored lists
open my $IGNORED_LISTS_FILE, "$ignored_lists_file" or die "Unable to open ignored lists file: $!";
my %ignored_lists;
for my $list (<$IGNORED_LISTS_FILE>) {
  chomp $list;
  
  $ignored_lists{$list} = 1;
}
close $IGNORED_LISTS_FILE;

# Loop through each list and check how many members it has
my %lists_num_members;
for my $each_list_name (`$list_lists_binary --bare`){
  chomp $each_list_name;

  # Get the list roster
  my @current_list_members = `$list_members_binary $each_list_name`;
  
  # Add the list and it's number of members to the hash
  $lists_num_members{$each_list_name} = scalar @current_list_members;

  # If the number of list members is equal to or higher than the threshold AND is not in the ignore list...
  if (($lists_num_members{$each_list_name} >= $member_num_threshold) and (!$ignored_lists{$each_list_name})){
    print "List $each_list_name has $lists_num_members{$each_list_name} members.\n";
    syslog("LOG_ERR", "NOC-NETCOOL-TICKET: List '$each_list_name' has more than $member_num_threshold members.  Please investigate.");
  }
}

closelog;