#!/usr/bin/env perl
use strict;
use warnings;
# Description: Parse multiple passwd files and create a CSV of what users have access to which systems
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


use Getopt::Long;
use Text::CSV;
use Net::LDAPS;
use Term::ReadKey;


GetOptions('h|help' => \my $helpopt,
           'r|text' => \my $text_mode,
          ) || die "Invalid usage, use -h for help.\n";


if ($helpopt) {
  print "Parse multiple passwd files and create a CSV of what users have access to which systems\n";
  print "Usage: $0 /path/to/systems/\n";
  print "\nIn the above example 'systems' would contain a directory with the name of each system \n";
  print "which each in turn contain a file called passwd which is /etc/passwd of that system.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "-h | --help : Show this help\n";
  print "-t | --text : Output human-readable text instead of a CSV\n";
  exit;
}


my $system_dir = $ARGV[0];

unless (($system_dir) and (-d $system_dir)) {
  die "Incorrect use of script, see -h for help\n";
}


# Users to be ignored
my %ignored_users = (
  "nobody" => 1,
  "daemon" => 1,
  "bin" => 1,
  "root" => 1,
  "lp" => 1,
  "uucp" => 1,
  "adm" => 1,
  "sshd" => 1,
  "smmsp" => 1,
  "mail" => 1,
  "sync" => 1,
  "games" => 1,
  "vcsa" => 1,
  "ftp" => 1,
  "ntp" => 1,
  "gopher" => 1,
  "shutdown" => 1,
  "operator" => 1,
  "halt" => 1,
  "rpc" => 1,
  "rpcuser" => 1,
  "nfsnobody" => 1,
  "dbus" => 1,
  "haldaemon" => 1,
  "gdm" => 1,
  "nscd" => 1,
  "sys" => 1,
  "news" => 1,
  "noaccess" => 1,
  "nobody4" => 1,
  "avahi" => 1,
  "mailnull" => 1,
  "pcap" => 1,
  "xfs" => 1,
  "avahi-autoipd" => 1,
  "listen" => 1,
  "nuucp" => 1,
  "apache" => 1,
  "postgres" => 1,
  "svctag" => 1,
  "webservd" => 1,
  "oprofile" => 1,
  "postfix" => 1,
  "mysql" => 1,
  "saslauth" => 1,
  "tcpdump" => 1,
  "abrt" => 1,
  "unknown" => 1,
  "sabayon" => 1,
  "distcache" => 1,
  "ldap" => 1,
  "squid" => 1,
  "webalizer" => 1,
  "qpidd" => 1,
  "applmgr" => 1,
  "tomcat" => 1,
  "pegasus" => 1,
  "nslcd" => 1,
  "named" => 1,
  "uuidd" => 1,
  "hrconv" => 1,
  "drupal" => 1,
  "syslog" => 1,
  "nagios" => 1,
  "ident" => 1,
  "ssmon" => 1,
  "man" => 1,
  "proxy" => 1,
  "www-data" => 1,
  "list" => 1,
  "rpm" => 1,
  "jboss" => 1,
  "cimsrvr" => 1,
  "dovecot" => 1,
  "backup" => 1,
  "klog" => 1,
  "irc" => 1,
  "dhcp" => 1,
  "Debian-exim" => 1,
  "gnats" => 1,
  "pvm" => 1,
  "tomcat6" => 1,
  "netdump" => 1,
  "ssadmin" => 1,
  "ssconfig" => 1,
  "nbar" => 1,
  "luctmp" => 1,
  "smtp" => 1,
  "pmdf" => 1,
  "pmdfuser" => 1,
  "source" => 1,
  "postmast" => 1,
  "asterisk" => 1,
  "tss" => 1,
  "magnascope" => 1,
  "splunk" => 1,
  "spmadmin" => 1,
  "ngenius" => 1,
  "casuser" => 1,
  "clam" => 1,
  "imsp" => 1,
  "cyrus" => 1,
  "veeam" => 1,
  "ganglia" => 1,
  "rrdcached" => 1,
  "ntop" => 1,
  "flowrpt" => 1,
  "galaxy" => 1,
  "accelrys" => 1,
  "clcgenomics" => 1,
  "gold" => 1,
  "hacluster" => 1,
  "rrdcached" => 1,
  "hsqldb" => 1,
  "jabber" => 1,
  "mailman" => 1,
  "cactiuser" => 1,
  "pddb" => 1,
  "ncoadmin" => 1,
  "rostertech" => 1,
);

