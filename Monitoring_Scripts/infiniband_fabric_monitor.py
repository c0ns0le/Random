#!/usr/bin/env python





import sys
import subprocess
import re
import os
import traceback
import pickle
import syslog
import datetime
import smtplib
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email import Encoders
from optparse import OptionParser





pickle_file = "/usr/local/etc/infiniband_fabric_monitor.pck"
red = "\033[31m"
endcolor = "\033[0m"





# How were we called?
parser = OptionParser("%prog\n" +
    "Monitor the status and health of an Infiniband fabric"
)


parser.add_option("-v", "--verbose",
    action="store_true", dest="verbose", default=False,
    help="Verbose mode"
)


(options, args) = parser.parse_args()





# Print a stack trace, exception, and an error string to STDERR
# then exit with the exit status given (default: 1) or don't exit
# if passed NoneType
def error(error_string, exit_status=1):
    exc_type, exc_value, exc_traceback = sys.exc_info()

    traceback.print_exception(exc_type, exc_value, exc_traceback)

    sys.stderr.write("\n" + red + str(error_string) + endcolor + "\n")

    if exit_status is not None:
        sys.exit(exit_status)





# Return a "pretty" timestamp: 2013-07-04 13:58:47
def timestamp():
    return datetime.datetime.today().strftime("%Y-%m-%d %H:%M:%S")





# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)





class fabric(object):
    def __init__(self, sm_guid, sm_desc):
        """ Create an empty fabric object.
        """

        self.switches = dict()


    def add_switch(self, switch):
        """ Add a switch object to the fabric.
        """

        self.switches[switch.guid] = switch

    def get_switch(self, guid):
        """ Return a switch object of a GUID or NoneType if no switch by thta GUID exists in the fabric.
        """

        try:
            return self.switches[guid]

        except KeyError:
            return None



class switch(object):
    def __init__(self, guid, desc):
        """ Create a new switch object.
        """

        self.guid = guid
        self.desc = desc
        self.endpoints = dict()

    def add_endpoint(self, endpoint):
        """ Add a endpoint object to a switch.
        """

        self.endpoints[endpoint.guid] = endpoint

    def get_endpoint(self, guid):
        """ Return a endpoint object of a GUID or NoneType if no endpoint by that GUID exists on the switch.
        """

        try:
            return self.endpoints[guid]

        except KeyError:
            return None



class endpoint(object):
    # Node isn't really the correct term here as switches are considered "endpoints" of a fabric just as
    # much as endpoint systems are.
    def __init__(self, guid, desc, etype, port):
        """ Create a new endpoint object.
        """

        self.guid = guid
        self.desc = desc
        self.etype = etype
        self.port = port





if os.path.exists(pickle_file) is False:
    print "No previous pickle file found, running in discover only mode.\n"

    discover_only_mode = True

else:
    with open(pickle_file, "r") as pickle_handle:
        old_fabric_obj = pickle.load(pickle_handle)

    discover_only_mode = False





# Find the subnet manager
print "Checking for subnet manager ..."
ibstat_process = subprocess.Popen(["ibstat"], stdout=subprocess.PIPE, shell=False)

out = ibstat_process.communicate()[0]

match = re.search("SM lid: (\d+)", out)

sm_lid = match.group(1)


smpquery_process = subprocess.Popen(["smpquery", "ND", "-L", sm_lid], stdout=subprocess.PIPE, shell=False)

out = smpquery_process.communicate()[0]

match = re.search("\.+(.*)", out)

sm_desc = match.group(1)
sm_desc = re.sub("MF0;", "", sm_desc)


smpquery_process = subprocess.Popen(["smpquery", "NI", "-L", sm_lid], stdout=subprocess.PIPE, shell=False)

out = smpquery_process.communicate()[0]

match = re.search("\nGuid:\.+0x(.*)", out)

sm_guid = match.group(1)

if options.verbose is True:
    print "Found subnet mananager: " + sm_guid + " (desc: " + sm_desc + ")"





new_fabric_obj = fabric(sm_guid, sm_desc)





# Get what switches are in the fabric
print "Scanning the fabric ..."
ibnetdiscover_process = subprocess.Popen(["ibnetdiscover"], stdout=subprocess.PIPE, shell=False)

out = ibnetdiscover_process.communicate()[0]

