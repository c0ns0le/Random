#!/usr/bin/perl
# Description: Check the health of compute nodes in a Beowulf HPC cluster
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 8.4.1
# Last change: Added tempurature display to almost all of the other nodes

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
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use Storable;
use File::Copy;
use Sys::Syslog qw( :DEFAULT setlogsock);

# Where are our binaries?
my $bpstat = "/usr/bin/bpstat";
my $bpsh = "/usr/bin/bpsh";
my $checknode = "/opt/sam/moab/6.1.7/bin/checknode";

# Defaults for some options
my $nodes = "0-176,243-324";

GetOptions('h|help' => \my $helpopt,
	   'n|nodes:s' => \$nodes,
	   'e|export' => \my $export,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Check the health of compute nodes in a Beowulf HPC cluster\n";
  print "-h | --help : Show this help\n";
  print "-n | --nodes : Which nodes to check.  Default: 0-176,243-324\n";
  print "-e | --export : Export the node health status data to /tmp/node_status.dump\n";
  print "\nExamples:\n";
  print "Check nodes 0 through 9, skip 5: $0 -n 0-4,6-9\n";
  exit;
}


# Prepare for syslog()
setlogsock("unix");
openlog($0, "nonul,pid", "user") or warn "Unable to open syslog connection\n";


# Create a lock file if we need to export the node states
my $LOCK_FILE;
if ($export) {
  if (-f "/tmp/node_check.lock") {
    die "Lock '/tmp/node_check.lock' already exists, can't continue without clobbering the export file";
#     syslog("LOG_WARN", "Lock '/tmp/node_check.lock' already exists, can't continue without clobbering the export file");
  }
  else {
    unless (open($LOCK_FILE, "+>", "/tmp/node_check.lock")) {
#       syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Unable to open/create lock file '/tmp/node_check.lock' -- $0");
      die "Unable to open/create lock file '/tmp/node_check.lock': $!";
    }
  }
}


my %node_states;
# This is what the data structure looks like.  This one named hash has a key for each node number.
# The value is an anonymous hash reference.  That hash reference has keys for "node_status", "moab", "IB", etc.
# The value of those keys are an anonymous hash reference.  That hash has keys of the state and values of the count.
# $node_states{$node_number} = {
#   "node_status" => {"down" => 1}, # The state: up, down, boot, error
#   "moab" => {"down" => 1}, # Moab's status: ok, down, sysfail
#   "ib" => {"ok" => 1}, # Infiniband state: ok, down, sysfail, n/a
#   "/scratch" => {"ok" => 1} # /scratch in use and mount check: above_95%, ok, sysfail, not_mounted
#   "/opt/sam" => {"ok" => 1} # /opt/sam mount check: ok, sysfail, not_mounted
#   "/opt/pkg" => {"ok" => 1} # /opt/pkg mount check: ok, sysfail, not_mounted
#   "/home" => {"ok" => 1} # /home mount check: ok, sysfail, not_mounted
#   "/home1" => {"ok" => 1} # /home1 mount check: ok, sysfail, not_mounted
#   "/gscratch1" => {"ok" => 1} # /gscratch1 mount check: ok, sysfail, not_mounted
#   "Temp" => {"temp" => 85} # CPU0 tempurature in C: temp, sysfail, n/a
# };


