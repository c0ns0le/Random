#!/usr/bin/env perl
use strict;
use warnings;
# Description: Find orphaned Mailman lists and Postini aliases
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.1
# Last change: Fixed the regex for the orphaned alias

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

# To get the Mailman admins:
# /usr/local/mailman/bin/list_admins --all | sed 's/,//' | awk '{print "addalias jwtest@pitt.edu, "$2"@list.pitt.edu"}'
# To get the Postini aliases:
# sed 's/"//g' cs.pitt.edu.dump | nawk '/@list.pitt.edu$/ && !/-subscribe/ && !/-unsub/ && !/-admin/ && !/-bounces/ && !/-confirm/ && !/-join/ && !/-leave/ && !/-owner/ && !/-request/ {print "addalias jwtest@pitt.edu, "$1"@cs.pitt.edu"}'
# sed 's/"//g' math.pitt.edu.dump | nawk '/@list.pitt.edu$/ && !/-subscribe/ && !/-unsub/ && !/-admin/ && !/-bounces/ && !/-confirm/ && !/-join/ && !/-leave/ && !/-owner/ && !/-request/ {print "addalias jwtest@pitt.edu, "$1"@math.pitt.edu"}'
# sed 's/"//g' isp.pitt.edu.dump | nawk '/@list.pitt.edu$/ && !/-subscribe/ && !/-unsub/ && !/-admin/ && !/-bounces/ && !/-confirm/ && !/-join/ && !/-leave/ && !/-owner/ && !/-request/ {print "addalias jwtest@pitt.edu, "$1"@isp.pitt.edu"}'
# sed 's/"//g' sis.pitt.edu.dump | nawk '/@list.pitt.edu$/ && !/-subscribe/ && !/-unsub/ && !/-admin/ && !/-bounces/ && !/-confirm/ && !/-join/ && !/-leave/ && !/-owner/ && !/-request/ {print "addalias jwtest@pitt.edu, "$1"@sis.pitt.edu"}'
# sed 's/"//g' phyast.pitt.edu.dump | nawk '/@list.pitt.edu$/ && !/-subscribe/ && !/-unsub/ && !/-admin/ && !/-bounces/ && !/-confirm/ && !/-join/ && !/-leave/ && !/-owner/ && !/-request/ {print "addalias jwtest@pitt.edu, "$1"@phyast.pitt.edu"}'
# sed 's/"//g' pharmacy.pitt.edu.dump | nawk '/@list.pitt.edu$/ && !/-subscribe/ && !/-unsub/ && !/-admin/ && !/-bounces/ && !/-confirm/ && !/-join/ && !/-leave/ && !/-owner/ && !/-request/ {print "addalias jwtest@pitt.edu, "$1"@pharmacy.pitt.edu"}'
# awk '{print $12","$15}' aliases-2012-7-17/good.txt

use Getopt::Long;
Getopt::Long::Configure("bundling");
use Sys::Syslog qw(:DEFAULT setlogsock);
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;

my $passwd_update_file = "/usr/local/etc/mailman_orphans/passwd_update";
my $list_owners_file = "/usr/local/etc/mailman_orphans/list_owners.txt";
my $postini_aliases_file = "/usr/local/etc/mailman_orphans/postini_aliases.csv";
my $verbose = 0;

GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \$verbose,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Check if a Postini alias exists.\n";
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
  print STDERR "! $_[0]\n";
  if ($_[1]) {
    syslog("LOG_ERR", "$_[1]: $_[0] -- $0.");
  }
  else {
    syslog("LOG_ERR", "$_[0] -- $0.");
  }
  return;
}

# Log a message to syslog and STDOUT.  Tag for Netcool alerts if asked to.
sub log_info {
  # Always returns undef.
  # Usage: log_info("Some log text", "syslog tag")
  # Syslog tag can be anything but NOC-NETCOOL-ALERT and NOC-NETCOOL-TICKET are for Netcool alerts.
  print STDOUT "$_[0]\n";
  if ($_[1]) {
    syslog("LOG_INFO", "$_[1]: $_[0] -- $0.");
  }
  else {
    syslog("LOG_INFO", "$_[0] -- $0.");
  }
  return;
}

#
# Create a list of terminated accounts
#

