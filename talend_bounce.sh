#!/bin/bash
#Name: talend_bounce.sh
#Description: Bash script to boucne the talend processes.
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
# 0.1 - 2011-11-17 - Initial version. - Jeff White
#
#####

tis_commandline_script="/TalendInstall/tiscommandline/commandline.sh"
remote_jobserver_start_script="/TalendInstall/org.talend.remote.jobserver_4.1.2_r53616/start_rs.sh"
remote_jobserver_stop_script="/TalendInstall/org.talend.remote.jobserver_4.1.2_r53616/stop_rs.sh"
tisuser="tisadmin"

function _log_entry { #Usage: _log_entry "Some text"
  echo "Talend restart - $1"
  logger -p info "Talend restart - $1"
}

function _log_minor_error_and_exit { #Usage: _log_minor_error_and_exit "Error text" exitnumber
  echo "CREATE TICKET FOR TIER II - Talend restart failed - $1"
  logger -p info "CREATE TICKET FOR TIER II - Talend restart failed - $1"
  exit $2
}

function _log_critical_error_and_exit { #Usage: _log_critical_error_and_exit "Error text" exitnumber
  echo "URGENT ALERT CALL TIER II - Talend restart failed - $1"
  logger -p info "URGENT ALERT CALL TIER II - Talend restart failed - $1"
  exit $2
}

_log_entry "Checking sanity of the script."
if [[ ! -x "$tis_commandline_script" -o -! -x "$remote_jobserver_start_script" -o ! -x "$remote_jobserver_stop_script" ]];then
  _log_minor_error_and_exit "Required scripts or binaries could not be found or are not executable." 1
elif [[ "$USER" != "$tisuser" ]];then
  _log_minor_error_and_exit "Talend admin script was not ran as $tisuser." 1
fi

_log_entry "Stopping Talend proccesses."
$remote_jobserver_stop_script || _log_critical_error_and_exit "Failed to start Talend on line $LINENO." 1
killall TISEE-linux-gtk-x86_64 || _log_critical_error_and_exit "Failed to start Talend on line $LINENO." 1
sleep 2
if ps -ef | grep "TISEE-linux-gtk-x86_64" >/dev/null;then
  killall -9 TISEE-linux-gtk-x86_64
  sleep 2
fi

_log_entry "Checking for remaining Talend processes."
if ps -ef | grep "TISEE-linux-gtk-x86_64" >/dev/null;then
  _log_critical_error_and_exit "Failed to kill Talend process TISEE-linux-gtk-x86_64" 1
fi

_log_entry "Starting Talend processes."
$tis_commandline_script -startServer || _log_critical_error_and_exit "Failed to start Talend on line $LINENO." 1
$remote_jobserver_start_script || _log_critical_error_and_exit "Failed to start remote jobserver on line $LINENO." 1

_log_entry "Checking that Talend is up and healthy."
#if not, _log_critical_error_and_exit