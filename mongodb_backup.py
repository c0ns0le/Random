#!/usr/bin/env python
# Description: Create a backup of MongoDB using mongodump
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, subprocess, traceback, shutil, syslog
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Create a backup of MongoDB using mongodump"
)

parser.add_option(
    "-b", "--backup-directory",
    dest="backup_dir", default="/var/tmp/mongo_backup", metavar="DIRECTORY",
    help="Where to store the backup image (default: /var/tmp/mongo_backup)"
)

parser.add_option(
    "-n", "--number-backups",
    dest="num_backups", default=1, metavar="NUM", type="int",
    help="Total number of backups to keep (default: 1)"
)

parser.add_option(
    "-u", "--user",
    dest="user", default="admin", metavar="USER",
    help="What user to authenticate as (default: admin)"
)

parser.add_option(
    "-p", "--password-file",
    dest="password_file", default="/var/tmp/mongo_pass.txt", metavar="PASSWORD_FILE",
    help="File where the password is stored (default: /var/tmp/mongo_pass.txt)"
)

(options, args) = parser.parse_args()





# Print a stack trace, exception, and an error string to STDERR
# then exit with the exit status given (default: 1) or don't exit
# if passed NoneType
def error(error_string, exit_status=1):
    red = "\033[31m"
    endcolor = "\033[0m"

    exc_type, exc_value, exc_traceback = sys.exc_info()

    if exc_type is not None:
        traceback.print_exception(exc_type, exc_value, exc_traceback)

    sys.stderr.write("\n" + red + str(error_string) + endcolor + "\n")
    
    if exit_status is not None:
        sys.exit(int(exit_status))
        
        
        
        
        
# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_USER)



syslog.syslog(syslog.LOG_INFO, "MongoDB backup started.")
        
        
        
        
        
# Verify our temp dump directory does not already exists
if os.path.exists(options.backup_dir + "/mongo_backup.dump-temp"):
    error("Temporary dump directory " + options.backup_dir + "/mongo_backup.dump-temp" + " already exists, exiting.")
    
    
# Get the password
try:
    mongo_password = open(options.password_file, "r").read().strip()
    
except:
    error("Unable to read the Mongo password.")


# Create the new dump
dump_proc = subprocess.Popen(["mongodump", "--username", options.user, "--password", mongo_password, "--out", options.backup_dir + "/mongo_backup.dump-temp"], stdin=None, shell=False)
dump_status = dump_proc.wait()

if dump_status == 0:
    print "Dump was successful."
    
else:
    error("Dump failed with exit code " + str(dump_status) + ".")


# Rotate old dump if needed, complain and exit if the number of backups we were
# told is less than 1
if options.num_backups < 1:
    error("Number of backups specified as less than 1?  Impossible, exiting.")
    
elif options.num_backups == 1:
    if os.path.exists(options.backup_dir + "/mongo_backup.dump-1"):
        try:
            shutil.rmtree(options.backup_dir + "/mongo_backup.dump-1")
            
        except:
            error("Unable to remove old backup, exiting.")
          
elif options.num_backups > 1:
    # Remove the oldest backup, if it exists
    if os.path.exists(options.backup_dir + "/mongo_backup.dump-" + str(options.num_backups)):
        try:
            shutil.rmtree(options.backup_dir + "/mongo_backup.dump-" + str(options.num_backups))
            
        except:
            error("Unable to remove oldest backup, exiting.")
            
    
    # Rename the rest of the backups (this skips the oldest one we just removed)
    for backup_num in reversed(range(1, options.num_backups)):
        if os.path.exists(options.backup_dir + "/mongo_backup.dump-" + str(backup_num)):
            try:
                os.rename(options.backup_dir + "/mongo_backup.dump-" + str(backup_num), options.backup_dir + "/mongo_backup.dump-" + str(backup_num + 1))
                
            except:
                error("Unable to rename old backup, exiting.")
                
                
# Rename the new backup
try:
    os.rename(options.backup_dir + "/mongo_backup.dump-temp", options.backup_dir + "/mongo_backup.dump-1")
        
except:
    error("Unable to rename old backup, exiting.")
    
    
    
syslog.syslog(syslog.LOG_INFO, "MongoDB backup completed.")



# Close syslog, we're done
syslog.closelog()
