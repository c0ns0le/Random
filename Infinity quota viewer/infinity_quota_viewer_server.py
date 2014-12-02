#!/usr/bin/env python
# Description: Display the quota of a user or group of an Infinity volume - server
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
import signal
import subprocess
import time
from SimpleXMLRPCServer import SimpleXMLRPCServer
from SimpleXMLRPCServer import SimpleXMLRPCRequestHandler
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Display the quota of a user or group of an Infinity volume - server."
)


parser.add_option(
    "-d", "--daemonize",
    action="store_true", dest="daemonize", default=False,
    help="Become a background daemon"
)


(options, args) = parser.parse_args()



# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)





def get_quota(name):
    infidisplay_info = subprocess.Popen(["/ovmh/bin/infidisplay", "-v", "test", "--quota"], stdin=None, stdout=subprocess.PIPE, shell=False)
    status = infidisplay_info.wait()
    
    if status != 0:
        return "Error, `infinidisplay` returned exit code " + str(status)
    
    else:
        for line in infidisplay_info.communicate()[0].split(os.linesep):
            if re.search(" " + name + " ", line) is not None:
                return "Type   Name   Limit    Used\n----   ----   -----    ----\n" + line
            
    syslog.syslog(syslog.LOG_ERR, "No Infinity quota could be found for user/group " + name + ". - NOC-NETCOOL-TICKET")
    return "Error, Infinity quota could not be found"





# Become a daemon if we were told to do so
if options.daemonize is True:
    pid = os.fork()
    
    if pid == 0: # Child
        os.setsid()
        # Set STDOUT, STDERR and STDIN to /dev/null
        dev_null = open(os.devnull, "w")
        
        os.dup2(dev_null.fileno(), 0) # STDIN
        os.dup2(dev_null.fileno(), 1) # STDOUT
        os.dup2(dev_null.fileno(), 2) # STDERR
        
    else:
        sys.exit(0)
        
        
    
# Restrict to a particular path.
class RequestHandler(SimpleXMLRPCRequestHandler):
    rpc_paths = ('/RPC2',)



# Create server
server = SimpleXMLRPCServer(("0.0.0.0", 8000), requestHandler=RequestHandler)
server.register_introspection_functions()



# Register our functions
server.register_function(get_quota)



# Run the server's main loop
server.serve_forever()



# We're done with syslog
syslog.closelog()
