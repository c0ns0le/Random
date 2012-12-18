#!/usr/bin/env perl
# Description: Example code of a wrapper script which gives STDIN to and takes STDOUT/STDERR from an external program
# Written by: Jeff White (jwhite530@gmail.com)
# Derived from code written by abstracts on perlmonks.org
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


use strict;
use warnings;
use Getopt::Long;
use IPC::Open3;
use IO::Select;
use Symbol; # for gensym


$| = 1;


GetOptions('h|help' => \my $helpopt,
          ) || die "Incorrect usage, use -h for help.\n";

if ($helpopt) {
  print "Example code of a wrapper script which gives STDIN to and takes STDOUT/STDERR from an external program\n";
  print "-h | --help : Show this help\n";
  exit;
}


# Prepare filehandles
my ($CHILD_IN, $CHILD_OUT, $CHILD_ERR); # these are the FHs for our child 
$CHILD_ERR = gensym(); # we create a symbol for $CHILD_ERR because open3 will not do that for us


# Start the external program
my $child_pid;

eval{
  $child_pid = open3($CHILD_IN, $CHILD_OUT, $CHILD_ERR, "bc");
};
die "open3: $@\n" if $@;

print "PID was $child_pid\n";


# Feed the external program
print $CHILD_IN "scale=2\n";
print $CHILD_IN "2*37/3\n";
print $CHILD_IN "quit\n";


# Grab each line of output
my $select_object_child_fhs = new IO::Select; # create a select object to notify us on reads on our FHs
$select_object_child_fhs->add($CHILD_OUT, $CHILD_ERR); # add the FHs we're interested in to the object

while(my @ready = $select_object_child_fhs->can_read) { # read ready

  foreach my $CHILD_FILE_HANDLE (@ready) {

    my $line = <$CHILD_FILE_HANDLE>; # read one line from this fh
    unless (defined $line) { # EOF on this FH
      $select_object_child_fhs->remove($CHILD_FILE_HANDLE); # remove it from the list
      next;              # and go handle the next FH
    }

    if ($CHILD_FILE_HANDLE == $CHILD_OUT) { # if we read from the outfh
      print "Out: $line"; # print it to OUTFH
    }
    elsif ($CHILD_FILE_HANDLE == $CHILD_ERR) {# do the same for errfh  
      print "Err: $line";
    }

  }

}


waitpid($child_pid, 1);
# It is important to waitpid on your child process, otherwise zombies could be created.  