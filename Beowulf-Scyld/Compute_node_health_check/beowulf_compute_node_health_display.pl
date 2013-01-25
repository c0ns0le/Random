#!/usr/bin/perl
# Description: Display the status of compute nodes via either plain text or HTML
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.6.5
# Last change: Adjusted for new nodes

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
use Storable;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

GetOptions('h|help' => \my $helpopt,
	   't|text' => \my $text_mode,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Display the status of compute nodes via either plain text or HTML\n";
  print "-h | --help : Show this help\n";
  print "-t | --text : output plain text instead of HTML\n";
  exit;
}


# Pull in the node state file
unless (-f "/tmp/node_status.dump") {
  print STDERR "Failed to find node state file '/tmp/node_status.dump'\n";
  die;
}

my %node_states = %{retrieve("/tmp/node_status.dump")};
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
#   "/home2" => {"ok" => 1} # /home2 mount check: ok, sysfail, not_mounted
#   "/gscratch1" => {"ok" => 1} # /gscratch1 mount check: ok, sysfail, not_mounted
#   "Temp" => {"temp" => 85} # CPU0 tempurature in C: temp, sysfail, n/a
# };


# Get the modification time of the status file
my $epoch_timestamp = (stat("/tmp/node_status.dump"))[9];
my $mod_timestamp  = localtime($epoch_timestamp);


# Print an HTML header
print <<EOI unless ($text_mode);
Content-type: text/html\n\n
<html>
<head>
<title>Frank Compute Node Status</title>
<link href="http://headnode1.frank.sam.pitt.edu/nodes-css/style-dev.css" rel="stylesheet" type="text/css">
</head>
<body>
  <center>
    <h2>Frank Compute Node Status: 0-176,242-378</h2>
    <h3>Nodes 177-241 are available <a href="http://headnode0.frank.sam.pitt.edu/nodes">here</a></h3>
    <p>Status last generated $mod_timestamp</p>
  </center>
<table id="nodes" summary="Node status" class="fancy">
  <thead>
    <tr>
      <th scope="col">Node</th>
      <th scope="col">State</th>
      <th scope="col">Moab</th>
      <th scope="col">Infiniband</th>
      <th scope="col">Tempurature</th>
      <th scope="col">/scratch</th>
      <th scope="col">/pan</th>
      <th scope="col">/home2</th>
      <th scope="col">/home1</th>
      <th scope="col">/home</th>
      <th scope="col">/gscratch</th>
      <th scope="col">/data/sam</th>
      <th scope="col">/data/pkg</th>
    </tr>
  </thead>
  <tbody>
EOI


