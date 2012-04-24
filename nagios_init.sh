#!/bin/sh
# 
# chkconfig: 345 99 01
# description: Nagios network monitor
#
# File : nagios
#
# Author : Jorge Sanchez Aymar (jsanchez@lanchile.cl)
# 
# Changelog :
#
# 1999-07-09 Karl DeBisschop <kdebisschop@infoplease.com>
#  - setup for autoconf
#  - add reload function
# 1999-08-06 Ethan Galstad <egalstad@nagios.org>
#  - Added configuration info for use with RedHat's chkconfig tool
#    per Fran Boon's suggestion
# 1999-08-13 Jim Popovitch <jimpop@rocketship.com>
#  - added variable for nagios/var directory
#  - cd into nagios/var directory before creating tmp files on startup
# 1999-08-16 Ethan Galstad <egalstad@nagios.org>
#  - Added test for rc.d directory as suggested by Karl DeBisschop
# 2000-07-23 Karl DeBisschop <kdebisschop@users.sourceforge.net>
#  - Clean out redhat macros and other dependencies
# 2003-01-11 Ethan Galstad <egalstad@nagios.org>
#  - Updated su syntax (Gary Miller)
# 2012-4-24 Jeff White <jaw171@pitt.edu>
#  - Fixed the 'status' section to exit 0 when the lock file is down (for better LSB compliance).
#
# Description: Starts and stops the Nagios monitor
#              used to provide network services status.
#

# Load any extra environment variables for Nagios and its plugins
if test -f /etc/sysconfig/nagios; then
        . /etc/sysconfig/nagios
fi

status_nagios ()
{

        if test -x $NagiosCGI/daemonchk.cgi; then
                if $NagiosCGI/daemonchk.cgi -l $NagiosRunFile; then
                        return 0
                else
                        return 1
                fi
        else
                if ps -p $NagiosPID > /dev/null 2>&1; then
                        return 0
                else
                        return 1
                fi
        fi

        return 1
}


printstatus_nagios()
{

        if status_nagios $1 $2; then
                echo "nagios (pid $NagiosPID) is running..."
        else
                echo "nagios is not running"
        fi
}


killproc_nagios ()
{

        kill $2 $NagiosPID

}


pid_nagios ()
{

        if test ! -f $NagiosRunFile; then
                echo "No lock file found in $NagiosRunFile"
                exit 1
        fi

        NagiosPID=`head -n 1 $NagiosRunFile`
}


# Source function library
# Solaris doesn't have an rc.d directory, so do a test first
if [ -f /etc/rc.d/init.d/functions ]; then
        . /etc/rc.d/init.d/functions
elif [ -f /etc/init.d/functions ]; then
        . /etc/init.d/functions
fi

prefix=/usr/local/nagios
exec_prefix=${prefix}
NagiosBin=${exec_prefix}/bin/nagios
NagiosCfgFile=${prefix}/etc/nagios.cfg
NagiosStatusFile=${prefix}/var/status.dat
NagiosRetentionFile=${prefix}/var/retention.dat
NagiosCommandFile=${prefix}/var/rw/nagios.cmd
NagiosVarDir=${prefix}/var
NagiosRunFile=${prefix}/var/nagios.lock
NagiosLockDir=/var/lock/subsys
NagiosLockFile=nagios
NagiosCGIDir=${exec_prefix}/sbin
NagiosUser=nagios
NagiosGroup=nagios
          

# Check that nagios exists.
if [ ! -f $NagiosBin ]; then
    echo "Executable file $NagiosBin not found.  Exiting."
    exit 1
fi

# Check that nagios.cfg exists.
if [ ! -f $NagiosCfgFile ]; then
    echo "Configuration file $NagiosCfgFile not found.  Exiting."
    exit 1
fi
          
# See how we were called.
case "$1" in

        start)
                echo -n "Starting nagios:"
                $NagiosBin -v $NagiosCfgFile > /dev/null 2>&1;
                if [ $? -eq 0 ]; then
                        su - $NagiosUser -c "touch $NagiosVarDir/nagios.log $NagiosRetentionFile"
                        rm -f $NagiosCommandFile
                        touch $NagiosRunFile
                        chown $NagiosUser:$NagiosGroup $NagiosRunFile
                        $NagiosBin -d $NagiosCfgFile
                        if [ -d $NagiosLockDir ]; then touch $NagiosLockDir/$NagiosLockFile; fi
                        echo " done."
                        exit 0
                else
                        echo "CONFIG ERROR!  Start aborted.  Check your Nagios configuration."
                        exit 1
                fi
                ;;

        stop)
                echo -n "Stopping nagios: "

                pid_nagios
                killproc_nagios nagios

                # now we have to wait for nagios to exit and remove its
                # own NagiosRunFile, otherwise a following "start" could
                # happen, and then the exiting nagios will remove the
                # new NagiosRunFile, allowing multiple nagios daemons
                # to (sooner or later) run - John Sellens
                #echo -n 'Waiting for nagios to exit .'
                for i in 1 2 3 4 5 6 7 8 9 10 ; do
                    if status_nagios > /dev/null; then
                        echo -n '.'
                        sleep 1
                    else
                        break
                    fi
                done
                if status_nagios > /dev/null; then
                    echo ''
                    echo 'Warning - nagios did not exit in a timely manner'
                else
                    echo 'done.'
                fi

                rm -f $NagiosStatusFile $NagiosRunFile $NagiosLockDir/$NagiosLockFile $NagiosCommandFile
                ;;

        status)
		if test ! -f $NagiosRunFile; then
		  echo "No lock file found in $NagiosRunFile"
		  exit 0
		fi

		NagiosPID=`head -n 1 $NagiosRunFile`

                printstatus_nagios nagios
                ;;

        checkconfig)
                printf "Running configuration check..."
                $NagiosBin -v $NagiosCfgFile > /dev/null 2>&1;
                if [ $? -eq 0 ]; then
                        echo " OK."
                else
                        echo " CONFIG ERROR!  Check your Nagios configuration."
                        exit 1
                fi
                ;;

        restart)
                printf "Running configuration check..."
                $NagiosBin -v $NagiosCfgFile > /dev/null 2>&1;
                if [ $? -eq 0 ]; then
                        echo "done."
                        $0 stop
                        $0 start
                else
                        echo " CONFIG ERROR!  Restart aborted.  Check your Nagios configuration."
                        exit 1
                fi
                ;;

        reload|force-reload)
                printf "Running configuration check..."
                $NagiosBin -v $NagiosCfgFile > /dev/null 2>&1;
                if [ $? -eq 0 ]; then
                        echo "done."
                        if test ! -f $NagiosRunFile; then
                                $0 start
                        else
                                pid_nagios
                                if status_nagios > /dev/null; then
                                        printf "Reloading nagios configuration..."
                                        killproc_nagios nagios -HUP
                                        echo "done"
                                else
                                        $0 stop
                                        $0 start
                                fi
                        fi
                else
                        echo " CONFIG ERROR!  Reload aborted.  Check your Nagios configuration."
                        exit 1
                fi
                ;;

        *)
                echo "Usage: nagios {start|stop|restart|reload|force-reload|status|checkconfig}"
                exit 1
                ;;

esac
  
# End of this script