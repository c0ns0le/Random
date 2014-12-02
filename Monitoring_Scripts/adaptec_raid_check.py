#!/usr/bin/env python
# Description: Check the status of an Adaptec RAID controller via StorMan
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

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
parser = OptionParser("%prog [options] $nodes\nCheck the status of a Adaptec RAID controller via StorMan")

(options, args) = parser.parse_args()





#
# Adapter check
#

try:
    info = subprocess.Popen(["/usr/StorMan/arcconf", "GETCONFIG", "1", "AD"], stdin=None, stdout=subprocess.PIPE, shell=False)
    out = info.communicate()[0]

    for line in out.split(os.linesep):
        line = line.rstrip()
        
        if re.search("Controller Status", line) is not None:
            status = line.split()[3]
            
            if status == "Optimal":
                sys.stdout.write("Adapter status: Optimal\n")
                
            else:
                sys.stdout.write("WARNING: Adapter status: " + status + "\n")
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID Adapter status: " + status)
            
            
except Exception as err:
    sys.stderr.write("Failed to get RAID adapter status: " + str(err))
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get RAID adapter status: " + str(err))

    
    
    

#
# Logical Device
#

try:
    info = subprocess.Popen(["/usr/StorMan/arcconf", "GETCONFIG", "1", "LD"], stdin=None, stdout=subprocess.PIPE, shell=False)
    out = info.communicate()[0]

    for line in out.split(os.linesep):
        line = line.rstrip()
        
        # Get the current logical device name
        if re.search("Logical device name", line) is not None:
            logical_device_name = line.split()[4]
            
        
        # Check the logical device status
        if re.search("Status of logical device", line) is not None:
            logical_device_status = line.split()[5]
            
            if logical_device_status == "Optimal":
                sys.stdout.write("Logical device " + logical_device_name + " status: Optimal\n")
                
            else:
                sys.stdout.write("WARNING: Logical device " + logical_device_name + " status: " + logical_device_status + "\n")
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID Logical device " + logical_device_name + " status: " + logical_device_status)
            
            
        # Check the segment status
        if re.search("Segment", line) is not None:
            [segment_number, segment_status] = line.split()[1:4:2]
            
            if segment_status == "Present":
                sys.stdout.write("Disk " + segment_number + " of logical device " + logical_device_name + " status: Optimal\n")
                
            else:
                sys.stdout.write("WARNING: Disk " + segment_number + " of logical device " + logical_device_name + " status: " + segment_status + "\n")
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID disk " + segment_number + " of logical device " + logical_device_name + " status: " + segment_status)
        
            
except Exception as err:
    sys.stderr.write("Failed to get RAID logical device status: " + str(err))
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get RAID logical device status: " + str(err))

    
    
    
    
#
# Physical Disk
#

try:
    info = subprocess.Popen(["/usr/StorMan/arcconf", "GETCONFIG", "1", "PD"], stdin=None, stdout=subprocess.PIPE, shell=False)
    out = info.communicate()[0]

    for line in out.split(os.linesep):
        line = line.rstrip()
        
        # Get disk number
        if re.search("Device #", line) is not None:
            disk_number = line.split()[1]
            
        
        # Check disk status
        if re.search("\s\sState", line) is not None:
            disk_status = line.split()[2]
            
            if disk_status == "Online":
                sys.stdout.write("Disk " + disk_number + " status: Online\n")
                
            else:
                sys.stdout.write("WARNING: Disk " + disk_number + " status: " + disk_status + "\n")
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID disk " + disk_number + " status: " + disk_status)
                
                
        # Check SMART status
        if re.search("S\.M\.A\.R\.T\. warnings", line) is not None:
            smart_status = line.split()[3]
            
            if smart_status == "0":
                sys.stdout.write("Disk " + disk_number + " SMART status: OK\n")
                
            else:
                sys.stdout.write("WARNING: Disk " + disk_number + " SMART status: Error\n")
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID Disk " + disk_number + " SMART status: Error")
            
            
except Exception as err:
    sys.stderr.write("Failed to get RAID disk status: " + str(err))
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get RAID disk status: " + str(err))
