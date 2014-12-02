#!/usr/bin/env python
# Description: Report changes to NetBackup policies, clients and schedules
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
import pickle
import datetime
import difflib
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Report changes to NetBackup policies and schedules.\n" +
    "WARNING: This program compares against the last known state of policies and schedules.\n" + 
    "This means running this will affect the next run's report!\n" + 
    "State data is held in /usr/local/nb_policy_reporter/.\n"
)

(options, args) = parser.parse_args()





#
# Preparation
#

# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_SYSLOG)



# Prepare needed directories
if not os.path.isdir("/usr/local/nb_policy_reporter"):
    try:
        os.mkdir("/usr/local/nb_policy_reporter", 0755)
        
    except Exception as err:
        sys.stderr.write("Failed to create directory /usr/local/nb_policy_reporter: " + str(err) + " - EXITING\n")
        #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to create directory /usr/local/nb_policy_reporter - EXITING")
    
        sys.exit(1)

        
        
class policy_class:
    pass

class schedule_class:
    pass
        
        
        
# The main data structures
clients = {
    "current_list" : [],
    "last_list" : [],
    "new_list" : [],
    "removed_list" : [],
}
schedules = {
    "current_list" : [],
    "last_list" : [],
    "new_list" : [],
    "removed_list" : [],
    "eachschedulename" : {
        "current_data" : [],
        "last_data" : [],
    },
}
policies = {
    "current_list" : [],
    "last_list" : [],
    "new_list" : [],
    "removed_list" : [],
    "eachpolicyname" : {
        "current_data" : [],
        "last_data" : [],
    },
}





#
# Get the previous data
#

# Clients
try:
    if os.path.isfile("/usr/local/nb_policy_reporter/clients.pkl"):
        pickle_handle = open("/usr/local/nb_policy_reporter/clients.pkl", "r")
        
        clients = pickle.load(pickle_handle)
        
        pickle_handle.close()
        
    else:
        sys.stderr.write("WARNING: Previous data for clients not found, moving on anyway\n")
    
    
except Exception as err:
    sys.stderr.write("Failed to get the get the previous data for clients: " + str(err) + "\n")
    #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get the get the previous data for clients:"  + str(err))
    
    
# Schedules
try:
    if os.path.isfile("/usr/local/nb_policy_reporter/schedules.pkl"):
        pickle_handle = open("/usr/local/nb_policy_reporter/schedules.pkl", "r")
        
        schedules = pickle.load(pickle_handle)
        
        pickle_handle.close()
        
    else:
        sys.stderr.write("WARNING: Previous data for schedules not found, moving on anyway\n")
    
    
except Exception as err:
    sys.stderr.write("Failed to get the get the previous data for schedules: " + str(err) + "\n")
    #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get the get the previous data for schedules:"  + str(err))
    
    
# Policies
try:
    if os.path.isfile("/usr/local/nb_policy_reporter/policies.pkl"):
        pickle_handle = open("/usr/local/nb_policy_reporter/policies.pkl", "r")
        
        policies = pickle.load(pickle_handle)
        
        pickle_handle.close()
        
    else:
        sys.stderr.write("WARNING: Previous data for policies not found, moving on anyway\n")
    
    
except Exception as err:
    sys.stderr.write("Failed to get the get the previous data for policies: " + str(err) + "\n")
    #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get the get the previous data for policies:"  + str(err))
    
    
    
# Move current to last
clients["last_list"] = clients["current_list"][:]
schedules["last_list"] = schedules["current_list"][:]
policies["last_list"] = policies["current_list"][:]
clients["current_list"] = []
schedules["current_list"] = []
policies["current_list"] = []
        
        
        
        
        
#
# Clients
#

# Get the current list of clients
try:
    clients_proc = subprocess.Popen(["/usr/openv/netbackup/bin/admincmd/bpplclients"], stdin=None, stdout=subprocess.PIPE, shell=False)
    out = clients_proc.communicate()[0]
    
    for line in out.split(os.linesep):
        line = line.rstrip()
        
        # Skip the header lines and add the client to the current list of clients
        match = re.search("^(Hardware\s+|-+|^\s*$)", line)
        if match: continue
        
        clients["current_list"].append(line.lower().split()[2])
        
        
except Exception as err:
    sys.stderr.write("Failed to get the current list of clients: " + str(err) + " - EXITING\n")
    #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get current list of clients - EXITING")
    
    sys.exit(1)
        
        
        
# Compare the client lists   
clients["new_list"] = [i for i in clients["current_list"] if i not in clients["last_list"]]
clients["removed_list"] = [i for i in clients["last_list"] if i not in clients["current_list"]]
        
        
        
        

