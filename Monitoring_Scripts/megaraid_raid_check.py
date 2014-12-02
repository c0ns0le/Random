#!/usr/bin/env python
# Description: Check the status of a MegaRAID controller via StorCLI
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.1
# Last change: Changed how the status is gathered, skip battery check while charging

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
parser = OptionParser("%prog [options] $nodes\nCheck the status of a MegaRAID controller via StorCLI")

(options, args) = parser.parse_args()





#
# Battery status
#

info = subprocess.Popen(["/usr/local/MegaRAID Storage Manager/StorCLI/storcli64", "/c0/bbu", "show", "all"], stdin=None, stdout=subprocess.PIPE, shell=False)
out = info.communicate()[0]

if re.search("^Charging Status", out):
    
    match = re.match("^Charging Status\s+(.*)$", out)
      
    status = match.group(1)    
    
    sys.stdout.write("RAID battery charge state: " + status)
    
else:   
    for line in out.split(os.linesep):
        line = line.rstrip()
    
        if re.search("^Battery State", line) is not None:
        
            match = re.match("^Battery State (.*)$", line)
        
            status = match.group(1)
    
            if status == "Operational":
                sys.stdout.write("RAID battery status: Operational\n")
        
            else:
                sys.stdout.write("WARNING: RAID battery status: " + status + "\n")
            
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID battery status: " + status)
        

        elif re.search("^Battery Pack Missing", line) is not None:
        
            missing_status = line.split()[3]
    
            if missing_status != "No":
                sys.stdout.write("WARNING: RAID battery not found\n")
            
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID battery not found")
                
                
        elif re.search("^Battery Replacement required", line) is not None:
        
            replacement_status = line.split()[3]
    
            if replacement_status != "No":
                sys.stdout.write("WARNING: RAID battery needs replaced\n")
            
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID battery needs replaced")

                
        elif re.search("^Pack is about to fail", line) is not None:
        
            replacement_status = line.split()[9]
    
            if replacement_status != "No":
                sys.stdout.write("WARNING: RAID battery needs replaced\n")
            
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID battery needs replaced")


            
            
            
#
# Controller status
#

info = subprocess.Popen(["/usr/local/MegaRAID Storage Manager/StorCLI/storcli64", "/c0", "show", "all"], stdin=None, stdout=subprocess.PIPE, shell=False)
out = info.communicate()[0]

for line in out.split(os.linesep):
    line = line.rstrip()
  
    if re.search("^Controller Status", line) is not None:
        
        match = re.match("^Controller Status = (.*)$", line)
      
        status = match.group(1)

        if status == "OK":
            sys.stdout.write("RAID controller status: OK\n")
    
        else:
            sys.stdout.write("WARNING: RAID controller status: " + status + "\n")
        
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID controller status: " + status)
            
            
    elif re.search("^Memory Correctable Errors", line) is not None:
        
        num_errors = line.split()[4]
        num_errors = int(num_errors)

        if num_errors == 0:
            sys.stdout.write("RAID memory status (correctable errors): OK\n")
    
        else:
            sys.stdout.write("WARNING: RAID memory status (correctable errors): " + str(num_errors) + " errors found\n")
        
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID memory status (correctable errors): " + str(num_errors) + " errors found")

            
    elif re.search("^Memory Uncorrectable Errors", line) is not None:
        
        num_errors = line.split()[4]
        num_errors = int(num_errors)

        if num_errors == 0:
            sys.stdout.write("RAID memory status (uncorrectable errors): OK\n")
    
        else:
            sys.stdout.write("WARNING: RAID memory status (uncorrectable errors): " + str(num_errors) + " errors found\n")
        
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID memory status (uncorrectable errors): " + str(num_errors) + " errors found")

            
            
            
            
#
# Array status
#

info = subprocess.Popen(["/usr/local/MegaRAID Storage Manager/StorCLI/storcli64", "/c0/v0", "show"], stdin=None, stdout=subprocess.PIPE, shell=False)
out = info.communicate()[0]

for line in out.split(os.linesep):
    line = line.rstrip()
  
    if re.search("^0/0", line) is not None: # FIXME: This only checks the first array, what does a second array look like?  0/1 or 1/0?
        
        status = line.split()[2]

        if status == "Optl":
            sys.stdout.write("RAID array status: Optimal\n")
    
        else:
            sys.stdout.write("WARNING: RAID array status: " + status + "\n")
        
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID array status: " + status)




#
# Drive status
#

info = subprocess.Popen(["/usr/local/MegaRAID Storage Manager/StorCLI/storcli64", "/c0/dall", "show", "all"], stdin=None, stdout=subprocess.PIPE, shell=False)
out = info.communicate()[0]

for line in out.split(os.linesep):
    line = line.rstrip()
  
    if re.search("\s+HDD\s+", line) is not None or re.search("\s+SDD\s+", line) is not None:
      
        [disk, status] = line.split()[0:4:2]
  
        if status == "Onln":
            sys.stdout.write("RAID status for disk '" + disk + "': Online\n")
    
        else:
            sys.stdout.write("WARNING: RAID status for disk '" + disk + "': " + status + "\n")
    
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID status for disk '" + disk + "': " + status)
