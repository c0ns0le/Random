#!/usr/bin/env python
# Description: Run real or synthetic full backups in Netbackup based off a configuration file
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, re, syslog, signal, subprocess, datetime, traceback, time, ConfigParser, pickle
from optparse import OptionParser





# How were we called?
parser = OptionParser("%prog [options] config_file\n" + 
    "Run real or synthetic full backups in Netbackup based off a configuration file"
)

parser.add_option("-r", "--report",
    action="store_true", dest="report", default=False,
    help="Report mode, do no backup just show state of the policy (last backup time, synths remaining, etc.)"
)

parser.add_option("-f", "--force",
    action="store", dest="backup_type", type="string",
    help="Force a backup to run ignoring the failure count and schedueld weekday.  Requires an argument of 'real' or 'synth'."
)

parser.add_option("-s", "--set",
    action="store", dest="remaining_synths", type="int",
    help="Set the number of remaining synths, argument must be an integer."
)

(options, args) = parser.parse_args()





# Print a stack trace, exception, and an error string to STDERR
# and exit with the exit status given or don't exit
# if passed NoneType
def error(error_string, exit_status=1):
    red = "\033[31m"
    endcolor = "\033[0m"

    exc_type, exc_value, exc_traceback = sys.exc_info()
    if exc_type is not None:
        traceback.print_exception(exc_type, exc_value, exc_traceback)

    sys.stderr.write(red + str(error_string) + endcolor)
    
    if exit_status is not None:
        sys.exit(int(exit_status))



# Prepare for subprocess timeouts
class Alarm(Exception):
    pass

def alarm_handler(signum, frame):
    raise Alarm

signal.signal(signal.SIGALRM, alarm_handler)



# Return a "pretty" timestamp: 2013-07-04 13:58:47
def timestamp():
    return datetime.datetime.today().strftime("%Y-%m-%d %H:%M:%S")



# Save a pickle file keeping a copy of the previous one if possible
def save_pickle(pickle_file, data_structure):
    try:
        # Remove the old pickle
        try:
            os.unlink(pickle_file + "-old")
        
        except:
            pass
        
        try:
            os.rename(pickle_file, pickle_file + "-old")
            
        except:
            pass

        pickle_handle = open(pickle_file, "w")
        
        pickle.dump(data_structure, pickle_handle)
        
        pickle_handle.close()
        
        return True
        
    except:
        return False



# Check if a current backup is running for a given client and policy
# Returns:
#       None = No running job was found matching criteria
#       False = An error occurred
#       dict() with the keys: job_id, job_state, schedule
def backup_running(find_policy, find_client):
    running_job = dict()
    
    bpdbjobs_info = subprocess.Popen(["/usr/openv/netbackup/bin/admincmd/bpdbjobs", "-most_columns"], stdin=None, stdout=subprocess.PIPE, shell=False)
    out = bpdbjobs_info.communicate()[0]
    status = bpdbjobs_info.wait()
    
    if status == 0:
        for line in out.split(os.linesep):
            line = line.rstrip()
            
            if line == "":
                continue
            
            job_id = line.split(",")[0]
            job_state = line.split(",")[2] # 0=queued and awaiting resources, 1=active, 2=requeued and awaiting resources, 3=done, 4=suspended, 5=incomplete
            policy = line.split(",")[4]
            schedule = line.split(",")[5]
            client = line.split(",")[6]
            
            if client == find_client and policy == find_policy:
                if job_state == "0":
                    running_job["job_state"] = "queued"
                    running_job["job_id"] = job_id
                    running_job["schedule"] = schedule
                    
                elif job_state == "1":
                    running_job["job_state"] = "active"
                    running_job["job_id"] = job_id
                    running_job["schedule"] = schedule
                    
                elif job_state == "2":
                    running_job["job_state"] = "requeued"
                    running_job["job_id"] = job_id
                    running_job["schedule"] = schedule
                    
                else:
                    continue
            
    else:
        return False
    
    if len(running_job) == 0:
        return None
    
    else:
        return running_job
            



# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)





