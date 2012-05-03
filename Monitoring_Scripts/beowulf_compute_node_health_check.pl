#!/usr/bin/perl
# Description: Perl script to check the health of compute nodes in a Beowulf HPC cluster
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 4 (2012-5-3)
# Last change: Added NetCool ticket tag to syslog message for local scratch space usage

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

GetOptions('h|help' => \my $helpopt,
	   'm|mounts=s' => \@mounts,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Usage: $0 -m /scratch -m /home\n";
  print "-m | --mounts : Mount points to check\n";
  print "-h | --help : Show this help\n";
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

for my $bpstat_line (`$bpstat --long`) {
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
  # Has IB:
  # 1,2,3,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,
  # 53,54,55,56,57,58,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,
  # 93,94,95,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,
  # 120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
  # 144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,
  # 168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
  # 192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,
  # 216,217,218,219,220,221,222,223,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,
  if (($node_number =~ m/^[4-9]$/) or # Which nodes to skip
     ($node_number =~ m/^4[0-9]/) or
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
    $ssh->error and die "Failed to get /scratch info on node $node_number: " . $ssh->error;

    # Get the free space
    my $local_scratch_used_space = (split(/\s+/,$stdout))[11];
    $local_scratch_used_space =~ s/\%//;

    # Check the free space
    if ($local_scratch_used_space < 95) {
      print "Filesystem /scratch usage is OK (${local_scratch_used_space}% used).\n";
    } else {
      warn BOLD RED "PROBLEM: Filesystem /scratch is ${local_scratch_used_space}% full on node $node_number.\n";
      syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Filesystem /scratch is ${local_scratch_used_space}% full on node $node_number. -- $0.");
    }

  }

  print "\n";

}

closelog;
