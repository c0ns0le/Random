#!/usr/bin/env python
# Description: Parse syslog and determine when compute nodes were down
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.2
# Last change: Added a regex to catch more node down messages

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, re, datetime, time
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Parse syslog and determine when compute nodes were down.\n"
)

(options, args) = parser.parse_args()



if len(sys.argv) is 1:
    sys.stderr.write("No log files specified, see --help.\n")
    sys.exit(2)
    
    

# Get the log file names
log_files = []
for arg_num in range(1, len(sys.argv)):
    if os.path.isfile(sys.argv[arg_num]):
        log_files.append(sys.argv[arg_num])
    

    
if len(log_files) is 0:
    sys.stderr.write("No log files specified, see --help.\n")
    sys.exit(2)

    
    
class node_class:
    pass

    
# Loop through the log files and gather the data
nodes = {}
earliest_time = 0
latest_time = 0
down_re1 = re.compile("^(\w+\s+\d+\s+\d+:\d+:\d+)\s+<.*Node (\d+) is not up, state: down$")
down_re2 = re.compile("^(\w+\s+\d+\s+\d+:\d+:\d+)\s+<.*bpmaster:\s+lost connection to slave (\d+) on read$")
up_re = re.compile("^(\w+\s+\d+\s+\d+:\d+:\d+)\s+<.*I, node (\d+), am now alive$")

for log_file in log_files:
    log_file_handle = open(log_file, "r")
    
    for line in log_file_handle:
        line = line.rstrip()
        
        # Throw away lines we don't care about and get the data we care about
        timestamp = ""
        node = ""
        
        match_down1 = down_re1.search(line)
        match_down2 = down_re2.search(line)
        match_up = up_re.search(line)
        
        if match_down1:
            timestamp = match_down1.group(1)
            node = match_down1.group(2)
            
        elif match_down2:
            timestamp = match_down2.group(1)
            node = match_down2.group(2)
        
        elif match_up:
            timestamp = match_up.group(1)
            node = match_up.group(2)
                
        else:
            continue
        
        
        # Convert the timestamp to epoch time
        timestamp = re.sub("\s+", " ", timestamp)
        epoch_time = int(time.mktime(time.strptime(datetime.datetime.today().strftime("%Y") + " " + timestamp, "%Y %b %d %H:%M:%S")))
        
        
        # Note the time if it is the earliest or latest we've seen
        if earliest_time is 0 and latest_time is 0:
            earliest_time = epoch_time
            latest_time = epoch_time
        
        else:
            if epoch_time < earliest_time:
                earliest_time = epoch_time
                
            if epoch_time > latest_time:
                latest_time = epoch_time
        
        
        # Create or get the node object
        if node in nodes:
            node_obj = nodes[node]
        
        else:
            node_obj = node_class()
            
            node_obj.down_times = []
            node_obj.up_times = []
            node_obj.state = ""
            
            nodes[node] = node_obj
            
        
        # Add the data to the node object
        if match_down1 and node_obj.state is not "down":
            node_obj.down_times.append(epoch_time)
            node_obj.state = "down"
            
        elif match_down2 and node_obj.state is not "down":
            node_obj.down_times.append(epoch_time)
            node_obj.state = "down"
        
        elif match_up and node_obj.state is not "up":
            node_obj.up_times.append(epoch_time)
            node_obj.state = "up"
            
            
    log_file_handle.close()
        
        
        
        
        
# Look through the data and print our final output
sys.stdout.write("Node down data starting at " + datetime.datetime.fromtimestamp(earliest_time).strftime("%Y-%m-%d at %T") + "\n")
       
      
# I would expect there to be a cleaner way to sort the keys numerically but fuck it
nodes_list = []   
for i in nodes.iterkeys():
    i = int(i)
    nodes_list.append(i)
    
nodes_list.sort()

for node in nodes_list:
    node = str(node)
    node_obj = nodes[node]
    
    sys.stdout.write("Node " + node + "\n")
    
    while len(node_obj.down_times) is not 0 or len(node_obj.up_times) is not 0:
        # Get the lowest up/down times
        if len(node_obj.down_times) is 0:
            down_time = 0
            
        else:
            down_time = min(node_obj.down_times)
            
        if len(node_obj.up_times) is 0:
            up_time = 0
    
        else:
            up_time = min(node_obj.up_times)
        
        
        # If the lowest down time is higher than the lowest up time,
        # then we missed a down (most likely it's in an older log file).
        # Don't remove this down, it may coincide with the next up
        if down_time > up_time and up_time is not 0:
            down_time = 0

            
        # Remove non-zero entries from the lists, we're done with them
        if down_time is not 0:
            node_obj.down_times.remove(down_time)
            
        if up_time is not 0:
            node_obj.up_times.remove(up_time)
            
        
        # Print the data
        if down_time is 0:
            sys.stdout.write("  Down: unknown\n")
            
        else:
            sys.stdout.write("  Down: " + datetime.datetime.fromtimestamp(float(down_time)).strftime("%Y-%m-%d at %T") + "\n")
            
            
        if up_time is 0:
            sys.stdout.write("  Up: unknown\n")
            
        else:
            sys.stdout.write("  Up: " + datetime.datetime.fromtimestamp(float(up_time)).strftime("%Y-%m-%d at %T") + "\n")
            
        
        if down_time is not 0 and up_time is not 0:
            diff = up_time - down_time
            
            days = diff / (60 * 60 * 24)
            
            remaining_seconds = diff - days
            
            sys.stdout.write("  Outage: " + str(days) + " days " + time.strftime('%H:%M:%S', time.gmtime(remaining_seconds)) + "\n\n")
            
        else:
            sys.stdout.write("\n")
    
    
        
sys.stdout.write("Node down data ending at " + datetime.datetime.fromtimestamp(latest_time).strftime("%Y-%m-%d at %T") + "\n")