# Pull in the last run's hash if it exists
%node_states = %{retrieve("/tmp/node_status.dump")} if (-f "/tmp/node_status.dump");


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
  if ($node_status eq "up") {
    delete ${${$node_states{$node_number}}{'node_status'}}{'down'};
    delete ${${$node_states{$node_number}}{'node_status'}}{'boot'};
    delete ${${$node_states{$node_number}}{'node_status'}}{'error'};
    
    ${${$node_states{$node_number}}{'node_status'}}{'up'}++;
    
    print "Up (${${$node_states{$node_number}}{'node_status'}}{'up'})\n";
  }
  elsif ($node_status eq "down") {
    delete $node_states{$node_number} unless (${${$node_states{$node_number}}{'node_status'}}{'down'});
    
    ${${$node_states{$node_number}}{'node_status'}}{'down'}++;
    
    print STDERR BOLD RED "Node $node_number is not up, state: down (${${$node_states{$node_number}}{'node_status'}}{'down'})\n\n";
    
    if (${${$node_states{$node_number}}{'node_status'}}{'down'} >= 2) {
#       syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Node $node_number is not up, state: down-- $0");
    }
    
    next;
  }
  elsif ($node_status eq "boot") {
    delete $node_states{$node_number} unless (${${$node_states{$node_number}}{'node_status'}}{'boot'});
    
    ${${$node_states{$node_number}}{'node_status'}}{'boot'}++;
    
    print STDERR BOLD RED "Not up, state: boot (${${$node_states{$node_number}}{'node_status'}}{'boot'})\n\n";
    
    if (${${$node_states{$node_number}}{'node_status'}}{'boot'} >= 18) {
#       syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Node $node_number is not up, state: boot -- $0");
    }
    
    next;
  }
  elsif ($node_status eq "error") {
    delete $node_states{$node_number} unless (${${$node_states{$node_number}}{'node_status'}}{'error'});
    
    ${${$node_states{$node_number}}{'node_status'}}{'error'}++;
    
    print STDERR BOLD RED "Not up, state: $node_status (${${$node_states{$node_number}}{'node_status'}}{'error'})\n\n";
    
#     syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Node $node_number is not up, state: error -- $0");
    
    next;
  }



  # Check if Moab thinks the nodes are ok
