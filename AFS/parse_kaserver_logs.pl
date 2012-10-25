#!/usr/bin/env perl
use strict;
use warnings;
# Description: Parse the logs of OpenAFS' kaserver and gather useful information
# Written by: Jeff White (jwhite530@gmail.com)
# Version: 1
# Last change: Re-write to output by-IP or by-user statistics

# License:
# This software is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


use Getopt::Long;
Getopt::Long::Configure("bundling");
use Socket;
use Time::Local;


GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \my $verbose,
           'h|host' => \my $host_mode,
           'u|user' => \my $user_mode,
          ) || die "Invalid usage, use -h for help.\n";

          
if ($helpopt) {
  print "Parse the logs of OpenAFS' kaserver and gather useful information.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "The input to this program can be generated by:\n";
  print "kdb | nawk '/gtck/ {print $1}' | while read -r each_ticket;do kdb -key \$each_ticket;done\n\n";
  print "Usage: $0 [options] input_file\n"; 
  print "-h | --help : Show this help\n";
  print "-h | --host : Display statistics by host/IP\n";
  print "-u | --user : Display statistics by user\n";
  exit;
}


my $current_epoch = time;


if ($user_mode) {
  print "Not yet implemented\n"
}
else {

  my %hosts_last_30_days;
  my %hosts_all_time;
  my %dns_lookup_cache;

  while (defined(my $each_entry = <>)) {
    chomp $each_entry;
    
    # Get the information we need from the entry
    my ($ip_in_hex, $month, $monthday, $time, $year) = (split(m/\s+/, $each_entry))[5, 8, 9, 10, 11];
    
    # Skip old entries
    next if ($year < 2012 );
    
    my ($hour, $minute, $second) = split(m/:/, $time);
    
    if ($month eq "Jan") {
      $month = 0;
    }
    elsif ($month eq "Feb") {
      $month = 1;
    }
    elsif ($month eq "Mar") {
      $month = 2;
    }
    elsif ($month eq "Apr") {
      $month = 3;
    }
    elsif ($month eq "May") {
      $month = 4;
    }
    elsif ($month eq "Jun") {
      $month = 5;
    }
    elsif ($month eq "Jul") {
      $month = 6;
    }
    elsif ($month eq "Aug") {
      $month = 7;
    }
    elsif ($month eq "Sep") {
      $month = 8;
    }
    elsif ($month eq "Oct") {
      $month = 9;
    }
    elsif ($month eq "Nov") {
      $month = 10;
    }
    elsif ($month eq "Dec") {
      $month = 11;
    }
    
    my $entry_epoch = timelocal($second,$minute,$hour,$monthday,$month,$year);
    
    # Switch the hex IP to to dotted decimal
    my $P1 = hex(substr($ip_in_hex,0,2));
    my $P2 = hex(substr($ip_in_hex,2,2));
    my $P3 = hex(substr($ip_in_hex,4,2));
    my $P4 = hex(substr($ip_in_hex,6,2));
    my $ip_in_decimal = "$P1.$P2.$P3.$P4";
    
    
    # Get the hostname from the IP
    my $host;
    if ($dns_lookup_cache{$ip_in_decimal}) {
      $host = $dns_lookup_cache{$ip_in_decimal};
    }
    else {
      my $iaddr = inet_aton("$ip_in_decimal");
      $host = gethostbyaddr($iaddr, AF_INET);
      $host = "Unknown" unless ($host);
      $dns_lookup_cache{$ip_in_decimal} = $host;
    }
    
    # Add the entry to the hash(es)
    $hosts_all_time{"$host - $ip_in_decimal"}++;
    
    if (($current_epoch - $entry_epoch) <= 2592000) {
      $hosts_last_30_days{"$host - $ip_in_decimal"}++;
    }
    
  }
  
  # Print the final statistics
  print "Hosts in the last 30 days:\n";
  for my $each_host (sort {$hosts_last_30_days{$b} <=> $hosts_last_30_days{$a}} (keys(%hosts_last_30_days))) {
    print "$each_host ($hosts_last_30_days{$each_host})\n";
  }
  
  print "\n\nHosts in 2012:\n";
  for my $each_host (sort {$hosts_all_time{$b} <=> $hosts_all_time{$a}} (keys(%hosts_all_time))) {
    print "$each_host ($hosts_all_time{$each_host})\n";
  }

}