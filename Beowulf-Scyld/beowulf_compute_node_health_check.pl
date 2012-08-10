#!/usr/bin/perl
# Description: Perl script to check the health of compute nodes in a Beowulf HPC cluster
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 7.1 (2012-8-10)
# Last change: Added nodes to skip the IB check on

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
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

# Where are our binaries?
my $bpstat = "/usr/bin/bpstat";
my $bpsh = "/usr/bin/bpsh";
my $checknode = "/opt/sam/moab/6.1.7/bin/checknode";

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
  print "Check nodes 0 through 9 including their /home mount: $0 -m /home -n 0-9\n";
  print "Check nodes 0 through 9 and 15 including multiple mount points: $0 -m /home -m /scratch_global -n 0-9,15\n";
  print "\nWarning: The -n option doesn't check for correct syntax so use the correct syntax or expect problems.\n";
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
openlog($0, "nonul,pid", "user") or warn "Unable to open syslog connection\n";

for my $bpstat_line (`$bpstat --long $nodes`) {
  chomp $bpstat_line;


  # Skip the header line
  if ($bpstat_line =~ m/^Node/) {
    next
  }


  # Get the node number and status
  my ($node_number,$node_status) = (split(/\s+/,$bpstat_line))[1,3];
  print BOLD GREEN "Working on node: $node_number\n";


  # Check if the node is up
  if ($node_status !~ m/^up$/) {
    print STDERR BOLD RED "Node $node_number is not up.  State: $node_status.\n\n";
    syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Node $node_number is not up.  State: $node_status.\n. -- $0.");
    next;
  }
  print "Node $node_number is up.\n";


  # Check if Moab thinks the nodes are up
  system("$checknode n$node_number >/dev/null"); # /bin/sh is called here to handle the >/dev/null
  
  # Did the call to checknode fail?
  my $status = $? / 256;
  if ($? == -1) {
    warn BOLD RED "Call to Moab's checknode failed on node $node_number.";
  }
  elsif ($status == 0) {
    print "Moab is OK\n";
  }
  elsif ($status == 1) {
    print STDERR BOLD RED "Moab exited with status '$status' on node $node_number.  Down?\n";
    syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Moab exited with status '$status'.  Down?\n. -- $0.");
  }
  else {
    print STDERR BOLD RED "Moab's checknode failed with status $status on node $node_number.";
    syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Moab's checknode failed with status $status on node $node_number.\n. -- $0.");
  }
  
  
  # Check the node's mount points
  for my $each_mount (@mounts) {

    print "Checking mount: $each_mount\n";
    my $test_string = &generate_random_string(5);

    # Create a file in the mount point with a timeout of 10 seconds
    my $test_string_written;
    eval {
      local $SIG{ALRM} = sub {die "Timed out"};
      alarm 10; # Timeout in seconds
      system("$bpsh", "--stdout", "$each_mount/.${test_string}.$node_number", "$node_number", "printf", "$test_string");

      # Did the call to bpsh fail?
      my $status = $? / 256;
      if ($? == -1) {
	warn BOLD RED "Call to bpsh failed on node $node_number.";
      }
      elsif ($status != 0) {
	warn BOLD RED "bpsh failed with status $status on node $node_number.";
      }
      $test_string_written = `$bpsh $node_number cat $each_mount/.$test_string.$node_number`;

      # Did the call to bpsh fail?
      $status = $? / 256;
      if ($? == -1) {
	warn BOLD RED "Call to bpsh failed on node $node_number.";
      }
      elsif ($status != 0) {
	warn BOLD RED "bpsh failed with status $status on node $node_number.";
      }

      alarm 0;
    };

    # Did the system commands time out?
    if ($@ =~ m/^Timed out/) {
      warn BOLD RED "Failed to create test file in mount '$each_mount' on node $node_number: Timed out.\n";
    }

    # Did the test work?
    if ($test_string eq $test_string_written) {
      print "Mount '$each_mount' is OK.\n";
    }
    else {
      warn BOLD RED "Failed to create test file in mount '$each_mount' on node $node_number: Test strings didn't match";
      syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Unable to write to mount '$each_mount' on node $node_number. -- $0.");
      next;
    }
    
    # Remove the file from the mount point with a timeout of 10 seconds
    eval {
      local $SIG{ALRM} = sub {die "Timed out"};
      alarm 10; # Timeout in seconds
      system("rm", "-f", "$each_mount/.$test_string.$node_number");

      # Did the call to bpsh fail?
      my $status = $? / 256;
      if ($? == -1) {
	warn BOLD RED "Call to bpsh failed on node $node_number.";
      }
      elsif ($status != 0) {
	warn BOLD RED "bpsh failed with status $status on node $node_number.";
      }

      alarm 0;
    };

    # Did the system commands time out?
    if ($@ =~ m/^Timed out/) {
      warn BOLD RED "Failed to remove test file in mount '$each_mount' on node $node_number: Timed out.\n";
    }

  }


  # Check the node's Infiniband
  if ( # Which nodes to skip
    ($node_number =~ m/^[4-9]$/) or 
    ($node_number =~ m/^1[0-1]$/) or
    ($node_number =~ m/^4[0-9]$/) or
    ($node_number =~ m/^5[0-2,9]$/) or
    ($node_number =~ m/^6[0-6]$/) or
    ($node_number =~ m/^242$/)
    ) {
    print "Infiniband check disabled, skipping\n";
  }
  else {
    # Get the IB device info
    my $ibv_devinfo_output = `$bpsh $node_number ibv_devinfo`;

    # Did the call to bpsh fail?
    my $status = $? / 256;
    if ($? == -1) {
      warn BOLD RED "Call to bpsh failed.";
    }
    elsif ($status != 0) {
      warn BOLD RED "bpsh failed with status $status on node $node_number.";
    }

    # Check the state
    if (($ibv_devinfo_output) and ($ibv_devinfo_output =~ m/state:\s+PORT_ACTIVE/)) {
      print "IB is OK.\n";
    }
    else {
      warn BOLD RED "Infiniband state is not PORT_ACTIVE on node $node_number.\n";
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
    my $df_output = `$bpsh $node_number df -hP /scratch`;

    # Did the call to bpsh fail?
    my $status = $? / 256;
    if ($? == -1) {
      warn BOLD RED "Call to bpsh failed.";
    }
    elsif ($status != 0) {
      warn BOLD RED "bpsh failed with status $status.";
    }

    # Get the free space
    my $local_scratch_used_space = (split(/\s+/,$df_output))[11];
    $local_scratch_used_space =~ s/\%//;

    # Check the free space
    if ($local_scratch_used_space < 95) {
      print "Filesystem /scratch usage is OK (${local_scratch_used_space}% used).\n";

    } else {
      warn BOLD RED "Filesystem /scratch is ${local_scratch_used_space}% full on node $node_number.\n";
#       syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Filesystem /scratch is ${local_scratch_used_space}% full on node $node_number. -- $0.");

    }

  }

  print "\n";

}

closelog;
