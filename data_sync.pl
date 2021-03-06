#!/usr/bin/env perl
use strict;
use warnings;
# Description: Daemon to sync a directory between two systems
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.8
# Last change: Added -f (foreground) option to not daemonize, switch STDOUT and STDERR to /dev/null when daemonizing, 
# added -d (delete) option to control rsync's --delete, wrote a better sleep function due to issues with system()
# and SIGINT and to deal with perl's interruptable sleep().

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
use POSIX qw(WIFSIGNALED WTERMSIG setsid);
use File::Rsync;
use File::Path qw(make_path);

my $pidfile = "/var/run/data_sync";
my $log_file = "/var/log/data_sync.log";
my $status_file = "/tmp/data_sync.status";

# Don't change these
$| = 1;
my $verbose = 0;
my $rsync_delete = 0;
my %run_stats;

GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \$verbose,
           'f|foreground' => \my $foreground,
           'd|delete' => \$rsync_delete,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Daemon to sync a directory between two system.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options] {start|stop|status}\n"; 
  print "-d | --delete : Enable rsync's --delete (default: off)\n";
  print "-f | --foreground : Run in the foreground instead of daemonizing\n";
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity\n";
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

  print STDERR "! ", scalar(localtime(time)), " : $message\n";
  if ($tag) {
    syslog("LOG_ERR", "$tag: $message -- $0.");
  }
  else {
    syslog("LOG_ERR", "$message -- $0.");
  }
  return;
}

# Log a message to syslog and STDOUT.  Tag for Netcool alerts if asked to.
sub log_info {
  # Returns true if the print worked.
  # Usage: log_info("Some log text") # Scalar

  my $message = shift;

  print STDOUT scalar(localtime(time)), " : $message\n";
  # This script sends STDOUT to the log when it forks so we don't really need this sub...
}

# Check sanity
sub check_sanity {
  # Returns true is successful, commits suicide on any failure
  # Usage: check_sanity()
  
  # Open /proc/mounts and ensure the source and destination are mounted
  my $MOUNTS;
  unless (open($MOUNTS, "<", "/proc/mounts")) {
    log_error("Failed to open /proc/mounts, can't check sanity.");
    daemon_stop();
    die "Sanity check failed but could not exit cleanly!";
  }
  my @mounts = <$MOUNTS>;
  # This is ugly as it has my mounts hard-coded ... I'll fix it later
  unless (grep(m|/data|, @mounts) and grep(m|/mnt/home|, @mounts)) {
    log_error("Sanity check failed: Either source mount '/data' or destination mount '/mnt/home' is not mounted.");
    daemon_stop();
    die "Sanity check failed but could not exit cleanly!";
  }
  
  log_info("Sanity check passed, starting run.");
  return 1;
}


