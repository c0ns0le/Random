#!/usr/bin/env python
# Description: Test that Netbackup is still running jobs and replicating data
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
import syslog
import signal
import subprocess
import time
import datetime
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Test that Netbackup is still running jobs and replicating data."
)

(options, args) = parser.parse_args()



# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)



# Prepare for subprocess timeouts
class Alarm(Exception):
    pass

def alarm_handler(signum, frame):
    raise Alarm

signal.signal(signal.SIGALRM, alarm_handler)



# Is the test job running?
# Returns True is yes, False if no
def job_running(policy_name):
    signal.alarm(60 * 5)
    
    try:
        bpdbjobs_info = subprocess.Popen(["/usr/openv/netbackup/bin/admincmd/bpdbjobs", "-report"], stdin=None, stdout=subprocess.PIPE, shell=False)
        out = bpdbjobs_info.communicate()[0]
        status = bpdbjobs_info.wait()
        
        signal.alarm(0)
        
        if status != 0:
            sys.stderr.write("NBU Tester - Error - Unable to get list of jobs, bpdbjobs exited with a status of " + str(status) + ", exiting.\n")
            syslog.syslog(syslog.LOG_ERR, "NBU Tester - Error - Unable to get list of jobs, bpdbjobs exited with a status of " + str(status) + ", exiting. - NOC-NETCOOL-TICKET")
            sys.exit(1)
            
        job_running = False
            
        for line in out.split(os.linesep):
            if re.search(policy_name, line) is None:
                continue
            
            if re.search("Active\s+" + policy_name, line) is not None:
                return True
            
        return job_running
            
        
        
    except Alarm:
        sys.stderr.write("NBU Tester - Error - Timeout while getting list of jobs, exiting.\n")
        syslog.syslog(syslog.LOG_ERR, "NBU Tester - Error - Timeout while getting list of jobs, exiting. - NOC-NETCOOL-TICKET")
        sys.exit(1)
        
        
        
# SIGTERM a process
def send_sigterm(pid):
    print "NBU Tester - Info - Sending SIGTERM to PID " + str(pid) + "."
    syslog.syslog(syslog.LOG_INFO, "NBU Tester - Info - Sending SIGTERM to PID " + str(pid) + ".")
    
    try:
        os.kill(pid, 15) # 15 = SIGTERM
        
    # The process could have exited by now, that's fine 
    except OSError:
        pass
        
        
        
print "NBU Tester - Info - Started with PID " + str(os.getpid()) + "."
syslog.syslog(syslog.LOG_INFO, "NBU Tester - Info - Started with PID " + str(os.getpid()) + ".")



# Don't run the job if one is already running
print "NBU Tester - Info - Checking for running test job."
if job_running("NBU-TESTER") is True:
    sys.stderr.write("NBU Tester - Error - Existing NBU Tester job is currently running, exiting.\n")
    syslog.syslog(syslog.LOG_INFO, "NBU Tester - Error - Existing NBU Tester job is currently running, exiting.")
    sys.exit(1)



# Fork a child watchdog process to ensure the backup we are about to start completes in a timely fashion
pid = os.fork()

if pid == 0: # Child
    os.setsid()
    
    print "NBU Tester Watchdog - Info - Started with PID " + str(os.getpid()) + "."
    syslog.syslog(syslog.LOG_INFO, "NBU Tester Watchdog - Info - Started with PID " + str(os.getpid()) + ".")
    
    parent_pid = os.getppid()

    # Time out after 30 minutes
    signal.alarm(60 * 30)
    
    try:
        # We sleep in small increments here because time.sleep() is interruptable and can get woken
        # too early if we simply did a time.sleep(999999999)
        while True:
            time.sleep(10)
            
    except Alarm:
        sys.stderr.write("NBU Tester - Error - Timeout while running test job.\n")
        syslog.syslog(syslog.LOG_ERR, "NBU Tester - Error - Timeout while running test job. - NOC-NETCOOL-TICKET")
            


