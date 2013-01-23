#!/usr/local/perl/bin/perl
# Description: Sync a directory between two systems
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
use Getopt::Long;
use File::Rsync;


my $rsync_delete = 0;
my $source = "/tftpboot/";
my $dest = "tftpsync\@tornado.ns.pitt.edu:/tftpboot/";


GetOptions('h|help' => \my $helpopt,
           'd|delete' => \$rsync_delete,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Sync a directory between two systems\n";
  print "License: GNU General Public License (GPL) v3\n\n";
  print "Usage: $0 [options]\n"; 
  print "-d | --delete : Enable rsync's --delete (default: off)\n";
  print "-h | --help : Show this help\n";
  exit;
}


my $rsync_obj = File::Rsync->new({
  archive => 1,
  inplace => 1,
  del => $rsync_delete,
  rsh => "/usr/local/bin/ssh -o PreferredAuthentications=publickey -i /usr/home/tftpsync/.ssh/id_rsa -o StrictHostKeyChecking=no",
  "rsync-path" => "/usr/bin/sudo /usr/local/rsync/bin/rsync",
});


$rsync_obj->exec({
  src => $source,
  dest => $dest,
});


# Was the rsync a success?
my $status = $rsync_obj->status;

if (($status != 0) and ($status != 24)) { # 24 == vanished source files
  
  my $ref_to_errors = $rsync_obj->err;
  
  system("/usr/bin/logger", "-p", "user.err", "-t", "NOC-NETCOOL-TICKET", "Error '$status' during transfer: '$source' => '$dest'");
  foreach my $error_line (@$ref_to_errors) {
    system("/usr/bin/logger", "-p", "user.err", $error_line);
  }

}
else {
  print "Sync of /tftpboot/ to tornado.ns completed successfully\n";
  system("/usr/bin/logger", "-p", "user.info", "Sync of /tftpboot/ to tornado.ns completed successfully");
}