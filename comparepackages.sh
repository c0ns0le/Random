#!/bin/bash
#Description: Compares packages and package versions between RHEL boxes.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.2
#Revision Date: 8-01-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o nounset

#The package lists should be sorted and uniqed, made with:
#+ rpm -qa --queryformat "%{name}-%{version}-%{release}.%{arch}\n"

#Were we called with an argument?
curpkglst=${1?"Usage: $0 current_package_list_to_check good_package_list_to_check_against"}
goodpkglst=${2?"Usage: $0 current_package_list_to_check good_package_list_to_check_against"}

#Check for packages which are in the current server, but not in the good list, or "extra".
echo "Checking for extra packages (ones in $curpkglst but not $goodpkglst)."
cat "$curpkglst" | while read -r eachcurrentpkg;do
  grep "$eachcurrentpkg" "$goodpkglst" > /dev/null
  if [ "$?" != "0" ];then
    echo "Extra: $eachcurrentpkg"
  fi
done

#Check for packages which are in the good list, but not on the current server, or "missing".
echo "Checking for missing packages (ones in $goodpkglst but not in $curpkglst)."
cat "$goodpkglst" | while read -r eachgoodpkg;do
  grep "$eachgoodpkg" "$curpkglst" > /dev/null
  if [ "$?" != "0" ];then
    echo "Missing: $eachgoodpkg"
  fi
done