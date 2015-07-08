#!/usr/bin/env python



import sys
import os
import subprocess
import re
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options]\n" +
    "Check the if the expected number of GPUs exist"
)

parser.add_option("-c", "--count",
    action="store", dest="expected_count", type="int",
    help="The count of GPUs expected to exist."
)

(options, args) = parser.parse_args()





deviceQuery_proc = subprocess.Popen(["/data/sam/cuda/5.5/bin/deviceQuery"], stdin=None, stdout=subprocess.PIPE, shell=False)

status = deviceQuery_proc.wait()

if status != 0:
    print "UNKNOWN: deviceQuery process exited non-zero, " + str(status)
    sys.exit(3)


match = re.search("Detected ([0-9]+) CUDA Capable device", deviceQuery_proc.communicate()[0])


if match is None:
    print "UNKNOWN: Failed to parse deviceQuery output"
    sys.exit(3)


if int(match.group(1)) != options.expected_count:
    print "CRITICAL: GPU count " + str(match.group(1)) + " does not match expected count of " + str(options.expected_count)
    sys.exit(2)


print "OK: GPU count " + str(match.group(1)) + " matches expected count of " + str(options.expected_count)
sys.exit(0)
