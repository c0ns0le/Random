#!/bin/bash
#Description: Bash script to find lists owned by a particular user.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.2
#Revision Date: 6-29-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

whichemailtosearchfor="$1"

#Were we called with an argument?
if [ -z "$1" ]; then
  echo "Error $LINENO - You must provide an email (or any string, really) as an arguement."
  exit 2
elif [ -n "$2" ]; then
  echo "Error $LINENO - More than one arguement specified."
  exit 2
fi

/usr/local/mailman/bin/list_lists | nawk '{print $1}' | while read -r eachlistname;do
  /usr/local/mailman/bin/list_owners $eachlistname | grep $whichemailtosearchfor >/dev/null
  if [ $? = 0 ];then
    echo "$eachlistname : $whichemailtosearchfor"
  fi
done