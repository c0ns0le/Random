#!/usr/bin/awk -f
#Description: Awk script to check for missing or failed fiber paths.
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
# 0.1 - 2012-01-19 - Initial version. - Jeff White
#
#####

BEGIN {
#  cmd="/sbin/multipath -ll"
  cmd="cat /tmp/multipath.out"
  while ((cmd | getline) > 0) {
    if (/\[failed\]/ || /\[faulty\]/) {
      print "Failed or faulty path found on device: " $3
      numfailedpaths++
    }
    else if (/^\\_/) {
      for(i=0;i<2;i++) {
#	getline
	if ($0 !~ /^ \\_/) {
	  print "Error at line " NR
#	  break
	}
      }
    }
  }

#Check the number of failed or faulty paths, alert if any are found.
  if (numfailedpaths == 0) { 
    printf "\n0 failed or faulty fiber paths were found.\n"
  } 
  else if (numfailedpaths == 1) {
    printf "\n1 failed or faulty fiber path was found.\n"
    system("logger -p info 'CREATE TICKET FOR SE - 1 failed or faulty fiber path was found.'")
  }
  else if (numfailedpaths > 1) {
    printf "\n"numfailedpaths" failed or faulty fiber paths were found.\n"
    system("logger -p info 'URGENT ALERT CALL TIER II - Multiple failed or faulty fiber paths were found.'")
  }
}