# Do the actual rsync
sub do_stuff {
  # Returns true, always
  # Usage: do_stuff()

  my $source = "/data/home"; # Without the trailing slash
  my $dest = "/mnt/home"; # Without the trailing slash
  
  # Die if we are truely insane
  unless (check_sanity()) {
    log_error("Sanity check failed but could not exit cleanly!");
    die;
  }
  
  my $rsync_obj = File::Rsync->new({
    archive => 1,
    inplace => 1,
    del => $rsync_delete,
  });

  # Get a array of group dirs
  my @group_dirs;
  for my $each_fs_object (glob("$source/*")) {
  
    if (-d $each_fs_object) {
      $each_fs_object =~ s|^\Q$source/\E||;
      push(@group_dirs, $each_fs_object);
    }
    # If we ran into something that is not a a directory, just transer it now.
    # We shouldn't have files inside of the source directory but we need to handle them just in case
    else {
      $each_fs_object =~ s|^\Q$source/\E||;
      
      # Do the rsync
      $rsync_obj->exec({
        src => "$source/$each_fs_object",
        dest => "$dest/",
      });
      
      # Was the rsync a success?
      my $status = $rsync_obj->status;
      
      if (($status != 0) and ($status != 24)) { # 24 == vanished source files
        my $ref_to_errors = $rsync_obj->err;
        
        # Skip errors due to quota being exceeded.
        unless (grep(m/Disk quota exceeded/, @$ref_to_errors)) {
          log_error("Error '$status' during transfer: '$source/$each_fs_object' => '$dest/'", "NOC-NETCOOL-TICKET");
          foreach my $error_line (@$ref_to_errors) {
            log_error($error_line);
          }
        }
      }
    }
    
  }
  
  $run_stats{"Total groups"} = scalar(@group_dirs);
  $run_stats{"Groups to go"} = $run_stats{"Total groups"};
  print "Found run_stats{'Total groups'} group directories: @group_dirs\n" if ($verbose);
  
  # Loop through each group dir to work on the user dirs inside of it
  for my $group_dir (@group_dirs) {

    $run_stats{"Current group start epoch"} = time();
    $run_stats{"Current group start"} = scalar(localtime(time));
    $run_stats{"Current group"} = scalar($group_dir);
    $run_stats{"Groups to go"}--;
    print "Working on group directory '$group_dir': ", scalar(localtime(time)), "\n" if ($verbose);
        
    # Create an array of each user dir in the current group dir
    my @user_dirs;
    for my $each_fs_object (glob("$source/$group_dir/*")) {

      if (-d $each_fs_object) {
        $each_fs_object =~ s|^\Q$source/$group_dir/\E||;
        push(@user_dirs, $each_fs_object);
      }
      # If we ran into something that is not a a directory, just transer it now.
      # We shouldn't have files inside of a group directory but we need to handle them just in case
      else {
        $each_fs_object =~ s|^\Q$source/$group_dir/\E||;
        
        # Do the rsync
        $rsync_obj->exec({
          src => "$source/$group_dir/$each_fs_object",
          dest => "$dest/$group_dir/",
        });
        
        # Was the rsync a success?
        my $status = $rsync_obj->status;
        
        if (($status != 0) and ($status != 24)) { # 24 == vanished source files
          my $ref_to_errors = $rsync_obj->err;
        
          # Skip errors due to quota being exceeded.
          unless (grep(m/Disk quota exceeded/, @$ref_to_errors)) {
            log_error("Error '$status' during transfer: '$source/$group_dir/$each_fs_object' => '$dest/$group_dir/'", "NOC-NETCOOL-TICKET");
            foreach my $error_line (@$ref_to_errors) {
              log_error($error_line);
            }
          }
        }
      }

    }

    $run_stats{"Users in current group"} = scalar(@user_dirs);
    $run_stats{"Users in current group to go"} = $run_stats{"Users in current group"};
    print "Found $run_stats{'Users in current group'} user directories: @user_dirs\n" if ($verbose);
    
    for my $user_dir (@user_dirs) {

      $run_stats{"Current user start epoch"} = time();
      $run_stats{"Current user start"} = scalar(localtime(time));
      $run_stats{"Current user"} = scalar($user_dir);
      $run_stats{"Users in current group to go"}--;
      print "Working on user directory '$group_dir/$user_dir': ", scalar(localtime(time)), "\n" if ($verbose);
      
      # Do the rsync
      $rsync_obj->exec({
        src => "$source/$group_dir/$user_dir",
        dest => "$dest/$group_dir/",
      });
      
      # Was the rsync a success?
      my $status = $rsync_obj->status;
      
      if (($status != 0) and ($status != 24)) { # 24 == vanished source files
        my $ref_to_errors = $rsync_obj->err;
        
        # Skip errors due to quota being exceeded.
        unless (grep(m/Disk quota exceeded/, @$ref_to_errors)) {
          log_error("Error '$status' during transfer: '$source/$group_dir/$user_dir' => '$dest/$group_dir/'", "NOC-NETCOOL-TICKET");
          foreach my $error_line (@$ref_to_errors) {
            log_error($error_line);
          }
        }
      }
      else {
        my $time = scalar(localtime(time));
        log_info("Success: '$source/$group_dir/$user_dir' => '$dest/$group_dir/'");
      }
      
      print "User '$user_dir' took '", time() - $run_stats{"Current user start epoch"}, "' seconds.\n";
      
    }

    print "Group '$group_dir' took '", time() - $run_stats{"Current group start epoch"}, "' seconds.\n";
    
  }
  
}


