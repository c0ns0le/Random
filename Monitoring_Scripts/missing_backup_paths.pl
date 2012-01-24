#!/usr/bin/perl
#Description: Perl script to check for directories which are not in a backup policy.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.3 - 2012-01-24 - Fixed the syslog for NetCool's parsing. - Jeff White
# 0.2 - 2012-01-23 - Re-write so the script gets the existing included dirs direclty from NetBackup. - Jeff White
# 0.1 - 2012-01-23 - Initial version. - Jeff White
#
#####

use warnings; #Print warnings
use strict; #Enforce 'good' programming rules
use Sys::Syslog;

my $dirs_included_in_a_policy = "";
my @policy_names = ("Frank-Data-SAM-P","Frank-Data-User1-P","Frank-Data-User2-P");

foreach my $each_policy_name (@policy_names) {
  open (POLICYDETAILS, "/usr/openv/netbackup/bin/admincmd/bppllist $each_policy_name -l |") || die "Failed to run bppllist for policy name $each_policy_name: $!";
  while (<POLICYDETAILS>) {
    if ("$_" =~ m/^INCLUDE/ ) {
      my @include_dir = split(/ /, $_, 2);
      $dirs_included_in_a_policy = "$dirs_included_in_a_policy" . "$include_dir[1]";
    }
  }
  close POLICYDETAILS;
}

my $num_missing_dirs = 0;
foreach my $each_local_dir (glob("/data/home-login0/*")) {
  if ($dirs_included_in_a_policy !~ m/($each_local_dir)/) {
    print "Directory missing from backup policy: $each_local_dir\n";
    $num_missing_dirs++
  }
}

if ($num_missing_dirs > 0) {
  print "Missing $num_missing_dirs user directories.\n"; 
  syslog("LOG_ERR", "NOC-NETCOOL-TICKET: $num_missing_dirs user directories are not in a backup policy -- $0.");
}