# Loop through the node number hash
if ($text_mode) {
  print "Status last generated $mod_timestamp\n";

  for my $node_number (sort { $a <=> $b } (keys(%node_states))) {
    print "Node: $node_number\n";
    
    # Loop through each monitor
    for my $monitor (reverse(sort(keys(%{${node_states{$node_number}}})))) {
      print "  $monitor: ";
      
      # Find the current status
      for my $status (qw(temp up ok down boot error sysfail n/a above_95% not_mounted)) {

        # Print success in black ...
        if ((${${$node_states{$node_number}}{$monitor}}{$status}) and (($status eq "ok") or ($status eq "up") or ($status eq "n/a") or ($status eq "temp"))) {
          if ($status eq "temp") {
          
            if (
              ($node_number =~ m/^[0-9]$/) or
              ($node_number =~ m/^[1-9]\d$/) or
              ($node_number =~ m/^1[0-6]\d$/) or
              ($node_number =~ m/^17[0-6]$/)
              ) {
              print "${${$node_states{$node_number}}{'Temp'}}{'temp'} (System\n";
            }
            elsif (
              ($node_number =~ m/^17[7-9]$/) or
              ($node_number =~ m/^1[8-9]\d$/) or
              ($node_number =~ m/^2[0-3]\d$/) or
              ($node_number =~ m/^24[0-2]$/)
              ) {
              print "${${$node_states{$node_number}}{'Temp'}}{'temp'} (Ambient)\n";
            }
            elsif (
              ($node_number =~ m/^28[3-4]$/) or
              ($node_number =~ m/^24[3-9]$/) or
              ($node_number =~ m/^2[5-9]\d$/) or
              ($node_number =~ m/^3[0-1]\d$/) or
              ($node_number =~ m/^32[0-4]$/)
              ) {
              print "${${$node_states{$node_number}}{'Temp'}}{'temp'} (CPU0)\n";
            }
            else {
              print "n/a\n";
            }
            
          }
          else {
            print "$status\n";
          }
        }
        # ... pending failures in magenta ...
        elsif
          ( # The most complicated condition created by mankind
            (${${$node_states{$node_number}}{$monitor}}{$status}) and (
              (($monitor eq 'node_status') and ($status eq 'down') and (${${$node_states{$node_number}}{$monitor}}{$status} < 2)) or
              (($monitor eq 'node_status') and ($status eq 'boot') and (${${$node_states{$node_number}}{$monitor}}{$status} < 18)) or
              (($status eq 'sysfail') and (${${$node_states{$node_number}}{$monitor}}{$status} < 3)) or
              (($monitor eq 'moab') and ($status eq 'down') and (${${$node_states{$node_number}}{$monitor}}{$status} < 6)) or
              (($monitor eq 'ib') and ($status eq 'down') and (${${$node_states{$node_number}}{$monitor}}{$status} < 6)) or
              (($status eq 'not_mounted') and (${${$node_states{$node_number}}{$monitor}}{$status} < 2)) or
              (($monitor eq '/scratch') and ($status eq 'above_95%') and (${${$node_states{$node_number}}{$monitor}}{$status} < 12))
            )
          ) {
          print MAGENTA "$status (For about ", sprintf("%.2f", ${${$node_states{$node_number}}{$monitor}}{$status} * 10 / 60), " hours)\n";
        }
        # ... and failures in red
        elsif (${${$node_states{$node_number}}{$monitor}}{$status}) {
          print RED "$status (For about ", sprintf("%.2f", ${${$node_states{$node_number}}{$monitor}}{$status} * 10 / 60), " hours)\n";
        }
        
      }
      
    }
    
    print "\n";
  }
}
else {
  for my $node_number (sort { $a <=> $b } (keys(%node_states))) {
    
    print "<tr>\n";
    
    print "<td>$node_number</td>\n";
    
    # Loop through each monitor
    for my $monitor (reverse(sort(keys(%{${node_states{$node_number}}})))) {

      # Find the current status
      for my $status (qw(temp up ok down boot error sysfail n/a above_95% not_mounted)) {
      
        # Print success in black ...
        if ((${${$node_states{$node_number}}{$monitor}}{$status}) and (($status eq "ok") or ($status eq "up") or ($status eq "n/a") or ($status eq "temp"))) {
          
          if ($status eq "temp") {
            
            if (
              ($node_number =~ m/^[0-9]$/) or
              ($node_number =~ m/^[1-9]\d$/) or
              ($node_number =~ m/^1[0-6]\d$/) or
              ($node_number =~ m/^17[0-6]$/)
              ) {
              print "<td>${${$node_states{$node_number}}{'Temp'}}{'temp'} (System)</td>\n";
            }
            elsif (
              ($node_number =~ m/^17[7-9]$/) or
              ($node_number =~ m/^1[8-9]\d$/) or
              ($node_number =~ m/^2[0-3]\d$/) or
              ($node_number =~ m/^24[0-2]$/)
              ) {
              print "<td>${${$node_states{$node_number}}{'Temp'}}{'temp'} (Ambient)</td>\n";
            }
            elsif (
              ($node_number =~ m/^28[3-4]$/) or
              ($node_number =~ m/^24[3-9]$/) or
              ($node_number =~ m/^2[5-9]\d$/) or
              ($node_number =~ m/^3[0-1]\d$/) or
              ($node_number =~ m/^32[0-4]$/)
              ) {
              print "<td>${${$node_states{$node_number}}{'Temp'}}{'temp'} (CPU0)</td>\n";
            }
            else {
              print "<td>n/a</td>\n";
            }
            
          }
          else {
            print "<td>$status</td>\n";
          }
          
	}
	# ... pending failures in magenta ...
	elsif
          ( # The most complicated condition created by mankind
            (${${$node_states{$node_number}}{$monitor}}{$status}) and (
              (($monitor eq 'node_status') and ($status eq 'down') and (${${$node_states{$node_number}}{$monitor}}{$status} < 2)) or
              (($monitor eq 'node_status') and ($status eq 'boot') and (${${$node_states{$node_number}}{$monitor}}{$status} < 18)) or
              (($status eq 'sysfail') and (${${$node_states{$node_number}}{$monitor}}{$status} < 3)) or
              (($monitor eq 'moab') and ($status eq 'down') and (${${$node_states{$node_number}}{$monitor}}{$status} < 6)) or
              (($monitor eq 'ib') and ($status eq 'down') and (${${$node_states{$node_number}}{$monitor}}{$status} < 6)) or
              (($status eq 'not_mounted') and (${${$node_states{$node_number}}{$monitor}}{$status} < 2)) or
              (($monitor eq '/scratch') and ($status eq 'above_95%') and (${${$node_states{$node_number}}{$monitor}}{$status} < 12))
            )
          ) {
          print "<td> <span style='color:magenta' class='dropt'>$status<span>For about ",sprintf("%.2f", ${${$node_states{$node_number}}{$monitor}}{$status} * 10 / 60), " hours</span></span> </td>\n";
	}
	# ... and failures in red
	elsif (${${$node_states{$node_number}}{$monitor}}{$status}) {
          print "<td> <span style='color:red' class='dropt'>$status<span>For about ", sprintf("%.2f", ${${$node_states{$node_number}}{$monitor}}{$status} * 10 / 60), " hours</span></span> </td>\n";
	}

      }
      
    }
    
    # If node_status is not up then just print blank table cells for everything else
    unless (${${$node_states{$node_number}}{'node_status'}}{'up'}) {
      print "<td></td>\n" x 11;
      next;
    }
    
    print "</tr>\n";
    
  }
}




# Print an HTML footer
print <<EOI unless ($text_mode);
  </tbody>
</table>
<p>
  Key:<br>
  OK (black)<br>
  Pending Failure (<span style='color:magenta'>magenta</span>)<br>
  Failed (<span style='color:red'>red</span>)
</p>
</body>
</html>
EOI
