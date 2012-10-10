#!/usr/bin/perl
# Description: Display the size and name of files and directories in the current working directory
# Written By: Jeff White (jwhite530@gmail.com)
# Version: 1
# Last change: Initial version

##### License
# This software is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

use strict;
use warnings;
use Getopt::Long;

GetOptions('h|help' => \my $helpopt,
           'b|bytes' => \my $bytes,
           's|size' => \my $sort_size,
           'r|reverse' => \my $reverse,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Display the size and name of files and directories in the current working directory\n";
  print "-h | --help : Show this help\n";
  print "-b | --bytes : Display size in bytes instead of human-readable\n";
  print "-s | --size : Sort output by size\n";
  print "-r | --reverse : Reverse the sort\n";
  exit;
}


# Take size in bytes and give back a human-readable size and unit
sub human_readable_size {
  # Returns a list of the size and unit
  # Usage: my ($human_size, $unit) = human_readable_size(3654856460)
  my $size = shift;
  
  # Calculate the size
  if (($bytes) or ($size < 1024)) {
    return ($size, "B");
  }
  elsif ($size < 1048576) {
    return ($size / 1024, "KB");
  }
  elsif ($size < 1073741824) {
    return ($size / 1024 / 1024, "MB");
  }
  elsif ($size < 1099511627776) {
    return ($size / 1024 / 1024 / 1024, "GB");
  }
  else {
    return ($size / 1024 /1024 / 1024 / 1024, "TB");
  }
}


my %fs_objects_size if ($sort_size);


# Loop through every filesystem object in the CWD and add it to the hash
for my $fs_object (glob("*")) {

  # Is it a regular file or a directory?
  if (-f $fs_object) {
    $fs_objects_size{$fs_object} = (stat($fs_object))[7];
  }
  elsif (-d $fs_object) {
    my $size = `du -bs "$fs_object"`;
    $fs_objects_size{$fs_object} = (split(m/\s+/, $size))[0];
  }
  else {
    next;
  }

}


# Print the final output
if ($sort_size) {

  my @sorted_fs_objects;
  if ($reverse) {
    @sorted_fs_objects = reverse (sort { $fs_objects_size{$a} <=> $fs_objects_size{$b} } keys %fs_objects_size);
  }
  else {
    @sorted_fs_objects = sort { $fs_objects_size{$a} <=> $fs_objects_size{$b} } keys %fs_objects_size;
  }

  for my $fs_object (@sorted_fs_objects) {;
    my ($size, $unit) = human_readable_size($fs_objects_size{$fs_object});
    
    if ($unit eq "B") {
      print "$size $unit - $fs_object\n";
    }
    else {
      print sprintf("%.2f", $size), " $unit - $fs_object\n";
    }
    
  }
  
}
else {
  
  my @sorted_fs_objects;
  if ($reverse) {
    @sorted_fs_objects = reverse (sort (keys (%fs_objects_size)));
  }
  else {
    @sorted_fs_objects = sort (keys (%fs_objects_size));
  }

  for my $fs_object (@sorted_fs_objects) {
    my ($size, $unit) = human_readable_size($fs_objects_size{$fs_object});
    
    if ($unit eq "B") {
      print "$size $unit - $fs_object\n";
    }
    else {
      print sprintf("%.2f", $size), " $unit - $fs_object\n";
    }
    
  }
  
}