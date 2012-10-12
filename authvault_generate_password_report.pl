#!/usr/bin/perl
# Description: Perl script to parse a CSV and generate a report
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.1
# Last change: Don't output old password if there was none, minor code cleanup

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

use strict;
use warnings;
use Getopt::Long;
use Text::CSV;

GetOptions('h|help' => \my $helpopt,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Usage: $0 file1 file2 filen\n";
  print "-h | --help : Show this help\n";
  exit;
}

# Read in the files into an array
my @all_lines = <>;

# Loop through each line of the CSV and note the category
my @categories;
my $csv = Text::CSV->new({ binary => 1, empty_is_undef => 1});
for my $each_line (@all_lines) {

  # Warn if we can't parse a line
  if ($csv->parse($each_line)) {
    my ($name,$category,$user,$password,$old_password,$change_date) = $csv->fields();

    # Note the category if it's a new one
    if (!grep /\Q$category\E/, @categories) {
      push @categories, $category;
    }

  } else {
    my $error_desc = $csv->error_diag;
    warn "Failed to parse line: $error_desc";
  }

}

for my $each_category (@categories) {
  print "$each_category:\n";

  # Loop through each line of the CSV and print out the line if it matches the category
  for my $each_line (@all_lines) {

    # Warn if we can't parse a line
    if ($csv->parse($each_line)) {
      my ($name,$category,$user,$password,$old_password,$change_date) = $csv->fields();
      
      # Print if it matches the category
      if ($category eq $each_category) {
	print "Name: $name\n";
	print "User: $user\n";
	print "Password: $password\n";
	if (($old_password) and ($old_password eq "nothing")) {
          print "\n";
	}
	elsif ($old_password) {
          print "Old Password: $old_password\n\n";
        }
      }

    }
    else {
      my $error_desc = $csv->error_diag;
      warn "Failed to parse line: $error_desc";
    }
  }
  print "\n\n";
}