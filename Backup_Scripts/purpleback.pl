#!/usr/bin/env perl
use strict;
use warnings;
# Description: Custom backup software for my own network
# Written by: Jeff White (jwhite530@gmail.com)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


use Getopt::Long;
Getopt::Long::Configure("bundling");
use POSIX;
use File::Rsync;
use File::Path qw(make_path);
use File::Basename;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use Net::OpenSSH;
use Fcntl ':flock'; # import LOCK_* constants
use MIME::Lite;


# Get our start date and time
my $start_epoch = time;
my ($start_year, $start_month, $start_day, $start_hour, $start_minute, $start_second) = (localtime(time))[5,4,3,2,1,0];
$start_year = $start_year + 1900;
$start_month = $start_month + 1;
my $start_date = "$start_year-$start_month-$start_day";
my $start_time = "$start_hour:$start_minute:$start_second";

my $verbose = 0;
my %transfer_stats;
my $data_transferred_kb = 0;
my $LOG_FILE;

# This will hold all error messages so we can print a summary at the end of each backup run
my %error_messages;

my $log_file = "/var/log/purpleback/purpleback-$$-${start_date}_$start_time.log";
$| = 1;


GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \$verbose,
           'e|email=s' => \my @emails,
           'd|datastore-nodelete' => \my $datastore_no_delete,
           'D|datastore-withdelete' => \my $datastore_with_delete,
           'l|linux-os-no-delete=s' => \my @linux_clients_no_delete,
           'L|linux-os-with-delete=s' => \my @linux_clients_with_delete,
          ) || die "Invalid usage, use -h for help.\n";


if ($helpopt) {
  print "Custom backup software for my (Jeff White) own network.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n";
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity (add more -v for higher verbosity)\n";
  print "-e | --email : List of emails to send the output and log to\n";
  print "-d | --datastore-nodelete : Datastore option without rsync's --delete\n";
  print "-D | --datastore-withdelete : Datastore option with rsync's --delete\n";
  print "-l | --linux-os-no-delete : OS backup of a Linux client without rsync's --delete (requires arguement of a client to back up, short hostname - Can be specified multiple times for multiple clients)\n";
  print "-L | --linux-os-with-delete : OS backup of a Linux client with rsync's --delete (requires arguement of client to back up, short hostname - Can be specified multiple times for multiple clients)\n";
  exit;
}


#
# Subroutine definitions
#


# Handle SIGINT and SIGTERM
sub exit_on_signal {
  # Returns nothing, always exits
  # Usage: Use with %SIG

  log_error("Cancelled or terminated\n");

  final_output();

  exit 1;
}

$SIG{'TERM'} = 'exit_on_signal';
$SIG{'INT'} = 'exit_on_signal';


# Log and print error messages
sub log_error {
  # Always returns undef
  # Does NOT add a newline
  # Usage: log_error("Some log" . "message") # Scalar, unlike print!

  my $log_message;
  unless ($log_message = shift) {
    print STDERR BOLD RED "Improper use of log_error, no log message given\n";
  }

  my $num_errors = keys(%error_messages);
  $error_messages{++$num_errors} = $log_message;
  print $LOG_FILE "$log_message";
  print STDERR BOLD RED "$log_message";

  return;
}


# Log and print informational messages
sub log_info {
  # Always returns undef
  # Does NOT add a newline
  # Usage: log_info("Some log" . "message") # Scalar, unlike print!

  my $log_message;
  unless ($log_message = shift) {
    print STDERR BOLD RED "Improper use of log_info, no log message given\n";
  }

  print $LOG_FILE "$log_message";
  print "$log_message";

  return;
}


# Create an SSH connection object to a given system
sub connect_ssh {
  # Usage: connect_ssh($hostname)
  # Returns a scalar Net::OpenSSH object on success, undef on failure

  # Get the hostname to connect to
  my $hostname;
  unless ($hostname = shift) {
    log_error("Incorrect use of create_ssh_object()\n");
    return;
  }


  # Determine what log level we should be on
  my $ssh_log_level;
  if ($verbose >= 4) {
    $ssh_log_level = "DEBUG3";
  }
  elsif ($verbose == 3) {
    $ssh_log_level = "DEBUG2";
  }
  elsif ($verbose == 2) {
    $ssh_log_level = "DEBUG";
  }
  elsif ($verbose == 1) {
    $ssh_log_level = "VERBOSE";
  }
  else {
    $ssh_log_level = "INFO";
  }


  # Open an ssh connection
  print BOLD BLUE "Opening SSH connection on $hostname\n" if ($verbose);
  my $ssh_object = Net::OpenSSH->new(
    "$hostname",
    user => "backupuser",
    timeout => 60,
    kill_ssh_on_timeout => 1,
    master_opts => [-o => "LogLevel=$ssh_log_level",
                    -o => "PreferredAuthentications=publickey",
                    -o => "StrictHostKeyChecking=no",
                    -l => "backupuser",
                    "-i" => "/home/backupuser/.ssh/id_rsa",
                   ],
  );


  # Check for an SSH error
  if ($ssh_object->error) {
    for my $line ($ssh_object->error) {
      log_error("$line\n");
    }
    return;
  }
  else {
    print BOLD BLUE "Successfully made SSH connection on $hostname\n" if ($verbose);
    return $ssh_object;
  }
}