else: # Parent
    # Give our child time to get set up
    time.sleep(5)
    
    print "NBU Tester - Info - Starting test job, progress log: /tmp/nbu_tester.log."
    syslog.syslog(syslog.LOG_INFO, "NBU Tester - Info - Starting test job, progress log: /tmp/nbu_tester.log.")
    
    bpdbjobs_info = subprocess.Popen(["/usr/openv/netbackup/bin/bpbackup", "-i", "-p", "NBU-TESTER", "-w", "-L", "/tmp/nbu_tester.log"], stdin=None, stdout=subprocess.PIPE, shell=False)
    status = bpdbjobs_info.wait()
    
    if status == 0:
        print "NBU Tester - Info - Test backup completed successfully."
        syslog.syslog(syslog.LOG_INFO, "NBU Tester - Info - Test backup completed successfully.")
        
        print "NBU Tester - Info - Finding image to duplicate."
        syslog.syslog(syslog.LOG_INFO, "NBU Tester - Info - Finding image to duplicate.")
        
        bpimagelist_info = subprocess.Popen(["/usr/openv/netbackup/bin/admincmd/bpimagelist", "-hoursago", "1", "-policy", "NBU-TESTER"], stdin=None, stdout=subprocess.PIPE, shell=False)
        status = bpimagelist_info.wait()
        
        if status == 0:
            highest_image_id = 0
            for line in bpimagelist_info.communicate()[0].split(os.linesep):
                if re.search("^IMAGE", line) is not None:
                    image_name = line.split()[5]
                    image_id = image_name.split("_")[1]
                    
                    if image_id > highest_image_id:
                        highest_image_id = image_id
                        image_to_dup = image_name
                        
        elif status == 227:
            sys.stderr.write("NBU Tester - Error - Test duplication failed, no primary image copy found.\n")
            syslog.syslog(syslog.LOG_ERR, "NBU Tester - Error - Test duplication failed, no primary image copy found, exiting. - NOC-NETCOOL-TICKET")
            
        else:
            sys.stderr.write("NBU Tester - Error - Test duplication failed, no primary image copy found.\n")
            syslog.syslog(syslog.LOG_ERR, "NBU Tester - Error - Test duplication failed, no primary image copy found, exiting. - NOC-NETCOOL-TICKET")
            # Kill our watchdog process
            send_sigterm(pid)
            sys.exit(1)
            
        
        print "NBU Tester - Info - Starting duplication of image " + image_to_dup + "."
        syslog.syslog(syslog.LOG_INFO, "NBU Tester - Info - Starting duplication of image " + image_to_dup + ".")
        
        with open(os.devnull, "w") as devnull:
            bpduplicate_info = subprocess.Popen(["/usr/openv/netbackup/bin/admincmd/bpduplicate", "-backupid", image_to_dup, "-dstunit", "DR-Main"], stderr=devnull, stdin=None, shell=False)
            status = bpduplicate_info.wait()
        
        if status == 0:
            print "NBU Tester - Info - Successfully duplicated image " + image_to_dup + "."
            syslog.syslog(syslog.LOG_INFO, "NBU Tester - Info - Successfully duplicated image " + image_to_dup + ".")
            
        else:
            sys.stderr.write("NBU Tester - Error - Duplication failed, bpduplicate exited with a status of " + str(status) + ", exiting.\n")
            syslog.syslog(syslog.LOG_ERR, "NBU Tester - Error - Duplication failed, bpduplicate exited with a status of " + str(status) + ", exiting. - NOC-NETCOOL-TICKET")
            # Kill our watchdog process
            send_sigterm(pid)
            sys.exit(1)
        
        
    else:
        sys.stderr.write("NBU Tester - Error - Test job failed, bpbackup exited with a status of " + str(status) + ", exiting.\n")
        syslog.syslog(syslog.LOG_ERR, "NBU Tester - Error - Test job failed, bpbackup exited with a status of " + str(status) + ", exiting. - NOC-NETCOOL-TICKET")
        # Kill our watchdog process
        send_sigterm(pid)
        sys.exit(1)
        

    # Kill our watchdog process
    send_sigterm(pid)
    
    
print "NBU Tester - Info - Checking that the test policy has had a backup within the past 2 hours."
syslog.syslog(syslog.LOG_INFO, "NBU Tester - Getting list of images from the scheduled test policy.")

# Time out after 5 minutes
signal.alarm(60 * 5)

bpimagelist_info = subprocess.Popen(["/usr/openv/netbackup/bin/admincmd/bpimagelist", "-U", "-client", "nb-master-stage.cssd.pitt.edu"], stdout=subprocess.PIPE, stdin=None, shell=False)
status = bpimagelist_info.wait()

signal.alarm(0)    

highest_backup_time = 0

for line in bpimagelist_info.communicate()[0].split(os.linesep):
    if re.search("NBU-TESTER-SCHEDULED", line) is None:
        continue
    
    image_date = line.split()[0]
    month = int(image_date.split("/")[0])
    day = int(image_date.split("/")[1])
    year = int(image_date.split("/")[2])
    
    image_time = line.split()[1]
    hour = int(image_time.split(":")[0])
    minute = int(image_time.split(":")[1])
    
    backup_time_epoch = int(datetime.datetime(year, month, day, hour, minute).strftime('%s'))
    
    if backup_time_epoch > highest_backup_time:
        highest_backup_time = backup_time_epoch
        

if highest_backup_time == 0:
    sys.stderr.write("NBU Tester - Error - Failed to find any images from the scheduled test policy NBU-TESTER-SCHEDULED.\n")
    syslog.syslog(syslog.LOG_ERR, "NBU Tester - Error - Failed to find any images from the scheduled test policy NBU-TESTER-SCHEDULED. - NOC-NETCOOL-TICKET")

else:
    two_hours_in_seconds = 60 * 60 * 2
    
    time_diff = time.time() - highest_backup_time
    
    if time_diff > two_hours_in_seconds:
        sys.stderr.write("NBU Tester - Error - Latest image from scheduled test policy NBU-TESTER-SCHEDULED is greater than 2 hours old (" + str(time_diff) + " seconds), scheduler hung?\n")
        syslog.syslog(syslog.LOG_ERR, "NBU Tester - Error - Latest image from scheduled test policy NBU-TESTER-SCHEDULED is greater than 2 hours old (" + str(time_diff) + " seconds), scheduler hung? - NOC-NETCOOL-TICKET")

    else:
        print "NBU Tester - Info - Success, an image from the scheduled test job from within the past 2 hours was found."
        syslog.syslog(syslog.LOG_INFO, "NBU Tester - Info - Success, an image from the scheduled test job from within the past 2 hours was found.")


    
    print "NBU Tester - Info - NBU Tester complete."
    syslog.syslog(syslog.LOG_INFO, "NBU Tester - Info - NBU Tester complete.")



# We're done with syslog
syslog.closelog()
