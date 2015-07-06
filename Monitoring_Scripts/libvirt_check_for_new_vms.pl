#!/usr/bin/env perl
# Description: Check for new VMs
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Switch from a grep() on an array to a hash check

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

use warnings;
use strict;
use Sys::Syslog;
use Getopt::Long;

# Where are our binaries?
my $virsh_binary= "/usr/bin/virsh";
my $known_vms_file = "/usr/local/etc/known_vms.txt";

GetOptions('h|help' => \my $helpopt,
	   'k|known-vms=s' => \$known_vms_file,
          ) || die "Incorrect usage, use -h for help.\n";

if (($helpopt) or (!$known_vms_file)) {
  print "Description: Check KVM for new VMs.\n";
  print "Usage: $0 [OPTION]\n";
  print "-h, --help : Show this help.\n";
  print "-k, --known-vms (Default: /usr/local/etc/known_vms.txt)\n";
  exit;
}

# Get the known VMs
open my $KNOWN_VMS_FILE, "$known_vms_file" or die "Unable to open ignored lists file: $!";
my %known_vms;

for my $known_vm (<$KNOWN_VMS_FILE>) {
  chomp $known_vm;
  $known_vms{$known_vm} = 1;
}

close $KNOWN_VMS_FILE;


# Loop through each VM and check if it is a known one
for my $each_virsh_line (`$virsh_binary list --all`){
  chomp $each_virsh_line;

  # If the line does not start with a space then a number...
  if ($each_virsh_line !~ m/ \d/) {
    # The line must not be the info of a VM, skip it
    next;
  }

  my $vm_name = (split /\s+/, $each_virsh_line)[2];

  # If the VM name is a known one...
  if ($known_vms{$vm_name}) {
    print "$vm_name is a known VM.\n";
  }
  else {
    print "Found new VM: $vm_name\n";
    syslog("LOG_ERR", "NOC-NETCOOL-TICKET: $vm_name is new RODS KVM virtual server.");
  }
}