#!/usr/bin/env perl
use strict;
use warnings;

# Description: Parse multiple passwd files and print an ordered list of unique users
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

use Getopt::Long;

GetOptions('h|help' => \my $helpopt,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Parse multiple passwd files and print an ordered list of unique users\n";
  print "Usage: $0 file1 file2 filen\n";
  print "-h | --help : Show this help\n";
  exit;
}


my %unique_users;


# Get the list of users
for my $passwd_line (<>) {
  chomp $passwd_line;
  
  my $user = (split(m/:/, $passwd_line))[0];
  
  $unique_users{$user}++;
}


# Print the users sorted by 
for my $user (sort { $unique_users{$b} <=> $unique_users{$a} } keys %unique_users) {
  print "$user : $unique_users{$user}\n";
}