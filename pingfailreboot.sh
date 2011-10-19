#!/bin/sh

#=====================================================================
# pingtest.sh, v1.0.1
# Created 2009 by Bennett Lee
# Released to public domain
#
# (1) Attempts to ping several hosts to test connectivity.  After
#     first successful ping, script exits.
# (2) If all pings fail, resets interface and retries all pings.
# (3) If all pings fail again after reset, then reboots pfSense.
#
# History
# 1.0.1   Added delay to ensure interface resets (thx ktims).
# 1.0.0   Initial release.
#=====================================================================

#=====================================================================
# USER SETTINGS
#
# Set multiple ping targets separated by space.  Include numeric IPs
# (e.g., remote office, ISP gateway, etc.) for DNS issues which
# reboot will not correct.
ALLDEST="yahoo.com red.com 208.67.222.222"
# Interface to reset, usually your WAN
BOUNCE=eth1
# Log file
LOGFILE=/root/pingtest.log
#=====================================================================

COUNT=1
while [ $COUNT -le 2 ]
do

	for DEST in $ALLDEST
	do
		#echo `date +%Y%m%d.%H%M%S` "Pinging $DEST" >> $LOGFILE
		ping -c1 $DEST >/dev/null 2>/dev/null
		if [ $? -eq 0 ]
		then
			#echo `date +%Y%m%d.%H%M%S` "Ping $DEST OK." >> $LOGFILE
			exit 0
		fi
	done

	if [ $COUNT -le 1 ]
	then
		echo `date +%Y%m%d.%H%M%S` "All pings failed. Resetting interface $BOUNCE." >> $LOGFILE
		/sbin/ifconfig $BOUNCE down
		# Give interface time to reset before bringing back up
		sleep 10
		/sbin/ifconfig $BOUNCE up
		# Give WAN time to establish connection
		sleep 10
	else
		echo `date +%Y%m%d.%H%M%S` "All pings failed twice. Rebooting..." >> $LOGFILE
		/sbin/shutdown -r now >> $LOGFILE
		exit 1
	fi

	COUNT=`expr $COUNT + 1`
done
