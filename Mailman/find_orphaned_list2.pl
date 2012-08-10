#!/usr/bin/env perl
use strict;
use warnings;
# Description: Find orphaned Mailman lists and Postini aliases
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version (see find_orphaned_list.pl for an earlier version)

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

# To get the Mailman admins:
# /usr/local/mailman/bin/list_admins --all | sed 's/,//' | awk '{print "addalias jwtest@pitt.edu, "$2"@list.pitt.edu"}'
#
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

my $passwd_file = "/usr/local/etc/mailman_orphans/passwd";
my $postini_aliases_file = "/usr/local/etc/mailman_orphans/postini_aliases.csv";
my $verbose = 0;

GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \$verbose,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Find orphaned Mailman lists and Postini aliases.\n";
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
#     syslog("LOG_ERR", "$_[1]: $_[0] -- $0.");
  }
  else {
#     syslog("LOG_ERR", "$_[0] -- $0.");
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
# Create a hash of active usernames
#
my $PASSWD_FILE;
unless (open($PASSWD_FILE, "<", $passwd_file)) {
  log_error("Failed to open file '$passwd_file'", "NOC-NETCOOL-ALERT");
  die;
}

my %active_users = map {
  my $user = (split(m/:/, $_))[0];
  $user => "1";
} <$PASSWD_FILE>;

close $PASSWD_FILE;

print "Found '", scalar(keys(%active_users)), "' active users.\n" if ($verbose);


#
# Find non-existant list owners and fully orphaned lists
#

# Loop through each list see if an owner is gone
# WARNING: Mailman owners are emails, not users.  We can't tell which account each email address maps to.
# This means the code below may give false results since we can't check non-pitt email addresses and
# we assume the email of a terminated account would be user@ instead of alias@ (such as jeff.white@).

print "Getting list of lists and their owners.\n" if ($verbose);
my $num_list_orphans = 0;
my $num_missing_owners_total = 0;

for my $each_line (`/usr/local/mailman/bin/list_admins --all`) {
  chomp $each_line;
  my $num_missing_owners = 0;

  # Get the list name from the line
  my $list_name = (split(m/\s+/, $each_line))[1];
  $list_name =~ s/,//g; # Remove commas

  # Get the list owners from the line
  my $list_owners = $each_line;
  $list_owners =~ s/^.*Owners: //; # Strip out the beginning of the line
  $list_owners =~ s/\s+//g; # Remove whitespace
  $list_owners = lc($list_owners); # Force to lowercase
  my @owners = split(m/,/, $list_owners);

  print "List: $list_name\n" if ($verbose >= 2);
  print "Num owners: ", scalar(@owners), "\n" if ($verbose >= 2);
  print "Owners: @owners\n" if ($verbose >= 2);

  # Now we can find the terminated owners...
  for my $each_owner (@owners) {

    # Skip non-pitt email address
    next unless ($each_owner =~ m/\@[A-Za-z0-9._%+-]*pitt\.edu/i);

    # Get the raw username out of the address (see the warning above)
    my $user = $each_owner;
    $user =~ s/\@.*$//;

    # Is the user active?
    unless ($active_users{$user}) {
      print "Non-existant owner: $each_owner => $list_name\n"; 
      $num_missing_owners++;
      $num_missing_owners_total++;
    }

    # Is the list now fully orphaned?
    if ($num_missing_owners == scalar(@owners)) {
      print "Orphaned list: $list_name\n";
      $num_list_orphans++;
    }

  }

}


#
# Check if a Postini alias is orphaned
#

# Open the Postini alias database
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

  # Get the raw username out of the address
  my $user = $owner;
  $user =~ s/@.*$//;

  unless ($active_users{$user}) {
    print "Orphaned alias: $alias => $owner\n";
    $num_postini_orphans++;
  }

}
close $POSTINI_ALIASES_FILE;


#
# All done, print our final output.
#

print "\nNon-existant owners: $num_missing_owners_total\n";
print "Orphaned lists: $num_list_orphans\n";
print "Orphaned mail aliases: $num_postini_orphans\n";