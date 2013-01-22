#!/usr/bin/env perl
# Description: Take a cold backup of the AFS databases
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure("bundling");
use Sys::Syslog qw(:DEFAULT setlogsock);


my $db_directory="/usr/afs/db";
my $backup_directory="/afsbackup";


GetOptions('h|help' => \my $helpopt,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Take a cold backup of the AFS databases.\n";
  print "WARNING: Running this program will bring down the AFS processes!\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  exit;
}


# Prepare for syslog()
setlogsock("unix");
openlog($0, "nonul,pid", "user") or warn "Unable to open syslog connection\n";


# Log an error to syslog and STDERR.  Tag for Netcool alerts if asked to.
sub log_error {
  # Returns true if the print worked.
  # Usage: log_error("Some error text", "syslog tag") # Scalar
  # Syslog tag can be anything but NOC-NETCOOL-ALERT and NOC-NETCOOL-TICKET are for Netcool alerts.

  my $message = shift;
  my $tag = shift;

  print STDERR "! : $message\n";
  if ($tag) {
    syslog("LOG_ERR", "$tag: $message");
  }
  else {
    syslog("LOG_ERR", $message);
  }
  return;
}


umask(077);


#
# Stop the AFS server processes
#
print "Stopping AFS server processes ...\n";
system("service", "openafs-server", "stop");
my $daemon_stop = $? / 256;

system("service", "openafs-server", "status");
my $daemon_status = $? / 256;

unless (($daemon_stop == 0) and ($daemon_status == 3)) {
  log_error("Failed to stop AFS database processes for cold backup.", "NOC-NETCOOL-ALERT");
  die;
}


#
# Create a new backup
#
print "Backing up AFS databases ...\n";
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year += 1900;
$mon++;

system("tar", "czf", "$backup_directory/all-afs-dbs_$year-$mon-$mday-$hour:$min:$sec.tgz", "/usr/afs/db");

unless (($? / 256) == 0) {
  log_error("Failed to create new tar backup of AFS databases.", "NOC-NETCOOL-ALERT");
}


#
# Start the AFS server processes
#
print "Starting AFS server processes ...\n";
system("service", "openafs-server", "start");
my $daemon_start = $? / 256;

system("service", "openafs-server", "status");
$daemon_status = $? / 256;

unless (($daemon_start == 0) and ($daemon_status == 0)) {
  log_error("Failed to start AFS database processes after cold backup.", "NOC-NETCOOL-ALERT");
  die;
}


#
# Remove old backups
#
print "Removing old AFS database backups ...\n";
for my $each_backup (glob("$backup_directory/all-afs-dbs_*")) {

  # Skip things that aren't files
  next unless (-f $each_backup);
  
  # Delete it if the file is older than 60 days (well, not modifified in 60 days)
  if ((time - (stat($each_backup))[9]) > 5184000) {
    print "... Removing old AFS database backup $each_backup\n";
    unlink($each_backup);
  }
  
}


closelog;
print "Completed backing up AFS databases\n";
syslog("LOG_INFO", "Completed backing up AFS databases");