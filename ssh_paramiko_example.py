#!/usr/bin/env python
# Description: Example of how to use Paramiko
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



#cat>/tmp/justsayfuck
##!/bin/bash

#echo "Fuck"

#echo "I said fuck!" 1>&2  

#exit 7



import sys, paramiko


  
try:
  # Create the client object
  ssh = paramiko.SSHClient()

  
  # Handle keys
  ssh.load_system_host_keys()
  ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
  
  
  # Connect and create a channel
  ssh.connect("clusman0-dev.francis.sam.pitt.edu")
  channel = ssh.get_transport().open_session()

  
  # Create file object we can use normal I/O stuff with
  stdin = channel.makefile("wb", 1024)
  stdout = channel.makefile("rb", 1024)
  stderr = channel.makefile_stderr("rb", 1024)
  
  
  # Ok, run our commands ... the exit status will be of the *shell*
  # we invoked, not the program ran!
  channel.exec_command("/tmp/justsayfuck; exit $?")
  
  
  # Handle our I/O (Python will block waiting for I/O so we don't need recv_ready)
  stdin.close()
  
  out = stdout.read()
  stdout.close()  
  if out:
    sys.stdout.write("Out: " + out)
  
  err = stderr.read()
  stderr.close()  
  if err:
    sys.stderr.write("Err: " + err)
  
  
  # Get the exit status
  status = channel.recv_exit_status()
  sys.stdout.write("Status: " + str(status) + "\n")
  
  
  # Done!
  channel.close()
  ssh.close()
  
except Exception, err:
  sys.stderr.write("We failed: " + str(err) + "\n")