#!/usr/bin/env python
# Description: Perform a hot or cold backup of Redhat Satellite's database
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, re, syslog, signal, subprocess, glob, datetime, traceback, time
from optparse import OptionParser





# How were we called?
parser = OptionParser("%prog [options] cold|hot\n" + 
    "Perform a hot or cold backup of Redhat Satellite's database"
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



# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)



# Should we do a hot or cold backup?
if len(sys.argv) == 1:
    syslog.syslog(syslog.LOG_ERR, "Redhat Satellite DB Backup - Error - Required argument 'hot' or 'cold' not specified, exiting. - NOC-NETCOOL-TICKET\n")
    error("Redhat Satellite DB Backup - Error - Required argument 'hot' or 'cold' not specified, exiting.\n")

backup_type = sys.argv[1].lower()





if backup_type == "hot":
    current_backup_file = "/var/satellite/db_backup/" + datetime.datetime.now().strftime("%Y-%m-%d") + "_hot.sql"

    # Do the backup
    syslog.syslog(syslog.LOG_INFO, "Redhat Satellite DB Backup - Info - Performing hot database backup.\n")
    print "Redhat Satellite DB Backup - Info - Performing hot database backup."
    
    db_control_info = subprocess.Popen(["/usr/bin/db-control", "online-backup", current_backup_file], stdin=None, shell=False)
    status = db_control_info.wait()

    if status != 0:
        syslog.syslog(syslog.LOG_ERR, "Redhat Satellite DB Backup - Error - db-control returned non-zero error code " + str(status) + ", exiting. - NOC-NETCOOL-TICKET")
        error("Redhat Satellite DB Backup - Error - db-control returned non-zero error code " + str(status) + ", exiting.\n")
        
        
    # Remove hot backups older than a 8 days
    syslog.syslog(syslog.LOG_INFO, "Redhat Satellite DB Backup - Info - Removing hot backups older than 8 days.\n")
    print "Redhat Satellite DB Backup - Info - Removing hot backups older than 8 days."

    todays_epoch = int(time.time())
    seven_days_in_seconds = 60 * 60 * 24 * 8

    for each_file in glob.glob("/var/satellite/db_backup/*_hot.sql"):
        file_creation_time = int(os.path.getctime(each_file))
        
        if (todays_epoch - file_creation_time) > seven_days_in_seconds:
            print "Removing old hot backup " + each_file
            
            try:
                os.unlink(each_file)
                
            except:
                syslog.syslog(syslog.LOG_ERR, "Redhat Satellite DB Backup - Error - Failed to remove " + each_file + ". - NOC-NETCOOL-TICKET\n")
                error("Redhat Satellite DB Backup - Error - Failed to remove " + each_file + ".\n", None)
    

elif backup_type == "cold":
    # Shut down the Satellite daemoms
    syslog.syslog(syslog.LOG_INFO, "Redhat Satellite DB Backup - Info - Shutting down Satellite daemons for cold database backup.\n")
    print "Redhat Satellite DB Backup - Info - Shutting down Satellite daemons for cold database backup."
    
    rhn_satellite_info = subprocess.Popen(["/usr/sbin/rhn-satellite", "stop"], stdin=None, shell=False)
    status = rhn_satellite_info.wait()

    if status != 0:
        syslog.syslog(syslog.LOG_ERR, "Redhat Satellite DB Backup - Error - rhn-satellite returned non-zero error code " + str(status) + " while shutting down Satellite daemons, exiting. - NOC-NETCOOL-TICKET")
        error("Redhat Satellite DB Backup - Error - rhn-satellite returned non-zero error code " + str(status) + " while shutting down Satellite daemons, exiting.\n")
    
    
    # Verify daemons are stopped
    rhn_satellite_info = subprocess.Popen(["/usr/sbin/rhn-satellite", "status"], stdin=None, stdout=subprocess.PIPE, shell=False)
    status = rhn_satellite_info.wait()
    out = rhn_satellite_info.communicate()[0]

    if re.search("is running\.\.\.", out) is not None:
        syslog.syslog(syslog.LOG_ERR, "Redhat Satellite DB Backup - Error - rhn-satellite shows Satellite daemons are still running, exiting. - NOC-NETCOOL-ALERT")
        error("Redhat Satellite DB Backup - Error - rhn-satellite shows that Satellite daemons are still running, exiting.\n")
        
        
    current_backup_directory = "/var/satellite/db_backup/" + datetime.datetime.now().strftime("%Y-%m-%d") + "_cold"
    os.mkdir(current_backup_directory)
    
        
    # Do the backup
    syslog.syslog(syslog.LOG_INFO, "Redhat Satellite DB Backup - Info - Performing cold database backup.\n")
    print "Redhat Satellite DB Backup - Info - Performing cold database backup."
    
    db_control_info = subprocess.Popen(["/usr/bin/db-control", "backup", current_backup_directory], stdin=None, shell=False)
    status = db_control_info.wait()

    if status != 0:
        syslog.syslog(syslog.LOG_ERR, "Redhat Satellite DB Backup - Error - db-control returned non-zero error code " + str(status) + " during cold database backup, exiting. - NOC-NETCOOL-ALERT")
        error("Redhat Satellite DB Backup - Error - db-control returned non-zero error code " + str(status) + " during cold database backup, exiting.\n")
        
        
    # Start the satellite daemons
    syslog.syslog(syslog.LOG_INFO, "Redhat Satellite DB Backup - Info - Starting Satellite daemons from cold database backup.\n")
    print "Redhat Satellite DB Backup - Info - Starting Satellite daemons from cold database backup."
    
    rhn_satellite_info = subprocess.Popen(["/usr/sbin/rhn-satellite", "start"], stdin=None, shell=False)
    status = rhn_satellite_info.wait()

    if status != 0:
        syslog.syslog(syslog.LOG_ERR, "Redhat Satellite DB Backup - Error - rhn-satellite returned non-zero error code " + str(status) + " while starting Satellite daemons after cold database backup, exiting. - NOC-NETCOOL-TICKET")
        error("Redhat Satellite DB Backup - Error - rhn-satellite returned non-zero error code " + str(status) + " while starting Satellite daemons after cold database backup, exiting.\n")
    
    
    # Remove cold backups older than 2 weeks
    syslog.syslog(syslog.LOG_INFO, "Redhat Satellite DB Backup - Info - Removing cold backups older than 2 weeks.\n")
    print "Redhat Satellite DB Backup - Info - Removing cold backups older than 2 weeks."
    
    todays_epoch = int(time.time())
    two_weeks_in_seconds = 60 * 60 * 24 * 7 * 2

    for each_dir in glob.glob("/var/satellite/db_backup/*_cold"):
        file_creation_time = int(os.path.getctime(each_dir))
        
        if (todays_epoch - file_creation_time) > two_weeks_in_seconds:
            syslog.syslog(syslog.LOG_INFO, "Redhat Satellite DB Backup - Info - Removing old cold backup " + each_dir + ".\n")
            print "Redhat Satellite DB Backup - Info - Removing old cold backup " + each_dir
            
            try:
               shutil.rmtree(each_dir)
                
            except:
                syslog.syslog(syslog.LOG_ERR, "Redhat Satellite DB Backup - Error - Failed to remove " + each_dir + ". - NOC-NETCOOL-TICKET\n")
                error("Redhat Satellite DB Backup - Error - Failed to remove " + each_dir + ".\n", None)

else:
    syslog.syslog(syslog.LOG_ERR, "Redhat Satellite DB Backup - Error - Required argument 'hot' or 'cold' not specified, exiting. - NOC-NETCOOL-TICKET\n")
    error("Redhat Satellite DB Backup - Error - Required argument 'hot' or 'cold' not specified, exiting.")






syslog.closelog()
