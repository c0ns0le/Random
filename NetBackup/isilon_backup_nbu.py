#!/usr/bin/env python
"""Manage snapshots in an EMC Isilon cluster, controlled by NetBackup
Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)

License:
This software is released under version three of the GNU General Public License (GPL) of the
Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
Use or modification of this software implies your acceptance of this license and its terms.
This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.
"""



import os
import sys
import requests
import syslog
import datetime
import traceback
import subprocess
import re
from optparse import OptionParser



ASCII_RED = "\033[31m"
ASCII_ENDCOLOR = "\033[0m"



def timestamp():
    """Return a "pretty" timestamp: 2013-07-04 13:58:47
    """
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



class Snap(object):
    """Snap object which contains information about a snapshot and methods to manage it
    """
    def __init__(self, **kwargs):
        """Create a snap object, requires the following kwargs:
        backup_dir
        isilon_dir
        snapshot_name
        """

        self.backup_dir = kwargs["backup_dir"]
        self.isilon_dir = kwargs["isilon_dir"]
        self.snapshot_name = kwargs["snapshot_name"]

        self.get_credentials("/path/to/pass.txt")



    def get_credentials(self, password_file):
        """Get the credentials to use with API calls to Isilon
        """

        self.api_username = "apiuser"

        try:
            self.api_password = open(password_file, "r").read().rstrip()

        except IOError:
            error("Unable to acquire credentails", 1, "NOC-NETCOOL-TICKET")



    def create_snapshot(self):
        """Create a snapshot on an Isilon array
        """

        print timestamp() + "Creating snapshot named " + self.snapshot_name

        url = "https://panacea.sam.example.edu:8080/platform/1/snapshot/snapshots"

        payload = {
            "name" : self.snapshot_name,
            "path" : self.isilon_dir,
        }

        response = requests.post(url, verify=False, auth=(self.api_username, self.api_password), json=payload)

        if "errors" in response.json():
            error("Failed to create snapshot, server response: " + str(response.json()), 1, "NOC-NETCOOL-TICKET")



    def remove_snapshot(self):
        """Remove the snapshot on an Isilon array
        """
        print timestamp() + "Removing snapshot named " + self.snapshot_name

        url = "https://panacea.sam.example.edu:8080/platform/1/snapshot/snapshots/" + self.snapshot_name

        response = requests.delete(url, verify=False, auth=(self.api_username, self.api_password))

        try:
            if "errors" in response.json():
                # Do not exit non-zero here or NetBackup will consider the backup as failed and throw it away
                error("Failed to create snapshot, server response: " + str(response.json()), 0, "NOC-NETCOOL-TICKET")

        except ValueError:
            # "No JSON object could be decoded" - Ok, no 'errors' so no problem.
            pass



    def mount_snapshot(self):
        """ Mount a snapshot directory from an Isilon cluster
        """

        print timestamp() + "Mounting snapshot at " + self.backup_dir

        mounts = open("/proc/mounts", "r").read()

        if re.search(self.backup_dir, mounts) is not None:
            error("Failed to mount snapshot at " + self.backup_dir + ", a filesystem is already mounted there", 1, "NOC-NETCOOL-TICKET")


        if os.path.exists(self.backup_dir) is False:
            try:
                os.mkdir(self.backup_dir, 0700)

            except OSError:
                error("Failed to create backup mount directory " + self.backup_dir, 1, "NOC-NETCOOL-TICKET")


        mount_proc = subprocess.Popen(["mount", "-t", "nfs", "-o", "vers=3,proto=tcp", "sc-system.isilon.sam.example.edu:/ifs/.snapshot/" + self.snapshot_name, self.backup_dir], stdin=None, shell=False)
        status = mount_proc.wait()

        if status != 0:
            error("Failed to mount snapshot at " + self.backup_dir + ", mount returned status " + str(status), 1, "NOC-NETCOOL-TICKET")



    def unmount_snapshot(self):
        """ Unmount the snapshot
        """

        print timestamp() + "Unmounting snapshot at " + self.backup_dir

        umount_proc = subprocess.Popen(["umount", self.backup_dir], stdin=None, shell=False)
        status = umount_proc.wait()

        if status != 0:
            # Do not exit non-zero here or NetBackup will consider the backup as failed and throw it away
            error("Failed to unmount snapshot at " + self.backup_dir + ", mount returned status " + str(status), 0, "NOC-NETCOOL-TICKET")





if __name__ == "__main__":
    # How were we called?
    parser = OptionParser("%prog [options]\n" + "Manage snapshots in an EMC Isilon cluster, controlled by NetBackup")

    (options, args) = parser.parse_args()



    # Set STDOUT, STDIN, and STDERR to a file - Netbackup requires this
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
        #"status" : sys.argv[5], # only exists when called as a bpend script, should always be 0
        #"result_file" : sys.argv[6],
    }



    print timestamp() + "Panacea backup script invoked with: " + str(nbu_args)



    # Set up the snap objects
    snaps = list()

    if nbu_args["policy_name"] == "DATA-PANACEA-SNAP-HOME":
        snap_obj = Snap(
            backup_dir="/backup/sam/home",
            isilon_dir="/ifs/sam/home",
            snapshot_name="nbu_home" + "-" + nbu_args["policy_name"] + "-" + nbu_args["schedule_type"]
        )

        snaps.append(snap_obj)

    elif nbu_args["policy_name"] == "DATA-PANACEA-SNAP-OPT":
        # This policy has 4 NFS exports to handle
        for directory in ["sam", "pkg", "mpi", "htc"]:
            snap_obj = Snap(
                backup_dir="/backup/sam/opt/" + directory,
                isilon_dir="/ifs/sam/opt/" + directory,
                snapshot_name="nbu_opt_" + directory + "-" + nbu_args["policy_name"] + "-" + nbu_args["schedule_type"]
            )

            snaps.append(snap_obj)

    else:
        print timestamp() + "Policy name " + nbu_args["policy_name"] + " was not expected, exiting."
        sys.exit(0)



    if len(sys.argv) == 5: # If we received 4 args we are the start script
        for snap in snaps:
            snap.create_snapshot()
            snap.mount_snapshot()

    elif len(sys.argv) == 6: # If we received 5 args we are the end script
        for snap in snaps:
            snap.unmount_snapshot()
            snap.remove_snapshot()


    print timestamp() + "Returning to NetBackup"

    sys.exit(0)
