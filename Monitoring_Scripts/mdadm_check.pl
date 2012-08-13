#!/usr/bin/perl
use strict;
use warnings;
# Description: Checks the status of mdadm disk arrays
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 2.1
# Last change: Fixed a bug with commas in the array status

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Getopt::Long;
use Sys::Syslog qw( :DEFAULT setlogsock);
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

GetOptions('h|help' => \my $helpopt,
	  ) || die "Incorrect usage, use -h for help.\n";

if (($helpopt) or (!$ARGV[0])) {
  print "Checks the status of mdadm disk arrays.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "-h | --help : Show this help\n\n";
  print "Usage:\n";
  print "$0 /dev/md0 /dev/md1 /dev/md2 ...\n";
  exit;
}

# Prepare for syslog()
setlogsock("unix");
openlog($0, "nonul,pid", "user") or warn BOLD RED "Unable to open syslog connection\n";

my $mdadm_binary = "/sbin/mdadm";

foreach my $each_array (@ARGV) {
  print "Checking: $each_array\n";
  
  if (!-b $each_array) {
    warn BOLD RED "Device '$each_array' not found or not a block device.";
    exit 1;
  }

  my @mdadm_detail = `$mdadm_binary --detail $each_array`;

  # Get the array state
  my $array_state_line = (grep(/\s+State/, @mdadm_detail))[0];
  my $array_state = (split(/\s+/, $array_state_line))[3];
  $array_state =~ s/,//;
  chomp $array_state;

  # Check the array state
  if ($array_state !~ m/^(clean|active)$/) {
    print BOLD RED "Array '$each_array' is not clean/active.  State: ${array_state}x\n";
    syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Array '$each_array' is not clean/active.  State: $array_state. -- $0.");
  }

  # Check that the expected number of RAID devices are active, working, and none are failed
  # FIXME

  else {
    print BOLD GREEN "Array clean/active: $each_array\n";
  }
}

closelog;