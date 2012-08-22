#!/usr/bin/env perl
use strict;
use warnings;
# Description: Convert a string to a valid URL or an encoded URL to a string
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.0
# Last change: Intial version

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Getopt::Long;

my $decode = 0;

GetOptions('h|help' => \my $helpopt,
	   'e|encode' => \my $encode,
	   'd|decode' => \$decode,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Convert a string to a valid URL or an encoded URL to a string.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options] < /path/to/file\n"; 
  print "-h | --help : Show this help\n";
  print "-e | --encode : Encode (default)\n";
  print "-d | --decode : Decode\n";
  exit;
}

# If we were not asked to be in decode mode we fall through to encode mode
if ($decode){
  for my $line (<>) {

    $line =~ s/%25/%/g;
    $line =~ s/%20/ /g;
    $line =~ s/%3C/</g;
    $line =~ s/%3E/>/g;
    $line =~ s/%23/#/g;
    $line =~ s/%7B/{/g;
    $line =~ s/%7D/}/g;
    $line =~ s/%7C/|/g;
    $line =~ s/%5C/\\/g;
    $line =~ s/%5E/^/g;
    $line =~ s/%7E/~/g;
    $line =~ s/%5B/[/g;
    $line =~ s/%5D/]/g;
    $line =~ s/%60/`/g;
    $line =~ s/%3B/;/g;
    $line =~ s/%2F/\//g;
    $line =~ s/%3F/?/g;
    $line =~ s/%3A/:/g;
    $line =~ s/%40/@/g;
    $line =~ s/%3D/=/g;
    $line =~ s/%26/&/g;
    $line =~ s/%2B/+/g;

    print "$line";

  }

}
# Nothing else to do but encode...
else {
  for my $line (<>) {

    $line =~ s/%/%25/g;
    $line =~ s/ /%20/g;
    $line =~ s/</%3C/g;
    $line =~ s/>/%3E/g;
    $line =~ s/#/%23/g;
    $line =~ s/{/%7B/g;
    $line =~ s/}/%7D/g;
    $line =~ s/\|/%7C/g;
    $line =~ s/\\/%5C/g;
    $line =~ s/\^/%5E/g;
    $line =~ s/~/%7E/g;
    $line =~ s/\[/%5B/g;
    $line =~ s/\]/%5D/g;
    $line =~ s/`/%60/g;
    $line =~ s/;/%3B/g;
    $line =~ s/\//%2F/g;
    $line =~ s/\?/%3F/g;
    $line =~ s/:/%3A/g;
    $line =~ s/\@/%40/g;
    $line =~ s/\=/%3D/g;
    $line =~ s/\&/%26/g;
    $line =~ s/\+/%2B/g;

    print "$line";

  }
}