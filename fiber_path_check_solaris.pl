#!/usr/bin/env perl
use strict;
use warnings;

# Description: Check for missing fiber paths on Solaris
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





my $luxadm = "/usr/sbin/luxadm";
my %whitelisted_disks = (
    "/dev/rdisk/somediskpath" => 1,
);





GetOptions('h|help' => \my $helpopt,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Check for missing fiber paths on Solaris.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  exit;
}





my $error_found = 0;
for my $line (`$luxadm probe`) {
    chomp $line;
    
    next unless ($line =~ m|\s+Logical Path:(/dev/rdsk/c.*005076801908208A.*)|);
    
    my $disk = $1;

    if ($whitelisted_disks{$disk}) {
        print "$disk : Whitelisted\n";
        
        next;
    }
    
    my $online_paths = grep(m/State\s+ONLINE/, `$luxadm display $disk`);
    
    if ($online_paths == 4) {
        print "$disk : 4\n";
    }
    else {
        print "$disk : $online_paths <--- WARNING!\n";
        
        $error_found++;
    }
}



if ($error_found != 0) {
     system("/usr/bin/logger -p user.err -t NOC-NETCOOL-TICKET 'One of more fiber paths are missing'");
}