#   system("$checknode n$node_number >/dev/null"); # /bin/sh is called here to handle the >/dev/null
  system("/bin/true");
  
  # Did the call to checknode fail?
  my $moab_status = $? / 256;
  
  if ($moab_status == -1) {
    delete ${${$node_states{$node_number}}{'moab'}}{'down'};
    delete ${${$node_states{$node_number}}{'moab'}}{'ok'};
    
    ${${$node_states{$node_number}}{'moab'}}{'sysfail'}++;
    
    print STDERR BOLD RED "Call to Moab's checknode failed (${${$node_states{$node_number}}{'moab'}}{'sysfail'})\n";

    if (${${$node_states{$node_number}}{'moab'}}{'sysfail'} >= 3) {
#       syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Call to Moab's checknode failed on node $node_number -- $0");
    }
    
  }
  elsif ($moab_status == 0) {
    delete ${${$node_states{$node_number}}{'moab'}}{'sysfail'};
    delete ${${$node_states{$node_number}}{'moab'}}{'down'};
    
    ${${$node_states{$node_number}}{'moab'}}{'ok'}++;
    
    print "Moab is ok (${${$node_states{$node_number}}{'moab'}}{'ok'})\n";
  }
  else {
    delete ${${$node_states{$node_number}}{'moab'}}{'ok'};
    delete ${${$node_states{$node_number}}{'moab'}}{'sysfail'};
    
    ${${$node_states{$node_number}}{'moab'}}{'down'}++;
    
    print STDERR BOLD RED "Moab is down (${${$node_states{$node_number}}{'moab'}}{'down'})\n";

    if (${${$node_states{$node_number}}{'moab'}}{'down'} >= 6) {
#       syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Moab (resource scheduler) is down on node $node_number -- $0");
    }
    
  }
  
  
  # Check the node's Infiniband
  # Which nodes to skip
  if (
    ($node_number =~ m/^[4-9]$/) or 
    ($node_number =~ m/^1[0-1]$/) or
    ($node_number =~ m/^4[0-9]$/) or
    ($node_number =~ m/^5[0-2,9]$/) or
    ($node_number =~ m/^6[0-6]$/) or
    ($node_number =~ m/^242$/) or
    ($node_number =~ m/^28[3-4]$/) or
    ($node_number =~ m/^31[7-9]$/) or
    ($node_number =~ m/^32[0-4]$/)
  ) {
    delete ${${$node_states{$node_number}}{'ib'}}{'down'};
    delete ${${$node_states{$node_number}}{'ib'}}{'ok'};
    delete ${${$node_states{$node_number}}{'ib'}}{'sysfail'};
    
    ${${$node_states{$node_number}}{'ib'}}{'n/a'}++;
    
    print "IB is N/A (${${$node_states{$node_number}}{'ib'}}{'n/a'})\n";
  }
  else {
    # Get the IB device info
    my $ibv_devinfo_output = `$bpsh $node_number ibv_devinfo`;
    my $ib_status = $? / 256;
    
    # Did the call to bpsh fail?
    if (($ib_status == -1) or (!$ibv_devinfo_output)) {
      delete ${${$node_states{$node_number}}{'ib'}}{'down'};
      delete ${${$node_states{$node_number}}{'ib'}}{'ok'};
      delete ${${$node_states{$node_number}}{'ib'}}{'n/a'};
      
      ${${$node_states{$node_number}}{'ib'}}{'sysfail'}++;
      
      print STDERR BOLD RED "Call to check IB failed (${${$node_states{$node_number}}{'ib'}}{'sysfail'})\n";
    
      if (${${$node_states{$node_number}}{'ib'}}{'sysfail'} >= 3) {
#         syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Call to check IB failed on node $node_number -- $0");
      }
    
    }
    elsif (($ib_status == 0) and ($ibv_devinfo_output) and ($ibv_devinfo_output =~ m/state:\s+PORT_ACTIVE/)) {
      delete ${${$node_states{$node_number}}{'ib'}}{'sysfail'};
      delete ${${$node_states{$node_number}}{'ib'}}{'down'};
      delete ${${$node_states{$node_number}}{'ib'}}{'n/a'};
      
      ${${$node_states{$node_number}}{'ib'}}{'ok'}++;
      
      print "IB is ok\n";
    }
    else {
      delete ${${$node_states{$node_number}}{'ib'}}{'ok'};
      delete ${${$node_states{$node_number}}{'ib'}}{'sysfail'};
      delete ${${$node_states{$node_number}}{'ib'}}{'n/a'};
      
      ${${$node_states{$node_number}}{'ib'}}{'down'}++;
      
      print STDERR BOLD RED "IB is down (${${$node_states{$node_number}}{'ib'}}{'down'})\n";
      
      if (${${$node_states{$node_number}}{'ib'}}{'down'} >= 6) {
#         syslog("LOG_ERR", "NOC-NETCOOL-TICKET: IB is down on node $node_number -- $0");
      }
      
    }

  }

  
  
  # Check that things are mounted
  my @proc_mounts = `$bpsh $node_number cat /proc/mounts`;
  my $bpsh_status = $? / 256;
  
  for my $mount_point (qw(/scratch /home /home1 /data/sam /data/pkg /gscratch1 /pan)) {
  
    if ($bpsh_status == -1) {
      delete ${${$node_states{$node_number}}{$mount_point}}{'above_95%'};
      delete ${${$node_states{$node_number}}{$mount_point}}{'ok'};
      delete ${${$node_states{$node_number}}{$mount_point}}{'not_mounted'};
      
      ${${$node_states{$node_number}}{$mount_point}}{'sysfail'}++;
      
      print STDERR BOLD RED "Call to check $mount_point failed (${${$node_states{$node_number}}{$mount_point}}{'sysfail'})\n";

      if (${${$node_states{$node_number}}{$mount_point}}{'sysfail'} >= 3) {
#         syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Call to check $mount_point failed on node $node_number -- $0");
      }
    
    }
    elsif (grep(m|\Q $mount_point \E|, @proc_mounts)) {
      delete ${${$node_states{$node_number}}{$mount_point}}{'not_mounted'};
      delete ${${$node_states{$node_number}}{$mount_point}}{'sysfail'};
      delete ${${$node_states{$node_number}}{$mount_point}}{'above_95%'};
      
      ${${$node_states{$node_number}}{$mount_point}}{'ok'}++;
      
      print "$mount_point is ok (${${$node_states{$node_number}}{$mount_point}}{'ok'})\n";
    
    }
    else {
      delete ${${$node_states{$node_number}}{$mount_point}}{'ok'};
      delete ${${$node_states{$node_number}}{$mount_point}}{'sysfail'};
      delete ${${$node_states{$node_number}}{$mount_point}}{'above_95%'};
      
      ${${$node_states{$node_number}}{$mount_point}}{'not_mounted'}++;
      
      print STDERR BOLD RED "$mount_point not mounted (${${$node_states{$node_number}}{$mount_point}}{'not_mounted'})\n";

      if (${${$node_states{$node_number}}{$mount_point}}{'not_mounted'} >= 2) {
#         syslog("LOG_ERR", "NOC-NETCOOL-TICKET: $mount_point not mounted on node $node_number -- $0");
      }
      
    }
  
  }
  
  

  # Check the node's /scratch fullness
  next if (${${$node_states{$node_number}}{'/scratch'}}{'not_mounted'});
  
  # Get the scratch space info
  my $df_output = `$bpsh $node_number df -hP /scratch`;
  my $scratch_status = $? / 256;

  # Get the free space
  my $local_scratch_used_space = (split(/\s+/,$df_output))[11];
  $local_scratch_used_space =~ s/\%//;

  if (($scratch_status == -1) or (!$local_scratch_used_space)) {
    delete ${${$node_states{$node_number}}{'/scratch'}}{'above_95%'};
    delete ${${$node_states{$node_number}}{'/scratch'}}{'ok'};
    delete ${${$node_states{$node_number}}{'/scratch'}}{'not_mounted'};
    
    ${${$node_states{$node_number}}{'/scratch'}}{'sysfail'}++;
    
    print STDERR BOLD RED "Call to check /scratch space failed (${${$node_states{$node_number}}{'/scratch'}}{'sysfail'})\n";

    if (${${$node_states{$node_number}}{'/scratch'}}{'sysfail'} >= 3) {
#       syslog("LOG_ERR", "NOC-NETCOOL-TICKET: Call to check /scratch space failed on node $node_number -- $0");
    }
    
  }
  elsif (($scratch_status == 0) and ($local_scratch_used_space < 95)) {
    delete ${${$node_states{$node_number}}{'/scratch'}}{'sysfail'};
    delete ${${$node_states{$node_number}}{'/scratch'}}{'above_95%'};
    delete ${${$node_states{$node_number}}{'/scratch'}}{'not_mounted'};
    
    # We don't set the status to ok again as it was set to ok in the mount check
#     ${${$node_states{$node_number}}{'/scratch'}}{'ok'}++;
    
    print "/scratch space is ok (${${$node_states{$node_number}}{'/scratch'}}{'ok'})\n";
  }
  else {
    delete ${${$node_states{$node_number}}{'/scratch'}}{'ok'};
    delete ${${$node_states{$node_number}}{'/scratch'}}{'sysfail'};
    delete ${${$node_states{$node_number}}{'/scratch'}}{'not_mounted'};
    
    ${${$node_states{$node_number}}{'/scratch'}}{'above_95%'}++;
    
    print STDERR BOLD RED "/scratch space above 95% (${${$node_states{$node_number}}{'/scratch'}}{'above_95%'})\n";

    if (${${$node_states{$node_number}}{'/scratch'}}{'above_95%'} >= 12) {
#       syslog("LOG_ERR", "NOC-NETCOOL-TICKET: /scratch space above 95% on node $node_number -- $0");
    }  
    
  }
  
  
  # Check the node's CPU tempurature
  if (
    ($node_number !~ m/^242$/)
    ) {
    delete ${${$node_states{$node_number}}{'Temp'}}{'sysfail'};
    delete ${${$node_states{$node_number}}{'Temp'}}{'temp'};
    
    # Time out after 5 seconds
    my @ipmi_cpu0_sensor;
    eval {

      local $SIG{ALRM} = sub {
        print STDERR BOLD RED "CPU0 tempurature check timed out\n";
        die;
      };

      my $sensor_name;
      if (
        ($node_number =~ m/^[0-9]$/) or
        ($node_number =~ m/^[1-9]\d$/) or
        ($node_number =~ m/^1[0-6]\d$/) or
        ($node_number =~ m/^17[0-6]$/)
        ) {
        $sensor_name = "System Temp";
      }
      elsif (
        ($node_number =~ m/^17[7-9]$/) or
        ($node_number =~ m/^1[8-9]\d$/) or
        ($node_number =~ m/^2[0-3]\d$/) or
        ($node_number =~ m/^24[0-2]$/)
        ) {
        $sensor_name = "Ambient Temp";
      }
      elsif ($node_number =~ m/^28[3-4]$/) {
        $sensor_name = "CPU0 Temp";
      }
      elsif (
        ($node_number =~ m/^24[3-9]$/) or
        ($node_number =~ m/^2[5-9]\d$/) or
        ($node_number =~ m/^3[0-1]\d$/) or
        ($node_number =~ m/^32[0-4]$/)
        ) {
        $sensor_name = "CPU0_Temp";
      }
      
      alarm(5); # Arm the time bomb
      @ipmi_cpu0_sensor = `bpsh $node_number ipmitool sensor get '$sensor_name' 2>/dev/null`;
      alarm(0); # Cut the blue wire

    };

    # Did the call to bpsh fail?
    if (!@ipmi_cpu0_sensor) {
      delete ${${$node_states{$node_number}}{'Temp'}}{'temp'};

      ${${$node_states{$node_number}}{'Temp'}}{'sysfail'}++;

      print STDERR BOLD RED "Call to check CPU tempurature failed (${${$node_states{$node_number}}{'Temp'}}{'sysfail'})\n";

    }
    else {
      # Get the temp of CPU0 from the output
      my $temp_0 = (grep(m/^\s+Sensor Reading/, @ipmi_cpu0_sensor))[0];
      chomp $temp_0;
      $temp_0 = (split(m/\s+/, $temp_0))[4];

      ${${$node_states{$node_number}}{'Temp'}}{'temp'} = $temp_0;

      print "Tempurature: ${${$node_states{$node_number}}{'Temp'}}{'temp'}\n";
    }
  }
#   elsif ($node_number =~ m/^28[3-4]$/) {
    
#   }
  else {
    ${${$node_states{$node_number}}{'Temp'}}{'n/a'}++;
  }
  
  # FIXME: For failures we didn't catch
  if (
    (!${${$node_states{$node_number}}{'Temp'}}{'sysfail'}) and
    (!${${$node_states{$node_number}}{'Temp'}}{'temp'}) and
    (!${${$node_states{$node_number}}{'Temp'}}{'n/a'})
    ) {
    ${${$node_states{$node_number}}{'Temp'}}{'sysfail'}++;
  }
  
  
  print "\n";

}


# Dump the status
if ($export) {
  unless (store(\%node_states, "/tmp/node_status.dump-temp")) {
    warn "Failed to export node states";
  }
  
  unless (move("/tmp/node_status.dump-temp", "/tmp/node_status.dump")) {
    warn "Failed to rename exported node states";
  }
  
  unless (unlink("/tmp/node_check.lock")) {
    warn "Failed to remove lock file '/tmp/node_check.lock'";
  }
}

# Done with syslog
closelog;