#!/usr/bin/perl
use strict;
use warnings;
# Description: Creates a new global /etc/passwd, /etc/shadow, and /etc/group on GNU+Linux (tested on RHEL)
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
use Sys::Syslog qw( :DEFAULT setlogsock);
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use IO::Handle;

my $run_log = "/var/log/passwd_builder.log";
my $verbose = 0;
my @skip_users = qw(root bin daemon adm lp sync shutdown halt mail uucp operator games gopher ftp nobody dbus vcsa rpc \
abrt saslauth postfix qpidd haldaemon rpcuser nfsnobody ntp sshd tcpdump oprofile);
my @skip_groups = qw(root bin daemon sys adm tty disk lp mem kmem wheel mail uucp man games gopher video dip ftp lock \
audio nobody users dbus utmp utempter floppy vcsa rpc abrt cdrom tape dialout qpidd saslauth postdrop postfix haldaemon \
rpcuser nfsnobody ntp stapdev stapusr sshd cgred tcpdump screen oprofile slocate);
my ($RUN_LOG, $GLOBAL_PASSWD, $LOCAL_PASSWD, $GLOBAL_GROUP, $LOCAL_GROUP);

GetOptions('h|help' => \my $helpopt,
           'p|password-file=s' => \my $ldap_password_file,
           'v|verbose+' => \$verbose,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Creates a new global /etc/passwd, /etc/shadow, and /etc/group on GNU+Linux (tested on RHEL).\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity\n";
  exit;
}

$| = 1;

# Log an error to syslog and STDERR.  Tag for Netcool alerts if asked to.
sub log_error {
  # Always returns undef.
  # Usage: log_error("Some error text", "syslog tag")
  # Syslog tag can be anything but NOC-NETCOOL-ALERT and NOC-NETCOOL-TICKET are for Netcool alerts.
  print STDERR "! $_[0]\n";
  if ($RUN_LOG) {
    print $RUN_LOG "! $_[0]\n";
  }
  if ($_[1]) {
    syslog("LOG_ERR", "$_[1]: $_[0] -- $0.");
  }
  else {
    syslog("LOG_ERR", "$_[0] -- $0.");
  }
  return;
}

sub log_info {
  # Always returns undef.
  # Usage: log_info("Some log text", "syslog tag")
  # Syslog tag can be anything but NOC-NETCOOL-ALERT and NOC-NETCOOL-TICKET are for Netcool alerts.
  print STDOUT "$_[0]\n";
  if ($RUN_LOG) {
    print $RUN_LOG "$_[0]\n";
  }
  if ($_[1]) {
    syslog("LOG_INFO", "$_[1]: $_[0] -- $0.");
  }
  else {
    syslog("LOG_INFO", "$_[0] -- $0.");
  }
  return;
}

# Prepare for syslog()
setlogsock("unix");
openlog($0, "nonul,pid", "user") or die "Failed to open syslog connection.\n";

# Open the files we will need
if (!open($RUN_LOG, "+>>", "$run_log")) {
  log_error("Failed to open run log.", "NOC-NETCOOL-TICKET");
  die;
}
if (!open($GLOBAL_PASSWD, "<", "/afs/pitt.edu/common/etc/passwd.global")) {
  log_error("Failed to open global password file from AFS.", "NOC-NETCOOL-TICKET");
  die;
}
if (!open($LOCAL_PASSWD, "<", "/etc/passwd")) {
  log_error("Failed to open local password file /etc/passwd.", "NOC-NETCOOL-TICKET");
  die;
}
if (!open($GLOBAL_GROUP, "<", "/afs/pitt.edu/common/etc/group.global")) {
  log_error("Failed to open global group file from AFS.", "NOC-NETCOOL-TICKET");
  die;
}
if (!open($LOCAL_GROUP, "<", "/etc/group")) {
  log_error("Failed to open local group file /etc/group.", "NOC-NETCOOL-TICKET");
  die;
}
# Flush writes to the run log so we don't lose error messages
$RUN_LOG->autoflush(1);

log_info("Starting run of $0 - $$\n");

# Read the files into memory.  Why?  Because I (jaw171) am too lazy to do this a better way.
my @global_passwd = <$GLOBAL_PASSWD>;
my @local_passwd = <$LOCAL_PASSWD>;
my @global_group = <$GLOBAL_GROUP>;
my @local_group = <$LOCAL_GROUP>;
close $GLOBAL_PASSWD;
close $LOCAL_PASSWD;
close $GLOBAL_GROUP;
close $LOCAL_GROUP;