# Open the passwd update file and read it into an array
my $PASSWD_UPDATE_FILE;
unless (open($PASSWD_UPDATE_FILE, "+<", $passwd_update_file)) {
  log_error("Failed to open file '$passwd_update_file'", "NOC-NETCOOL-ALERT");
  die;
}
my @passwd_update_file = <$PASSWD_UPDATE_FILE>;


# Create an array of each terminated account
print "Getting list of terminated users.\n" if ($verbose);
my @terminated_users;
for my $each_line (@passwd_update_file) {
  chomp $each_line;

  if ($each_line =~ m/^modify:t/) {
    my $user = (split(m/:/, $each_line))[2];
    print "Found terminated user: $user\n" if ($verbose);

    # See if the user was already unterminated, skip them if so
    if (grep(m/^modify:a:\Q$user\E/, @passwd_update_file)) {
      print "Skipping user '$user', terminated and unterminated in the same run.\n" if ($verbose);
      next;
    }
    
    push (@terminated_users, $user);
  }

}

if (!$terminated_users[0]) {
  log_info("No terminated users found.");
  exit 0;
}



#
# Check if a Mailman list is orphaned (owner is gone)
#

# Open the list owner file and read it into an array
my $LIST_OWNERS_FILE;
unless (open($LIST_OWNERS_FILE, "<", $list_owners_file)) {
  log_error("Failed to open file '$list_owners_file'", "NOC-NETCOOL-ALERT");
  die;
}


# Loop through each list see if an owner is gone
# WARNING: Mailman owners are emails, not users.  We can't tell which account each email maps to.
# This means the code below may give false results since we can't check non-pitt email addresses and
# we assume the email of a terminated account would be user@ instead of alias@ (such as jeff.white@).
print "Getting list of lists and their owners.\n" if ($verbose);
my $num_list_orphans = 0;
for my $each_line (<$LIST_OWNERS_FILE>) {
  chomp $each_line;

  # Get the list name from the line
  my $list_name = (split(m/\s+/, $each_line))[1];
  $list_name =~ s/,//;

  # Get the list owners from the line
  my $list_owner = $each_line;
  $list_owner =~ s/^.*Owners: //;
  $list_owner =~ s/\s+//;

#   print "List: $list_name\n";
#   print "Owners: $list_owner\n";

  for my $each_terminated_user (@terminated_users) {
    # If 'user@' for each terminated user exists as an admin of a list
    # and there's no other admin (no , character) then assume the terminated
    # user is the only admin of the list.
    if (($list_owner =~ m/\Q$each_terminated_user\E@/) and ($list_owner !~ m/,/)) {
      print "Found orhpaned list: $list_name => $list_owner\n";
      $num_list_orphans++;
    }
  }
  
}
close $LIST_OWNERS_FILE;



#
# Check if a Postini alias is orphaned (owner is gone)
#

# Open the Postini alias database and read it into a hash
print "Reading Postini alias database.\n" if ($verbose);
my $POSTINI_ALIASES_FILE;
unless (open($POSTINI_ALIASES_FILE, "<", $postini_aliases_file)) {
  log_error("Failed to open file '$postini_aliases_file'", "NOC-NETCOOL-ALERT");
  die;
}

# Loop through the Postini alias database and check each owner
print "Checking for orphaned Postini aliases.\n" if ($verbose);
my $num_postini_orphans = 0;
for my $each_line (<$POSTINI_ALIASES_FILE>) {
  chomp $each_line;

  my ($alias, $owner) = split(m/,/, $each_line);

  my $user = $owner;
  $user =~ s/@.*$//;

  if (grep(m/^\Q$user\E$/, @terminated_users)) {
    print "Found orphaned alias: $alias => $owner\n";
    $num_postini_orphans++;
  }

}
close $POSTINI_ALIASES_FILE;


# Truncate the passwd_update file
# There's a race condition here as it could have been updated as we were working but....whatever, I don't care
truncate($PASSWD_UPDATE_FILE, 0);
close $PASSWD_UPDATE_FILE;

#
# All done, print our final output.
#

print "Terminated users: ", scalar(@terminated_users), "\n";
print "Mailman Postini alias orphans: $num_postini_orphans\n";
print "Mailman list orphans: $num_list_orphans\n";