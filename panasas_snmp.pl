#!/usr/bin/env perl
use strict;
use warnings;
# Description: Check the status of a Panasas devices via SNMP
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 0.1
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
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use Net::SNMP;

my $verbose = 0;

GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \$verbose,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Check the status of a Panasas devices via SNMP.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity\n";
  exit;
}

# Log an error to syslog and STDERR.  Tag for Netcool alerts if asked to.
sub log_error {
  # Always returns undef.
  # Usage: log_error("Some error text", "syslog tag")
  # Syslog tag can be anything but NOC-NETCOOL-ALERT and NOC-NETCOOL-TICKET are for Netcool alerts.

  my $message = shift;
  my $tag = shift;

  print STDERR "! $message\n";
  if ($tag) {
#     syslog("LOG_ERR", "$tag: $message] -- $0.");
  }
  else {
#     syslog("LOG_ERR", "$message -- $0.");
  }
  return;
}

# Log a message to syslog and STDOUT.  Tag for Netcool alerts if asked to.
sub log_info {
  # Always returns undef.
  # Usage: log_info("Some log text", "syslog tag")
  # Syslog tag can be anything but NOC-NETCOOL-ALERT and NOC-NETCOOL-TICKET are for Netcool alerts.

  my $message = shift;
  my $tag = shift;

  print STDOUT "$message\n";
  if ($tag) {
    syslog("LOG_INFO", "$tag: $message -- $0.");
  }
  else {
    syslog("LOG_INFO", "$message -- $0.");
  }
  return;
}


# Perform an SNMP GET
sub snmp_get {
  # In a scalar context, returns the value retrieved via SNMP
  # Usage: snmp_get($oid, $session)
  # Returns undef on error
  # $oid should be the numberic OID, $session should be the result of Net::SNMP->session.

  my $oid = shift;
  my $session = shift;

  unless ($session) {
    log_error("SNMP session not started (use: Net::SNMP->session)");
    return;
  }

  # Do the GET
  my $result = $session->get_request($oid);

  # Did we get a result?
  unless ($result) {
    my $error = $session->error();
    log_error("Failed to query: $oid ($error)");
    return;
  }

  my $value = $result->{$oid};

  return $value;
}


# Define the OIDs
my %snmp_objects = (
  "vol_root_status" => ".1.3.6.1.4.1.10159.1.3.4.1.1.7.1.47",
  "vol_genomics_status" => ".1.3.6.1.4.1.10159.1.3.4.1.1.7.9.47.103.101.110.111.109.105.99.115",
  "bs_set1_availcapacity" => ".1.3.6.1.4.1.10159.1.3.3.1.1.8.5.83.101.116.32.49",
);


# Load the Panasas MIBs
$ENV{'MIBSDIR'}="/usr/share/snmp/mibs:/home/cssd/jaw171/PANASAS-MIBS";
$ENV{'MIBS'}="ALL"; 


# Start a new session
my ($session, $error) = Net::SNMP->session(
  -hostname => "10.200.10.19",
  -version => "1",
  -community => "vKz1xkQe",
);


# Was the session started?
unless ($session) {
  log_error("SNMP session not started (use: Net::SNMP->session): $error");
  exit 1;
}


# Loop through each SNMP object and get the value
for my $each_object (keys %snmp_objects) {
  
  # Do the GET
  next unless (my $value = snmp_get($snmp_objects{$each_object}, $session));

  # Print the result
  print "Result: $each_object => $value\n";

}


# Tear down the session
$session->close(); 