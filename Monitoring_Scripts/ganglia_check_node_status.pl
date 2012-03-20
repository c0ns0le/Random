#!/usr/bin/perl
#Description: Perl script to check the status of compute nodes with Ganglia
#Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
# 0.1 - 2012-3-20 - Initial version. - Jeff White
#####

use strict;
use warnings;
use Getopt::Long;
use Sys::Syslog;

my $gstat = "/opt/ganglia/bin/gstat";

GetOptions('h|help' => \my $helpopt,
          ) or die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Usage: $0\n";
  print "This script will run '$gstat' and parse the output to determine if any computes node are down.\n";
  print "-h | --help : Show this help\n";
  exit;
}

my @gstat_output = `$gstat -da` or die "Unable to run gstat: $!";

foreach (@gstat_output) {
  chomp;
  if ((m/Dead Hosts: (\d{1,})$/) and ($1 > 0)) {
    print "$1 nodes are down!\n";
    syslog("LOG_ERR", "NOC-NETCOOL-TICKET: $1 nodes are down -- $0.");
    exit 1;
  }
}

print "All nodes are up.\n";