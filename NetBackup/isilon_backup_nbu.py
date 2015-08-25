#!/usr/bin/env python
# Description: Manage snapshots in an EMC Isilon cluster for NetBackup jobs
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
import sys
import json
import requests
import syslog
import time
import datetime
import traceback
import subprocess
import re
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options]\n" +
    "Manage snapshots in an EMC Isilon cluster for NetBackup jobs"
)

(options, args) = parser.parse_args()



ASCII_RED = "\033[31m"
ASCII_ENDCOLOR = "\033[0m"



# Return a "pretty" timestamp: 2013-07-04 13:58:47
def timestamp():
    return datetime.datetime.today().strftime("%Y-%m-%d %H:%M:%S: ")





def error(error_string, exit_status=1, syslog_tag=None):
    """Print a stack trace, exception, and an error string to STDERR
       then exit with the exit status given (default: 1) or don't exit
       if passed NoneType
    """

    exc_type, exc_value, exc_traceback = sys.exc_info()

    if exc_type is not None:
        traceback.print_exception(exc_type, exc_value, exc_traceback)

    sys.stderr.write(ASCII_RED + timestamp() + str(error_string) + ASCII_ENDCOLOR + "\n")

    syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_USER)

    if syslog_tag is not None:
        syslog.syslog(syslog.LOG_ERR, syslog_tag + ": " + str(error_string))

    else:
        syslog.syslog(syslog.LOG_ERR, str(error_string))

    syslog.closelog()

    if exit_status is not None:
        sys.exit(int(exit_status))





class snap(object):
    def __init__(self):
        """Create a snap object which will contain information about a snapshot
        """

        self.backup_dir = None
        self.isilon_dir = None
        self.snapshot_name = None





def get_credentials(password_file):
    """Get the credentials to use with API calls to Isilon and set the USERNAME and PASSWORD global variables
    """

    global USERNAME
    global PASSWORD

    USERNAME = "apiuser"

    try:
        PASSWORD = open(password_file, "r").read().rstrip()

    except:
        error("Unable to acquire credentails", 1, "NOC-NETCOOL-TICKET")





def create_snapshot(snap_obj):
    """Create a snapshot on an Isilon array
    """

    print timestamp() + "Creating snapshot named " + snap_obj.snapshot_name

    url = "https://panacea.sam.example.edu:8080/platform/1/snapshot/snapshots"

    payload = {
        "name" : snap_obj.snapshot_name,
        "path" : snap_obj.isilon_dir,
    }

    response = requests.post(url, verify=False, auth=(USERNAME, PASSWORD), json=payload)

    if "errors" in response.json():
        error("Failed to create snapshot, server response: " + str(response.json()), 1, "NOC-NETCOOL-TICKET")





def remove_snapshot(snap_obj):
    """Remove the snapshot on an Isilon array
    """
    print timestamp() + "Removing snapshot named " + snap_obj.snapshot_name

    url = "https://panacea.sam.example.edu:8080/platform/1/snapshot/snapshots/" + snap_obj.snapshot_name

    response = requests.delete(url, verify=False, auth=(USERNAME, PASSWORD))

    try:
        if "errors" in response.json():
            # Do not exit non-zero here or NetBackup will consider the backup as failed and throw it away
            error("Failed to create snapshot, server response: " + str(response.json()), 0, "NOC-NETCOOL-TICKET")

    except ValueError:
        # "No JSON object could be decoded" - Ok, no 'errors' so no problem.
        pass