# Get the configs and fork a child to handle each one
child_pids = []
for policy_file in sys.argv[1:]:
    if not os.path.isfile(policy_file):
        continue
    
    policy_name = os.path.basename(policy_file)

    pid = os.fork()
    
    if pid != 0:
        child_pids.append(pid)
        
        print "NBU Synth Scheduler - Master (" + str(os.getpid()) + ") - " + timestamp() + " - Forked child '" + str(pid) + "' for policy file '" + policy_name + "'"
        
        if options.report is False:
            log_file_handle = open("/usr/local/nbu_synth_scheduler/logs/master.log", "a", 1)
            log_file_handle.write("NBU Synth Scheduler - Master (" + str(os.getpid()) + ") - " + timestamp() + " - Forked child '" + str(pid) + "' for policy file '" + policy_name + "'\n")
            log_file_handle.close()
        
        continue
        
    else:# We're the child
        os.setsid()
        
        # Open the config and verify we have all the settings we need
        config = ConfigParser.ConfigParser()
        config.read(policy_file)
            
        policy_config = dict(config.items("main"))

        for setting_name in ["client", "enabled", "num_synths_before_real_full", "frequency", "policy", "weekday"]:
            if setting_name not in policy_config:
                syslog.syslog(syslog.LOG_ERR, "NOc-NETCOOL-TICKET: NBU Synth Scheduler - " + policy_name + " - Missing configuration setting '" + setting_name + "', exiting.\n")
                error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Missing configuration setting '" + setting_name + "', exiting.")
                
                
                
        if options.report is False:
            log_file_handle = open("/usr/local/nbu_synth_scheduler/logs/" + re.sub("\.conf$", ".log", policy_name), "a", 1)
        
        

        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Starting run."
        if options.report is False:
            log_file_handle.write("\nNBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Starting run.\n")
                
                
                
        # If we have an existing non-zero pickle for the client and policy, open it and suck in its data
        pickle_file = "/usr/local/nbu_synth_scheduler/state_data/" + policy_config["policy"] + "_" + policy_config["client"] + ".pkl"
        try:
            pickle_file_size = os.stat(pickle_file).st_size
            
        except OSError:
            pickle_file_size = 0
        
        if os.path.exists(pickle_file) and pickle_file_size != 0:
            if options.report is False: log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Non-zero sized pickle file found, opening it.\n")
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Non-zero sized pickle file found, opening it."
            
            pickle_file_handle = open(pickle_file, "r")
            
            state_data = pickle.load(pickle_file_handle)
            
            pickle_file_handle.close()
        
        else:
            if options.report is False: log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - No pickle file found, starting initial run.\n")
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - No pickle file found, starting initial run."
            
            state_data = {
                "last_real_full" : 0,
                "last_synth_full" : 0,
                "num_synths_remaining" : 0,
                "failure_count" : 0,
            }
            
            
        state_data["client"] = policy_config["client"]
        state_data["enabled"] = policy_config["enabled"]
        state_data["num_synths_before_real_full"] = int(policy_config["num_synths_before_real_full"])
        state_data["frequency"] = policy_config["frequency"]
        state_data["policy"] = policy_config["policy"]
        state_data["weekday"] = policy_config["weekday"]
        
        if save_pickle(pickle_file, state_data) is not True:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'.\n")
            error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "\n", None)
            
        
        
        
        
        # If we were told to set the number of remaining synthetic fulls, do so and exit
        if options.remaining_synths is not None:
            if options.report is False:
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Setting number of remaining synthetic fulls to '" + str(options.remaining_synths) + "'.\n")
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Setting number of remaining synthetic fulls to '" + str(options.remaining_synths) + "'."
            
            state_data["num_synths_remaining"] = options.remaining_synths
            
            if save_pickle(pickle_file, state_data) is not True:
                if options.report is False:
                    log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'.\n")
                error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "\n")
                
            log_file_handle.close()
            sys.exit(0)
            
            
            
            
            
        # Show our current stats
        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Policy: " + policy_config["policy"]
        if options.report is False:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Policy: " + policy_config["policy"] + "\n")
        
        
        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Client: " + policy_config["client"]
        if options.report is False:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Client: " + policy_config["client"] + "\n")
            
            
        if policy_config["enabled"] == "1":
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Enabled: Yes"
            if options.report is False:
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Enabled: Yes\n")
                
        else:
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Enabled: No"
            if options.report is False:
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Enabled: No\n")
                
                
        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Frequency: " + state_data["frequency"]
        if options.report is False:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Frequency: " + state_data["frequency"] + "\n")
            
            
        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Weekday: " + state_data["weekday"]
        if options.report is False:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Weekday: " + state_data["weekday"] + "\n")
            
            
        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Number of synthetics before a real full: " + str(state_data["num_synths_before_real_full"])
        if options.report is False:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Number of synthetics before a real full: " + str(state_data["num_synths_before_real_full"]) + "\n")
        
        
        if state_data["last_real_full"] != 0:
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Last real full: " + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(state_data["last_real_full"]))
            if options.report is False:
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Last real full: " + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(state_data["last_real_full"])) + "\n")
            
        else:
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Last real full: never"
            if options.report is False:
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Last real full: never\n")
            
            
        if state_data["last_synth_full"] != 0:
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Last synth full: " + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(state_data["last_synth_full"]))
            if options.report is False:
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Last synth full: " + time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(state_data["last_synth_full"])) + "\n")
            
        else:
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Last synth full: never"
            if options.report is False:
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Last synth full: never\n")
            
            
        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Number of synthetic fulls remaining: " + str(state_data["num_synths_remaining"])
        if options.report is False:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Number of synthetic fulls remaining: " + str(state_data["num_synths_remaining"]) + "\n")
            
            
        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count: " + str(state_data["failure_count"])
        if options.report is False:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count: " + str(state_data["failure_count"]) + "\n")
            
            
        # If we are in report mode, exit now
        if options.report is True:
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Ending report mode run."
            
            if options.report is False:
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Ending report mode run.\n")
                log_file_handle.close()
                
            sys.exit(0)





        # Were we told to do a forced backup?
        if options.backup_type is not None:
            start_time = time.time()
            
            if options.backup_type.lower() == "real":
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Forced real full backup requested, starting backup.\n")
                print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Forced real full backup requested, starting backup."
                
                bpbackup_info = subprocess.Popen(["/usr/openv/netbackup/bin/bpbackup", "-i", "-p", state_data["policy"], "-s", "REAL-FULL", "-w"], stdin=None, shell=False)
                status = bpbackup_info.wait()
                
                if status == 0:
                    log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup was successful, ending run.\n\n")
                    print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup was successful, ending run."
                    
                    state_data["last_real_full"] = start_time
                    state_data["num_synths_remaining"] = int(state_data["num_synths_before_real_full"])
                    state_data["failure_count"] = 0
                    
                    if save_pickle(pickle_file, state_data) is not True:
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'\n.", None)
                    
                else:
                    log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup failed with exit status '" + str(status) + "', ending run.\n")
                    print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup failed with exit status '" + str(status) + "', ending run."
                    
                log_file_handle.close()
                sys.exit(0)
                
                
            elif options.backup_type.lower() == "synth":
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Forced synthetic full backup requested, starting backup.\n")
                print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Forced synthetic full backup requested, starting backup."
                
                bpbackup_info = subprocess.Popen(["/usr/openv/netbackup/bin/bpbackup", "-i", "-p", state_data["policy"], "-s", "SYNTH-FULL", "-w"], stdin=None, shell=False)
                status = bpbackup_info.wait()
                
                if status == 0:
                    log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup was successful, ending run.\n")
                    print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup was successful, ending run."
                    
                    state_data["last_synth_full"] = start_time
                    state_data["num_synths_remaining"] = state_data["num_synths_remaining"] - 1
                    state_data["failure_count"] = 0
                    
                    if save_pickle(pickle_file, state_data) is not True:
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'\n.", None)
                    
                else:
                    log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup failed with exit status '" + str(status) + "', ending run.\n")
                    print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup failed with exit status '" + str(status) + "', ending run."
                    
                log_file_handle.close()
                sys.exit(0)
                
            else:
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Forced backup option detected with invalid option, see --help, exiting.\n")
                error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Forced backup option detected with invalid option, see --help, exiting.")
                
                log_file_handle.close()
                sys.exit(1)
                
                
                
        
                
        # If we got here we were not told to do a manual backup or anything else
        # so now we need to determine if we should run a scheduled backup or not

        # Has it been long enough since the last full backup to try to run one?
        last_full_backup = 0
        
        if state_data["last_real_full"] > last_full_backup:
            last_full_backup = state_data["last_real_full"]
            
        if state_data["last_synth_full"] > last_full_backup:
            last_full_backup = state_data["last_synth_full"]
            
        # Set the frequency to 1 hour less than the real frequency since we are comparing seconds
        # and not days (it would be silly to not run a monthly backup because it has only been 
        # 27 days, 23 hours, 59 minutes and 47 seconds and not >= 28 days)
        if state_data["frequency"].lower() == "monthly":
            frequency_seconds = (60 * 60 * 24 * 28) - (60 * 60)
            
        elif state_data["frequency"].lower() == "weekly":
            frequency_seconds = (60 * 60 * 24 * 7) - (60 * 60)
            
        else:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Invalid frequency specified, only 'monthly' and 'weekly' are supported, exiting.\n")
            error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Invalid frequency specified, only 'monthly' and 'weekly' are supported, exiting.")
            
        if not (time.time() - last_full_backup) > frequency_seconds:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Not enough time has passed since the last full backup for another scheduled backup to run, exiting.\n")
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Not enough time has passed since the last full backup for another scheduled backup to run, exiting."
            
            log_file_handle.close()
            sys.exit(0)



        # Is the failure count already too high to attempt another backup?
        if state_data["failure_count"] >= 3:
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: NBU Synth Scheduler - " + policy_name + " - Failure count '" + str(state_data["failure_count"]) + "' is equal to or greater than threshold of 3.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.")
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is equal to or greater than threshold of 3.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.\n")
            error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is equal to or greater than threshold of 3.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.\n")
            
            log_file_handle.close()
            sys.exit(0)



        # Are we on our scheduled day to run a backup?
        if not datetime.date.fromtimestamp(time.time()).strftime("%A").lower() == state_data["weekday"]:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - A full backup is ready to be ran but today is not the scheduled weekday (" + state_data["weekday"] + ") to do so, exiting.\n")
            print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - A full backup is ready to be ran but today is not the scheduled weekday (" + state_data["weekday"] + ") to do so, exiting."
            
            log_file_handle.close()
            sys.exit(0)



        # See if a job is already running for thie policy and client
        running_job = backup_running(state_data["policy"], state_data["client"])
        
        if running_job is False:
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to determine if a job for the specified policy and client is currently running, exiting.\n")
            error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to determine if a job for the specified policy and client is currently running, exiting.\n")
            
        elif running_job is not None:
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: NBU Synth Scheduler - " + policy_name + " - A job (ID: " + running_job["job_id"] + ", state: " + running_job["job_state"] + ", schedule: " + running_job["schedule"] + ") is currently running on the specified policy and client, cannot run scheduled full backup, exiting.")
            log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - A job (ID: " + running_job["job_id"] + ", state: " + running_job["job_state"] + ", schedule: " + running_job["schedule"] + ") is currently running on the specified policy and client, cannot run scheduled full backup, exiting.\n")
            error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - A job (ID: " + running_job["job_id"] + ", state: " + running_job["job_state"] + ", schedule: " + running_job["schedule"] + ") is currently running on the specified policy and client, cannot run scheduled full backup, exiting.\n")
        
        
        
        # If we never did a real full or there are no more synthetic fulls to run, try to run a real full
        if state_data["last_real_full"] == 0 or state_data["num_synths_remaining"] == 0:
            # If we got here then it is our scheduled day to run and no other job for this policy and client is running, run the real full backup
            while True:
                start_time = time.time()
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Starting scheduled real full backup.\n")
                print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Starting scheduled real full backup."
                
                bpbackup_info = subprocess.Popen(["/usr/openv/netbackup/bin/bpbackup", "-i", "-p", state_data["policy"], "-s", "REAL-FULL", "-w"], stdin=None, stderr=log_file_handle, shell=False)
                status = bpbackup_info.wait()
                
                if status == 0:
                    log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup was successful, ending run.\n")
                    print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup was successful, ending run."
                    
                    state_data["last_real_full"] = start_time
                    state_data["num_synths_remaining"] = state_data["num_synths_before_real_full"]
                    state_data["failure_count"] = 0
                    
                    if save_pickle(pickle_file, state_data) is not True:
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'\n.", None)
                        
                    break
                    
                else:
                    state_data["failure_count"] = state_data["failure_count"] + 1
                    
                    if save_pickle(pickle_file, state_data) is not True:
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'\n.", None)
                    
                    log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup failed with exit status '" + str(status) + "'.\n")
                    print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup failed with exit status '" + str(status) + "'."
                    
                    # Are we already over our failure count threshold?  If so, error and bail out
                    if state_data["failure_count"] >= 3:
                        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: NBU Synth Scheduler - " + policy_name + " - Failure count '" + str(state_data["failure_count"]) + "' is equal to or greater than 3.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.")
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is equal to or greater than 3.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is equal to or greater than 3.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.\n")

                    # If we are still on our scheduled weekday, retry the backup
                    if datetime.date.fromtimestamp(time.time()).strftime("%A").lower() == state_data["weekday"]:
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is less than 3 and today is still the scheduled weekday, retrying backup.\n")
                        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is less than 3 and today is still the scheduled weekday, retrying backup."
                        
                        continue
                        
                    else:
                        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: NBU Synth Scheduler - " + policy_name + " - Today is no longer the scheduled weekday, unable to retry backup.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.")
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Today is no longer the scheduled weekday, unable to retry backup.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Today is no longer the scheduled weekday, unable to retry backup.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.")
                
        
        
        else:
            # If we got here then it is our scheduled day to run and no other job for this policy and client is running, run the synthetic full backup
            while True:
                start_time = time.time()
                log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Starting scheduled synthetic full backup.\n")
                print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Starting scheduled synthetic full backup."
                
                bpbackup_info = subprocess.Popen(["/usr/openv/netbackup/bin/bpbackup", "-i", "-p", state_data["policy"], "-s", "SYNTH-FULL", "-w"], stdin=None, stderr=log_file_handle, shell=False)
                status = bpbackup_info.wait()
                
                if status == 0:
                    log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup was successful, ending run.\n")
                    print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup was successful, ending run."
                    
                    state_data["last_synth_full"] = start_time
                    state_data["num_synths_remaining"] = state_data["num_synths_remaining"] - 1
                    state_data["failure_count"] = 0
                    
                    if save_pickle(pickle_file, state_data) is not True:
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'\n.", None)
                        
                    break
                    
                else:
                    state_data["failure_count"] = state_data["failure_count"] + 1
                    
                    if save_pickle(pickle_file, state_data) is not True:
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failed to save state data into pickle file '" + pickle_file + "'\n.", None)
                    
                    log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup failed with exit status '" + str(status) + "'.\n")
                    print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Backup failed with exit status '" + str(status) + "'."
                    
                    # Are we already over our failure count threshold?  If so, error and bail out
                    if state_data["failure_count"] >= 3:
                        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: NBU Synth Scheduler - " + policy_name + " - Failure count '" + str(state_data["failure_count"]) + "' is equal to or greater than 3.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.")
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is equal to or greater than threshold of 3.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is equal to or greater than threshold of 3.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.\n")

                    # If we are still on our scheduled weekday, retry the backup
                    if datetime.date.fromtimestamp(time.time()).strftime("%A").lower() == state_data["weekday"]:
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is less than threshold of 3 and today is still the scheduled weekday, retrying backup in 30 minutes.\n")
                        print "NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Failure count '" + str(state_data["failure_count"]) + "' is less than threshold of 3 and today is still the scheduled weekday, retrying backup in 30 minutes."
                        
                        # Wait 30 minutes in case there was a temporary problem which is now cleared
                        sleep_until = time.time() + (60 * 30)
                        
                        while True:
                            time.sleep(60)
                            
                            if time.time() >= sleep_until:
                                break
                        
                        continue
                        
                    else:
                        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: NBU Synth Scheduler - " + policy_name + " - Today is no longer the scheduled weekday, unable to retry backup.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.")
                        log_file_handle.write("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Today is no longer the scheduled weekday, unable to retry backup.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.\n")
                        error("NBU Synth Scheduler - " + policy_name + " - " + timestamp() + " - Today is no longer the scheduled weekday, unable to retry backup.  Correct the issue preventing a successful backup and run one by hand using the --force option (see --help), exiting.")
            
                
                
                
        log_file_handle.close()
        sys.exit(0)





# Wait for our children to exit
for child_pid in child_pids:
    os.waitpid(child_pid, 0)
    
print "NBU Synth Scheduler - Master (" + str(os.getpid()) + ") - " + timestamp() + " - All child processes exited, exiting."
if options.report is False:
    log_file_handle = open("/usr/local/nbu_synth_scheduler/logs/master.log", "a", 1)
    log_file_handle.write("NBU Synth Scheduler - Master (" + str(os.getpid()) + ") - " + timestamp() + " - All child processes exited, exiting\n")
    log_file_handle.close()
sys.exit(0)
