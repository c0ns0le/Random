#!/usr/bin/python
# Description: Remote GlusterFS quota viewer - Client
# Originally written by m0zes of #gluster on irc.freenode.net
# Written by: Adam Cerini of the University of Pittsburgh
# Version: 1
# Last change: Initial version

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

import xmlrpclib
import os
from optparse import OptionParser


optparser = OptionParser()

optparser.add_option("-p", "--path", type="string", dest="path", help="Specify path to check quota")


optparser.add_option("-v", "--volume", type="string", dest="vol", help="Specify volume where path lives")
(options, args) = optparser.parse_args()




gserver = ''


if options.path is None:
        optparser.error("Must specify path to check with -p or --path and volume with -v or --volume")

if options.vol is None:
        optparser.error("Must specify volume to check with -v or --volume and volume with -v or --volume")





if options.vol == 'vol_home':
        gserver = 'http://storage1.frank.sam.pitt.edu:9001'
elif options.vol == 'vol_global_scratch':
        gserver = 'http://storage2.frank.sam.pitt.edu:9001'
elif options.vol == 'vol_span':
        gserver = 'http://storage0-dev.cssd.pitt.edu:9001'
else:
        print("{0} is not a valid volume".format(vol))
        exit(1)





try:
        client = xmlrpclib.ServerProxy(gserver)
        result = client.getquota(options.path, options.vol)
except:
        print("Could not connect to {0}".format((gserver[7:])[:-5]))
        exit(1)

print result
exit()