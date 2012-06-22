#!/usr/bin/nawk -f 
#Description: Awk script to check for pending tape requests in NetBackup.
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
# 0.1 - 2012-01-13 - Initial version. - Jeff White
#
#####

BEGIN {
  cmd="/usr/openv/volmgr/bin/vmoprcmd -devmon pr"
  while ((cmd | getline) > 0) {
    if ($0 ~ /<NONE>/) {
      print "No pending tape requests found."
      exit
    } else if ($2 ~ /^[0-9].*[0-9]$/) {
      if ($0 ~ /\.pitt\.edu$/) {
	system("logger -p err 'NetBackup is requesting tape number " $2 " for host " $NF ".  Please put it in the appropriate drive/robot.'")
	print "NetBackup is requesting tape number " $2 " for host " $NF ".  Please put it in the appropriate drive/robot."
      } else {
	system("logger -p err 'NetBackup is requesting tape number " $2 ".  Please put it in the appropriate drive/robot.'")
	print "NetBackup is requesting tape number " $2 ".  Please put it in the appropriate drive/robot."
      }
    }
  }
}