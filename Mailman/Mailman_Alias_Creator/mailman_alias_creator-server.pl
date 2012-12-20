#!/usr/bin/env perl
# Description: Create mail aliases with PMDF when a new Mailman list is created (server)
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
use IO::Socket::INET;
use Getopt::Long;
use POSIX;
use IPC::Open3;
use IO::Select;
use Symbol; # for gensym


my $pidfile = "/var/run/list_alias_creator.pid";
my $listen_address = "130.49.193.130";
my $listen_port = "4488";


GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \my $verbose,
           'f|foreground' => \my $foreground,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Create mail aliases with PMDF when a new Mailman list is created (server).\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-f | --foreground : Run in the foreground instead of daemonizing\n";
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity\n";
  exit;
}


# Log an error to syslog and STDERR.  Tag for Netcool alerts if asked to.
sub log_error {
  # Returns true if the print worked.
  # Usage: log_error("Some error text", "syslog tag")
  # Syslog tag can be anything but NOC-NETCOOL-ALERT and NOC-NETCOOL-TICKET are for Netcool alerts.

  my $message = shift;
  my $tag = shift;

  print STDERR "! ", scalar(localtime(time)), " : $message\n";
  if ($tag) {
    system("/usr/bin/logger -p user.err -t $tag '$message'");
  }
  else {
    system("/usr/bin/logger -p user.err '$message'");
  }
  return;
}


# Log a message to syslog and STDOUT.
sub log_info {
  # Returns true
  # Usage: log_info("Some log text") # Scalar

  my $message = shift;

  print STDOUT scalar(localtime(time)), " : $message\n";
  system("/usr/bin/logger -p daemon.info '$message'");
}


# Stop listening and exit on SIGINT or SIGTERM
sub exit_on_signal {
  # Always exists without returning
  # Usage: exit_on_signal($server_socket)
  
  print "Caught signal, exiting\n" if ($verbose);
  
  unlink($pidfile) or log_error("Failed to remove PID file '$pidfile': $!");
  
  exit;

}
$SIG{'TERM'} = "exit_on_signal";
$SIG{'INT'} = "exit_on_signal";


# Are we being ran as root?
unless ($> == 0) {
  log_error("Must be ran as root.  Your EUID is '$>'");
  die;
}



# Check/open the PID file
if ( -f "$pidfile" ) {
  log_error("PID file '$pidfile' exists, cannot start.");
  die;
}

my $PIDFILE;
unless (open($PIDFILE, "+>", $pidfile)) {
  log_error("Unable to open PID file '$pidfile': $!");
  die;
}
$PIDFILE->autoflush;


# Daemonize unless we were told not to
unless ($foreground) {

  unless (chdir '/') {
    log_error("Unable to chdir to /: $!");
    die;
  }

  unless ((open STDIN, '/dev/null') and (open STDOUT, '/dev/null') and (open STDERR, '/dev/null')) {
    log_error("Unable to read from /dev/null: $!");
    die;
  }

  my $pid;
  unless (defined($pid = fork)) {
    log_error("Unable to fork: $!");
    die;
  }
  exit if $pid;

  unless (POSIX::setsid()) {
    log_error("Unable to start a new session.");
    die;
  }
  
}

unless (print $PIDFILE "$$\n") {
  log_error("Unable to write PID to '$pidfile': $!");
  die;
}
close $PIDFILE;


# Create a new socket and start listening
my $server_socket;
unless ($server_socket = IO::Socket::INET->new(
  LocalAddr => $listen_address,
  LocalPort => $listen_port,
  Proto => "tcp",
  Listen => 10,
  ReuseAddr => 1,
)) {
  log_error("Could not create socket on $listen_address:$listen_port TCP: $!", "NOC-NETCOOL-ALERT");
  die;
}


