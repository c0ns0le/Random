#!/usr/bin/env python
# Description: Display the quota of a user or group of an Infinity volume - client
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
import signal
import subprocess
import time
import xmlrpclib
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options] username/groupname\n" + 
    "Display the quota of a user or group of an Infinity volume - client."
)

(options, args) = parser.parse_args()





try:
    name = sys.argv[1]
    
except IndexError:
    sys.stderr.write("No username or groupname given, see --help")
    sys.exit(1)




print "dfngkfngdfg"
server_connection = xmlrpclib.ServerProxy('http://infinity.frank.sam.pitt.edu:8000')
print server_connection.get_quota(name)
