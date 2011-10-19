#!/bin/bash
#Description: Bash script to find video files which are 720p.
#Written By: Jeff White (jwhite530@gmail.com)
#Version Number: 1.0
#Revision Date: 10-16-2011
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

find . -type f | sed -e 's/\.\///g' | while read -r each;do
  mplayer -nosound -vo null -ss 03:00:00 -really-quiet -identify "$each" 2>/dev/null | awk -F'=' '/ID_VIDEO_HEIGHT/ {if ($2==720) {exit 0} else {exit 1}}' && echo "$each"
done
