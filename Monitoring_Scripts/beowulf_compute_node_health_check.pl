#!/usr/bin/perl
# Description: Perl script to check the health of compute nodes in a Beowulf HPC cluster
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 5 (2012-5-3)
# Last change: Added -n option to check only the nodes we were told to check rather than checking all of them,
# fixed a regex in the Infiniband section.

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

use strict;
use warnings;
use Sys::Syslog qw( :DEFAULT setlogsock);
use Getopt::Long;
use Net::OpenSSH;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

# Where are our binaries?
my $bpstat = "/usr/bin/bpstat";

# Defaults for some options
my @mounts;
my $nodes = "0-241";

GetOptions('h|help' => \my $helpopt,
	   'm|mounts=s' => \@mounts,
	   'n|nodes:s' => \$nodes,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "-h | --help : Show this help\n";
  print "-m | --mounts : Mount points to check.  Default: None\n";
  print "-n | --nodes : Which nodes to check.  Default: 0-241\n";
  print "\nExamples:\n";
  print "Check nodes 0 through 9 including their /home mount: $0 -m /home -n 0..9\n";
  print "Check nodes 0 through 9 and 15 including multiple mount points: $0 -m /home -m /scratch_global -n 0-9,15\n";
  print "\nWarning: The -n option doesn't check for correct syntax so use the corect syntax or expect problems.\n";
  exit;
}

# Create a random string
# Written by Guy Malachi http://guymal.com
# 18 August, 2002
sub generate_random_string {
  my $length_of_randomstring=shift;
  my @chars=('a'..'z','A'..'Z','0'..'9');
  my $random_string;
  foreach (1..$length_of_randomstring) {
    # rand @chars will generate a random 
    # number between 0 and scalar @chars
    $random_string.=$chars[rand @chars];
  }
  return $random_string;
}

# Prepare for syslog()
setlogsock("unix");
openlog($0, "nonul,pid", "user") or die "Unable to open syslog connection\n";

for my $bpstat_line (`$bpstat --long $nodes`) {
  chomp $bpstat_line;


  # Skip the header line
  if ($bpstat_line =~ m/^Node/) {
    next
  }


  # Get the node number and status
  my ($node_number,$node_status) = (split(/\s+/,$bpstat_line))[1,3];
  print "Working on node: $node_number\n";


  # Check if the node is up
  if ($node_status !~ m/^up$/) {
    print STDERR BOLD RED "Node $node_number is not up.  State: $node_status.\n\n";
    syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Node $node_number is not up.  State: $node_status.\n. -- $0.");
    next
  }
  print "Node $node_number is up.\n";


  # Make an SSH connection to the node
  my $ssh = Net::OpenSSH->new(
    "n$node_number",
    key_path => "/root/.ssh/id_dsa",
    timeout => 30,
    kill_ssh_on_timeout => 1,
    default_ssh_opts => [-o => "ConnectionAttempts=2", -o => "StrictHostKeyChecking no"]
  );
  if ($ssh->error) {
#     syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Failed to establish SSH connection to node $node_number.\n. -- $0.")
    warn BOLD RED "ERROR: Failed to establish SSH connection to node $node_number: " . $ssh->error;
    next;
  }


  # Check the node's mount points
  for my $each_mount (@mounts) {

    print "Checking mount: $each_mount\n";
    my $test_string = &generate_random_string(5);

    # Create a file in the mount point
    if ($ssh->system("echo \"$test_string\" > $each_mount/.$test_string.$node_number")) {
      print "Mount '$each_mount' is OK.\n";
    }
    else {
      warn BOLD RED "PROBLEM: Failed to create test file in mount '$each_mount' on node $node_number: " . $ssh->error;
      syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Unable to write to mount '$each_mount' on node $node_number. -- $0.");
      next;
    }
    
    # Remove the file from the mount point
    if ($ssh->system("rm -f $each_mount/.$test_string.$node_number")) {
      print "Successfully removed test file.\n";
    }
    else {
      warn BOLD RED "ERROR: Failed to remove test file in mount '$each_mount' on $node_number: " . $ssh->error;
      next;
    }

  }


  # Check the node's Infiniband
  if (($node_number =~ m/^[4-9]$/) or # Which nodes to skip
     ($node_number =~ m/^4[0-9]$/) or
     ($node_number =~ m/^5[0-2,9]$/) or
     ($node_number =~ m/^6[0-6]$/)) {
    print "Infiniband check disabled, skipping\n";
  }
  else {
    # Get the IB device info
    my ($stdout, $stderr) = $ssh->capture2("ibv_devinfo");

    # Check the state
    if (($stdout) and ($stdout =~ m/state:\s+PORT_ACTIVE/)) {
      print "IB is OK.\n";
    }
    else {
      warn BOLD RED "PROBLEM: Infiniband state is not PORT_ACTIVE on node $node_number.\n";
      syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Infiniband state is not PORT_ACTIVE on node $node_number.");
    }

    # We should do more testing such as seeing if the node can ping over IB

  }


  # Check the node's /scratch fullness
  if ($node_number =~ m/^$/) { # Which nodes to skip
    print "Scratch partition fullness check disabled, skipping\n";
  }
  else {

    # Get the scratch space info
    my ($stdout, $stderr) = $ssh->capture2("df -hP /scratch");
    $ssh->error and warn "Failed to get /scratch info on node $node_number: " . $ssh->error;

    # Get the free space
    my $local_scratch_used_space = (split(/\s+/,$stdout))[11];
    $local_scratch_used_space =~ s/\%//;

    # Check the free space
    if ($local_scratch_used_space < 95) {
      print "Filesystem /scratch usage is OK (${local_scratch_used_space}% used).\n";

#       # Write out the usage so we can track it (needed so we can alert only if usage has been high for multiple checks by this 
#       # script rather than alerting every time we this script runs)
#       $ssh->system("echo \"$local_scratch_used_space:0\" > /var/tmp/.scratch_usage")
#       $ssh->error and warn BOLD RED "Failed to update scratch free space file on node $node_number: " . $ssh->error;

    } else {
      warn BOLD RED "PROBLEM: Filesystem /scratch is ${local_scratch_used_space}% full on node $node_number.\n";
      syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Filesystem /scratch is ${local_scratch_used_space}% full on node $node_number. -- $0.");

      # Write out the usage so we can track it

    }

  }

  print "\n";

}

closelog;
