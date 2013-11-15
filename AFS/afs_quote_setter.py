#!/usr/bin/env python
# Description: AFS quota setter
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version



# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, subprocess, traceback, re
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options] file_with_ucas.txt quota_amount\n" + 
    "AFS quota setter"
)

(options, args) = parser.parse_args()



# Print a stack trace, exception, and an error string to STDERR
# then exit with the exit status given (default: 1) or don't exit
# if passed NoneType
def fatal_error(error_string, exit_status=1):
    red = "\033[31m"
    endcolor = "\033[0m"

    exc_type, exc_value, exc_traceback = sys.exc_info()

    traceback.print_exception(exc_type, exc_value, exc_traceback)

    sys.stderr.write("\n" + red + str(error_string) + endcolor + "\n")
    
    if exit_status is not None:
        sys.exit(int(exit_status))
        
        
        
        
        
try:
    uca_file = sys.argv[1]
    
    uca_file_handle = open(uca_file, "r")
    
except:
    fatal_error("Unable to open UCA file, see --help.")
    
    
try:
    quota_amount = sys.argv[2]
    
except:
    fatal_error("Unable to get quota amount from the command line, see --help.")
    
    
    
for uca in uca_file_handle:
    uca = uca.rstrip()
    
    
    uca_path = "/afs/pitt.edu/home/" + uca[0] + "/" + uca[1] + "/" + uca
    
    # Verify the new quota is greater than the current quota
    quota_info = subprocess.Popen(["fs", "lq", uca_path], stdout=subprocess.PIPE, shell=False)
    out = quota_info.communicate()[0]
    
    for line in out.split(os.linesep):
        line = line.rstrip()
        
        # Skip lines we don't care about
        if re.search("^u\.", line) is not None:
            current_quota = line.split()[1]
            
        
    if int(current_quota) > int(quota_amount):
        print "Skipping user " + uca + " as the current quota is higher than the requested quota"
        
        continue
    
    
    print "Setting quota of " + quota_amount + " on user " + uca
    
    fs_proc = subprocess.Popen(["fs", "sq", uca_path, quota_amount], shell=False)
    status = fs_proc.wait()
    
    if status == 0:
        print "Success\n"
        
    else:
        sys.stderr.write("Failed\n\n")
    
