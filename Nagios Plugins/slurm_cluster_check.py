#!/usr/bin/env python



import sys
import os
import traceback
import pyslurm
from optparse import OptionParser



# How were we called?
parser = OptionParser("%prog [options]\n" +
    "Check the overall status of SLURM compute nodes in a cluster"
)

(options, args) = parser.parse_args()





node_states = {
    "down" : 0,
    "fail" : 0,
    "failing" : 0,
    "drain" : 0,
    "unknown" : 0,
    "idle" : 0,
    "allocated" : 0,
}





a = pyslurm.node()

node_dict = a.get()

for node in node_dict:
    node_states[node_dict[node]["node_state"].rstrip("*").lower()] += 1





if node_states["down"] >= 10:
    print "DOWN CRITICAL: " + str(node_states)
    sys.exit(2)

elif node_states["fail"] >= 10:
    print "FAIL CRITICAL: " + str(node_states)
    sys.exit(2)

elif node_states["failing"] >= 10:
    print "FAILING CRITICAL: " + str(node_states)
    sys.exit(2)

elif node_states["unknown"] >= 10:
    print "UNKNOWN: " + str(node_states)
    sys.exit(3)

else:
    print "OK: " + str(node_states)
    sys.exit(0)