# Create the transfer/backup statistics
sub rsync_transfer_stats {
  # Returns true on success and updates %transfer_stats hash and $data_transferred_kb
  # Usage: rsync_transfer_stats($rsync_out_ref) # Array reference from $rsync_object->out

  my $rsync_out_ref;
  unless ($rsync_out_ref = shift) {
    log_error("Incorrect usage of rsync_transfer_stats()");
    return;
  }

  # Loop through each line of rsync's output and add it to %transfer_stats
  for my $rsync_line (@$rsync_out_ref) {
    if ($rsync_line =~ m/^Number of files:/) {
      $transfer_stats{"Total number of files"} += (split(m/\s+/, $rsync_line))[3];
    }
    elsif ($rsync_line =~ m/^Number of files transferred:/) {
      $transfer_stats{"Number of files transferred"} += (split(m/\s+/, $rsync_line))[4];
    }
    elsif ($rsync_line =~ m/^Total file size:/) {
      $transfer_stats{"Total file size (GB)"} += sprintf("%.2f", (split(m/\s+/, $rsync_line))[3] / 1024 / 1024 / 1024);
    }
    elsif (($rsync_line =~ m/^Total bytes sent:/) or ($rsync_line =~ m/^Total bytes received:/)) {
      $data_transferred_kb += sprintf("%.2f", (split(m/\s+/, $rsync_line))[3] / 1024);
    }
  }

  return 1;
}


