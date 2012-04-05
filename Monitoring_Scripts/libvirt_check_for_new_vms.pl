#!/usr/bin/perl
#Description: Perl script to check for new VMs.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
# 0.1 - 2012-4-5 - Initial version. - Jeff White
#####

use warnings; #Print warnings
use strict; #Enforce 'good' programming rules
use Sys::Syslog;
use Getopt::Long;

# Where are our binaries?
my $virsh_binary= "/usr/bin/virsh";

GetOptions('h|help' => \my $helpopt,
	   'k|known-vms=s' => \my $known_vms_file,
          ) || die "Incorrect usage, use -h for help.\n";

if (($helpopt) or (!$known_vms_file)) {
  print "Description: Check KVM for new VMs.\n";
  print "Usage: $0 [OPTION]\n";
  print "-h, --help : Show this help.\n";
  print "-k, --known-vms : Required. File with a list of the known VMs to not alert on.\n";
  exit;
}

# Get the known vms
open my $KNOWN_VMS_FILE, "$known_vms_file" or die "Unable to open ignored lists file: $!";
my @known_vms = <$KNOWN_VMS_FILE>;
close $KNOWN_VMS_FILE;

# Loop through each VM and check if it is a known one
for my $each_virsh_line (`$virsh_binary list --all`){
  chomp $each_virsh_line;

  # If the line does not start with a space then a number...
  if ($each_virsh_line !~ m/ \d/) {
    # The line must not be the info of a VM, skip it
    next;
  }

  my ($junk1,$junk2,$vm_name) = split(/\s+/, $each_virsh_line);

  # If the VM name is not a known one...
  if (!grep /$vm_name/, @known_vms) {
    print "Found new VM: $vm_name\n";
    syslog("LOG_ERR", "$vm_name is new RODS KVM virtual server.  Please create a master ticket for new server. -- $0 -- NOC-NETCOOL-TICKET:");
  } else {
    print "$vm_name is a known VM.\n";
  }
}