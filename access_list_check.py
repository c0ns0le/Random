#!/usr/bin/env python
# Description: Check that access lists on switches match
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import os, re, sys, glob
from optparse import OptionParser



# If you add switches here you must add them to the loop(s) later in this script
switches = {
    "rd-core-1" : {},
    "rd-core-2" : {},
    "rd-core-3" : {},
    "rd-core-4" : {},
    "rd-core-5" : {},
    "rd-core-6" : {}
}



# How were we called?
parser = OptionParser("%prog [options] $nodes\nCheck that access lists on switches match")

parser.add_option("-v", "--verbose",
    action="store_true", dest="verbose", default=False,
    help="Verbose mode"
)

(options, args) = parser.parse_args()



# Compare two lists for differences
def compare_lists(list1, list2):
    # Returns True if the lists match False otherwise
    
    diff_list = [item for item in list1 if not item in list2]
    
    diff_list2 = [item for item in list2 if not item in list1]
    
    if (len(diff_list) > 0) or (len(diff_list2) > 0):
        return False
    
    else:
        return True
    
    

#
# Find the latest config file of each switch
#

if options.verbose is True: sys.stdout.write("Finding the latest config files ...\n")

for switch in switches:
    highest_mtime = int()
    
    latest_config = ""
    
    switch_dict = switches[switch]

    for config_file in glob.iglob("/tftpboot/ciscoconfg/" + switch + ".gw*"):
        if options.verbose: sys.stdout.write("Checking file " + config_file + " ...\n")
        
        mtime = os.stat(config_file).st_mtime
        
        if mtime > highest_mtime:
            latest_config = config_file
            
            highest_mtime = mtime
            
    # Build a dictionary of switch to latest config file
    switch_dict.update({"latest_config" : latest_config})
    
    

#
# Loop through each config file and create a list rules in each access list for each switch
#

if options.verbose is True: sys.stdout.write("Reading the latest config files ...\n")

for switch in switches:    
    switch_dict = switches[switch]
    
    switch_dict.update({
        "access_lists" : {}
    })
    
    access_lists_dict = switch_dict["access_lists"]
    
    access_list = ""
    
    try:
        print "Latest config: " + switch_dict["latest_config"]
        config_file_handle = open(switch_dict["latest_config"], "r")
        
    except IOError as err:
        sys.stderr.write("Failed to open latest config file for " + switch + "\n")
        
    for line in config_file_handle:
        line = line.rstrip()
        
        # Did we hit a new access list?
        match = re.match("^(ip|mac)\s*access-list", line)
        
        if match is not None:
            access_list = line.split()[-1]
            
            if options.verbose is True: sys.stdout.write("Found a access list: " + access_list + "\n")
            
            # Add the access list to the dictionary for this switch
            access_lists_dict.update({
                access_list : []
            })

            continue
            
        # Did we hit a new rule in the current access list?
        match = re.match("^\s*(permit|deny)", line)
        
        if match is not None:
            if options.verbose is True: sys.stdout.write("Found a new rule for " + access_list + " : " + line + "\n")

            current_access_list_list = access_lists_dict[access_list]
            
            current_access_list_list.append(line)
            
    config_file_handle.close()
            
            
            
#
# Compare the lists for each switch
#

# Compare rd-core-1 and rd-core-3

if options.verbose is True: sys.stdout.write("Comparing access lists for rd-core-1 vs rd-core-3 ...\n")

for access_list in sorted(switches["rd-core-1"]["access_lists"]):
    if options.verbose is True: sys.stdout.write("Checking access list: " + access_list + "\n")

    try:
        if compare_lists(switches["rd-core-1"]["access_lists"][access_list], switches["rd-core-3"]["access_lists"][access_list]) is False:
            sys.stdout.write("Access list " + access_list + " differs between rd-core-3 and rd-core-1!\n")
            
            for rule in switches["rd-core-1"]["access_lists"][access_list]:
                if rule not in switches["rd-core-3"]["access_lists"][access_list]:
                    sys.stdout.write("     Missing rule on rd-core-3: " + rule + "\n")
                    
            for rule in switches["rd-core-3"]["access_lists"][access_list]:
                if rule not in switches["rd-core-1"]["access_lists"][access_list]:
                    sys.stdout.write("     Missing rule on rd-core-1: " + rule + "\n")
            
    except KeyError:
        sys.stdout.write("Access list " + access_list + " is missing on rd-core-3 (exists on rd-core-1)!\n")
                
        
# Compare rd-core-2, rd-core-4, rd-core-5 and rd-core-6

for switch in ["rd-core-2", "rd-core-4", "rd-core-5", "rd-core-6"]:
    if options.verbose is True: sys.stdout.write("Checking switch: " + switch + "\n")
        
    for access_list in sorted(switches["rd-core-2"]["access_lists"]):
        if options.verbose is True: sys.stdout.write("Checking access list: " + access_list + "\n")

        try:
            if compare_lists(switches[switch]["access_lists"][access_list], switches["rd-core-2"]["access_lists"][access_list]) is False:
                sys.stdout.write("Access list " + access_list + " differs between rd-core-2 and " + switch + "!\n")
                
                for rule in switches["rd-core-2"]["access_lists"][access_list]:
                    if rule not in switches[switch]["access_lists"][access_list]:
                        sys.stdout.write("     Missing rule on " + switch + ": " + rule + "\n")
                    
                for rule in switches[switch]["access_lists"][access_list]:
                    if rule not in switches["rd-core-2"]["access_lists"][access_list]:
                        sys.stdout.write("     Missing rule on rd-core-2: " + rule + "\n")
                
        except KeyError:
            sys.stdout.write("Access list " + access_list + " is missing on " + switch + " (exists on rd-core-2)!\n")
                
sys.stdout.write("Done!\n")




