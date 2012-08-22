#!/usr/bin/perl
use warnings;
use strict;
# Description: Create a simple report of IPs and their DNS entries
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.1
# Last change: Fixed a bug that caused an exit when a forward lookup failed

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Getopt::Long;
use Socket;

GetOptions('h|help' => \my $helpopt,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Create a simple report of IPs and their DNS entries (from STDIN or file args)\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 < /path/to/list\n"; 
  print "-h | --help : Show this help\n";
  exit;
}

#Print a header
print "IP,Hostname\n";

while (defined(my $line = <>)) {
  chomp $line;
  my ($hostname, $ipaddr);
  
  # If it looks like an IP...
  if ($line =~ m/^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5]).([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$/) {
    $ipaddr = $line;
    my $ipaddr_binary = inet_aton("$ipaddr");
    $hostname = gethostbyaddr($ipaddr_binary, AF_INET);
  }
  # ...otherwise it must be hostname
  else {
    $hostname = $line;
    my $ipaddr_binary = gethostbyname($hostname);
    if ($ipaddr_binary) {
      $ipaddr = inet_ntoa($ipaddr_binary);
    }
    else {
      $ipaddr = undef;
    }
  }

  # Print the results for this entry
  if (($hostname) and ($ipaddr)) {
    print "$ipaddr,$hostname\n";
  }
  elsif (($hostname) and (!$ipaddr)) {
    print "UNKNOWN,$hostname\n";
  }
  elsif (($ipaddr) and (!$hostname)) {
    print "$ipaddr,UNKNOWN\n";
  }

}