# Get the running daemon's PID
sub get_pid {
  # In a scalar context returns the running daemon's PID and undef on error
  # Usage: get_pid()

  my $PIDFILE;
  unless (open($PIDFILE, "<", "$pidfile")) {
    log_error("Unable to open PID file '$pidfile': $!");
    return;
  }

  my $daemon_pid = <$PIDFILE>;
  chomp($daemon_pid);
  close $PIDFILE;

  if ($daemon_pid) {
    return $daemon_pid;
  }
  else {
    log_error("Unable to determine the data_sync daemon's PID.");
    return;
  }
}


# Start the daemon
sub daemon_start {
  # Exits on error, returns 1 on success.
  # Usage: daemon_start()

  # Are we being ran as root?
  unless ($> == 0) {
    log_error("Must be ran as root.  Your EUID is '$>'");
    die;
  }

  # Check/create the lock


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
    
    # Send STDOUT and STDERR to the log from now on
    unless (open(STDOUT, ">>", $log_file)) {
      log_error("Unable to open log file '$log_file'.");
      die;
    }
    open STDERR, '>&STDOUT';
    
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

  # Start the rsync
  $run_stats{"Run"} = 0;
  while (1) {
    $run_stats{"Run"}++;
    $run_stats{"Run start epoch"} = time();
    $run_stats{"Run start"} = scalar(localtime(time));
    $run_stats{"Status"} = "Running";
    my $time = scalar(localtime(time));
    log_info("Starting run number '$run_stats{'Run'}'");
    
    do_stuff;
    
    $run_stats{"Last run length in seconds"} = time() - $run_stats{"Run start epoch"};
    print "Total time for this run: $run_stats{'Last run length in seconds'} seconds.\n";
    
    delete $run_stats{"Current group"};
    delete $run_stats{"Current group start"};
    delete $run_stats{"Current group start epoch"};
    delete $run_stats{"Current user"};
    delete $run_stats{"Current user start"};
    delete $run_stats{"Current user start epoch"};
    delete $run_stats{"Groups to go"};
    delete $run_stats{"Users in current group"};
    delete $run_stats{"Users in current group to go"};
    delete $run_stats{"Run start"};
    delete $run_stats{"Run start epoch"};
    
    # Has it been 24 hours since we started a run?
    if ($run_stats{"Last run length in seconds"} >= 86400) {
      log_info("Last run took over 24 hours, starting next run now.");
    }
    else {
      my $run_sleep_second = 86400 - $run_stats{"Last run length in seconds"};
      my $sleep_start_datetime = scalar(localtime(time));
      my $waketime_epoch = $run_sleep_second + time();
      my $waketime_datetime = scalar(localtime($waketime_epoch));

      log_info("Waiting '$run_sleep_second' seconds until starting the next run (sleep started at $sleep_start_datetime).");
      $run_stats{"Status"} = "Sleeping '$run_sleep_second' seconds before next run (will wake up at $waketime_datetime)";

      # Sleep.  If we wake with sleep time left, go back to sleep.
      my $sleep_end_time = time() + $run_sleep_second;
      
      until(time() >= $sleep_end_time) {
        sleep(600);
      }
    }
  }
}

# Check that the daemon is running and print the status if it is
sub daemon_status {
  # In a scalar context returns undef on a stale pid file, 
  # the actual PID if the daemon is running, 0 if it is not running
  # If called with a true arguement, the current status will be printed as well
  # Usage: daemon_status($do_print)
  
  my $do_print = shift;

  # Does the PID file exist?
  unless (-f "$pidfile") {
    print "Stopped or PID file not found.\n";
    return 0;
  }

  my $daemon_pid = get_pid();

  # Is the daemon still running?
  unless (kill(0, $daemon_pid)) {
    log_error("No such process '$daemon_pid', stale pid file.");
    return;
  }
  
 
  if ($do_print) {

    # Send a USR1 to the daemon process to write its status to the file
    kill("USR1", $daemon_pid);
  
    # Wait up to 10 seconds for the daemon to write out its status
    for (my $waited_second = 0; $waited_second <= 10; $waited_second++) {
      if (-f $status_file) {
        last;
      }
      else {
        sleep 1;
      }
    }
    
    unless (-f $status_file) {
      log_error("Timeout while waiting for the daemon to write out it status to '$status_file'.");
      return $daemon_pid;
    }
    
    my $STATUS_FILE;
    unless (open($STATUS_FILE, "<", $status_file)) {
      log_error("Couldn't open status file '$status_file' for reading: $!");
      return $daemon_pid;
    }
    
    print <$STATUS_FILE>;

    close $STATUS_FILE;
    
    unless (unlink($status_file)) {
      log_error("Unable to remove status file '$status_file'");
    }
  }

  return $daemon_pid;

}