#
# Policies
#

# Get the current list of policies
try:
    policies_proc = subprocess.Popen(["/usr/openv/netbackup/bin/admincmd/bppllist", "-allpolicies", "-L"], stdin=None, stdout=subprocess.PIPE, shell=False)
    out = policies_proc.communicate()[0]
    
    for line in out.split(os.linesep):
        line = line.rstrip()
        
        if re.match("^$", line): continue
        
        match = re.match("^Policy Name:\s+(.*)$", line)

        # We hit a new policy
        if match:
            policy = match.group(1)
            
            policies["current_list"].append(policy)
        
            # Move current to last and create the policy object
            policy_obj = policy_class()
            policy_obj.name = policy
            policy_obj.current_data = []
            try:
                if policies[policy_obj.name]:
                    policy_obj.last_data = policies[policy_obj.name].current_data[:]
            except KeyError:
                policy_obj.last_data = []
                
            policies[policy_obj.name] = policy_obj
            
        # We hit a config line
        else:
            policies[policy_obj.name].current_data.append(line + "\n")
            
            
except Exception as err:
    sys.stderr.write("Failed to get the current list of policies: " + str(err) + " - EXITING\n")
    #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get current list of policies - EXITING")
    
    sys.exit(1)



# Compare the policy lists   
policies["new_list"] = [i for i in policies["current_list"] if i not in policies["last_list"]]
policies["removed_list"] = [i for i in policies["last_list"] if i not in policies["current_list"]]





#
# Schedules
#

# Get the current list of schedules
current_schedules = []
try:
    schedules_proc = subprocess.Popen(["/usr/openv/netbackup/bin/admincmd/bpschedule", "-L"], stdin=None, stdout=subprocess.PIPE, shell=False)
    out = schedules_proc.communicate()[0]
    
    for line in out.split(os.linesep):
        line = line.rstrip()
        
        if re.match("^$", line): continue
        
        match = re.match("^Schedule:\s+(.*)$", line)

        # We hit a new schedule
        if match:
            schedule = match.group(1)
            
            schedules["current_list"].append(schedule)
        
            # Move current to last and create the schedule object
            schedule_obj = schedule_class()
            schedule_obj.name = schedule
            schedule_obj.current_data = []
            try:
                if schedules[schedule_obj.name]:
                    schedule_obj.last_data = schedules[schedule_obj.name].current_data[:]
            except KeyError:
                schedule_obj.last_data = []
                
            schedules[schedule_obj.name] = schedule_obj
            
        # We hit a config line
        else:
            schedules[schedule_obj.name].current_data.append(line + "\n")
        
        
except Exception as err:
    sys.stderr.write("Failed to get the current list of schedules: " + str(err) + " - EXITING\n")
    #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get current list of schedules - EXITING")
    
    sys.exit(1)



# Compare the schedule lists   
schedules["new_list"] = [i for i in schedules["current_list"] if i not in schedules["last_list"]]
schedules["removed_list"] = [i for i in schedules["last_list"] if i not in schedules["current_list"]]





        
        
#
# Final output
#
        
sys.stdout.write("Server: " + os.uname()[1] + "\n")
sys.stdout.write("Date: " + datetime.datetime.today().strftime("%Y-%m-%d at %T") + "\n")
if os.path.exists("/usr/local/nb_policy_reporter/policies.pkl"):
    sys.stdout.write("Differences since: " + datetime.datetime.fromtimestamp(os.stat("/usr/local/nb_policy_reporter/policies.pkl")[8]).strftime("%Y-%m-%d at %T") + "\n\n")
else:
    sys.stdout.write("Differences since: The beginning of time\n\n")


# Counts
sys.stdout.write("New clients: " + str(len(clients["new_list"])) + "\n")
sys.stdout.write("Removed clients: " + str(len(clients["removed_list"])) + "\n")

sys.stdout.write("New policies: " + str(len(policies["new_list"])) + "\n")
sys.stdout.write("Removed policies: " + str(len(policies["removed_list"])) + "\n")

sys.stdout.write("New schedules: " + str(len(schedules["new_list"])) + "\n")
sys.stdout.write("Removed schedules: " + str(len(schedules["removed_list"])) + "\n")


# Change list
if len(clients["new_list"]) > 0:
    sys.stdout.write("\nNew clients:\n")
    for client in sorted(clients["new_list"]):
        sys.stdout.write(client + "\n")
        
if len(clients["removed_list"]) > 0:
    sys.stdout.write("\nRemoved clients:\n")
    for client in sorted(clients["removed_list"]):
        sys.stdout.write(client + "\n")
        
        
