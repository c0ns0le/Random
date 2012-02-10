#!/usr/bin/perl
#Description: Perl script to create a simple report of IPs and their DNS entries.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.1 - 2012-02-10 - Initial version. - Jeff White
#
#####

use warnings; #Print warnings
#use strict; #Enforce 'good' programming rules
use Socket;

if ( @ARGV != 1 ){
  print "Usage: $0 file\n";
  die "A file with a list of IPs or hostnames is required as an argument";
}

#Print a header
print "IP : Hostname\n";

while (defined(my $eachline = <>)) {

  chomp $eachline;

  if ($eachline =~ m/^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5]).([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$/) {
    $ipaddr = $eachline;
    my $ipaddr_binary = inet_aton("$ipaddr");
    $hostname = gethostbyaddr($ipaddr_binary, AF_INET);
  }
  else {
    $hostname = $eachline;
    my $ipaddr_binary = gethostbyname($hostname);
    $ipaddr = inet_ntoa($ipaddr_binary)
  }

  if ($hostname && $ipaddr) {
    print "$ipaddr : $hostname\n";
  }
  elsif ($hostname && !$ipaddr) {
    print "UNKNOWN : $hostname\n";
  }
  elsif ($ipaddr && !$hostname) {
    print "$ipaddr : UNKNOWN\n";
  }

}