#!/usr/bin/env python



import sys
import os
import re
import traceback
import time
import datetime
import pexpect
import syslog
from optparse import OptionParser





# How were we called?
parser = OptionParser("%prog [options]\n" +
    "Check the health of SaM's Infiniband gateway switches."
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





# Return a "pretty" timestamp: 2013-07-04 13:58:47
def timestamp():
    return datetime.datetime.today().strftime("%Y-%m-%d %H:%M:%S")





# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)





COMMAND_PROMPT = "rd-ib-gw-[0-9]+ \[rd-ib-gw: [a-z]+\] [>#]"





# Get the password
password = open("/usr/local/etc/infiniband_monitor_pass.txt", "r").read().rstrip()





# Connect to the VIP
try:
    print "Connecting ..."
    ssh_connection = pexpect.spawn("ssh -l monitor rd-ib-gw.sam.pitt.edu")
    ssh_connection.expect("Password: ", timeout=60)

except pexpect.TIMEOUT:
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Timed out while attempting to connect to SaM Infiniband gateway switch VIP")
    error("Timed out while attempting to connect to SaM Infiniband gateway switch VIP, exiting.\n", 1)

except:
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-ALERT: Failed to connect to SaM Infiniband gateway switch VIP")
    error("Failed to connect to SaM Infiniband gateway switch VIP, exiting.\n", 1)

else:
    print "Connection succeeded."



# Authenticate
try:
    print "Authenticating ..."
    ssh_connection.sendline(password)
    ssh_connection.expect(COMMAND_PROMPT)

except pexpect.TIMEOUT:
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Timed out while attempting authentication on SaM Infiniband gateway switch VIP")
    error("Timed out while attempting authentication on SaM Infiniband gateway switch VIP, exiting.\n", 1)

except:
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed while attempting authentication on SaM Infiniband gateway switch VIP")
    error("Failed while attempting authentication on SaM Infiniband gateway switch VIP, exiting.\n", 1)

else:
    print "Authentication succeeded."



# Enter enable mode
try:
    print "Entering enable mode ..."
    ssh_connection.sendline("enable")
    ssh_connection.expect(COMMAND_PROMPT, timeout=60)

except pexpect.TIMEOUT:
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Timed out while entering enable mode on SaM Infiniband gateway switch VIP")
    error("Timed out while entering enable mode on SaM Infiniband gateway switch VIP, exiting.\n", 1)

except:
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed while entering enable mode on SaM Infiniband gateway switch VIP")
    error("Failed while entering enable mode on SaM Infiniband gateway switch VIP, exiting.\n", 1)

else:
    print "Entered enable mode successfully."



# Check HA status
try:
    print "Checking HA status ..."
    ssh_connection.sendline("show proxy-arp ha")
    ssh_connection.expect(COMMAND_PROMPT, timeout=60)

except pexpect.TIMEOUT:
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Timed out while checking HA status on SaM Infiniband gateway switch VIP")
    error("Timed out while checking HA status on SaM Infiniband gateway switch VIP, exiting.\n", 1)

except:
    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed while checking HA status on SaM Infiniband gateway switch VIP")
    error("Failed while checking HA status on SaM Infiniband gateway switch VIP, exiting.\n", 1)

else:
    nodes_in_cluster = dict()

    for line in ssh_connection.before.split(os.linesep)[1:]:
        if line.startswith("rd-ib-gw-"):
            line_parts = line.split()

            nodes_in_cluster[line_parts[0]] = line_parts[1]

    if len(nodes_in_cluster) == 0: # This should never happen, how could we SSH to the VIP if no nodes are in the cluster?
        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-ALERT: No nodes detected in SaM Infiniband gateway switch HA cluster, cluster offline!?!?!?")
        print "FAILURE: No nodes detected in SaM Infiniband gateway switch HA cluster, cluster offline?"

    elif len(nodes_in_cluster) < 2:
        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-ALERT: Node is missing from SaM Infiniband gateway switch HA cluster")
        print "FAILURE: Node is missing from SaM Infiniband gateway switch HA cluster."

    else:
        for node in sorted(nodes_in_cluster.keys()):
            print "Node " + node + " has HA state '" + nodes_in_cluster[node] + "'"





# Check proxy-arp interfaces
interfaces = {
    "1" : "62",
    "2" : "3099"
}

for interface in interfaces:
    try:
        print "Checking proxy-arp interface " + interface + " (VLAN " + interfaces[interface] +  ") ..."
        ssh_connection.sendline("show interfaces proxy-arp " + interface + " ha")
        ssh_connection.expect(COMMAND_PROMPT, timeout=60)

    except pexpect.TIMEOUT:
        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Timed out while checking SaM Infiniband gateway switch proxy-arp interface " + interface + " (VLAN " + interfaces[interface] +  ") status")
        error("Timed out while checking SaM Infiniband gateway switch proxy-arp interface " + interface + " (VLAN " + interfaces[interface] +  ") status, exiting.\n", 1)

    except:
        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Failed while checking SaM Infiniband gateway switch proxy-arp interface " + interface + " (VLAN " + interfaces[interface] +  ") status")
        error("Failed while checking SaM Infiniband gateway switch proxy-arp interface " + interface + " (VLAN " + interfaces[interface] +  ") status, exiting.\n", 1)

    else:
        if re.search("% Proxy-arp " + interface + " does not exist", ssh_connection.before) is not None:
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-ALERT: Proxy-arp interface " + interface + " (VLAN " + interfaces[interface] +  ") on SaM Infiniband gateway switch HA cluster not found.")
            print "FAILURE: Proxy-arp interface " + interface + " (VLAN " + interfaces[interface] +  ") on SaM Infiniband gateway switch HA cluster not found."

            continue

        nodes_in_cluster = dict()

        for line in ssh_connection.before.split(os.linesep)[1:]:
            if line.startswith("  rd-ib-gw-"):
                line_parts = line.split()

                line_parts[0] = line_parts[0].rstrip("*")

                nodes_in_cluster[line_parts[0]] = dict()

                nodes_in_cluster[line_parts[0]]["lb_state"] = line_parts[2]
                nodes_in_cluster[line_parts[0]]["oper_state"] = line_parts[3]

        if len(nodes_in_cluster) == 0: # This should never happen, how could we SSH to the VIP if no nodes are in the cluster?
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-ALERT: No nodes detected on SaM Infiniband gateway switch HA cluster for proxy-arp interface " + interface + " (VLAN " + interfaces[interface] +  "), cluster offline!?!?!?")
            print "FAILURE: No nodes detected on SaM Infiniband gateway switch HA cluster for proxy-arp interface " + interface + " (VLAN " + interfaces[interface] +  "), cluster offline!?!?!?"

        elif len(nodes_in_cluster) < 2:
            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-ALERT: Node is missing on SaM Infiniband gateway switch HA cluster for proxy-arp interface " + interface + " (VLAN " + interfaces[interface] + ")")
            print "FAILURE: Node is missing on SaM Infiniband gateway switch HA cluster for proxy-arp interface " + interface + " (VLAN " + interfaces[interface] + ")"

        else:
            for node in sorted(nodes_in_cluster.keys()):
                if not nodes_in_cluster[node]["lb_state"] == "Active" or not nodes_in_cluster[node]["oper_state"] == "Up":
                    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-ALERT: Node " + node + " has LB state '" + nodes_in_cluster[node]["lb_state"] + "' and operational state '" + nodes_in_cluster[node]["oper_state"] + "' for proxy-arp interface " + interface + " (VLAN " + interfaces[interface] + ").  Should be 'Active' and 'Up'")
                    print "FAILURE: Node " + node + " has LB state '" + nodes_in_cluster[node]["lb_state"] + "' and operational state '" + nodes_in_cluster[node]["oper_state"] + "' for proxy-arp interface " + interface + " (VLAN " + interfaces[interface] + ").  Should be 'Active' and 'Up'"

                else:
                    print "Node " + node + " has LB state '" + nodes_in_cluster[node]["lb_state"] + "' and operational state '" + nodes_in_cluster[node]["oper_state"] + "' for proxy-arp interface " + interface + " (VLAN " + interfaces[interface] + ")."



ssh_connection.sendline("exit")



# Close syslog, we're done
syslog.closelog()
