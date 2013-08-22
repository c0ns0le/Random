#!/usr/bin/env python
# Description: Check the status of a RAID controller via MegaCli
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, syslog, signal, subprocess, re
from optparse import OptionParser



megacli = "/opt/MegaRAID/MegaCli/MegaCli64"
red = "\033[31m"
endcolor = '\033[0m' # end color



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Check the status of a RAID controller via MegaCli"
)

(options, args) = parser.parse_args()



# Prepare for timeouts
class Alarm(Exception):
    pass

def alarm_handler(signum, frame):
    raise Alarm

signal.signal(signal.SIGALRM, alarm_handler)



# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)



#
# Battery status
#

info = subprocess.Popen([megacli, "-AdpBbuCmd", "-aAll"], stdin=None, stdout=subprocess.PIPE, shell=False)

for line in info.communicate()[0].split(os.linesep):
    line = line.rstrip()
    
    battery_missing_match = re.match("\s+Battery Pack Missing\s+:\s+(.*)", line)
    
    if battery_missing_match is not None:
        if battery_missing_match.group(1) == "No":
            print "RAID battery pack found"
            
        else:
            print red + "RAID battery pack reported as missing" + endcolor
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID battery pack reported as missing")
            
            break
        
        continue
        
        
    battery_replacement_match = re.match("\s+Battery Replacement required\s+:\s+(.*)", line)
    
    if battery_replacement_match is not None:
        if battery_replacement_match.group(1) == "No":
            print "RAID battery pack ok"
            
        else:
            print red + "RAID battery pack replacement required" + endcolor
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID battery pack replacement required")
            
        break
    
    
    
#
# Logical device status
#

info = subprocess.Popen([megacli, "-LDInfo", "-Lall", "-aALL"], stdin=None, stdout=subprocess.PIPE, shell=False)

logical_device_id = ""
for line in info.communicate()[0].split(os.linesep):
    line = line.rstrip()
    
    id_match = re.match("Virtual Drive:\s+(\d+)", line)
    
    if id_match is not None:
        logical_device_id = id_match.group(1)
        
        continue
    
    
    state_match = re.match("State\s+:\s+(.*)$", line)
    
    if state_match is not None:
        if state_match.group(1) == "Optimal":
            print "RAID logical device " + str(logical_device_id) + " ok"
            
        else:
            print red + "RAID logical deivce " + str(logical_device_id) + "in state " + state_match.group(1) + endcolor
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID logical deivce " + str(logical_device_id) + "in state " + state_match.group(1))
            
            
            
#
# Physical device status
#

info = subprocess.Popen([megacli, "-PDList", "-aALL"], stdin=None, stdout=subprocess.PIPE, shell=False)

physical_device_id = ""
for line in info.communicate()[0].split(os.linesep):
    line = line.rstrip()
    
    id_match = re.match("Device Id:\s+(\d+)$", line)
    
    if id_match is not None:
        physical_device_id = id_match.group(1)
        
        continue
    
    
    media_error_count_match = re.match("Media Error Count:\s+(.*)", line)
    
    if media_error_count_match is not None:
        if media_error_count_match.group(1) == "0":
            print "RAID physical device " + physical_device_id + " media error count is ok"
            
        else:
            print red + "RAID physical device " + physical_device_id + " media error count is " + media_error_count_match.group(1) + endcolor
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID physical device " + physical_device_id + " media error count is " + media_error_count_match.group(1))
    
        continue
    
            
    other_error_count_match = re.match("Other Error Count:\s+(.*)", line)
    
    if other_error_count_match is not None:
        if other_error_count_match.group(1) == "0":
            print "RAID physical device " + physical_device_id + " other error count is ok"
            
        else:
            print red + "RAID physical device " + physical_device_id + " other error count is " + other_error_count_match.group(1) + endcolor
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID physical device " + physical_device_id + " other error count is " + other_error_count_match.group(1))
    
        continue
    
    
    predictive_failure_count_match = re.match("Predictive Failure Count:\s+(.*)", line)
    
    if predictive_failure_count_match is not None:
        if predictive_failure_count_match.group(1) == "0":
            print "RAID physical device " + physical_device_id + " predictive failure count is ok"
            
        else:
            print red + "RAID physical device " + physical_device_id + " predictive failure count is " + predictive_failure_count_match.group(1) + endcolor
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: RAID physical device " + physical_device_id + " predictive failure count is " + predictive_failure_count_match.group(1))
    
        continue



# Close the syslog, we're done with it
syslog.closelog()