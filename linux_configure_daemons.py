#!/usr/bin/env python
# Description: Configure what daemons to enable/disable on Linux
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial verison

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, re, subprocess, traceback
from urllib import urlopen
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options]\n" +
    "Configure what daemons to enable/disable on Linux systems"
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





# Determine what disto we are on
distro = None

if os.path.exists("/etc/redhat-release"):
    try:
        redhat_release_data = open("/etc/redhat-release", "r").read()

    except:
        error("Failed to read data from '/etc/redhat-release', exiting\n")


    if re.search("release 7", redhat_release_data) is not None:
        print "Detected RHEL 7"
        distro = "rhel7"

    elif re.search("release 6", redhat_release_data) is not None:
        print "Detected RHEL 6"
        distro = "rhel6"

    else:
        error("Unable to determine what version of RHEL is in use, exiting\n")

else:
    error("File '/etc/redhat-release' not found, not running on RHEL?, exiting\n")





# Configure the daemons
if distro == "rhel7":
    # Daemons to be enabled, all others will be disabled
    good_daemons = ["acpid", "auditd", "crond", "dsm_om_connsvc", "dsm_om_shrsvc", "dataeng", "kdump", "irqbalance", \
        "lvm2-monitor", "microcode-ctl", "multipathd", "network", "postfix", "ntpd", "rsyslog", "sshd", "cpuspeed", \
        "sysstat", "udev-post", "vmware-tools", "xinetd", "netbackup", "vxpbx_exchanged", "mcelogd", \
        "blk-availability", "rhnsd", "rngd", "dbus-org", "microcode", "systemd-readahead-collect", "systemd-readahead-drop", \
        "systemd-readahead-replay", "tuned", "getty@"]

    # First, we check the daemons chkconfig tells us
    with open("/dev/null", "w") as devnull:
        chkconfig_proc = subprocess.Popen(["chkconfig", "--list", "--type=sysv"], stdout=subprocess.PIPE, stderr=devnull, shell=False)
    out = chkconfig_proc.communicate("\n")[0]
    out = out.rstrip()

    for line in out.split(os.linesep):
        line = line.rstrip()

        is_enabled = False

        if re.search(":on", line) is not None:
            is_enabled = True

        daemon = line.split()[0]

        if daemon in good_daemons and is_enabled is False:
            enable_choice = raw_input("Would you like to enable " + daemon + "? y or n: ")

            if enable_choice.lower() == "y":
                chkconfig_change_proc = subprocess.Popen(["chkconfig", daemon, "on"], shell=False)
                chkconfig_change_proc.wait()

        if daemon not in good_daemons and is_enabled is True:
            enable_choice = raw_input("Would you like to disable " + daemon + "? y or n: ")

            if enable_choice.lower() == "y":
                chkconfig_change_proc = subprocess.Popen(["chkconfig", daemon, "off"], shell=False)
                chkconfig_change_proc.wait()


    # Next, check the daemons systemctl tells us
    systemctl_proc = subprocess.Popen(["systemctl", "list-unit-files"], stdout=subprocess.PIPE, shell=False)
    out = systemctl_proc.communicate("\n")[0]
    out = out.rstrip()

    for line in out.split(os.linesep):
        line = line.rstrip()

        is_enabled = False

        if re.search("\.service\s+enabled$", line) is not None:
            is_enabled = True

        daemon = re.sub("\.service.*", "", line)

        if daemon in good_daemons and is_enabled is False:
            enable_choice = raw_input("Would you like to enable " + daemon + "? y or n: ")

            if enable_choice.lower() == "y":
                with open("/dev/null", "w") as devnull:
                    systemctl_change_proc = subprocess.Popen(["systemctl", "enable", daemon + ".service"], stderr=devnull, shell=False)
                systemctl_change_proc.wait()

        if daemon not in good_daemons and is_enabled is True:
            enable_choice = raw_input("Would you like to disable " + daemon + "? y or n: ")

            if enable_choice.lower() == "y":
                with open("/dev/null", "w") as devnull:
                    systemctl_change_proc = subprocess.Popen(["systemctl", "disable", daemon + ".service"], stderr=devnull, shell=False)
                systemctl_change_proc.wait()


elif distro == "rhel6":

    # Daemons to be enabled, all others will be disabled
    good_daemons = ["acpid", "auditd", "crond", "dsm_om_connsvc", "dsm_om_shrsvc", "dataeng", "kdump", "irqbalance", \
        "lvm2-monitor", "microcode-ctl", "multipathd", "network", "postfix", "ntpd", "rsyslog", "sshd", "cpuspeed", \
        "sysstat", "udev-post", "vmware-tools", "xinetd", "netbackup", "vxpbx_exchanged", "mcelogd", \
        "blk-availability", "rhnsd", "rngd"]


    chkconfig_proc = subprocess.Popen(["chkconfig", "--list", "--type=sysv"], stdout=subprocess.PIPE, shell=False)
    out = chkconfig_proc.communicate("\n")[0]
    out = out.rstrip()

    for line in out.split(os.linesep):
        line = line.rstrip()

        is_enabled = False

        if re.search(":on", line) is not None:
            is_enabled = True

        daemon = line.split()[0]

        if daemon in good_daemons and is_enabled is False:
            enable_choice = raw_input("Would you like to enable " + daemon + "? y or n: ")

            if enable_choice.lower() == "y":
                chkconfig_change_proc = subprocess.Popen(["chkconfig", daemon, "on"], shell=False)
                chkconfig_change_proc.wait()

        if daemon not in good_daemons and is_enabled is True:
            enable_choice = raw_input("Would you like to disable " + daemon + "? y or n: ")

            if enable_choice.lower() == "y":
                chkconfig_change_proc = subprocess.Popen(["chkconfig", daemon, "off"], shell=False)
                chkconfig_change_proc.wait()


print "Done!"




















