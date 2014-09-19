#!/usr/bin/env python
# Description: Dump all volumes of an AFS cell then call Netbackup to back them up
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, re, syslog, signal, subprocess, time, datetime, traceback, pickle, shutil
from optparse import OptionParser



afs_servers = ["afs-fs-01.cssd.pitt.edu", "afs-fs-02.cssd.pitt.edu", "afs-fs-03.cssd.pitt.edu"]
#afs_servers = ["afs-fs-01.cssd.pitt.edu"]
kerberos_keytab = "/usr/local/etc/SOME_ADMIN_PRINCIPAL.keytab"
auther_pid = -1 # Don't change this



# How were we called?
parser = OptionParser("%prog [options]\n" +
    "Dump all volumes of an AFS cell then call netbackup to back them up"
)


parser.add_option(
    "-d", "--debug",
    action="store_true", dest="debug", default=False,
    help="Go into debug mode (shows every step of every volume being worked on)"
)


(options, args) = parser.parse_args()




# Print a stack trace, exception, and an error string to STDERR
# and exit with the exit status given or don't exit
# if passed NoneType
def error(error_string, exit_status):
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



# Try to remove the lock file, the AFS token and the Kerberos ticket but don't complain if we can't
def try_cleanup_temp_files():
    try:
        os.kill(auther_pid, 15)
        os.waitpid(auther_pid, 0)

    except:
        pass

    try:
        os.remove("/home/afsdumper/afs_backup.lock")

    except:
        pass

    try:
        unlog_info = subprocess.Popen(["/usr/bin/unlog"], stdin=None, stdout=None, shell=False)
        status = unlog_info.wait()

    except:
        pass

    try:
        kdestroy_info = subprocess.Popen(["/usr/bin/kdestroy"], stdin=None, stdout=None, shell=False)
        status = kdestroy_info.wait()

    except:
        pass

    return None





# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)





if os.path.exists("/home/afsdumper/afs_backup.lock"):
    syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Existing lock file /home/afsdumper/afs_backup.lock found, exiting. - NOC-NETCOOL-TICKET\n")
    error("AFS Backup " + str(os.getpid()) + " - Error - Existing lock file /home/afsdumper/afs_backup.lock found, exiting.\n", 1)



print "AFS Backup " + str(os.getpid()) + " - Info - Creating lock file"
syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Creating lock file.\n")

try:
    lock_file_handle = open("/home/afsdumper/afs_backup.lock", "w")
    lock_file_handle.write(str(os.getpid()))
    lock_file_handle.close()

except:
    try_cleanup_temp_files()
    syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Failed to create lock file /home/afsdumper/afs_backup.lock, exiting. - NOC-NETCOOL-TICKET\n")
    error("AFS Backup " + str(os.getpid()) + " - Error - Failed to create lock file /home/afsdumper/afs_backup.lock found, exiting.\n", 1)





print "AFS Backup " + str(os.getpid()) + " - Info - Forking child to handle Kerberos and AFS authentication"
syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Forking child to handle Kerberos and AFS authentication\n")

pid = os.fork()

if pid == 0: # We're the child
    os.setsid()

    while True:
        print "AFS Backup " + str(os.getpid()) + " - Info - Getting Kerberos 5 ticket using keytab " + kerberos_keytab
        syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Getting Kerberos 5 ticket using keytab " + kerberos_keytab + "\n")

        signal.alarm(60)

        kinit_info = subprocess.Popen(["/usr/bin/kinit", "-k", "-t", kerberos_keytab, "SOME_ADMIN_PRINCIPAL"], stdin=None, stdout=None, shell=False)
        status = kinit_info.wait()

        signal.alarm(0)

        if status != 0:
            try_cleanup_temp_files()
            syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Unable to get Kerberos ticket, kinit exited with a status of " + str(status) + ", exiting. - NOC-NETCOOL-TICKET")
            error("AFS Backup " + str(os.getpid()) + " - Error - Unable to get Kerberos ticket, kinit exited with a status of " + str(status) + ", exiting.\n", 1)





        print "AFS Backup " + str(os.getpid()) + " - Info - Getting AFS token"
        syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Getting AFS token\n")

        signal.alarm(60)

        aklog_info = subprocess.Popen(["/usr/bin/aklog"], stdin=None, stdout=None, shell=False)
        status = aklog_info.wait()

        signal.alarm(0)

        if status != 0:
            try_cleanup_temp_files()
            syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Unable to get AFS token, aklog exited with a status of " + str(status) + ", exiting. - NOC-NETCOOL-TICKET")
            error("AFS Backup " + str(os.getpid()) + " - Error - Unable to get AFS token, aklog exited with a status of " + str(status) + ", exiting.\n", 1)

        # Sleep for an hour then restart the loop to re-authenticate
        wakeup_time = int(time.time()) + (60 * 60)
        while True:
            if time.time() > wakeup_time:
                break

            else:
                time.sleep(60)


