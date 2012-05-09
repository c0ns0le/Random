#!/bin/bash
# Description: Bash script to dump the database of RHN Satellite
# Written By: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1 (2012-5-7)
# Last change: Initial version

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

script=${0##*/}
db_dump_dir="/var/satellite/db_backup"

function _printerr {
  echo "$1" 1>&2
}

if [ -d "${db_dump_dir}/old" ];then
  rm -rf "${db_dump_dir}/old"
  if [ $? != 0 ];then
    _printerr "RHN DB dump failed: Failed to remove old dump '${db_dump_dir}/old'."
    logger -p err -t NOC-NETCOOL-TICKET "RHN DB dump failed: Failed to remove old dump '${db_dump_dir}/old'. - $script"
    exit 1
  fi
fi

if [ -d "${db_dump_dir}/current" ];then
  mv "${db_dump_dir}/current" "${db_dump_dir}/old"
  if [ $? != 0 ];then
    _printerr "RHN DB dump failed: Failed to move '${db_dump_dir}/current' to '${db_dump_dir}/previous'."
    logger -p err -t NOC-NETCOOL-TICKET "RHN DB dump failed: Failed to move '${db_dump_dir}/current' to '${db_dump_dir}/previous'. - $script"
    exit 1
  fi
fi

mkdir -p "${db_dump_dir}/current"
if [ $? != 0 ];then
  _printerr "RHN DB dump failed: Failed to create backup directory '${db_dump_dir}/current'."
  logger -p err -t NOC-NETCOOL-TICKET "RHN DB dump failed: Failed to create backup directory '${db_dump_dir}/current'. - $script"
  exit 1
fi

chown -R oracle:oracle "${db_dump_dir}"
if [ $? != 0 ];then
  _printerr "RHN DB dump failed: Failed to set oracle user as owner of '${db_dump_dir}/current'."
  logger -p err -t NOC-NETCOOL-TICKET "RHN DB dump failed: Failed to set oracle user as owner of '${db_dump_dir}/current'. - $script"
  exit 1
fi

/usr/sbin/rhn-satellite stop
if [ $? != 0 ];then
  _printerr "RHN DB dump failed: Failed to stop RHN satellite, attempting to start it again."
  logger -p err -t NOC-NETCOOL-TICKET "RHN DB dump failed: Failed to stop RHN satellite, attempting to start it again. - $script"
  
  /usr/sbin/rhn-satellite start
  if [ $? != 0 ];then
    _printerr "RHN DB dump failed: Failed to start RHN satellite."
    logger -p err -t NOC-NETCOOL-TICKET "RHN DB dump failed: Failed to start RHN satellite. - $script"
    exit 1
  fi
fi

sudo -u oracle db-control backup /var/satellite/db_backup/current
if [ $? != 0 ];then
  _printerr "RHN DB dump failed: Failed to dump databases."
  logger -p err -t NOC-NETCOOL-TICKET "RHN DB dump failed: Failed to dump databases. - $script"
fi

/usr/sbin/rhn-satellite start
if [ $? != 0 ];then
  _printerr "RHN DB dump failed: Failed to start RHN satellite."
  logger -p err -t NOC-NETCOOL-TICKET "RHN DB dump failed: Failed to start RHN satellite. - $script"
  exit 1
fi

sudo -u oracle db-control verify "${db_dump_dir}/current"
if [ $? != 0 ];then
  _printerr "RHN DB dump failed: Verify of DB dumps failed."
  logger -p err -t NOC-NETCOOL-TICKET "RHN DB dump failed: Verify of DB dumps failed. - $script"
  exit 1
fi