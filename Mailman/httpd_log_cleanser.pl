#!/usr/bin/perl
# Description: Remove passwords from query strings of Mailman URLs
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

use strict;
use warnings;
use Getopt::Long;
use IO::Handle;


my $log_file = "/var/log/httpd/ssl_access_log";
$| = 1;



GetOptions('h|help' => \my $helpopt,
          ) || die "Incorrect usage, use -h for help.\n";


if ($helpopt) {
  print "Remove passwords from query strings of Mailman URLs\n";
  print "-h | --help : Show this help\n";
  exit;
}



my $LOG_FILE;
unless (open($LOG_FILE, "+>>", $log_file)) {
    die "Unable to open/create log file: $!";
}
$LOG_FILE->autoflush(1);



while (! eof(STDIN)) {
    defined( my $line = <STDIN> ) or die "readline failed: $!";
    
    $line =~ s/&password=[^&^\s]+/&password=REMOVED/ig;
    
    print $LOG_FILE "$line";
}