else: # We're the parent
    auther_pid = pid
    print "AFS Backup " + str(os.getpid()) + " - Info - Authentication handling child had pid " + str(auther_pid) + ", waiting 30 seconds for authentication"
    syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Authentication handling child had pid " + str(auther_pid) + ", waiting 30 seconds for authentication\n")

    # Give that child some time to authenticate
    time.sleep(30)





dumper_pids = []
for afs_server in afs_servers:
    print "AFS Backup " + str(os.getpid()) + " - Info - Forking child to dump volumes from " + afs_server
    syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Forking child to dump volumes from " + afs_server + ".\n")

    if os.path.exists("/usr/local/dump/" + afs_server) is False:
        os.mkdir("/usr/local/dump/" + afs_server)

    pid = os.fork()

    if pid == 0: # We're the child
        os.setsid()

        pickle_file = "/home/afsdumper/afs_backup-" + afs_server + ".pkl"

        print "AFS Backup " + str(os.getpid()) + " - Info - Getting pickle file (" + pickle_file + ") of previous backups"
        syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Getting pickle file (" + pickle_file + ") of previous backups")

        if os.path.isfile(pickle_file):
            pickle_handle = open(pickle_file, "r")

            afs_backup_history = pickle.load(pickle_handle)

            pickle_handle.close()

        else:
            print "AFS Backup " + str(os.getpid()) + " - Warning - No pickle file (" + pickle_file + ") of previous backups found, moving on anyway"
            syslog.syslog(syslog.LOG_WARNING, "AFS Backup " + str(os.getpid()) + " - Warning - No pickle file (" + pickle_file + ") of previous backups found, moving on anyway. - NOC-NETCOOL-TICKET")

            afs_backup_history = {}


        # On Sundays do a full dump
        todays_weekdate = datetime.date.fromtimestamp(time.time()).strftime("%A").lower()

        print "AFS Backup " + str(os.getpid()) + " - Info - Dumping volumes from server " + afs_server
        syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Dumping volumes from server " + afs_server + ".\n")

        vos_info = subprocess.Popen(["/usr/sbin/vos", "listvol", afs_server, "-quiet"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, shell=False)

        total_volume_count = 0
        failed_volume_count = 0
        for line in vos_info.communicate("\n")[0].split(os.linesep):
            line = line.rstrip()

            if re.search(" BK ", line) is None:
                continue

            total_volume_count = total_volume_count + 1

            volume = line.split()[0]

            if options.debug is True:
                print "AFS Backup " + str(os.getpid()) + " - Debug - Working on volume " + volume
                syslog.syslog(syslog.LOG_DEBUG, "AFS Backup " + str(os.getpid()) + " - Info - Working on volume " + volume + ".\n")

            # On Sundays do a full dump
            if todays_weekdate == "sunday":
            #if True is True:
                if options.debug is True:
                    print "AFS Backup " + str(os.getpid()) + " - Debug - Full backup needed, dumping volume " + volume
                    syslog.syslog(syslog.LOG_DEBUG, "AFS Backup " + str(os.getpid()) + " - Debug - Full backup needed, dumping volume " + volume + ".\n")

                with open(os.devnull, "w") as devnull:
                    vos2_info = subprocess.Popen(["/usr/sbin/vos", "dump", volume, "-file", "/usr/local/dump/" + afs_server + "/" + volume], stdin=None, stdout=None, stderr=devnull, shell=False)
                    status = vos2_info.wait()

                if status != 0:
                    syslog.syslog(syslog.LOG_WARNING, "AFS Backup " + str(os.getpid()) + " - Warning - Non-zero exit status (" + str(status) + ") of vos while dumping volume " + volume + ".\n")
                    error("AFS Backup " + str(os.getpid()) + " - Warning - Non-zero exit status (" + str(status) + ") of vos while dumping volume " + volume + "\n", None)

                    failed_volume_count = failed_volume_count + 1

                else:
                    afs_backup_history[volume] = int(time.time())

                    if options.debug is True:
                        syslog.syslog(syslog.LOG_DEBUG, "AFS Backup " + str(os.getpid()) + " - Debug - Successfully dumped volume " + volume + ".\n")
                        print "AFS Backup " + str(os.getpid()) + " - Debug - Successfully dumped volume " + volume

                print "Backup time: " + str(afs_backup_history[volume])

            else: # On other weekdays check if the volume has changed since last Thursday and only dump it if it has
                vos3_info = subprocess.Popen(["/usr/sbin/vos", "examine", "-id", volume], stdin=subprocess.PIPE, stdout=subprocess.PIPE, shell=False)
                for line in vos3_info.communicate("\n")[0].split(os.linesep):
                    line = line.rstrip()

                    if re.search("Last Update", line) is None:
                        continue

                    try:
                        day = int(line.split()[4])
                        month = line.split()[3]
                        year = int(line.split()[6])
                        vol_time = line.split()[5]
                        hour = int(vol_time.split(":")[0])
                        minute = int(vol_time.split(":")[1])

                    except:
                        syslog.syslog(syslog.LOG_WARNING, "AFS Backup " + str(os.getpid()) + " - Warning - Failed to get last update timestamp of volume " + volume + ".\n")
                        error("AFS Backup " + str(os.getpid()) + " - Warning - Failed to get last update timestamp of volume " + volume + "\n", None)

                        # We don't know the update time so pretend it is the highest value possible to force a dump to take place later
                        last_update_time = 2147483647

                    else:
                        if month == "Jan":
                            month = 1

                        elif month == "Feb":
                            month = 2

                        elif month == "Mar":
                            month = 3

                        elif month == "Apr":
                            month = 4

                        elif month == "May":
                            month = 5

                        elif month == "Jun":
                            month = 6

                        elif month == "Jul":
                            month = 7

                        elif month == "Aug":
                            month = 8

                        elif month == "Sep":
                            month = 9

                        elif month == "Oct":
                            month = 10

                        elif month == "Nov":
                            month = 11

                        elif month == "Dec":
                            month = 12

                        dt = datetime.datetime(year, month, day, hour, minute)
                        last_update_time = int(time.mktime(dt.timetuple()))

                        #print str(year) + ":" + str(month) + ":" + str(day) + ":" + str(hour) + ":" + str(minute)

                    # This is when the last backup was ran
                    try:
                        last_backup_time = afs_backup_history[volume]

                    except KeyError:
                        last_backup_time = 0

                    if options.debug is True:
                        print "AFS Backup " + str(os.getpid()) + " - Debug - Volume " + volume + " last backup time is " + time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(last_backup_time)) + " (" + str(last_backup_time) + ")"
                        syslog.syslog(syslog.LOG_DEBUG, "AFS Backup " + str(os.getpid()) + " - Info - Volume " + volume + " last backup time is " + time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(last_backup_time)) + " (" + str(last_backup_time) + ").\n")

                        print "AFS Backup " + str(os.getpid()) + " - Debug - Volume " + volume + " last update time is " + time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(last_update_time)) + " (" + str(last_update_time) + ")"
                        syslog.syslog(syslog.LOG_DEBUG, "AFS Backup " + str(os.getpid()) + " - Info - Volume " + volume + " last update time is " + time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(last_update_time)) + " (" + str(last_update_time) + ").\n")

                        #time.sleep(5)

                    # Do we need to backup this volume?
                    if last_update_time > last_backup_time:
                        if options.debug is True:
                            print "AFS Backup " + str(os.getpid()) + " - Debug - Volume " + volume + " has changed since last full backup, dumping."
                            syslog.syslog(syslog.LOG_DEBUG, "AFS Backup " + str(os.getpid()) + " - Info - Volume " + volume + " has changed since last full backup, dumping.\n")

                        with open(os.devnull, "w") as devnull:
                            vos4_info = subprocess.Popen(["/usr/sbin/vos", "dump", volume, "-file", "/usr/local/dump/" + afs_server + "/" + volume], stdin=subprocess.PIPE, stdout=None, stderr=devnull, shell=False)
                            status = vos4_info.wait()

                        if status != 0:
                            syslog.syslog(syslog.LOG_WARNING, "AFS Backup " + str(os.getpid()) + " - Warning - Non-zero exit status (" + str(status) + ") of vos while dumping volume " + volume + ".\n")
                            error("AFS Backup " + str(os.getpid()) + " - Warning - Non-zero exit status (" + str(status) + ") of vos while dumping volume " + volume, None)

                            failed_volume_count = failed_volume_count + 1

                        else:
                            afs_backup_history[volume] = int(time.time())

                            if options.debug is True:
                                syslog.syslog(syslog.LOG_DEBUG, "AFS Backup " + str(os.getpid()) + " - Debug - Successfully dumped volume " + volume + ".\n")
                                print "AFS Backup " + str(os.getpid()) + " - Debug - Successfully dumped volume " + volume

                    else:
                        if options.debug is True:
                            print "AFS Backup " + str(os.getpid()) + " - Debug - Volume " + volume + " has not changed since last full backup, skipping."
                            syslog.syslog(syslog.LOG_DEBUG, "AFS Backup " + str(os.getpid()) + " - Info - Volume " + volume + " has not changed since last full backup, skipping.\n")

                    if options.debug is True:
                        print ""

        if failed_volume_count > 100:
            syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Failed to dump greater than 100 volumes from server " + afs_server + ". - NOC-NETCOOL-TICKET\n")
            error("AFS Backup " + str(os.getpid()) + " - Error - Failed to dump greater than 100 volumes from server " + afs_server + "\n", None)

        print "AFS Backup " + str(os.getpid()) + " - Info - Completed dump from server " + afs_server + ", " + str(total_volume_count) + " volumes found, " + str(failed_volume_count) + " volumes failed to dump"
        syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Completed dump from server " + afs_server + ", " + str(total_volume_count) + " volumes found, " + str(failed_volume_count) + " volumes failed to dump\n")


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

            pickle.dump(afs_backup_history, pickle_handle)

            pickle_handle.close()


        except:
            syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Failed to save pickle file (" + pickle_file + ") of backup history. - NOC-NETCOOL-TICKET")
            error("AFS Backup " + str(os.getpid()) + " - Error - Failed to save pickle file (" + pickle_file + ") of backup history.\n", None)


        sys.exit(0)


    else:
        print "AFS Backup " + str(os.getpid()) + " - Info - Dumper process for server " + afs_server + " has pid " + str(pid)
        syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Dumper process for server " + afs_server + " has pid " + str(pid) + ".\n")

        dumper_pids.append(pid)