while (1) {

  print "Waiting for connections on $listen_address:$listen_port\n" if ($verbose);
  my $client_socket = $server_socket->accept();

  
  # Get the client's address and port
  my $client_address = $client_socket->peerhost();
  my $client_port = $client_socket->peerport();

  
  print "Accepted connection from $client_address:$client_port\n" if ($verbose);
  
  
  # Check that we trust this peer
  unless (
    ($client_address !~ m/130.49.193.98/) or # mailman-dev.cssd
    ($client_address !~ m/136.142.11.144/) or # mailman.cssd
    ($client_address !~ m/127.0.0.1/)
  ) {
    log_error("Peer '$client_address' is not trusted, closing connection.");
    $client_socket->close();
    next;
  }


  # Fork off a child to do the work
  my $fork_status = fork;
  if (!(defined($fork_status)) or ($fork_status < 0)) {

    die "Unable to fork: $!";

  }
  # We're the child, get to work
  elsif ($fork_status == 0) {
  
    print "I'm the child: $$\n" if ($verbose);
    
    # Read list name from the client, time out after 300 seconds
    $SIG{ALRM} = sub {
      log_error("Client $client_address timed out, closing connection.");
      $client_socket->send("Timed out, closing connection.\n");
      $client_socket->close();
      die "Timed out waiting for data from client\n";
    };
    
    my $list_name;
    
    alarm(300); # Arm the time bomb
    $client_socket->recv($list_name, 4096);
    alarm(0); # Cut the blue wire
    
    # Remove line endings
    $list_name =~ s/[\r\n]+//g;
    
    unless ($list_name) {
      log_error("No data received from client '$client_address:$client_port'");
      die;
    }
    
    print "Received: $list_name\n" if ($verbose);

    
    # Prepare filehandles
    my ($CHILD_IN, $CHILD_OUT, $CHILD_ERR); # these are the FHs for our child 
    $CHILD_ERR = gensym(); # we create a symbol for $CHILD_ERR because open3 will not do that for us


    # Start the external program
    my $child_pid;

    eval{
      $child_pid = open3($CHILD_IN, $CHILD_OUT, $CHILD_ERR, "pmdf", "db");
    };
    if ($@) {
      log_error("Failed to fork pmdf for list '$list_name': $@\n");
      $client_socket->send("Failed to make list aliases for '$list_name'\n");
      die;
    }

    print "PID is $child_pid\n" if ($verbose);
    
    
    # Feed the external program
    my $list_server = "\@route-list-dev.pitt.edu";
    print $CHILD_IN <<EOI;
open /pmdf/directories/list-dev.pitt.edu
add $list_name $list_name$list_server
add $list_name-admin $list_name-admin$list_server
add $list_name-bounces $list_name-bounces$list_server
add $list_name-confirm $list_name-confirm$list_server
add $list_name-join $list_name-join$list_server
add $list_name-leave $list_name-leave$list_server
add $list_name-owner $list_name-owner$list_server
add $list_name-request $list_name-request$list_server
add $list_name-subscribe $list_name-subscribe$list_server
add $list_name-unsubscribe $list_name-unsubscribe$list_server
quit
EOI

    # Grab each line of output
    my $select_object_child_fhs = new IO::Select; # create a select object to notify us on reads on our FHs
    $select_object_child_fhs->add($CHILD_OUT, $CHILD_ERR); # add the FHs we're interested in to the object

    my (@child_out, @child_err);
    while(my @ready = $select_object_child_fhs->can_read) { # read ready

      foreach my $CHILD_FILE_HANDLE (@ready) {

        my $line = <$CHILD_FILE_HANDLE>; # read one line from this fh
        unless (defined $line) { # EOF on this FH
          $select_object_child_fhs->remove($CHILD_FILE_HANDLE); # remove it from the list
          next; # and go handle the next FH
        }

        if ($CHILD_FILE_HANDLE == $CHILD_OUT) { # if we read from the outfh
          print "Out: $line" if ($verbose);
          push @child_out, $line;
        }
        elsif ($CHILD_FILE_HANDLE == $CHILD_ERR) {# do the same for errfh  
          print "Err: $line" if($verbose);
          push @child_err, $line;
        }

      }

    }

    
    # Reap the child
    waitpid($child_pid, 1);
    print "Child $child_pid is done\n" if ($verbose);
    
    my $pmdf_exit_status = $? / 256;
    
    
    # Check for errors
    # If we made 10 aliases report success to the client
    if (grep(m/Entry added to database/, @child_out) == 10) {
    
      log_info("Successfully made list aliases for '$list_name'") if ($verbose);
      $client_socket->send("Successfully made list aliases for '$list_name'\n");
      
    }
    # ... otherwise report a failure
    else {

      $client_socket->send("Failed to make list aliases for '$list_name'\n");

      my $LIST_ALIAS_EXCEPTIONS_FILE;
      log_error("Failed to create aliases for Mailman list '$list_name'.  Exit status was $pmdf_exit_status.  Check /tmp/list_alias_exceptions.$$.", "NOC-NETCOOL-TICKET");
      
      if (open($LIST_ALIAS_EXCEPTIONS_FILE, "+>", "/tmp/list_alias_exceptions.$$")) {
        print $LIST_ALIAS_EXCEPTIONS_FILE "Out:\n@child_out\n";
        print $LIST_ALIAS_EXCEPTIONS_FILE "Err:\n@child_err\n";
      }
      else {
        log_error("Failed to create list alias exceptions file '/tmp/list_alias_exceptions.$$'");
      }
    
    }

    
    # Child is done, let's disconnect and exit
    $client_socket->close();
    exit;
  
  }
  # We are the parent, close our client socket and wait for the next connection
  else {

    print "My child is: $fork_status\n" if ($verbose);
    $client_socket->close();

  }
  
}