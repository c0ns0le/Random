#!/usr/bin/perl
#Description: Perl script to parse the logs of OpenAFS' kaserver and gather useful information.
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
# 0.1 - 2012-01-23 - Initial version. - Jeff White
#
#####

use warnings; #Print warnings
use strict; #Enforce 'good' programming rules
use Socket;

my ($username_and_service,$junk,$ip_in_hex,$last_operation_date,$username,$service);

#Print a header
print "User,Service,Source IP,Source Hostname,Timestamp\n";

#Read each line of input
while (defined(my $eachline = <>)) {
  chomp $eachline;
  #Get rid of the :gtck: string.
  $eachline =~ s/:gtck://;

  #Split up each line of input into separate variables
  ($username_and_service,$junk,$junk,$junk,$junk,$ip_in_hex,$junk,$last_operation_date) = split(/ /, $eachline, 8);

  #Split the username and service into separate variables
  ($username,$service) = split(/,/, $username_and_service, 2);

  #Switch the hex IP to to dotted decimal
  my $ip_in_decimal = `/usr/local/bin/hex-ip-ascii $ip_in_hex`;
  chomp $ip_in_decimal;

  #Get the hostname from the IP
  my $iaddr = inet_aton("$ip_in_decimal");
  my $source_hostname = gethostbyaddr($iaddr, AF_INET);

  print "${username},${service},${ip_in_decimal},$source_hostname,${last_operation_date}\n";
}