#!/bin/bash
#shopt -s -o noclobber
shopt -s -o nounset
#Description: Bash script to check for software updates of non-default RHEL/CentOS repositories.
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
# 0.1 - 2012-01-20 - Initial version. - Jeff White
#
#####

script="${0##*/}"
previous_failure_seen="0"
previous_missing_logical_path_seen="0"

multipath -ll > /tmp/multipath.out

# This section looks for any fiber paths which show as faulty or failed.
# If one or more are found then it write the number of failures to /tmp/failed_or_faulty_paths_found
# The next time the script runs if it sees that there are failed/faulty fiber paths AND the file 
# /tmp/failed_or_faulty_paths_found exists then it logs an alert to syslog.  In this way we only 
# generate an alert if two runs of this script find failed/faulty fiber paths.
awk '
BEGIN {
  numfailedpaths=0
}

{
  if (/\[failed\]/ || /\[faulty\]/) {
    print "Failed or faulty path found on device: " $3
    numfailedpaths++
  }
}

END {
  print numfailedpaths > "/tmp/num_failed_or_faulty_path"
}' /tmp/multipath.out

num_failed_or_faulty_paths=$(cat /tmp/num_failed_or_faulty_path)
rm -f /tmp/num_failed_or_faulty_path

if [ -f /tmp/failed_or_faulty_paths_found ];then
  previous_failure_seen="1"
fi

if [ "$num_failed_or_faulty_paths" = 0 ];then
  rm -f /tmp/failed_or_faulty_paths_found
  echo "0 failed or faulty fiber paths were found."
elif  [ "$num_failed_or_faulty_paths" = 1 ];then
  echo "$num_failed_or_faulty_paths" > /tmp/failed_or_faulty_paths_found
  echo "1 failed or faulty fiber path was found."
  #Only alert if the last run also found a failed or faulty fiber path.
  if [ "$previous_failure_seen" = "1" ];then 
    logger -p info "CREATE TICKET FOR SE - 1 failed or faulty fiber path was found.  ($script)"
  fi
elif [ "$num_failed_or_faulty_paths" -gt 1 ];then
  echo "$num_failed_or_faulty_paths" > /tmp/failed_or_faulty_paths_found
  echo "$num_failed_or_faulty_paths failed or faulty fiber paths were found."
  #Only alert if the last run also found a failed or faulty fiber path.
  if [ "$previous_failure_seen" = "1" ];then
    logger -p info "URGENT ALERT CALL TIER II - Multiple failed or faulty fiber paths were found.  ($script)"
  fi
fi

# This section checks that for each physical path there are two logical paths.  The same logic as the
# previous section is here so alerts are only generated if a problem is found on two runs of this script.
awk '
BEGIN {
  num_missing_logical_paths=0
}

n-->0 && !/^ \\_/ {
  n=0
  print "Missing logical path on line " NR
  num_missing_logical_paths++
} 
/^\\_/ {
  n=2
}

END {
  if(n>0) {
    print "Missing logical path on line " NR
    num_missing_logical_paths++
  }
  print num_missing_logical_paths > "/tmp/num_missing_logical_paths"
}' /tmp/multipath.out

num_missing_logical_paths=$(cat /tmp/num_missing_logical_paths)
rm -f /tmp/num_missing_logical_paths

if [ -f /tmp/missing_logical_paths_found ];then
  previous_missing_logical_path_seen="1"
fi

if [ "$num_missing_logical_paths" = 0 ];then
  rm -f /tmp/missing_logical_paths_found
  echo "0 logical fiber paths are missing."
elif  [ "$num_missing_logical_paths" = 1 ];then
  echo "$num_missing_logical_paths" > /tmp/missing_logical_paths_found
  echo "1 logical fiber path is missing."
  #Only alert if the last run also found a missing logical fiber path.
  if [ "$previous_missing_logical_path_seen" = "1" ];then 
    logger -p info "CREATE TICKET FOR SE - 1 logical fiber path is missing.  ($script)"
  fi
elif [ "$num_missing_logical_paths" -gt 1 ];then
  echo "$num_missing_logical_paths" > /tmp/missing_logical_paths_found
  echo "$num_missing_logical_paths logical fiber paths are missing."
  #Only alert if the last run also found a missing logical fiber path.
  if [ "$previous_missing_logical_path_seen" = "1" ];then
    logger -p info "URGENT ALERT CALL TIER II - Multiple logical fiber paths are missing.  ($script)"
  fi
fi

rm -f /tmp/multipath.out