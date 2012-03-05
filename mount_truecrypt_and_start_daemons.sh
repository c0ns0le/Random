#!/bin/bash
shopt -s -o noclobber
shopt -s -o nounset

#Name: mount_truecrypt_and_start_daemons.sh
#Description: Bash script to mount and encrypted truecrypt volume and start daemons.
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
# 0.1 - 2012-02-26 - Initial version. - Jeff White
#
#####

truecryptbin="/usr/bin/truecrypt"
script=${0##*/}

if [ $# != 1 ];then
  echo "Usage: $script {start|stop|status}"
  exit 1
fi

case "$1" in
  status)
    #Check if the volume is mounted
    if grep '/var/lib/mysql' /etc/mtab >/dev/null;then
      volume_status=1
      echo "Volume mounted: Yes"
    else
      volume_status=0
      echo "Volume mounted: No"
    fi

    #Check if mysqld is running
    if service mysqld status | grep 'running';then
      mysqld_status=1
    elif service mysqld status | grep 'stopped';then
      mysqld_status=0
    else
      mysqld_status=2
      echo "Unable to determine if mysqld is running!"
    fi
  
    #Check if httpd is running
    if service httpd status | grep 'running';then
      httpd_status=1
    elif service httpd status | grep 'stopped';then
      httpd_status=0
    else
      httpd_status=2
      echo "Unable to determine if httpd is running!"
    fi
  
    if [[ $volume_status = 1 ]] && [[ $mysqld_status = 1 ]] && [[ $httpd_status = 1 ]];then
      echo "Authvaulth appears online."
    elif [[ $volume_status = 0 ]] && [[ $mysqld_status = 0 ]] && [[ $httpd_status = 0 ]];then
      echo "Authvaulth appears offline."
    else
      echo "Authvault is partially online/offline or in some state I can't figure out!"
    fi
  ;;

  start)
    echo "Starting..."
    $truecryptbin --protect-hidden=no /dev/vg_system/lv_mysql /var/lib/mysql || exit 1
    service mysqld start || exit 1
    service httpd start || exit 1
  ;;

  stop)
    echo "Stopping..."
    service httpd stop || exit 1
    service mysqld stop || exit 1
    $truecryptbin --dismount /var/lib/mysql || exit 1
  ;;
  *)
    echo "Usage: $script {start|stop|status}"
    exit 1
  ;;
esac
