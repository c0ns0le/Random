#!/usr/bin/env perl
# Description: Create mail aliases when a new Mailman list is created (client)
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Some of the Postini code was pulled from Postini directly, some was pulled from
# existing Pitt software
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


use strict;
use warnings;
use IO::Socket::INET;
use Getopt::Long;
use Sys::Syslog qw( :DEFAULT setlogsock);


my $server_address = "130.49.193.130";
my $server_port = "4488";


GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \my $verbose,
           'l|list=s' => \my $list_name,
           'o|owner=s' => \my $list_owner,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Create mail aliases when a new Mailman list is created (client).\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity\n";
  print "-l | --list : Name of the list (e.g. mynewlist, NOT mynewlist\@list.pitt.edu)\n";
  print "-o | --owner : Username of the list owner (who will own the alias in Postini)\n";
  print "\nWARNING: Postini integration does not exist in this version.  This will currently\n";
  print "only create aliases in PMDF on the mail backbone.\n";
  exit;
}


# Prepare for syslog()
setlogsock("unix");
openlog($0, "nonul,pid", "user") or warn "Unable to open syslog connection\n";


# Log an error to syslog and STDERR.  Tag for Netcool alerts if asked to.
sub log_error {
  # Returns true if the print worked.
  # Usage: log_error("Some error text", "syslog tag")
  # Syslog tag can be anything but NOC-NETCOOL-ALERT and NOC-NETCOOL-TICKET are for Netcool alerts.

  my $message = shift;
  my $tag = shift;

  print STDERR "! ", scalar(localtime(time)), " : $message\n";
  if ($tag) {
    syslog("LOG_ERR", "$tag: $message");
  }
  else {
    syslog("LOG_ERR", "$message");
  }
  return;
}


# Log a message to syslog and STDOUT.
sub log_info {
  # Returns true
  # Usage: log_info("Some log text") # Scalar

  my $message = shift;

  print STDOUT scalar(localtime(time)), " : $message\n";
  syslog("LOG_INFO", "$message");
}


# Were we called correctly?
unless (($list_name) and ($list_owner)) {
  die "Not called with list name or owner, see -h for help.";
}


# Create the aliases on the mail backbone
my $client_socket;
unless (
  $client_socket = IO::Socket::INET->new(
  PeerHost => $server_address,
  PeerPort => $server_port,
  Proto => "tcp",
)) {
  log_error("Failed to make list aliases for '$list_name' on the mail backbone: Unable to connect to $server_address:$server_port", "NOC-NETCOOL-TICKET");
  die;
}

print "Successfully connected to $server_address:$server_port\n" if ($verbose);


# Send the list name to the mail backbone
$client_socket->send($list_name);


# Get the response from the mail backbone, time out after 60 seconds
$SIG{ALRM} = sub {
  log_error("Server $server_address timed out, closing connection.");
  $client_socket->close();
  die "Timed out waiting for data from the server\n";
};

my $received_data;
alarm(60); # Arm the time bomb
$client_socket->recv($received_data, 4096);
alarm(0); # Cut the blue wire

# Remove line endings
$list_name =~ s/[\r\n]+//g;

unless ($received_data) {
  log_error("Failed to make list aliases for '$list_name' on the mail backbone: No response received from the server", "NOC-NETCOOL-TICKET");
  $client_socket->close();
  die;
}

print "Received: $received_data" if ($verbose);


# Verify we received a 'success' response or flag for a ticket to be created
if ($received_data =~ m/^Successfully made list aliases for/) {
  log_info("Successfully made list aliases for '$list_name' on the mail backbone");
}
elsif ($received_data =~ m/^Failed to make list aliases for/) {
  log_error("Failed to make list aliases for '$list_name' on the mail backbone: Error response received", "NOC-NETCOOL-TICKET");
}
else {
  log_error("Failed to make list aliases for '$list_name' on the mail backbone: Invalid response received.", "NOC-NETCOOL-TICKET");
}


$client_socket->close();
