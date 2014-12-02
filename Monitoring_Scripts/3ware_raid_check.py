#!/usr/bin/env python
# Description: Check the status of a 3ware RAID controller via tw_cli
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.3
# Last change: Fixed a bug in the disk check where it said "array" instead of "disk"

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import os
import re
import sys
import subprocess
import syslog
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options] $nodes\nCheck the status of a 3ware RAId controller via tw_cli")

(options, args) = parser.parse_args()



# Get our local short hostname
fqdn = os.uname()[1]

hostname = fqdn.split(".")[0]



#
# Battery status
#

info = subprocess.Popen(["/opt/3ware/CLI/tw_cli", "//" + hostname + "/c0/bbu", "show"], stdin=None, stdout=subprocess.PIPE, shell=False)
out = info.communicate()[0]

for line in out.split(os.linesep):
  line = line.rstrip()
  
  match = re.match("^bbu", line)
  
  if match == None:
    continue
  
  [online_state, bbu_ready, status] = line.split()[1:4:1]
  
  if online_state == "On":
    sys.stdout.write("RAID battery online state: On\n")
    
  else:
    sys.stdout.write("WARNING: RAID battery online state: " + online_state + "\n")
    
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID battery online state: " + online_state)
    
  
  if bbu_ready == "Yes":
    sys.stdout.write("RAID battery ready: Yes\n")
    
  else:
    sys.stdout.write("WARNING: RAID battery ready: " + online_state + "\n")
    
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID battery ready: " + online_state)
    
    
  if status == "OK":
    sys.stdout.write("RAID battery status: OK\n")
    
  else:
    sys.stdout.write("WARNING: RAID battery status: " + online_state + "\n")
    
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID battery status: " + online_state)



#
# Array status
#

info = subprocess.Popen(["/opt/3ware/CLI/tw_cli", "//" + hostname + "/c0", "show", "unitstatus"], stdin=None, stdout=subprocess.PIPE, shell=False)
out = info.communicate()[0]

for line in out.split(os.linesep):
  line = line.rstrip()
  
  match = re.match("^u\d", line)
  
  if match == None:
    continue
  
  [array, status] = line.split()[0:4:2]
  
  if status == "OK" or status == "VERIFYING" or status == "VERIFY-PAUSED":
    sys.stdout.write("RAID status for array '" + array + "': " + status + "\n")
    
  else:
    sys.stdout.write("WARNING: RAID status for array '" + array + "': " + status + "\n")
    
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID status for array '" + array + "': " + status)



#
# Drive status
#

info = subprocess.Popen(["/opt/3ware/CLI/tw_cli", "//" + hostname + "/c0", "show", "drivestatus"], stdin=None, stdout=subprocess.PIPE, shell=False)
out = info.communicate()[0]

for line in out.split(os.linesep):
  line = line.rstrip()
  
  match = re.match("^p\d", line)
  
  if match == None:
    continue
  
  [status, disk] = line.split()[1:8:6]
  
  if status == "OK":
    sys.stdout.write("RAID status for disk '" + disk + "': " + status + "\n")
    
  else:
    sys.stdout.write("WARNING: RAID status for disk '" + disk + "': " + status + "\n")
    
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID status for disk '" + disk + "': " + status)
