#!/usr/bin/env python
# Description: Check the status of network interfaces in a bond interface on Linux
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





# Print a warning message in red text to STDOUT
def warn(error_string):
    red = "\033[31m"
    endcolor = "\033[0m"
    sys.stdout.write(red + str(error_string) + endcolor)





# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)





# Are there any bonds to even look for?
if os.path.isdir("/proc/net/bonding") is False:
    error("/proc/net/bonding not found, bond module not loaded?\n", 1)





bond_interfaces = os.listdir("/proc/net/bonding/")


# Do we even have any bond interfaces?
if len(bond_interfaces) == 0:
    error("No bond interfaces found, exiting.\n", 1)



for bond_interface in bond_interfaces:
    print "\nChecking bond interface " + bond_interface

    for line in open("/proc/net/bonding/" + bond_interface, "r"):
        line = line.rstrip()
        #print "LINE: " + line

        match = None

        match = re.match("^Slave Interface: (.+)", line)

        if match is not None:
            slave_interface = match.group(1)
            print "\n    Found slave interface " + slave_interface

            continue


        # Don't check for anything until we have found a slave interface.
        # Otherwise we'll catch things we don't care about.
        try:
            slave_interface

        except NameError:
            continue


        match = re.match("^MII Status: (.+)", line)

        if match is not None:
            mii_status = match.group(1)

            if mii_status == "up":
                print "        MII Status: OK (up)"

            else:
                warn("        WARNING: MII Status: " + mii_status + "\n")
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Slave interface " + slave_interface + " of network bond interface " + bond_interface + " has MII status of " + mii_status)

            continue


        match = re.match("^Speed: ([0-9]+) Mbps", line)

        if match is not None:
            speed = match.group(1)

            if int(speed) >= 1000:
                print "        Speed: OK (" + speed + " Mbps)"

            else:
                warn("        WARNING: Speed: " + speed + " Mbps\n")
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Slave interface " + slave_interface + " of network bond interface " + bond_interface + " has port speed of " + speed)

            continue


        match = re.match("^Duplex: (.+)", line)

        if match is not None:
            duplex = match.group(1)

            if duplex == "full":
                print "        Duplex: OK (" + duplex + ")"

            else:
                warn("        WARNING: Duplex: " + duplex + "\n")
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Slave interface " + slave_interface + " of network bond interface " + bond_interface + " has duplex of " + duplex)

            continue


        match = re.match("^Link Failure Count: ([0-9])+", line)

        if match is not None:
            link_failure_count = match.group(1)

            if int(link_failure_count) < 5:
                print "        Link Failure Count: OK (" + link_failure_count + ")"

            else:
                warn("        WARNING: Link Failure Count: " + link_failure_count + "\n")
                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Slave interface " + slave_interface + " of network bond interface " + bond_interface + " has link failure count of " + link_failure_count)

            continue





# Close syslog, we're done
syslog.closelog()
