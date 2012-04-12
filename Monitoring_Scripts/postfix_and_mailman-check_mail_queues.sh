#!/bin/bash
#Description: Bash script to check that the mail queues are ok.  This also can log the size of each queue on a regular interval for performance monitoring.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
# 1.0 - 2012-4-6 - Ported to RHEL 6 from Solaris 10, made it look less ugly. - Jeff White
# 0.1 - 2011-05-17 - Initial version. - Jeff White
#####

#Logging options.
logfile="/var/log/mailq.stats"
logmode="1" #Set this to 0 to turn off logging.

#Mailman queue settings.
#Outgoing queue
mmoutqdir="/var/mailman/qfiles/out"
mmoutqthreshold="20"

#Archive queue
mmarchiveqdir="/var/mailman/qfiles/archive"
mmarchiveqthreshold="20"

#Bounces queue
mmbouncesqdir="/var/mailman/qfiles/bounces"
mmbouncesqthreshold="20"

#Email commands queue
mmcommandsqdir="/var/mailman/qfiles/commands"
mmcommandsqthreshold="20"

#Incoming queue
mminqdir="/var/mailman/qfiles/in"
mminqthreshold="20"

#News queue
mmnewsqdir="/var/mailman/qfiles/news"
mmnewsqthreshold="20"

#Retry queue
mmretryqdir="/var/mailman/qfiles/retry"
mmretryqthreshold="20"

#Shunt queue
mmshuntqdir="/var/mailman/qfiles/shunt"
mmshuntqthreshold="20"

#Virgin queue
mmvirginqdir="/var/mailman/qfiles/virgin"
mmvirginqthreshold="20"

#Postfix queue settings. - Note that each file in each queue is one piece of mail but could have many recipients.
#Active queue.  The active queue is a limited-size queue for mail that the queue manager has opened for delivery.

#Whenever there is space in the active queue, the queue manager lets in one message from the incoming queue and one from the deferred queue.
pfactivequeuedir="/var/spool/postfix/active/"
pfactiveqthreshold="500"

#Incoming queue.  The incoming queue is for mail that is still arriving or that the queue manager hasn't looked at yet.
pfincomingqueuedir="/var/spool/postfix/incoming/"
pfincomingqthreshold="500"

#Deferred queue
pfdeferredqueuedir="/var/spool/postfix/deferred/"
pfdeferredqthreshold="2000"

#Maildrop queue.  Locally-posted mail is deposited into the maildrop, and is copied to the incoming queue after some cleaning up.
pfmaildropqueuedir="/var/spool/postfix/maildrop/"
pfmaildropqthreshold="100"

#Define binaries we will use.
findbin="find"
wcbin="wc"
loggerbin="logger"
datebin="date"
sedbin="sed"

shopt -s -o noclobber
shopt -s -o nounset

#Start the performance logging if it is enabled.
if [ $logmode = 1 ];then
  echo "##### Starting run of the queue checker - $($datebin) #####" >> $logfile
fi

#Check queues for mailman.

