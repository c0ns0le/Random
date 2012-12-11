#!/usr/bin/env perl
use strict;
use warnings;
# Description: Daemon to create a persistent VPN connection with vpnc
# Written by: Jeff White (jwhite530@gmail.com)
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
use IO::Handle;
use POSIX;


my $vpnc_config = "/etc/vpnc/pitt.conf";
my $pidfile = "/var/run/vpncd.pid";


GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \my $verbose,
           'f|foreground' => \my $foreground,
          ) || die "Invalid usage, use -h for help.\n";

          
if ($helpopt) {
  print "Daemon to create a persistent VPN connection with vpnc.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity\n";
  print "-f | --foreground : Run in the foreground rather than daemonizing\n";
  exit;
}


# Prepare for syslog()
setlogsock("unix");
openlog($0, "nonul,pid", "user") or warn "Unable to open syslog connection\n";


# Log an error to syslog and STDERR.
sub log_error {
  # Returns true
  # Usage: log_error("Some error text") # Scalar

  my $message = shift;

  print STDERR "! ", scalar(localtime(time)), " : $message\n";
  syslog("LOG_ERR", "$message -- $0.");
  
  return;
}


# Log a message to syslog and STDOUT.
sub log_info {
  # Returns true
  # Usage: log_info("Some log text") # Scalar

  my $message = shift;

  print STDOUT scalar(localtime(time)), " : $message\n";
  syslog("LOG_INFO", "$message -- $0.");
}


# Connect VPN
sub vpnc_connect {
  # Returns true if vpnc exited with a status of 0, false if vpnc failed, undef on error
  
  system("vpnc --ifname tun0 --non-inter /etc/vpnc/pitt.conf >/dev/null");
  
  my $vpnc_connect_status = $? / 256;
  
  if ($vpnc_connect_status == 0) {
    print "Succesfully connected vpnc\n" if ($verbose);
    
    # EPEL's vpnc package doesn't support the config file setting to not change DNS
    my $RESOLV_CONF_FILE;
    unless (open($RESOLV_CONF_FILE, "+>", "/etc/resolv.conf")) {
      log_error("Failed to open '/etc/resolv.conf': $!");
      return;
    }
    print $RESOLV_CONF_FILE "nameserver 192.168.10.1\n";
    
    return 1;
  }
  else {
    log_error("Failed to connect vpnc: $vpnc_connect_status");
    return 0;
  }
  
}


# Disconnect VPN
sub vpnc_disconnect {
  # Returns true if vpnc-disconnect exited with a status of 0, returns false otherwise

  system("vpnc-disconnect >/dev/null");
  
  my $vpnc_disconnect_status = $? / 256;
  
  if ($vpnc_disconnect_status == 0) {
    print "Succesfully disconnected vpnc\n" if ($verbose);
    return 1;
  }
  else {
    log_error("Failed to disconnect vpnc: $vpnc_disconnect_status");
    return 0;
  }

}


# Check if vpnc is already running
sub check_vpn_status {
  # Returns true if the VPN is up, false if down, undef on error

  # If vpnc's PID file exists get the PID and see if it is still running
  if (-f "/var/run/vpnc/pid") {
  
    my $VPNC_PID_FILE;
    unless (open($VPNC_PID_FILE, "<", "/var/run/vpnc/pid")) {
      log_error("Failed to open vpnc's PID file '/var/run/vpnc/pid': $!");
      return;
    }
    
    my $vpnc_pid = <$VPNC_PID_FILE>;
    chomp $vpnc_pid;
    
    print "Checking vpnc PID $vpnc_pid\n" if ($verbose);
    
    if (-f "/proc/$vpnc_pid/status") {
      
      my $VPNC_STATUS_FILE;
      unless (open($VPNC_STATUS_FILE, "<", "/proc/$vpnc_pid/status")) {
        log_error("Failed to open vpnc process status file '/proc/$vpnc_pid/status': $!");
        return;
      }
      
      if (grep(m/^Name:\s+vpnc/, <$VPNC_STATUS_FILE>)) {
        
        print "vpnc is running as PID $vpnc_pid\n" if ($verbose);
        return 1;
        
      }
      else {
      
        print "PID $vpnc_pid exists but is not vpnc, stale PID file\n" if ($verbose);
        return 0;
        
      }
      
    }
    else {
      
      print "vpnc's PID file '/var/run/vpnc/pid' exists but the process is not running\n" if ($verbose);
      return 0;
      
    }
    
  }
  else {
  
    print "vpnc's PID file does not exist, assuming vpnc is not running.\n" if ($verbose);
    return 0;
    
  }
  
}


# Disconnect and exit on SIGINT or SIGTERM
sub exit_on_signal {
  # Always exists without returning
  
  print "Caught signal, exiting\n" if ($verbose);
  
  if (vpnc_disconnect()) {
    print "Successfully disconnected vpnc\n" if ($verbose);
  }
  else {
    log_error("Failed to disconnect vpnc, exiting anyway");
  }
  
  unlink($pidfile);
  
  exit;

}
$SIG{'TERM'} = 'exit_on_signal';
$SIG{'INT'} = 'exit_on_signal';


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

  # Send STDOUT and STDERR to /dev/null from now on
  my $DEV_NULL;
  unless (open($DEV_NULL, ">>", "/dev/null")) {
    log_error("Unable to open /dev/null: $!");
    die;
  }
  *STDOUT = $DEV_NULL;
  *STDERR = $DEV_NULL;

  unless (chdir '/') {
    log_error("Unable to chdir to /: $!");
    die;
  }

  unless (open STDIN, '/dev/null') {
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


# Check if vpnc is still up, connect if not
while (1) {
  if (check_vpn_status()) {

    print "vpnc appears to be running, sleeping for 60 seconds\n" if ($verbose);
    
  }
  else {

    if (vpnc_connect()) {
      log_info("vpnc successfully connected");
    }
    else {
      log_error("vpnc failed to connect, trying again in 60 seconds")
    }
    
  }

  sleep 60;
}


closelog;