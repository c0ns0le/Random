#!/bin/bash

#Description: Bash script to check the status of an Adaptect RAID card and arrays.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.5 - 2011-11-15 - Removed 'rm' from _print-stderr function. - Jeff White
#
# 0.4 - 2011-11-15 - Removed the exits on non-fatal errors. - Jeff White
#
# 0.3 - 2011-11-14 - Adjusted failed disk check: =1 then create ticket, >1 then call tier II. - Jeff White
#
# 0.2 - 2011-11-11 - Adjusted battery check to only alert on failure status. - Jeff White
#
# 0.1 - 2011-11-10 - Initial version. - Jeff White
#
#####

script="${0##*/}"
arcconfbin="/usr/StorMan/arcconf"
awkbin="/bin/awk"
temp_dir="/tmp/.$script"
adapter_output="$temp_dir/ad_output"
logical_device_output="$temp_dir/ld_output"
physical_device_output="$temp_dir/pd_output"

function _print-stderr-then-exit { # Usage: _print-stderr-then-exit "Some error text" exitnumber
echo "$1" 1>&2
logger -p err "$1"
rm -rf "$temp_dir"
exit $2
}

function _print-stderr { # Usage: _print-stderr-then-exit "Some error text"
echo "$1" 1>&2
logger -p err "$1"
}

mkdir -p "$temp_dir" || _print-stderr-then-exit "CREATE TICKET FOR SE - $LINENO - Unable to create temporary directory $temp_dir in script $script." 1

which $arcconfbin >/dev/null 2>&1|| _print-stderr-then-exit "CREATE TICKET FOR SE - $LINENO - Binary $arcconfbin was not found in script $script, did you install it?" 1

$arcconfbin getconfig 1 AD > "$adapter_output"
$arcconfbin getconfig 1 LD > "$logical_device_output"
$arcconfbin getconfig 1 PD > "$physical_device_output"

if [ ! -s "$adapter_output" -o ! -s "$logical_device_output" -o ! -s "$physical_device_output" ];then
  _print-stderr-then-exit "CREATE TICKET FOR SE - $LINENO - One or more output files of arcconf is null or does not exist in script $script." 1
fi

$awkbin '/Controller Status/ && $NF != "Optimal" {exit 1}' "$adapter_output" || _print-stderr "URGENT ALERT CALL TIER II - $LINENO - RAID controller status is not optimal in script $script.  This does NOT mean a drive failed."

$awkbin '/Status of logical device/ && $NF != "Optimal" {exit 1}' "$logical_device_output" || _print-stderr "CREATE TICKET FOR SE - $LINENO - RAID controller logical device is not in state optimal in script $script."

$awkbin '/Segment/ && $4 != "Present" {numfailures++} END {exit numfailures}' "$logical_device_output"
num_failed_disks="$?"
if [ "$num_failed_disks" = "0" ];then
  echo "All disks report as 'Present'."
elif [ "$num_failed_disks" = "1" ];then
  _print-stderr "CREATE TICKET FOR SE - $LINENO - A single physical disk is not in state present in script $script."
elif [ "$num_failed_disks" -gt "1" ];then
  _print-stderr "URGENT ALERT CALL TIER II - $LINENO - More than one physical disk is not in state present in script $script."
else
  _print-stderr "CREATE TICKET FOR SE - $LINENO - Unable to determine number of failed disks in script $script."
fi

$awkbin '/S.M.A.R.T. warnings/ && $4 != "0" {exit 1}' "$physical_device_output" || _print-stderr "CREATE TICKET FOR SE - $LINENO - RAID controller physical disk has one or more SMART warnings in script $script."

$awkbin '/Status/&&!/Controller/ && $NF == "Failed" {exit 1}' "$adapter_output" || _print-stderr "CREATE TICKET FOR SE - $LINENO - RAID controller battery is in state failed in script $script."

rm -rf "$temp_dir"