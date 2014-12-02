#!/usr/bin/env python
# Description: Verify that all fiber paths are up and online on RHEL
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys
import os
import re
import subprocess
import syslog
from optparse import OptionParser



multipath = "/sbin/multipath"
red = "\033[31m"
endcolor = '\033[0m'



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Verify that all fiber paths are up and online on RHEL.\n"
)

(options, args) = parser.parse_args()





# Verify the correct number of paths were found
def check_path_count(mpath, num_paths):
    # Did the previous mpath (if we had a previous) have all 4 paths?
    if num_paths != 0 and num_paths != 4:
        sys.stdout.write(red + mpath + ": WARNING!\n" + endcolor)
        
        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: One or more fiber paths on mpath " + mpath + " is missing or not active or ready")
        
    elif num_paths != 0:
        sys.stdout.write(mpath + ": OK\n")
        
    return None




multipath_info = subprocess.Popen([multipath, "-ll"], stdin=None, stdout=subprocess.PIPE, shell=False)
out = multipath_info.communicate()[0]

for line in out.split(os.linesep):
    line = line.rstrip()
    
    # Did we come across a new mpath?
    if re.search("^mpath", line) is not None:
        # This try block is in case this is the first mpath we are checking so mpath and num_paths are not yet defined
        try:
            check_path_count(mpath, num_paths)
            
        except NameError:
            pass
            
        # Note the mpath name we are now going to be working on
        mpath = line.split()[0]
        
        # Reset the path count to zero
        num_paths = 0
        
        
    # Did we find a fiber path?
    if re.search("sd[a-z]+\s+\d+:\d+\s+active\s+ready", line) is not None \
    or re.search("sd[a-z]+\s+\d+:\d+\s+\[active\]\[ready\]", line) is not None:
        num_paths += 1

check_path_count(mpath, num_paths)