if len(policies["new_list"]) > 0:
    sys.stdout.write("\nNew policies:\n")
    for policy in sorted(policies["new_list"]):
        sys.stdout.write(policy + "\n")
        
if len(policies["removed_list"]) > 0:
    sys.stdout.write("\nRemoved policies:\n")
    for policy in sorted(policies["removed_list"]):
        sys.stdout.write(policy + "\n")
    

if len(schedules["new_list"]) > 0:
    sys.stdout.write("\nNew schedules:\n")
    for schedule in sorted(schedules["new_list"]):
        sys.stdout.write(schedule + "\n")
        
if len(schedules["removed_list"]) > 0:
    sys.stdout.write("\nRemoved schedules:\n")
    for schedule in sorted(schedules["removed_list"]):
        sys.stdout.write(schedule + "\n")
    
    
    
# Compare the current and last version of each policy
for policy in sorted(policies["current_list"]):
    # Skip new policies
    if policy in policies["new_list"]:
        continue
    
    # Are the current policy and the old policy different?
    if len(set(policies[policy].current_data).difference(policies[policy].last_data)) is not 0:
        diff = list(difflib.unified_diff(policies[policy].last_data, policies[policy].current_data, n=0))
        
        # Remove junk I don't want
        del diff[0]
        del diff[0]
        pretty_diff = []
        for line in diff:
            if not re.search("^@@", line) and not re.search("^.Generation", line):
                pretty_diff.append(line)
        
        sys.stdout.write("\n\nChanges in policy " + policy + ":\n" + "".join(pretty_diff))

        
        
# Compare the current and last version of each schedule
for schedule in sorted(schedules["current_list"]):
    # Skip new schedules
    if schedule in schedules["new_list"]:
        continue
    
    # Are the current schedule and the old schedule different?
    if len(set(schedules[schedule].current_data).difference(schedules[schedule].last_data)) is not 0:
        diff = list(difflib.unified_diff(schedules[schedule].last_data, schedules[schedule].current_data, n=0))
        
        # Remove junk I don't want
        del diff[0]
        del diff[0]
        pretty_diff = []
        for line in diff:
            if not re.search("^@@", line):
                pretty_diff.append(line)
        
        sys.stdout.write("\n\nChanges in schedule " + schedule + ":\n" + "".join(pretty_diff))
    
    
    
    
#
# Save the current data
#

# Clients
try:
    # Remove the old pickle
    try:
        os.unlink("/usr/local/nb_policy_reporter/clients.pkl-old")
    
    except:
        pass
    
    try:
        os.rename("/usr/local/nb_policy_reporter/clients.pkl", "/usr/local/nb_policy_reporter/clients.pkl-old")
        
    except:
        pass
    
    pickle_handle = open("/usr/local/nb_policy_reporter/clients.pkl", "w")
    
    pickle.dump(clients, pickle_handle)
    
    pickle_handle.close()


except Exception as err:
    sys.stderr.write("Failed to get the save the current data for clients: " + str(err) + "\n")
    #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get the save the current data for clients: " + str(err))
    
    
    
# Schedules
try:
    # Remove the old pickle
    try:
        os.unlink("/usr/local/nb_policy_reporter/schedules.pkl-old")
        
    except:
        pass
    
    try:
        os.rename("/usr/local/nb_policy_reporter/schedules.pkl", "/usr/local/nb_policy_reporter/schedules.pkl-old")
        
    except:
        pass
    
    pickle_handle = open("/usr/local/nb_policy_reporter/schedules.pkl", "w")
    
    pickle.dump(schedules, pickle_handle)
    
    pickle_handle.close()


except Exception as err:
    sys.stderr.write("Failed to get the save the current data for schedules: " + str(err) + "\n")
    #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get the save the current data for schedules: " + str(err))
    
    
    
# Policies
try:
    # Remove the old pickle
    try:
        os.unlink("/usr/local/nb_policy_reporter/policies.pkl-old")
        
    except:
        pass
    
    try:
        os.rename("/usr/local/nb_policy_reporter/policies.pkl", "/usr/local/nb_policy_reporter/policies.pkl-old")
        
    except:
        pass
    
    pickle_handle = open("/usr/local/nb_policy_reporter/policies.pkl", "w")
    
    pickle.dump(policies, pickle_handle)
    
    pickle_handle.close()


except Exception as err:
    sys.stderr.write("Failed to get the save the current data for policies: " + str(err) + "\n")
    #syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed to get the save the current data for policies: " + str(err))
    
    
    
    
    
# Done
syslog.closelog()