# Stop the daemon
sub daemon_stop {
  # In a scalar context returns undef error, true on success
  # Usage: daemon_stop()

  # Is the daemon still running?
  unless (daemon_status()) {
    return;
  }

  my $daemon_pid = get_pid();

  # Is the PID the daemon's process?
  my $CMDLINE_FILE;
  unless (open($CMDLINE_FILE, "<", "/proc/$daemon_pid/cmdline")) {
    log_error("Unable to open proc file for PID '$daemon_pid'");
    log_error("Unable to determine if PID '$daemon_pid' is the data_sync daemon, not killing it.");
    return;
  }

  my $daemon_cmdline = <$CMDLINE_FILE>;
  close $CMDLINE_FILE;

  unless ($daemon_cmdline =~ m/perl\0*\Q$0\E/) {
    log_error("PID '$daemon_pid' does not appear to be the data_sync daemon, not killing it.  Stale PID file.");
    return;
  }

  # Send a SIGTERM to the daemon's process
  print "Signaling '$daemon_pid' to halt and exit...\n" if ($verbose);
  unless (kill(15, $daemon_pid)) {
    log_error("Unable to send SIGINT to PID '$daemon_pid': $!");
    return;
  }

  # Is the daemon gone?
  my $time = 0;
  while (kill(0, $daemon_pid)) {

    if ($time > 4) {
      log_error("Unable to stop daemonized data_sync with PID '$daemon_pid'");
      return;
    }

    print "Waiting...\n" if ($verbose);
    sleep 1;
    $time++;

  }

  print "Successfully stopped daemon data_sync with PID '$daemon_pid'\n";

}


# Exit when receiving the appropriate signal
sub exit_on_signal {
  # Always exists without returning
  # Usage: exit_on_signal()
  
  print "Caught signal, exiting\n";

  # Don't remove our files unless we are the daemon
  unless ($$ == get_pid()) {
    exit;
  }
  
  unless (unlink($pidfile)) {
    log_error("Unable to remove '$pidfile'.");
  }
  
  exit;
}


# Handle the USR1 signal by printing our status to the $status_file
sub print_status_on_signal {
  # In a scalar context, returns undef on error otherwise returns 1
  # Usage: print_status()
  
  # We print to a temporary status file then move it to the real file name when we are done
  # This prevents a race condition where the process reading from the file reads it when we were
  # only half done with writing our status
  
  my $STATUS_FILE;
  unless (open($STATUS_FILE, "+>", ${status_file}.$$)) {
    log_error("Unable to open status file '${status_file}.$$' for writing: $!");
    return;
  }
  
  print $STATUS_FILE "\n";
  for my $stat (sort(keys(%run_stats))){
    print $STATUS_FILE "$stat: $run_stats{$stat}\n";
  }
  print $STATUS_FILE "\n";
  
  close $STATUS_FILE;
  
  unless (rename(${status_file}.$$, $status_file)) {
    log_error("Unable to rename status file '${status_file}.$$' --> '$status_file': $!");
    return;
  }
  
  return 1;

}


# Signals we will trap
$SIG{'USR1'} = 'print_status_on_signal';
$SIG{'TERM'} = 'exit_on_signal';
$SIG{'INT'} = 'exit_on_signal';


# How were we called?
if ((!$ARGV[0]) or ($ARGV[1])) {
  print "Invalid usage.  See -h for help.\n";
  exit 1;
}

elsif ($ARGV[0] eq "start") {
  daemon_start;
}

elsif ($ARGV[0] eq "stop") {
  if (daemon_stop()) {
    exit 0;
  }
  else {
    exit 1;
  }
}

elsif ($ARGV[0] eq "status") {
  my $status = daemon_status("1");

  if (!defined($status)) {
    exit 1;
  }
  elsif ($status == 0) {
    exit 3;
  }
  else {
    print "Daemon 'data_sync' is running with PID '$status'.\n";
    exit;
  }
}

else {
  print "Invalid usage.  See -h for help.\n";
  exit 1;
}

closelog;