for line in out.split(os.linesep):
    line = line.rstrip()

    if line == "":
        continue

    #print line

    if line.startswith("Switch"):
        # If we already have a switch object, we are now done with it so add it to the fabric
        try:
            new_fabric_obj.add_switch(my_switch)

        except NameError:
            pass

        # We found a new switch
        match = re.search('"([^"]+)".*"([^"]+)"', line)

        guid = re.sub("S-", "", match.group(1))

        desc = re.sub("MF0;", "", match.group(2))

        my_switch = switch(guid, desc)

        if options.verbose is True:
            print "Found switch: " + guid + " (desc: " + desc + ")"

    elif line.startswith("["):
        # We found a connection on a switch
        match = re.search('\[(\d+)\]\s+"([^"]+)"[^"]+"([^"]+)"', line)

        port = match.group(1)

        if match.group(2).startswith("H"):
            etype = "host"

        elif match.group(2).startswith("S"):
            etype = "switch"

        guid = re.sub("[A-Z]-", "", match.group(2))

        desc = match.group(3)
        desc = re.sub("MF0;", "", desc)
        desc = re.sub("HCA-[\d]", "", desc)
        desc = re.sub("\s+$", "", desc)

        # Prepend the port to the GUID if it is a switch (it could have multiple connections which use the same GUID)
        if etype == "switch":
            guid = port + "-" + guid

        # Create a new endpoint object
        my_endpoint = endpoint(guid, desc, etype, port)

        # Add the endpoint to the switch
        my_switch.add_endpoint(my_endpoint)

        if options.verbose is True:
            print "Found endpoint: " + guid + " (desc: " + desc + ", etype: " + etype + ", port: " + port + ")"

    elif line.startswith("Ca"):
        # Done with ibnetdiscover output, add the last switch we found to the fabric object and move one
        new_fabric_obj.add_switch(my_switch)

        break





# Save the current fabric state for the next run to use
with open(pickle_file, "w") as pickle_handle:
    pickle.dump(new_fabric_obj, pickle_handle)





if discover_only_mode == False:
    print "Comparing current fabric to last known configuration ..."

    # Did a switch disappear?
    for each_switch in old_fabric_obj.switches:
        new_switch_obj = new_fabric_obj.get_switch(each_switch)

        if new_switch_obj is None:
            old_switch_obj = old_fabric_obj.get_switch(each_switch)

            email_body = list()

            syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET - Switch disappeared from fabric! (GUID: " + old_switch_obj.guid + ", desc: " + old_switch_obj.desc + ")")
            print red + "Switch disappeared from fabric! (GUID: " + old_switch_obj.guid + ", desc: " + old_switch_obj.desc + ")" + endcolor
            email_body.append("Switch disappeared from fabric! (GUID: " + old_switch_obj.guid + ", desc: " + old_switch_obj.desc + ")\n")

            print "    Endpoints now missing:"
            email_body.append("    Endpoints now missing:\n")

            for endpoint in old_switch_obj.endpoints:
                endpoint_obj = old_switch_obj.get_endpoint(endpoint)

                print "        " + endpoint_obj.guid + " (desc: " + endpoint_obj.desc + ", etype: " + endpoint_obj.etype + ", port: " + endpoint_obj.port + ")"
                email_body.append("        " + endpoint_obj.guid + " (desc: " + endpoint_obj.desc + ", etype: " + endpoint_obj.etype + ", port: " + endpoint_obj.port + ")\n")

            # Email message
            msg = MIMEMultipart()
            msg["From"] = "null@example.edu"
            msg["To"] = "jaw171@example.edu"
            msg["Subject"] = "Infiniband fabric monitor alert - Switch disappeared from fabric!"
            msg.attach(MIMEText("".join(email_body)))
            smtp = smtplib.SMTP('localhost')
            smtp.sendmail("null@example.edu", ["jaw171@example.edu"], msg.as_string())
            smtp.quit()

        else:
            if options.verbose is True:
                print "Switch " + new_switch_obj.guid + " (desc: " + new_switch_obj.desc + ") found"

            # Did an inter-switch link or endpoint disappear?
            old_switch_obj = old_fabric_obj.get_switch(each_switch)

            for each_endpoint in old_switch_obj.endpoints:
                new_endpoint_obj = new_switch_obj.get_endpoint(each_endpoint)

                if new_endpoint_obj is None:
                    old_endpoint_obj = old_switch_obj.get_endpoint(each_endpoint)

                    if old_endpoint_obj.etype == "host":
                        print red + "Host disappeared from fabric! (GUID: " + each_endpoint + ", desc: " + desc + ", port: " + port + ", switch GUID: " + old_switch_obj.guid + ", switch desc: " + old_switch_obj.desc + ")" + endcolor

                    elif old_endpoint_obj.etype == "switch":
                        syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET - Inter-switch link disappeared from fabric! (GUID: " + each_endpoint + ", desc: " + desc + ", port: " + port + ", switch GUID: " + old_switch_obj.guid + ", switch desc: " + old_switch_obj.desc + ")")
                        print red + "Inter-switch link disappeared from fabric! (GUID: " + each_endpoint + ", desc: " + desc + ", port: " + port + ", switch GUID: " + old_switch_obj.guid + ", switch desc: " + old_switch_obj.desc + ")" + endcolor





# Generate a diagram of the fabric
# TODO: /usr/local/ibgraph/graphGenerator.py -s Colosse /tmp/sam.txt /tmp/graph.svg





syslog.closelog()

print "Done!"
