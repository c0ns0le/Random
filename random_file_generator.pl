#!/usr/bin/env perl
use strict;
use warnings;
# Description: Create variable sized files filled with random data
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.1
# Last change: Removed/fixed a incorrect lines from the help output.

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Getopt::Long;


# Set defaults
my $num_files = 5;
my $lower_size = 1024; # 1 KB
my $upper_size = 1048576; # 1 MB


GetOptions('h|help' => \my $helpopt,
           'f|files=i' => \$num_files,
           'l|lower=i' => \$lower_size,
           'u|upper=i' => \$upper_size,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Create files with random data and variable sizes.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  print "-f | --files : Number of files to create [1]\n";
  print "-l | --lower : Smallest file to create in bytes [1 KB]\n";
  print "-u | --upper : Largest file to create in bytes [1 MB]\n";
  exit;
}


my $URANDOM;
open($URANDOM, "<", "/dev/urandom") or die "Failed to open /dev/urandom: $!";


for (my $i = 1; $i <= $num_files; $i++) {
  print "Creating file $i ...\n";
  
  
  # Open the output file
  my $OUTPUT_FILE;
  open($OUTPUT_FILE, ">", "out.$i") or die "Could not open new file: $!";
  
  
  # Determine how large the file should be
  my $file_bytes = int($lower_size+rand($upper_size - $lower_size));
  
  
  # Get the random data and write it out to the file
  read($URANDOM, my $bytes, $file_bytes);
  
  print $OUTPUT_FILE "$bytes\n";
  
  close $OUTPUT_FILE;
  
}