#Outgoing queue
nummmoutqfiles=$($findbin $mmoutqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Mailman out queue: $nummmoutqfiles" >> $logfile
fi
if [ $nummmoutqfiles -gt $mmoutqthreshold ];then
  echo "WARNING - Mailman outbound queue too high with $nummmoutqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Mailman outbound queue too high with $nummmoutqfiles messages."
fi

#Archive queue
nummmarchiveqfiles=$($findbin $mmarchiveqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Mailman archive queue: $nummmarchiveqfiles" >> $logfile
fi
if [ $nummmarchiveqfiles -gt $mmarchiveqthreshold ];then
  echo "WARNING - Mailman archive queue too high with $nummmarchiveqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Mailman archive queue too high with $nummmarchiveqfiles messages."
fi

#Bounces queue
nummmbouncesqfiles=$($findbin $mmbouncesqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Mailman bounce queue: $nummmbouncesqfiles" >> $logfile
fi
if [ $nummmbouncesqfiles -gt $mmbouncesqthreshold ];then
  echo "WARNING - Mailman bounces queue too high with $nummmbouncesqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Mailman bounces queue too high with $nummmbouncesqfiles messages."
fi

#Commands queue
nummmcommandsqfiles=$($findbin $mmcommandsqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Mailman commands queue: $nummmcommandsqfiles" >> $logfile
fi
if [ $nummmcommandsqfiles -gt $mmcommandsqthreshold ];then
  echo "WARNING - Mailman commands queue too high with $nummmcommandsqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Mailman commands queue too high with $nummmcommandsqfiles messages."
fi

#Inbound queue
nummminqfiles=$($findbin $mminqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Mailman in queue: $nummminqfiles" >> $logfile
fi
if [ $nummminqfiles -gt $mminqthreshold ];then
  echo "WARNING - Mailman inbound queue too high with $nummminqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Mailman inbound queue too high with $nummminqfiles messages."
fi

#News queue
nummmnewsqfiles=$($findbin $mmnewsqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Mailman news queue: $nummmnewsqfiles" >> $logfile
fi
if [ $nummmnewsqfiles -gt $mmnewsqthreshold ];then
  echo "WARNING - Mailman news queue too high with $nummmnewsqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Mailman news queue too high with $nummmnewsqfiles messages."
fi

#Retry queue
nummmretryqfiles=$($findbin $mmretryqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Mailman retry queue: $nummmretryqfiles" >> $logfile
fi
if [ $nummmretryqfiles -gt $mmretryqthreshold ];then
  echo "WARNING - Mailman retry queue too high with $nummmretryqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Mailman retry queue too high with $nummmretryqfiles messages."
fi

#Shunt queue
nummmshuntqfiles=$($findbin $mmshuntqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Mailman shunt queue: $nummmshuntqfiles" >> $logfile
fi
if [ $nummmshuntqfiles -gt $mmshuntqthreshold ];then
  echo "WARNING - Mailman shunt queue too high with $nummmshuntqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Mailman shunt queue too high with $nummmshuntqfiles messages."
fi

#Virgin queue
nummmvirginqfiles=$($findbin $mmvirginqdir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Mailman virgin queue: $nummmshuntqfiles" >> $logfile
fi
if [ $nummmvirginqfiles -gt $mmvirginqthreshold ];then
  echo "WARNING - Mailman virgin queue too high with $nummmvirginqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Mailman virgin queue too high with $nummmvirginqfiles messages."
fi

#Check queues for postfix.

#Active queue.
numpfactiveqfiles=$($findbin $pfactivequeuedir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Postfix active queue: $numpfactiveqfiles" >> $logfile
fi
if [ $numpfactiveqfiles -gt $pfactiveqthreshold ];then
  echo "WARNING - Postfix active queue too high with $numpfactiveqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Postfix active queue too high with $numpfactiveqfiles messages."
fi

#Incoming queue.  
numpfincomingqfiles=$($findbin $pfincomingqueuedir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Postfix icoming queue: $numpfincomingqfiles" >> $logfile
fi
if [ $numpfincomingqfiles -gt $pfincomingqthreshold ];then
  echo "WARNING - Post incoming queue too high with $numpfincomingqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Postfix incoming queue too high with $numpfincomingqfiles messages."
fi

#Deferred queue
numpfdeferredqfiles=$($findbin $pfdeferredqueuedir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Postfix deferred queue: $numpfdeferredqfiles" >> $logfile
fi
if [ $numpfdeferredqfiles -gt $pfdeferredqthreshold ];then
  echo "WARNING - Post deferred queue too high with $numpfdeferredqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-TICKET "Postfix deferred queue too high with $numpfdeferredqfiles messages."
fi

#Maildrop queue
numpfmaildropqfiles=$($findbin $pfmaildropqueuedir -type f | $wcbin -l | $sedbin -e 's/^[ \t]*//')
if [ $logmode = 1 ];then
  echo "Postfix maildrop queue: $numpfmaildropqfiles" >> $logfile
fi
if [ $numpfmaildropqfiles -gt $pfmaildropqthreshold ];then
  echo "WARNING - Post maildrop queue too high with $numpfmaildropqfiles messages."
  $loggerbin -p crit -t NOC-NETCOOL-ALERT "Postfix maildrop queue too high with $numpfmaildropqfiles messages."
fi

#End the performance logging if it is enabled.
if [ $logmode = 1 ];then
  echo "##### Completed run of the queue checker - $($datebin) #####"  >> $logfile
fi