# Loop through the global group file, add groups which don't exist locally
log_info("Working on adding new groups $0 - $$\n");
for my $each_global_line (@global_group) {
  chomp $each_global_line;
  print "Working on global line: $each_global_line\n" if ($verbose);

  # Split apart the line
  my ($group, $password, $gid, $members) = split(m/:/, $each_global_line);
  if ((!$group) or (!$gid)) {
    log_error("One or more fields are null for group '$group', skipping: $group, $password, $gid, $members");
    next;
  }

  print "Checking for global group: $group\n" if ($verbose);

  # Skip the group if it in @skip_groups (system groups)
  if (grep(m/\Q$group\E/, @skip_groups)) {
    print "Group '$group' found in skip array, skipping.\n" if ($verbose);
    next;
  }

  # Add the group if they are new
  if (!grep(m/^\Q$group\E:/, @local_group)) {
    print "New group found: $group\n";

    # Add the new group
    system("/usr/sbin/groupadd --gid $gid $group >>$run_log 2>&1");
    my $status = $? / 256;
    print "Status: $status\n";

    # Did the call to useradd fail?
    if ($status == 0) {
      print "Successfully added group: $group\n" if ($verbose);
    }
    elsif ($? == -1) {
      log_error("Failed to call /usr/sbin/groupadd for '$group'.", "NOC-NETCOOL-TICKET");
    }
    else {
      log_error("Failed to create group '$group'.  Status '$status', see the run log for details.", "NOC-NETCOOL-TICKET");
      log_error("Failed: $group, $password, $gid, $members");
    }
  }
  else {
    print "Skipping existing group '$group'\n" if ($verbose);
  }
}


# Loop through the local group file, remove groups which don't exist globally
# Global groups haven't changed since 1999 and I wrote this in 2012, I'm not going to bother writing this. - jaw171


# Loop through the global password file, add users which don't exist locally
log_info("Working on adding new users $0 - $$\n");
for my $each_global_line (@global_passwd) {
  chomp $each_global_line;
  print "Working on global line: $each_global_line\n" if ($verbose);

  # Split apart the line
  my ($user, $password, $uid, $gid, $gecos, $home, $shell) = split(m/:/, $each_global_line);
  $gecos = "Unknown" if (!$gecos);
  if ((!$user) or (!$password) or (!$uid) or (!$gid) or (!$gecos) or (!$home) or (!$shell)) {
    log_error("One or more fields are null for user '$user', skipping: $user, $password, $uid, $gid, $gecos, $home, $shell");
    next;
  }

  print "Checking for global user: $user\n" if ($verbose);

  # Skip the user if it in @skip_users (system accounts)
  if (grep(m/\Q$user\E/, @skip_users)) {
    print "User '$user' found in skip array, skipping.\n" if ($verbose);
    next;
  }

  # Add the user if they are new
  if (!grep(m/^\Q$user\E:/, @local_passwd)) {
    print "New user found: $user\n";

    # Add the new user
    system("/usr/sbin/useradd --shell '${shell}' --comment \"${gecos}\" --home '${home}' --gid '${gid}' --uid '${uid}' -M --no-user-group '${user}' >>$run_log 2>&1");
    my $status = $? / 256;
    print "Status: $status\n";

    # Did the call to useradd fail?
    if ($status == 0) {
      print "Successfully added user: $user\n" if ($verbose);
    }
    elsif ($? == -1) {
      log_error("Failed to call /usr/sbin/useradd for '$user'.", "NOC-NETCOOL-TICKET");
    }
    else {
      log_error("Failed to create user '$user'.  Status '$status', see the run log for details.", "NOC-NETCOOL-TICKET");
      log_error("Failed: $user, $password, $uid, $gid, $gecos, $home, $shell");
    }
  }
  else {
    print "Skipping existing user '$user'\n" if ($verbose);
  }
}


# Loop through the local password file, remove users which don't exist globally
log_info("Working on removing terminated users locally - $$\n");
for my $each_local_line (@local_passwd) {
  chomp $each_local_line;
  print "Working on local line: $each_local_line\n" if ($verbose);

  # Split apart the line
  my ($user, $password, $uid, $gid, $gecos, $home, $shell) = split(m/:/, $each_local_line);

  print "Checking for local user: $user\n" if ($verbose);

  # Skip the user if it in @skip_users (system accounts)
  if (grep(m/\Q$user\E/, @skip_users)) {
    print "User '$user' found in skip array, skipping.\n" if ($verbose);
    next;
  }

  # Delete the user if they no longer exist globally
  if (!grep(m/^\Q$user\E:/, @global_passwd)) {
    print "Terminated user found: $user\n";

    # Remove the old user
    system("/usr/sbin/userdel $user >>$run_log 2>&1");
    my $status = $? / 256;
    print "Status: $status\n";

    # Did the call to useradd fail?
    if ($status == 0) {
      print "Successfully removed user: $user\n" if ($verbose);
    }
    elsif ($? == -1) {
      log_error("Failed to call /usr/sbin/userdel for '$user'.", "NOC-NETCOOL-TICKET");
    }
    else {
      log_error("Failed to remove user '$user'.  Status '$status', see the run log for details.", "NOC-NETCOOL-TICKET");
    }
  }
  else {
    print "Skipping still existing user '$user'\n" if ($verbose);
  }
}

log_info("Completed run of $0 - $$\n");
closelog;