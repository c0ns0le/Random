#!/usr/bin/env perl
# Description: Example code for network communication with timeouts and forking (server)
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
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
use Getopt::Long;
use IO::Socket::INET;
use POSIX;


GetOptions('h|help' => \my $helpopt,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Example code for network communication with timeouts and forking (server).\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  exit;
}


print "Parent PID is $$\n";


# Create a new socket and start listening
my $server_socket = IO::Socket::INET->new(
  LocalAddr => "127.0.0.1",
  LocalPort => 4488,
  Proto => "tcp",
  Listen => 10,
  ReuseAddr => 1,
) or die "Could not create socket on 127.0.0.1:4488 TCP: $!";


while (1) {

  print "Waiting for connections on 127.0.0.1:4488\n";
  my $client_socket = $server_socket->accept();                                                                                                                                     
                                                                                                                                                                                    
  # Get the client's address and port                                                                                                                                               
  my $client_address = $client_socket->peerhost();                                                                                                                                  
  my $client_port = $client_socket->peerport();                                                                                                                                     
                                                                                                                                                                                    
  print "Accepted connection from $client_address:$client_port\n";                                                                                                                  
                                                                                                                                                                                    
  # Fork off a child to do the work                                                                                                                                                 
  my $fork_status = fork;                                                                                                                                                           
  if (!(defined($fork_status)) or ($fork_status < 0)) {                                                                                                                             
                                                                                                                                                                                    
    die "Unable to fork: $!";                                                                                                                                                       
                                                                                                                                                                                    
  }                                                                                                                                                                                 
  # We're the child, get to work                                                                                                                                                    
  elsif ($fork_status == 0) {                                                                                                                                                       
                                                                                                                                                                                    
    print "I'm the child: $$\n";                                                                                                                                                    
                                                                                                                                                                                    
    # Receive data from the client, time out after 10 seconds                                                                                                                       
    my $received_data;                                                                                                                                                              
    
    # If we time out inform the client, close the connection and die since we're the child
    $SIG{ALRM} = sub {                                                                                                                                                              
      $client_socket->send("Timed out, be faster next time.\n");                                                                                                                    
      $client_socket->close();                                                                                                                                                      
      die "Timed out waiting for data from client\n";                                                                                                                               
    };                                                                                                                                                                              
                                                                                                                                                                                    
    alarm(10); # Arm the time bomb                                                                                                                                                  
    $client_socket->recv($received_data, 4096);                                                                                                                                     
    alarm(0); # Cut the blue wire                                                                                                                                                   
                                                                                                                                                                                    
    # Remove line endings
    $received_data =~ s/[\r\n]+//g;

    unless ($received_data) {
      die "No data received from client '$client_address:$client_port'";
    }

    print "Received: $received_data\n";

    # Do real work here or after the send

    $client_socket->send("OK, got it, bye.\n");

    # Child is done, time to disconnect and exit
    print "Child $$ is done, exiting\n";
    $client_socket->close();
    exit;

  }
  # We are the parent, close our client socket and wait for the next connection
  else {

    print "My child is: $fork_status\n";
    $client_socket->close();

  }

}