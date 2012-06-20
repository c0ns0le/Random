#!/usr/bin/perl
# Description: Automatically SSH to many systems to run a command or transfer a file.
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use strict;
use warnings;
use Net::OpenSSH;
use Term::ReadKey;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

my $verbose = 0;

Getopt::Long::Configure("bundling");
GetOptions('h|help' => \my $helpopt,
	   'v|verbose+' => \$verbose,
	   't|transfer' => \my $transfer_mode,
	  ) or die "Incorrect usage, use -h for help.\n";

# Did the user ask for help?  Were we called correctly?
if (($helpopt) or (!$ARGV[0])) {
  print "Automatically SSH to many systems to run a command or transfer a file.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 file_with_hostnames\n\n";
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity (More -v means puts SSH in debug mode)\n";
  print "-t | --transfer : Transfer (SCP) mode\n";
  print "\nIn transfer mode if 'Copy remote => local' is selected, this script will\n";
  print "create a directory named for the system it is pulling the file from within\n";
  print "what was given as 'Local file/path'.  So if you gave '/tmp' as the local file/path\n";
  print "and the remote system is 'foo.example.com' then the data will be under /tmp/foo.example.com/.\n";
  exit;
}

# Get the username and password
print "User: ";
chomp(my $user = <STDIN>);
print "Password: ";
ReadMode('noecho'); # don't echo
chomp(my $pass = <STDIN>);
ReadMode(0);        # back to normal

# Are we in command mode or transfer mode?
my ($command, $local_file, $remote_file, $transfer_direction);
if ($transfer_mode) { # Transfer mode...
  print "\nLocal file/path (glob ok): ";
  chomp($local_file = <STDIN>);

  print "Remote file/path (glob ok): ";
  chomp($remote_file = <STDIN>);

  print "1  Copy local => remote\n";
  print "2  Copy remote => local\n";
  print "Select an option: ";
  chomp(my $user_choice = <STDIN>);
  if ($user_choice == 1) {
    $transfer_direction = "toremote";
  }
  elsif ($user_choice == 2) {
    $transfer_direction = "fromremote";
  }
  else {
    die BOLD RED "Invalid selection";
  }
}
else { # Command mode...
  print "\nCommand: ";
  chomp($command = <STDIN>);
}

# Show debug info for SSH connections?
my $ssh_log_level;
if ($verbose ge 4) {
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

while (my $each_system = <>) {
  chomp $each_system;

  # Open an ssh connection
  print BOLD BLUE "Opening SSH connection on $each_system\n" if ($verbose);
  my $ssh = Net::OpenSSH->new(
    "$each_system",
    user => $user,
    password => $pass,
    timeout => 10,
    kill_ssh_on_timeout => 1,
    master_opts => [-o => "LogLevel=$ssh_log_level"],
  );

  # Check for an SSH error
  if ($ssh->error) {
    print BOLD RED "Failed to open SSH connection on $each_system\n";
    next;
  }
  else {
    print BOLD GREEN "Successfully made SSH connection on $each_system\n" if ($verbose);
  }

  if ($transfer_mode) {
    my $scp_result;
    my $scp_quiet = 0 if ($verbose);
    print BOLD BLUE "Transferring file on $each_system\n" if ($verbose);

    if ($transfer_direction eq "toremote") {
      # Transfer the file
      $scp_result = $ssh->scp_put(
	{
	  quiet => $scp_quiet,
	  recursive => 1,
	  glob => 1,
	},
	$local_file,
	$remote_file,
      );
    }
    elsif ($transfer_direction eq "fromremote") {
      # Create a directory for each system.  Without this we would overwrite the local file
      # with every iteration of the loop.
      mkdir($local_file) if (!-d $local_file);
      print BOLD BLUE "Creating local directory for $each_system\n" if ($verbose);
      if ((-d "$local_file/$each_system") or mkdir("$local_file/$each_system")) {
	print BOLD GREEN "Successfully created local directory for $each_system or already exists\n" if ($verbose);
      }
      else {
	print BOLD RED "Failed to create local directory for $each_system\n";
	next;
      }

      # Transfer the file
      $scp_result = $ssh->scp_get(
	{
	  quiet => $scp_quiet,
	  recursive => 1,
	  glob => 1,
	},
	$remote_file,
	"$local_file/$each_system",
      );
    }

    # Did we transfer the file successfully?
    if ($scp_result) {
      print BOLD GREEN "Successfully transferred all files on $each_system\n";
    }
    else {
      print BOLD RED "Failed to transfer one or more files on $each_system\n";
    }
  }
  else {
    # Run a command and check the return status
    print BOLD BLUE "Running command on $each_system\n" if ($verbose);
    if ($ssh->system("$command")) {
      print BOLD GREEN "Successfully ran command on $each_system\n";
    }
    else {
      print BOLD RED "Failed to run command on $each_system\n";
    }
  }

}