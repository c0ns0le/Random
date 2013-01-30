#!/usr/bin/env perl
use strict;
use warnings;
# Description: Display the disk quotas for the current user and group
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 2
# Last change: Rewrite to handle multiple filesystems and use the Quota module

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Getopt::Long;
Getopt::Long::Configure("bundling");
use Sys::Syslog qw(:DEFAULT setlogsock);
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use POSIX qw(isdigit);
use Quota;


my %whitelisted_users = (
#   "kimwong" => "Kim Wong, SaM admin",
);

$| = 1;


GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \my $verbose,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Display the disk quotas for the current user and group.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity\n";
  exit;
}


# Prepare for syslog()
setlogsock("unix");
openlog($0, "nonul,pid", "user") or warn "Unable to open syslog connection\n";


my $user = getpwuid($<);
my $group = getgrgid($();
my ($uid_number, $gid_number) = (getpwnam($user))[2,3];


# Loop through each filesystem and try to find a quota
my $no_quota = 0;
for my $filesystem (qw(/home /home1 /home2 /gscratch1)) {
  
  print "Getting quota for user '$user' and group '$group' on '$filesystem'\n" if ($verbose);
  
  my $device = Quota::getqcarg( $filesystem );
  
  # User quotas
  {
    my ($current_usage, $soft_limit, $hard_limit) = (Quota::query( $device,$uid_number ))[0,1,2];
    
    if (($current_usage) or ($soft_limit) or ($hard_limit)) {
      
      $current_usage =~ s/\*//; # If the user is over quota we need to remove this from the output
      print BOLD RED "Warning: " if ($current_usage >= $soft_limit);      
      print "User $user is using " . sprintf("%.2f", $current_usage/1024/1024) . " GB of " . sprintf("%.2f", $soft_limit/1024/1024) . " GB on $filesystem (" . sprintf("%.2f", $hard_limit/1024/1024) . " GB hard limit)\n";
      
    }
    else {
      
      $no_quota++;
      
    }
  }
  
  
  # Group quotas
  {
    my ($current_usage, $soft_limit, $hard_limit) = (Quota::query( $device,$gid_number,1 ))[0,1,2];
  
    if (($current_usage) or ($soft_limit) or ($hard_limit)) {
    
      $current_usage =~ s/\*//; # If the user is over quota we need to remove this from the output
      print BOLD RED "Warning: " if ($current_usage >= $soft_limit); 
      print "Group $group is using " . sprintf("%.2f", $current_usage/1024/1024) . " GB of " . sprintf("%.2f", $soft_limit/1024/1024) . " GB on $filesystem (" . sprintf("%.2f", $hard_limit/1024/1024) . " GB hard limit)\n\n";
      
    }
    else {
    
      $no_quota++;
      
    }
  }
  
}


# Check that the user has at least some kind of quota
if ($no_quota == 8) {
  print "Unable to find quota, admins have been notified";
  syslog("LOG_ERR", "NOC-NETCOOL-TICKET: No quota is set for user $user");
}


closelog;