#!/usr/bin/env python
# Description: Create a usage report of the Frank cluster
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 2.1
# Last change: Fixed the FROM address to a valid DNS name

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
import signal
import smtplib
import datetime
import time
import locale
import ConfigParser
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email import Encoders
from optparse import OptionParser



config_file = "/usr/local/etc/frank_stats_gen.conf"



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Frank usage statistics generator.  This program will use `showstats` " + 
    "to create a CSV of cluster user by group for the past 30 days.\n"
)

(options, args) = parser.parse_args()



# Prepare for subprocess timeouts
class Alarm(Exception):
    pass

def alarm_handler(signum, frame):
    raise Alarm

signal.signal(signal.SIGALRM, alarm_handler)



class group_class:
    pass


    
locale.setlocale(locale.LC_ALL, 'en_US')



# Get the group data
config = ConfigParser.ConfigParser()
config.read(config_file)   
    

    
#
# Get the usage data
#
signal.alarm(60 * 5)

try:
    showstats_info = subprocess.Popen(["/opt/sam/moab/6.1.7/bin/showstats", "-g", "-t", "+30:00:00:00"], stdin=None, stdout=subprocess.PIPE)
    showstats_out = showstats_info.communicate()[0]
    
    signal.alarm(0)

except Alarm:
    sys.stdout.write("Usage statistics generator failed: Timeout on `showstats`\n")
    
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Usage statistics generator failed: Timeout on `showstats`")
        
except Exception as err:
    sys.stderr.write("Usage statistics generator failed: " + str(err) + "\n")
    
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Usage statistics generator failed: " + str(err))
    
    sys.exit(1)
  
  
  
    
  
#
# CSV header
#
csv_data = []
csv_data.append("Stats for completed jobs from " + datetime.datetime.fromtimestamp(time.time() - (60 * 60 * 24 * 30)).strftime("%Y-%m-%d") + " to " + datetime.datetime.today().strftime("%Y-%m-%d") + ",,,,,,,,,\n")
csv_data.append("Department,PI,Group,Jobs,%,PHReq,%,PHDed,%\n")




#
# Loop through the showstats output and get the data
#
totals = {
    "active_jobs" : 0,
    "active_procs" : 0,
    "active_prochours" : 0,
    "completed_jobs" : 0,
    "processor_hours_requested" : 0,
    "processor_hours_dedicated" : 0,
}

for line in showstats_out.split(os.linesep):
    line = line.rstrip()
    
    # Skip the header and blank lines
    if re.search("^$", line) or re.search("^statistics initialized", line) or re.search("^\s+|------ Active", line) or re.search("^group", line):
        continue
    
    line_data = line.split()
    
    group_name = line_data[0]
    completed_jobs = line_data[4]
    completed_jobs_percent = line_data[5]
    processor_hours_requested = line_data[6]
    processor_hours_requested_percent = line_data[7]
    processor_hours_dedicated = line_data[8]
    processor_hours_dedicated_percent = line_data[9]
    
    
    if completed_jobs == "------": completed_jobs = 0
    if completed_jobs_percent == "------": completed_jobs_percent = 0
    if processor_hours_requested == "------": processor_hours_requested = 0
    if processor_hours_requested_percent == "------": processor_hours_requested_percent = 0
    if processor_hours_dedicated == "------": processor_hours_dedicated = 0
    if processor_hours_dedicated_percent == "------": processor_hours_dedicated_percent = 0


    if re.search("K$", str(completed_jobs)) is not None:
        completed_jobs = re.sub("K$", "", str(completed_jobs))
        completed_jobs = float(completed_jobs) * float(1000)
        
    if re.search("K$", str(processor_hours_requested)) is not None:
        processor_hours_requested = re.sub("K$", "", str(processor_hours_requested))
        processor_hours_requested = float(processor_hours_requested) * float(1000)
        
    if re.search("K$", str(processor_hours_dedicated)) is not None:
        processor_hours_dedicated = re.sub("K$", "", str(processor_hours_dedicated))
        processor_hours_dedicated = float(processor_hours_dedicated) * float(1000)
        
        
    completed_jobs = int(completed_jobs)
    completed_jobs_percent = float(completed_jobs_percent)
    processor_hours_requested = float(processor_hours_requested)
    processor_hours_requested_percent = float(processor_hours_requested_percent)
    processor_hours_dedicated = float(processor_hours_dedicated)
    processor_hours_dedicated_percent = float(processor_hours_dedicated_percent)
        
    
    print "Group: " + group_name
    print "Completed jobs: " + locale.format("%d", completed_jobs, grouping=True) + " (" + str(completed_jobs_percent) + "%)"
    print "Processor hours requested: " + locale.format("%0.2f", processor_hours_requested, grouping=True) + " (" + str(processor_hours_requested_percent) + "%)"
    print "Process hours dedicated: " + locale.format("%0.2f", processor_hours_dedicated, grouping=True) + " (" + str(processor_hours_dedicated_percent) + "%)"
    print

    totals["completed_jobs"] += completed_jobs
    totals["processor_hours_requested"] += processor_hours_requested
    totals["processor_hours_dedicated"] += processor_hours_dedicated
    
    # Catch new groups
    try:
        group_department = config.get(group_name, "dept")
        group_pi = config.get(group_name, "pi")
        
    except ConfigParser.NoSectionError:
        group_department = "UNKNOWN"
        group_pi = "UNKNOWN"
        
    
    
    # Add the line to the CSV
    csv_data.append(group_department + "," + group_pi + "," + group_name + "," +
    str(completed_jobs) + "," + str(completed_jobs_percent) + "," + 
    str(processor_hours_requested) + "," + str(processor_hours_requested_percent) + "," + 
    str(processor_hours_dedicated) + "," + str(processor_hours_dedicated_percent) + "\n")
    
    
    
    
    
#
# Totals
#
csv_data.append("TOTAL:,,," + str(totals['completed_jobs']) + ",," + str(totals['processor_hours_requested']) + ",," + str(totals['processor_hours_dedicated']) + ",\n")





#
# CSV key
#
csv_data.append(",,,,,,,,\n")
csv_data.append("Reference Key,,,,,,,,\n")
csv_data.append("Jobs,Number of jobs completed.,,,,,,,\n")
csv_data.append("%,Percentage of total jobs that were completed by group.,,,,,,,\n")
csv_data.append("PHReq,Total proc-hours requested by completed jobs.,,,,,,,\n")
csv_data.append("%,Percentage of total proc-hours requested by completed jobs that were requested by group.,,,,,,,\n")
csv_data.append("PHDed,Total proc-hours dedicated to active and completed jobs (allocated hours regardless of the job's CPU usage).,,,,,,,\n")
csv_data.append("%,Percentage of total proc-hours dedicated that were dedicated by group.,,,,,,,\n")





#
# Send the final CSV
#
# Message
msg = MIMEMultipart()
msg["From"] = "null@pitt.edu"
msg["To"] = "jaw171@pitt.edu"
msg["Subject"] = "Frank Usage Statistics"
msg.attach(MIMEText("Attached...\n"))

# Attachment
part = MIMEBase('application', "octet-stream")
part.set_payload("".join(csv_data))
Encoders.encode_base64(part)
part.add_header("Content-Disposition", 'attachment; filename="Frank_Usage_Statistics.csv"')
msg.attach(part)

# Send it
smtp = smtplib.SMTP('localhost')
smtp.sendmail("null@pitt.edu", ["jaw171@pitt.edu"], msg.as_string())
smtp.quit()
