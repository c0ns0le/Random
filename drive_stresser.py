#!/usr/bin/env python
# Description: Write a random set of data in to a file over and over again
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.2
# Last change:
# * Fixed a bug in exit_handler() where sys.exit() was not always called
# * Fixed a bug where the amount of data written was not output because the bytes_written variable was not passed



# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys
import os
import traceback
import signal
import errno
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog /directory/to/write/to [options]\n" + 
    "Drive stresser: Write a random set of data in to a file over and over again.\n"
)

parser.add_option(
    "-b", "--background",
    action="store_true", dest="background", default=False,
    help="Silence and background the process (must be terminated with `kill`)"
)

parser.add_option(
    "-c", "--chunk", dest="chunk", type="int",
    help="How large of a chunk size to use in KB (default: 1MB)"
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
        
        
        
        
        
def print_amount_data_written(bytes_written):
    if bytes_written < 1048576: # MB
        print "\nWrote " + str(round(bytes_written / float(1024), 2)) + " KB of data"
        
    elif bytes_written < 1073741824: # GB
        print "\nWrote " + str(round(bytes_written / float(1024) / float(1024), 2)) + " MB of data"
        
    elif bytes_written < 1099511627776: # TB
        print "\nWrote " + str(round(bytes_written / float(1024) / float(1024) / float(1024), 2)) + " GB of data"
        
    else:
        print "\nWrote " + str(round(bytes_written / float(1024) / float(1024) / float(1024) / float(1024), 2)) + " TB of data"
        
    return None
        
        
        
        
        
# Where should we write our output to?
try:
    output_dir = sys.argv[1]
    
except IndexError:
    fatal_error("Unable to get directory to write to, see --help")
    

if os.path.isdir(output_dir) is False:
    os.makedirs(output_dir)
        
        
        
        
        
# Should we background ourself?
if options.background is True:
    # Set STDOUT and STDIN to /dev/null
    with open(os.devnull, "w") as dev_null:
        os.dup2(dev_null.fileno(), 0) # STDIN
        os.dup2(dev_null.fileno(), 1) # STDOUT
        
    # Fork time!
    os.chdir("/")
    
    pid = os.fork()
    
    if not pid == 0:
        print "Background process is PID " + str(pid)
        sys.exit(0)
    
    os.setsid()
    
    



# Get 1MB of randomish data and hold it in memory
print "Getting random data..."

if options.chunk is None:
    chunk_size = 1024 * 1024
    
else:
    chunk_size = options.chunk * 1024
    

with open("/dev/urandom", "r") as urandom_handle:
    data_chunk = urandom_handle.read(chunk_size)
    


# Keep track of how much data we wrote
bytes_written = 0


# Pick a randomish file name and write to it
outfile = output_dir + "/" + "driver_stresser_out." + str(os.getpid())

with open(outfile, "w+") as outfile_handle:
    print "Output file is " + outfile
    
    # Clean up our data when we are asked to terminate
    def exit_handler(signum, frame):
        if os.path.exists(outfile):
            os.remove(outfile)
            
            if options.background is False:
                print_amount_data_written(bytes_written)
            
        sys.exit(0)
            
    signal.signal(signal.SIGTERM, exit_handler)
    signal.signal(signal.SIGINT, exit_handler)
        
        
    # Write the data chunk
    print "Writing..."
    while True:
        try:
            outfile_handle.write(data_chunk)
        
            bytes_written += len(data_chunk)
            
        except IOError as err:
            if err.errno == errno.ENOSPC:
                if options.background is False:
                    print_amount_data_written(bytes_written)
                    
                sys.stderr.write("No space left on " + output_dir + "\n")
                
                sys.exit(1)
                
            else:
                fatal_error()
        
