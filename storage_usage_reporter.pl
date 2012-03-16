#!/usr/bin/perl
use warnings; #Print warnings
use strict; #Enforce 'good' programming rules

# Name: storage_usage_reporter.pl
# Description: Perl script to create a report of data usage on Pitt's Frank HPC cluster.
# Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.2 - 2012-03-17 - Switched largest user/group section to use TB instead of GB, clarified file counts as files/directories.. - Jeff White
# 0.1 - 2012-03-16 - Initial version. - Jeff White
#
#####

use Getopt::Long;
GetOptions('h|help' => \my $help_opt);

if ($help_opt) {
  print "This script is designed to parse the output of 'find /path -ls' as input.\n";
  exit;
}

my (%user_numfiles, %group_numfiles, %user_datausage, %group_datausage);
our ($total_num_files, $total_datausage);

while (<>) {
  chomp;
  my ($user, $group, $filesize) = (split)[4,5,6];

  # User: number of files
  $user_numfiles{$user} += 1;

  # Group: number of files
  $group_numfiles{$group} += 1;

  # User: data usage
  $user_datausage{$user} += $filesize;

  # Group: data usage
  $group_datausage{$group} += $filesize;

  # Global stats
  $total_num_files++;
  $total_datausage += $filesize;
}

# Print the report for each user
for my $user (keys %user_numfiles) {
  my $average_file_size = sprintf "%.2f", $user_datausage{$user} / $user_numfiles{$user};
  print "User: $user\n";
  print "Number of files/directories: $user_numfiles{$user}\n";
  print "Data usage: " . sprintf("%.2f", $user_datausage{$user} / 1024 / 1024) . " MB\n";
  print "Average file size: " . sprintf("%.2f", $average_file_size / 1024 / 1024) . " MB\n";
}

# Print the report for each group
for my $group (keys %group_numfiles) {
  my $average_file_size = sprintf "%.2f", $group_datausage{$group} / $group_numfiles{$group};
  print "Group: $group\n";
  print "Number of files/directories: $group_numfiles{$group}\n";
  print "Data usage: " . sprintf("%.2f", $group_datausage{$group} / 1024 / 1024) . " MB\n";
  print "Average file size: " . sprintf("%.2f", $average_file_size / 1024 / 1024) . " MB\n";
}

# Print the final summary
use vars qw/$total_num_files $total_datausage/;
print "\n##### Summary\n";
print "Number of users: " . keys(%user_numfiles) . "\n";
print "Number of groups: " . keys(%group_numfiles) . "\n";
print "Total number of files/directories: $total_num_files\n";
print "Total file size: " . sprintf("%.2f", $total_datausage / 1024 / 1024 / 1024 / 1024) . " TB\n";
print "Average file size: " . sprintf("%.2f", $total_datausage / $total_num_files / 1024 / 1024) . " MB\n";
print "Average number of files/directories per user: " . sprintf("%.2f", $total_num_files / keys(%user_numfiles)) . "\n";
print "Average number of files/directories per group: " . sprintf("%.2f", $total_num_files / keys(%group_numfiles)) . "\n";
print "\nLargest users:\n";
my $user_loop_count;
foreach my $user (sort {$user_datausage{$b} <=> $user_datausage{$a}} keys %user_datausage) {
  print "$user " . sprintf("%.2f", $user_datausage{$user} / 1024 / 1024 / 1024 / 1024) . " TB \n";
  $user_loop_count++;
  last if ($user_loop_count >= 5);
}
print "\nLargest groups:\n";
my $group_loop_count;
foreach my $group (sort {$group_datausage{$b} <=> $group_datausage{$a}} keys %group_datausage) {
  print "$group " . sprintf("%.2f", $group_datausage{$group} / 1024 / 1024 / 1024 / 1024) . " TB \n";
  $group_loop_count++;
  last if ($group_loop_count >= 5);
}
print "#####\n";