def mount_snapshot(snap_obj):
    """ Mount a snapshot directory from an Isilon cluster
    """

    print timestamp() + "Mounting snapshot at " + snap_obj.backup_dir

    mounts = open("/proc/mounts", "r").read()

    if re.search(snap_obj.backup_dir, mounts) is not None:
        error("Failed to mount snapshot at " + snap_obj.backup_dir + ", a filesystem is already mounted there", 1, "NOC-NETCOOL-TICKET")


    if os.path.exists(snap_obj.backup_dir) is False:
        try:
            os.mkdir(snap_obj.backup_dir, 0700)

        except OSError:
            error("Failed to create backup mount directory " + snap_obj.backup_dir, 1, "NOC-NETCOOL-TICKET")


    mount_proc = subprocess.Popen(["mount", "-t", "nfs", "-o", "vers=3,proto=tcp", "sc-system.isilon.sam.pitt.edu:/ifs/.snapshot/" + snap_obj.snapshot_name, snap_obj.backup_dir], stdin=None, shell=False)
    status = mount_proc.wait()

    if status != 0:
        error("Failed to mount snapshot at " + snap_obj.backup_dir + ", mount returned status " + str(status), 1, "NOC-NETCOOL-TICKET")





def unmount_snapshot(snap_obj):
    """ Unmount the snapshot
    """

    print timestamp() + "Unmounting snapshot at " + snap_obj.backup_dir

    umount_proc = subprocess.Popen(["umount", snap_obj.backup_dir], stdin=None, shell=False)
    status = umount_proc.wait()

    if status != 0:
        # Do not exit non-zero here or NetBackup will consider the backup as failed and throw it away
        error("Failed to unmount snapshot at " + snap_obj.backup_dir + ", mount returned status " + str(status), 0, "NOC-NETCOOL-TICKET")





if __name__ == "__main__":
    #Set STDOUT, STDIN, and STDERR - Netbackup requires this
    dev_null = open(os.devnull, "w")
    os.dup2(dev_null.fileno(), 0) # STDIN

    out_file = open("/var/log/panacea_backup.out", "a")
    os.dup2(out_file.fileno(), 1) # STDOUT

    err_file = open("/var/log/panacea_backup.err", "a")
    os.dup2(err_file.fileno(), 2) # STDERR



    # Disable warning about self-signed SSL certs
    requests.packages.urllib3.disable_warnings()



    nbu_args = {
        "client_name" : sys.argv[1],
        "policy_name" : sys.argv[2],
        "schedule_name" : sys.argv[3],
        "schedule_type" : sys.argv[4], # FULL, INCR, CINC, UBAK, UARC
        #"status" : sys.argv[5], # always 0
        #"result_file" : sys.argv[6],
    }



    print timestamp() + "Panacea backup script for invoked with: " + str(nbu_args)



    # Set up the snap objects
    snaps = list()

    if nbu_args["policy_name"] == "DATA-PANACEA-SNAP-HOME":
        my_snap = snap()

        my_snap.backup_dir = "/backup/sam/home"
        my_snap.isilon_dir = "/ifs/sam/home"
        my_snap.snapshot_name = "nbu_home" + "-" + nbu_args["policy_name"] + "-" + nbu_args["schedule_type"]

        snaps.append(my_snap)

    elif nbu_args["policy_name"] == "DATA-PANACEA-SNAP-OPT":
        for directory in ["sam", "pkg", "mpi", "htc"]:
            my_snap = snap()

            my_snap.backup_dir = "/backup/sam/opt/" + directory
            my_snap.isilon_dir = "/ifs/sam/opt/" + directory
            my_snap.snapshot_name = "nbu_opt_" + directory + "-" + nbu_args["policy_name"] + "-" + nbu_args["schedule_type"]

            snaps.append(my_snap)

    else:
        print timestamp() + "Policy name " + nbu_args["policy_name"] + " was not expected, exiting."
        sys.exit(0)


    get_credentials("/path/to/pass.txt")


    if len(sys.argv) == 5: # If we received 4 args we are the start script
        for snap in snaps:
            create_snapshot(snap)
            mount_snapshot(snap)

    elif len(sys.argv) == 6: # If we received 5 args we are the end script
        for snap in snaps:
            unmount_snapshot(snap)
            remove_snapshot(snap)


    print timestamp() + "Returning to NetBackup"

    sys.exit(0)

