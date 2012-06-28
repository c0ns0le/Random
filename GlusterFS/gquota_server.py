#!/usr/bin/python
# Description: Remote GlusterFS quota viewer - Server
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

from SimpleXMLRPCServer import SimpleXMLRPCServer
from SimpleXMLRPCServer import SimpleXMLRPCRequestHandler
import commands
import socket
import logging
import logging.handlers
import signal
import sys
import os
import atexit
import time
import re
import shlex
import subprocess
import SocketServer
class Daemon:

        def __init__(self, pidfile, stdin='/dev/null', stdout='/dev/null', stderr='/dev/null'):
                self.stdin = stdin
                self.stdout = stdout
                self.stderr = stderr
                self.pidfile = pidfile

        def daemonize(self):

                try:
                        pid = os.fork()
                        if pid > 0:
                                # exiting parent process with 0#
                                sys.exit(0)

                except OSError, e:
                        sys.stderr.write("process fork #1 failed: {0} {1}\n".format(e.errno, e.strerror))
                        sys.exit(1)

                #decouple#
                os.chdir("/")
                os.setsid()
                os.umask(0)

                # fork a second time #

                try:
                        pid = os.fork()
                        if pid > 0:
                                # exiting parent process with 0#
                                sys.exit(0)

                except OSError, e:
                        sys.stderr.write("process fork #2 failed: {0} {1}\n".format(e.errno, e.strerror))
                        sys.exit(1)


                # IO redirection #

                sys.stdout.flush()
                sys.stderr.flush()
                si = file(self.stdin, 'r')
                so = file(self.stdout, 'a+')
                se = file(self.stderr, 'a+', 0)
                os.dup2(si.fileno(), sys.stdin.fileno())
                os.dup2(so.fileno(), sys.stdout.fileno())
                os.dup2(se.fileno(), sys.stderr.fileno())

                #write a pidfile#
                atexit.register(self.delpid)
                pid = str(os.getpid())
                pfile = file(self.pidfile, 'w+')
                pfile.write("{0}".format(pid))



        def delpid(self):
                os.remove(self.pidfile)



        def start(self):

                try:
                        pf = file(self.pidfile, 'r')
                        pid = int(pf.read().strip())
                        pf.close()
                except IOError:
                        pid = None

                if pid:
                        message = "pidfile {0} already exists".format(self.pidfile)
                        sys.stderr.write(message)
                        sys.exit(1)

                self.daemonize()

                self.run()




        def stop(self):
                try:
                        pf = file(self.pidfile, 'r')
                        pid = int(pf.read().strip())
                        pf.close()
                except IOError:
                        pid = None
                if not pid:
                        message = "pidfile {0} does not exist.".format(self.pidfile)
                        sys.stderr.write(message)
                        return


                try:
                        while 1:
                                os.kill(pid, signal.SIGTERM)
                                time.sleep(0.1)
                                print "quota_server.py stopped..."
                except OSError, err:
                        err = str(err)
                        if err.find("No such process") > 0:
                                if os.path.exists(self.pidfile):
                                        os.remove(self.pidfile)

                        else:
                                print str(err)
                                sys.exit(1)




        def restart(self):
                self.stop()
                self.start()



        def run(self):
                pass


class ForkingXMLRPCServer (SocketServer.ForkingMixIn, SimpleXMLRPCServer):
        pass




class ServerDaemon(Daemon):

        def run(self):



                class RequestHandler(SimpleXMLRPCRequestHandler):
                        rpc_paths = ('/RPC2')

                server = ForkingXMLRPCServer((socket.gethostname(), 9001), requestHandler=RequestHandler)
                server.register_introspection_functions()


                def getquota(path, vol):

                        if re.match(".*/$", path):
                                path = path[:-1]


                        gluster_output = commands.getstatusoutput("/usr/sbin/gluster volume quota {0} list {1}".format(vol, path))


                        if (int(gluster_output[0]) != 0):

                                return "Error 1, gluster command failed"

                        if '\n' not in gluster_output[1]:

                                return "No quota found for {0}".format(path)




                        else:

                                dir = gluster_output[1].split('\n')[2].split()[0]
                                quota = gluster_output[1].split('\n')[2].split()[1]

                                try:

                                        used = gluster_output[1].split('\n')[2].split()[2]

                                except IndexError, e:

                                        used = 0


                                return "{0}, {1} of {2} used".format(path, used, quota)


                server.register_function(getquota, 'getquota')






                server.serve_forever()





if __name__ == "__main__":
        Server = ServerDaemon('/tmp/quota_server.pid')
        if len(sys.argv) == 2:
                if 'start' == sys.argv[1]:
                        Server.start()
                elif 'stop' == sys.argv[1]:
                        Server.stop()
                elif 'restart' == sys.argv[1]:
                        Server.restart()
                else:
                        print "Unknown command::: usage  = start|stop|restart"
                        sys.exit(2)

                sys.exit(0)

        else:
                print "usage: {0} start|stop|restart".format(sys.argv[0])
                sys.exit(2)