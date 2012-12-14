#!/bin/bash
#
# vpnc_daemon     This script starts and stop vpnc_daemon
#
# chkconfig: - 13 87
# description: vpnc_daemon is a program to periodically check \
# and the status of a vpnc instance and restart it if needed
# probe: true

### BEGIN INIT INFO
# Provides: $vpnc_daemon
# Required-Start: $local_fs $network $syslog
# Required-Stop: $local_fs $network $syslog
# Default-Start:
# Default-Stop: 0 1 2 3 4 5 6
# Short-Description: start|stop|restart|status
# Description: Control vpnc daemonizer
### END INIT INFO

# Written by: Jeff White (jwhite530@gmail.com)
# Version: 1.1
# Last change: Switched to /bin/bash, changed status scheck to send signal 0

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


pid_file="/var/run/vpncd.pid"
program="/usr/local/bin/vpnc_daemon.pl"


# Check the status of the daemon
function check_status {
  # Returns true if the daemon is running, false otherwise
  
  if [ -f "$pid_file" ];then
  
    pid=$(cat "$pid_file")
    
    if kill -0 $pid;then
      true
    else
      false
    fi
    
  else
  
    false
    
  fi
}


# Start the daemon
function daemon_start {
  if check_status;then
  
    echo "Already running"
    exit 0
    
  else
  
    if $program;then
    
      echo "$program [Started]"
      exit 0
      
    else
    
      echo "Failed to start"
      exit 1
      
    fi
    
  fi
}


# Stop the daemon
function daemon_stop {
  if check_status;then
  
    pid=$(cat $pid_file)
    kill $pid
    sleep 2
    
    if check_status;then
    
      echo "Failed to stop"
      exit 1
      
    else
    
      echo "$program [Stopped]"
      exit 0
      
    fi
    
  else
    
    echo "$program [Stopped]"
    exit 0
    
  fi
}

case "$1" in
  status)
    if check_status;then
    
      echo "$program [Started]"
      exit 0
      
    else
    
      echo "$program [Stopped]"
      exit 3
      
    fi
    ;;
    
  start)
    daemon_start
    ;;
  
  stop)
    daemon_stop
    ;;
    
  restart)
    daemon_stop && daemon_start
    ;;
esac