$| = 1;


chdir($system_dir) or die "Failed to chdir to $system_dir: $!";


# Connect to LDAP (to convert usernames to real names later)
print "Enter the LDAP password: ";
ReadMode('noecho'); # don't echo
chomp(my $ldap_password = <STDIN>);
ReadMode(0); # back to normal

my $ldap_object = Net::LDAPS->new(
  "dept-ldap.pitt.edu",
  port => "636",
  verify => "none",
);

my $bind_mesg = $ldap_object->bind(
  "uid=uls,o=University of Pittsburgh,c=US",
  password => $ldap_password
);

$bind_mesg->code && die "Failed to bind with the LDAP server: " . $bind_mesg->error;
                                 
                                 
# Loop through each system and build a hash with an anon array of the users on the system
my %user_real_name_mapping = (
  "jaw171" => "Jeff White",
);

my %systems_user_list;
for my $system (glob("*")) {

  # Skip things that don't appear to be passwd files
  next unless (-f "$system/passwd");

  
  my $PASSWD_FILE;
  unless (open($PASSWD_FILE, "<", "$system/passwd")) {
    warn "Failed to open passwd file for $system: $!";
    next;
  }
  
  
  # Loop through the passwd files and push the user to the list
  $systems_user_list{$system} = [];
  for my $passwd_line (<$PASSWD_FILE>) {
    chomp $passwd_line;
    
    my $username = (split(m/:/, $passwd_line))[0];
    next unless ($username);
    
    
    # Skip ignored users
    next if ($ignored_users{$username});
    
    # Try to get the user's real name if we haven't done so already
    unless ($user_real_name_mapping{$username}) {
    
      # Do the search
      my $user_search_result = $ldap_object->search(
        base => "o=University of Pittsburgh,c=US",
        scope => "sub",
        timelimit => 30,
        filter => "(uid=$username)",
        attrs => ['cn']
      );
      
      # Get the search results
      my @entries = $user_search_result->entries;
      
      if (@entries) {
        my $real_name = $entries[0]->get_value("cn");
        
        if ($real_name) {
          $user_real_name_mapping{$username} = $real_name;
        }
        else {
          $user_real_name_mapping{$username} = $username;
        }
      }
      else {
        $user_real_name_mapping{$username} = $username;
      }  

    }
    
    push($systems_user_list{$system}, $user_real_name_mapping{$username});
  }
  
  
  close $PASSWD_FILE;
  
}


# Print the final user list for each system
if ($text_mode) {

  for my $system (sort(keys(%systems_user_list))) {
    
    print "\n$system:\n";
    
    my $user_ref = $systems_user_list{$system};
    
    for my $user (@$user_ref) {
      print "$user\n";
    }
    
  }
  
}
else { # CSV

  # Print a header
  for my $system (sort(keys(%systems_user_list))) {
    print "$system,";    
  }
  print "\n";
  
  
  # Loop through each system, pop off a user from the array and print it
  my $no_more_users = 0;
  until ($no_more_users) {
  
    my $did_find_user = 0;
  
    for my $system (sort(keys(%systems_user_list))) {
      my $user_list_ref = $systems_user_list{$system};   
      
      my $user = pop(@$user_list_ref);
      
      if ($user) {
        print "$user,";
        $did_find_user++;
      }
      else {
        print ",";
      }
      
    }

    $no_more_users++ unless ($did_find_user);
    
    print "\n";
  
  }
}