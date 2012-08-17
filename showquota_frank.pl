#!/usr/bin/env perl
use strict;
use warnings;
# Description: Display the disk quotas for the current user and group
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Getopt::Long;
Getopt::Long::Configure("bundling");
use Sys::Syslog qw(:DEFAULT setlogsock);

my %whitelisted_users = (
#   "kimwong" => "Kim Wong, SaM admin",
);

$| = 1;
my $verbose = 0;

GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \$verbose,
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

print "Getting quota for user '$user' and group '$group'...\n" if ($verbose);

# Get the /home user quota
{
  print "Getting user quota for /home...\n" if ($verbose);
  my @quota_out = `quota -u $user 2>/dev/null`;
  my $quota_line = $quota_out[-1];
  
  # Is any quota set?
  if ($quota_line =~ m/none$/) {
    print "/home: No quota is set for user $user.\n\n";
    
    # If the user isn't whitelisted, create an alert for the issue
    unless ($whitelisted_users{$user}) {
      syslog("LOG_ERR", "NOC-NETCOOL-TICKET: /home: No quota is set for user $user");
    }
    
    next;
  }
  
  my ($quota_used, $home_soft, $quota_hard) = (split(m/\s+/, $quota_line))[1,2,3];

  # If we were able to get the quota...
  if (($quota_used) and ($quota_hard)) {
    my $home_free = sprintf("%.2f", ($quota_hard - $quota_used) / 1024 / 1024);
    $quota_used = sprintf("%.2f", $quota_used / 1024 / 1024);
    $quota_hard = sprintf("%.2f", $quota_hard / 1024 / 1024 );

    print "/home: ${quota_used}GB used of ${quota_hard}GB limit (${home_free}GB free) for user $user\n\n"
  }
  else {
    print "Unable to find quota of /home for $user\n\n";
  }
}



# Get the /home group quota
{
  print "Getting group quota for /home...\n" if ($verbose);
  my @qouta_out = `quota -g $group 2>/dev/null`;
  my $quota_line = $qouta_out[-1];
  
  # Is any quota set?
  if ($quota_line =~ m/none$/) {
#     print "/home: No quota is set for group $group.  Please report this on http://core.sam.pitt.edu.\n\n";
    next;
  }
  
  my ($quota_used, $quota_hard) = (split(m/\s+/, $quota_line))[1,3];

  # If we were able to get the quota...
  if (($quota_used) and ($quota_hard)) {
    my $home_free = sprintf("%.2f", ($quota_hard - $quota_used) / 1024 / 1024);
    $quota_used = sprintf("%.2f", $quota_used / 1024 / 1024);
    $quota_hard = sprintf("%.2f", $quota_hard / 1024 / 1024 );

    print "/home: ${quota_used}GB used of ${quota_hard}GB limit (${home_free}GB free) for group $group\n\n"
  }
  else {
    print "Unable to find quota of /home for $group\n\n";
  }
}



# Get the /gscratch user quota
{
  print "Getting user quota for /gscratch...\n" if ($verbose);
  my @quota_out = `gquota_client.py --volume=vol_global_scratch --path=/$group/$user`;
  my $quota_line = $quota_out[-1];
  
  # Is any quota set?
  if ($quota_line =~ m/^No quota found/) {
#     print "/gscratch: No quota is set for user $user.  Please report this on http://core.sam.pitt.edu.\n\n";
    next;
  }
  
  my ($quota_used, $quota_hard) = (split(m/\s+/, $quota_line))[1,3];

  # If we were able to get the quota...
  if (($quota_used) and ($quota_hard)) {
    print "/gscratch: $quota_used used of $quota_hard limit for user $user\n\n"
  }
  else {
    print "Unable to find quota of /gscratch for $user\n\n";
  }
}



# Get the /gscratch group quota
{
  print "Getting group quota for /gscratch...\n" if ($verbose);
  my @quota_out = `gquota_client.py --volume=vol_global_scratch --path=/$group`;
  my $quota_line = $quota_out[-1];
  
  # Is any quota set?
  if ($quota_line =~ m/^No quota found/) {
#     print "/gscratch: No quota is set for group $group.  Please report this on http://core.sam.pitt.edu.\n\n";
    next;
  }
  
  my ($quota_used, $quota_hard) = (split(m/\s+/, $quota_line))[1,3];

  # If we were able to get the quota...
  if (($quota_used) and ($quota_hard)) {
    print "/gscratch: $quota_used used of $quota_hard limit for group $group\n\n"
  }
  else {
    print "Unable to find quota of /gscratch for $group\n\n";
  }
}



# Get the Panasas user quota



# Get the Panasas group quota


closelog;