# Generate and print the final output
sub final_output {
  # Returns true on success
  # Usage: final_output();

  # Get our end date and time
  my $end_epoch = time;
  my ($end_year, $end_month, $end_day, $end_hour, $end_minute, $end_second) = (localtime(time))[5,4,3,2,1,0];
  $end_year = $end_year + 1900;
  $end_month = $end_month + 1;
  my $end_date = "$end_year-$end_month-$end_day";
  my $end_time = "$end_hour:$end_minute:$end_second";

  # Build the main summary output
  my @summary_output;
  push(@summary_output, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");

  push(@summary_output, "Server: cyan.jealwh.local\n");
  push(@summary_output, "Script: $0\n");
  push(@summary_output, "Log: $log_file\n");
  push(@summary_output, "Start: $start_date at $start_time\n");
  push(@summary_output, "End: $end_date at $end_time\n");

  # Calculate the run time
  my $runtime_seconds = $end_epoch - $start_epoch;
  my $dur_days = sprintf("%.0f", $runtime_seconds / 86400);
  my $dur_hours = sprintf("%.0f", ($runtime_seconds - ($dur_days * 86400)) / 3600);
  my $dur_min = sprintf("%.0f", (($runtime_seconds - ($dur_days * 86400)) - ($dur_hours * 3600)) / 60);
  my $dur_sec = sprintf("%.0f", (($runtime_seconds - ($dur_days * 86400)) - ($dur_hours * 3600)) - ($dur_min * 60));

#   push(@summary_output, "Duration: $dur_days days, $dur_hours hours, $dur_min minutes, $dur_sec seconds (Total: $runtime_seconds)\n");
  push(@summary_output, "Email(s): @emails\n") if (@emails);
  push(@summary_output, "Option enabled: Datastore without delete (teal.jealwh.local)\n") if ($datastore_no_delete);
  push(@summary_output, "Option enabled: Datastore with delete (teal.jealwh.local)\n") if ($datastore_with_delete);
  push(@summary_output, "Option enabled: Linux OS without delete (@linux_clients_no_delete)\n") if (@linux_clients_no_delete);
  push(@summary_output, "Option enabled: Linux OS with delete (@linux_clients_with_delete)\n") if (@linux_clients_with_delete);
  while (my ($transfer_key, $transfer_value) = each(%transfer_stats)) {
    push(@summary_output, "$transfer_key: $transfer_value\n");
  }
  push(@summary_output, "Data transferred: " . sprintf("%.2f", $data_transferred_kb / 1024 / 1024) . " GB\n");

  # Add the error messages we found if any exist
  if (%error_messages) {
    push(@summary_output, "Errors found:\n\n");

    for my $error_message (values(%error_messages)) {
      push(@summary_output, $error_message);
    }

    push(@summary_output, "\nSee the log for more details and/or increase verbosity with -v\n");
  }
  else {
    push(@summary_output, "\nSuccess!\n\n");
  }

  push(@summary_output, "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n");


  # Print and log the output
  print @summary_output;
  print $LOG_FILE @summary_output;


  # Email the output
  if (@emails){

    my $email_subject;
    if (%error_messages) {
      $email_subject = "Purpleback backup report - Errors found";
    }
    else {
      $email_subject = "Purpleback backup report - Success";
    }

    my $email_message = MIME::Lite->new(
      From => "root\@cyan.jealwh.local",
      To => \@emails,
      Subject => $email_subject,
      Type => "multipart/mixed",
    );

    $email_message->attach(
      Type => "TEXT",
      Data => \@summary_output,
    );

    $email_message->attach(
      Type => "text/plain",
      Path => $log_file,
    );

    $email_message->send;
  }

  return 1;
}


#
# Locking
#
INIT {
  open *{0} or die "What!? $0:$!";

  flock *{0}, LOCK_EX|LOCK_NB or die "$0 is already running, exiting\n";
}


#
# Logging
#

# Create our log directory
unless (-d (fileparse($log_file))[1]) {
  print "Creating log directory '" . (fileparse($log_file))[1], "'\n" if ($verbose);
  mkdir((fileparse($log_file))[1]) or die "Failed to create log directory '" . (fileparse($log_file))[1];
}

# Open the new log
unless (open($LOG_FILE, ">>", $log_file)) {

  die "Failed to open/create log file '$log_file', exiting";
}


#
# Sanity checking
#


# If in datastore mode, ensure things are mounted.
if (($datastore_no_delete) or ($datastore_with_delete)) {
  my $ssh_object_teal;
  if ($ssh_object_teal = (connect_ssh("teal.jealwh.local"))) {

    # Ensure /media/Backup is mounted on teal.jealwh.local
    if ($ssh_object_teal->test("grep" => "-q" => "' /media/Backup '" => "/proc/mounts")) {
      log_error("/media/Backup is not mounted on teal.jealwh.local, disabling datastore backup\n");
      undef $datastore_with_delete;
      undef $datastore_no_delete;
      undef $ssh_object_teal;
    }
    else {
      print BOLD BLUE "/media/Backup mount check on teal.jealwh.local passed\n" if ($verbose);
    }

  }
  else {
    log_error("Failed to create SSH connection to 'teal.jealwh.local' during sanity checking\n");
  }

}


#
# Datastore
#


if (($datastore_no_delete) or ($datastore_with_delete)) {
  log_info("Starting datastore backup\n");

  # Make an SSH connection or bail out
  log_info("Testing connection to teal.jealwh.local for datastore backup\n") if ($verbose);
  if (connect_ssh("teal.jealwh.local")) {

    # What is to be excluded?
    my @exclude_list = qw(
    );

    # Should we enable rsync's --delete?
    my $do_delete = 0;
    if ($datastore_with_delete) {
      log_info("rsync's --delete enabled for datastore backup\n") if ($verbose);
      $do_delete = 1
    }

    # How verbose should rsync be?
    my ($do_debug, $do_verbose);
    $do_verbose = $verbose if ($verbose);
    $do_debug = 1 if ($verbose >= 3);

    # Create the rsync object and set default options
    my $rsync_object = File::Rsync->new({
      "archive" => 1,
      "inplace" => 1,
      "delete" => $do_delete,
      "max-delete" => 50000,
      "partial" => 1,
      "stats" => 1,
      "hard-links" => 1,
      "acls" => 1,
#       "xattrs" => 1,
      "verbose" => $do_verbose,
      "debug" => $do_debug,
      "rsh" => "ssh -o PreferredAuthentications=publickey -l backupuser -i /home/backupuser/.ssh/id_rsa -o StrictHostKeyChecking=no",
      "rsync-path" => "sudo rsync",
    });

    # Do the rsync
    eval {
      $rsync_object->exec({
        "src" => "/media/Data/",
        "dest" => "teal.jealwh.local:/media/Backup/",
        "exclude" => \@exclude_list,
      });
    };

    # Could we even exec the rsync object?
    if (!$rsync_object) {
      log_error("Datastore backup failed, could not create rsync object\n");
      print BOLD RED $@;
    }
    else {
      my $rsync_status = $rsync_object->status;

      if (($rsync_status != 0) and ($rsync_status != 24)) { # 24 == vanished source files
        my $rsync_err_ref = $rsync_object->err;

        log_error("Error '$rsync_status' from rsync during datastore transfer\n");
        log_error("Datastore backup failed\n");
          foreach my $error_line (@$rsync_err_ref) {
            log_error($error_line);
          }
      }
      else {
        log_info("Datastore backup completed successfully\n") if ($verbose);
      }

      # Get the transfer stats
      my $rsync_out_ref = $rsync_object->out;
      if ($rsync_out_ref) {
        rsync_transfer_stats($rsync_out_ref);
        print $LOG_FILE @$rsync_out_ref;
      }

    }

  }
  else {
    log_error("Datastore backup failed, unable to create SSH connection to 'teal.jealwh.local' before backup\n");
  }

}


#
# Linux OS
#


# Back up a Linux OS
sub backup_linux_os {
  # Returns undef on failure, 1 on success
  # If the second arguement is "true" then rsync's --delete will be used
  # Usage: backup_linux_os($client_name) # Back up without rsync's --delete (default)
  # Usage: backup_linux_os($client_name, 1) # Back up with rsync's --delete

  my $linux_client;
  unless ($linux_client = shift) {
    log_error("Incorrect use of backup_linux_os()\n");
    return;
  }
  $linux_client = "${linux_client}.jealwh.local";

  log_info("Starting Linux OS backup of $linux_client\n");

  # Make an SSH connection or bail out
  log_info("Testing connection to $linux_client for Linux OS backup\n") if ($verbose);
  if (connect_ssh($linux_client)) {

    make_path("/media/Data/OS_Backups/$linux_client/OS/") unless (-d "/media/Data/OS_Backups/$linux_client/OS/");

    # What is to be excluded?
    my @exclude_list = qw(
      /proc
      /sys
      /selinux
      /mnt
      /afs
      /tmp
      /dev/shm
      /media
      .gvfs
      .cache
      Cache
      cache
      .truecrypt*
      pub
      mysql
      sql
      tc
      tc2
      /bricks
      /run
    );

    # Should we enable rsync's --delete?
    my $if_delete = shift;
    my $do_delete = 0;
    if ($if_delete) {
      log_info("rsync's --delete enabled for Linux OS backup of $linux_client") if ($verbose);
      $do_delete = 1
    }

    # Create the rsync object and set default options
    my $rsync_object = File::Rsync->new({
      "archive" => 1,
      "inplace" => 1,
      "delete" => $do_delete,
      "max-delete" => 50000,
      "partial" => 1,
      "stats" => 1,
      "hard-links" => 1,
      "acls" => 1,
#       "xattrs" => 1,
      "rsh" => "ssh -o PreferredAuthentications=publickey -l backupuser -i /home/backupuser/.ssh/id_rsa -o StrictHostKeyChecking=no",
      "rsync-path" => "sudo rsync",
    });

    # Do the rsync
    eval {
      $rsync_object->exec({
        "src" => "$linux_client:/",
        "dest" => "/media/Data/OS_Backups/$linux_client/OS/",
        "exclude" => \@exclude_list,
      });
    };

    # Check for failure of the rsync
    if (!$rsync_object) {
      log_error("Linux OS backup of $linux_client failed, could not create rsync object\n");
      print BOLD RED $@;
    }
    else {
      my $rsync_status = $rsync_object->status;

      if (($rsync_status != 0) and ($rsync_status != 24)) { # 24 == vanished source files
        my $rsync_err_ref = $rsync_object->err;

        log_error("Error '$rsync_status' from rsync during transfer for Linux OS backup on $linux_client\n");
          foreach my $error_line (@$rsync_err_ref) {
            log_error($error_line);
          }
      }
      else {
        log_info("Linux OS backup on $linux_client completed successfully\n");
      }

      # Get the transfer stats
      my $rsync_out_ref = $rsync_object->out;
      if ($rsync_out_ref) {
        rsync_transfer_stats($rsync_out_ref);
        print $LOG_FILE @$rsync_out_ref;
      }

    }

  }
  else {
    log_error("Failed to create SSH connection to $linux_client during backup\n");
  }

}


# Loop through each Linux OS client and back it up
if ((@linux_clients_no_delete) or (@linux_clients_with_delete)) {

  for my $linux_client (@linux_clients_no_delete) {
    backup_linux_os($linux_client);
  }

  for my $linux_client (@linux_clients_with_delete) {
    backup_linux_os($linux_client, 1);
  }

}


#
# Display and email final summary
#


final_output();