# Wait for our children to exit
for dumper_pid in dumper_pids:
    os.waitpid(dumper_pid, 0)





try:
    os.kill(auther_pid, 15)
    os.waitpid(auther_pid, 0)

except:
    syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Failed to kill authentication handling child process with PID " + str(auther_pid) + ". - NOC-NETCOOL-TICKET\n")
    error("AFS Backup " + str(os.getpid()) + " - Error - Failed to kill authentication handling child process with PID " + str(auther_pid) + ".\n", None)





print "AFS Backup " + str(os.getpid()) + " - Info - All dumper child processes have exited, calling out to netbackup to start the backup."
syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - All dumper child processes have exited, calling out to netbackup to start the backup" + ".\n")

bpbackup_info = subprocess.Popen(["/usr/bin/sudo", "/usr/openv/netbackup/bin/bpbackup", "-p", "DATA-AFS-DUMP", "-L", "/var/log/afs-dump-netbackup.log", "-w", "/usr/local/dump"], stdin=None, stdout=None, shell=False)
status = bpbackup_info.wait()

if status != 0:
    try_cleanup_temp_files()
    syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Netbackup returned non-zero error code " + str(status) + ". - NOC-NETCOOL-TICKET")
    error("AFS Backup " + str(os.getpid()) + " - Error - Netbackup returned non-zero error code " + str(status) + ".\n", None)





