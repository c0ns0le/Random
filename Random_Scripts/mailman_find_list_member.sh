#!/bin/bash
#Description: Bash script to find a member in any list
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.1
#Revision Date: 5-2-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

LISTLISTSBIN="/usr/local/mailman/bin/list_lists"
LISTMEMBERSBIN="/usr/local/mailman/bin/list_members"
NAWKBIN="/bin/nawk"

#We we called with an argument?
if [ -z "$1" ]; then
  echo "$LINENO Error - You must include an email as an argument. EXITING"
  exit 2
elif [ -n "$2" ]; then
  echo "$LINENO Error - You must only include ONE email as an argument. EXITING"
  exit 2
fi

echo "Lists "$1" is a member of:"

$LISTLISTSBIN | $NAWKBIN '{ if (NR > 1 ) { print $1 }}' | while read -r EACHLISTNAME;do
  $LISTMEMBERSBIN "$EACHLISTNAME" | grep -i "$1" >/dev/null
  if [ $? = 0 ];then
    echo "$EACHLISTNAME"
  fi
done

echo "All done!"