print "AFS Backup " + str(os.getpid()) + " - Info - Backup completed, removing local copy of volumes"
syslog.syslog(syslog.LOG_INFO, "AFS Backup " + str(os.getpid()) + " - Info - Backup completed, removing local copy of volumes.\n")

for afs_server in afs_servers:
    try:
        shutil.rmtree("/usr/local/dump/" + afs_server)

    except:
        syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Failed to remove local copy of volumes for server " + afs_server + ". - NOC-NETCOOL-TICKET")
        error("AFS Backup " + str(os.getpid()) + " - Error - Failed to remove local copy of volumes for server " + afs_server + ".\n", None)





# We're done, clean up after ourselves
try:
    unlog_info = subprocess.Popen(["/usr/bin/unlog"], stdin=None, stdout=None, shell=False)
    status = unlog_info.wait()

except:
    syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Failed to remove AFS token, unlog exited with status " + str(status) + ". - NOC-NETCOOL-TICKET\n")
    error("AFS Backup " + str(os.getpid()) + " - Error - Failed to remove AFS token, unlog exited with status " + str(status) + ".\n", None)



try:
    kdestroy_info = subprocess.Popen(["/usr/bin/kdestroy"], stdin=None, stdout=None, shell=False)
    status = kdestroy_info.wait()

except:
    syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Failed to remove Kerberos ticket, kdestroy exited with status " + str(status) + ". - NOC-NETCOOL-TICKET\n")
    error("AFS Backup " + str(os.getpid()) + " - Error - Failed to remove Kerberos ticket, kdestroy exited with status " + str(status) + ".\n", None)



try:
    os.remove("/home/afsdumper/afs_backup.lock")

except:
    syslog.syslog(syslog.LOG_ERR, "AFS Backup " + str(os.getpid()) + " - Error - Failed to remove lock file /var/log/afs_backup.lock. - NOC-NETCOOL-TICKET\n")
    error("AFS Backup " + str(os.getpid()) + " - Error - Failed to remove lock file /var/log/afs_backup.lock found, exiting.\n", None)



syslog.closelog()
