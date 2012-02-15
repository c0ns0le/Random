#!/bin/bash
#shopt -s -o noclobber
#shopt -s -o nounset
#Description: Bash script to back up Linux, MySQL, Apache httpd, VMware Workstation, Oracle VirtualBox, Palm WebOS, and Android.
#Written By: Jeff White (jwhite530@gmail.com)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 1.9.4 - 2012-02-05 - Switched datastore option to one that uses rsync's --delete and another that does not. - Jeff White
# 1.9.3 - 2012-01-16 - Really removed Viridian and Urobilin as LinuxOS clients, added Byzantium as a LinuxOS client. - Jeff White
# 1.9.2 - 2012-01-14 - Added Skobeloff and Vermilion as a LinuxOS clients and Skobeloff as a MySQL client, removed Viridian as a LinuxOS and MySQL client, removed an old config directive for the LinuxOS section. - Jeff White
# 1.9.1 - 2011-12-24 - Removed permfix script, removed some hard coded paths to binaries, re-wrote apache httpd section, fixed some documentation. - Jeff White
# 1.9 - 2011-12-23 - Added Android option. - Jeff White
# 1.8.4 - 2011-12-13 - Excluded /bricks from Linux OS backups. - Jeff White
# 1.8.3 - 2011-12-12 - Minor fixes with logging. - Jeff White
# 1.8.2 - 2011-12-11 - Changed the -d option to transfer via rsync's SSH. - Jeff White
# 1.8.1 - 2011-12-11 - Re-wrote some of the VMware Workstation section. - Jeff White
#
#####

#SECURITY NOTES AND CONSIDERATIONS: -- READ THIS --
#+This script will accept any host key if it does not already know of one.  If you are a victim of a man-in-the-middle attack the first time you talk to the client,
#+this script will blindly accept the host key (but most users would do that same thing iteractively).  Be sure to secure the destination of your backups as important files
#+such as shadow files and entire databases will be there (obviously).  Ensure all files which hold passwords used by this script are only readable by the user who 
#+will run the script (owned by that user with a mode of 600).  Protect your SSH keys just as would your password.  Data transferred via some options is not encrypted.
#+By giving your backupuser sudo access to run rsync as root you are pretty much giving the user full root access since it can use rsync to copy a different sudoers or shadow file then do anything as root.

#KNOWN BUGS AND LIMITATIONS:
#+ For the MySQL option it eventually does a command which looks like: ssh backupuser@mysqlserver mysqldump --username=foo --password=badpass...
#+ This means anyone loooking at the process list on the backup server will see the username and password being used for MySQL.

#Prerequisites: This script assumes that on all clients: a backup user specified in $sshuser exists, password-less SSH logons are permitted, that user has /bin/bash as a default shell, that user has a 
#+writable home directory, and password-less sudo privileges are given to that user for the needed commands.  The /etc/sudoers files on the backup server should look like:
#+backupuser backupservername = NOPASSWD: /usr/bin/rsync,/bin/rm,/bin/chown
#+On the client it should look like:
#+backupuser backupclientrname = NOPASSWD: /usr/bin/rsync

#Android option: -c
#+Client dependencies: Bash (or a similar shell), rsync (client), OpenSSH (daemon)
#+Server dependencies: Bash, OpenSSH (client)
#+This option was designed for Cyanogenmod but you could do this with any ROM as long as you have root access.
#+Install SSHDroid, import your SSH key, and I recommend disabling password access since this is for the root account.
#+You may also need to install 'rsync backup for Android' or something else with rsync and add it to your $PATH

#WebOS option: -w
#+Client dependencies: Bash, OpenSSH (daemon), rsync (client), ipkg, sudo
#++You'll need to install most of this software yourself, WebOS does not come with it.  You should also use Wifi, not EVDO/3G.
#+Server dependencies: Bash, rsync (daemon), OpenSSH (client and daemon)

#Linux OS option: -l
#+Client dependencies: Bash, OpenSSH (daemon), rsync (client), sort, [apt-cache + dpkg || rpm || ipkg], sudo
#+Server dependencies: Bash, OpenSSH (client)
#+To use the package list on Debian-like systems use: dpkg --set-selections < /path/to/packages_list && apt-get -u dselect-upgrade

#getmail option: -g
#+Server dependencies: getmail4 (and its configuration)
#+This is designed for gmail but would work with any pop/imap email.  See the getmail Website for information on how to set up the config file, but here's one for gmail:
#+/etc/getmail/somedude-gmail.com 
#[retriever]
#type = SimpleIMAPSSLRetriever
#server =imap.gmail.com
#username = somedude@gmail.com
#password = longandcomplicatedtobesecure
##mailboxes = ("[Gmail]/All Mail",) #If you want it all...
#mailboxes = ("Inbox","School","Work")
#[destination]
#type = Mboxrd
#path = /media/Data/Backup/somedude-gmail.com/ALL.mbox
#[options]
#verbose = 2
#message_log = /var/log/getmail.log
#read_all = false
#delivered_to = false
#received = false
#delete = false

#Apache option: -a
#+Client dependencies: Bash, OpenSSH (daemon), rsync (client), sudo
#+Server dependencies: Bash, rsync (daemon), OpenSSH (client)

#MySQL option: -m
#+Client dependencies: Bash, OpenSSH (daemon), mysqldump
#+Server dependencies: Bash, OpenSSH (client)
#+Create a file at /etc/mysql/mysql.cred which contains the MySQL credentials as such:
#user=someuser
#password=somepass
#+Make sure only your backupuser account can read this: chown backupuser:backupuser /etc/mysql/mysql.creds && chmod 660 /etc/mysql/mysql.creds
#+Use the following create statement to create a backup user in MySQL:
#CREATE USER 'backupuser'@'localhost' IDENTIFIED BY 'CHANGEPASSHERE';
#+Use the following grant statement to allow the user to back up the data:
#GRANT SHOW DATABASES, SELECT, LOCK TABLES, RELOAD ON *.* to backupuser@localhost IDENTIFIED BY 'CHANGEPASSHERE';FLUSH PRIVILEGES;
#+MySQL slaves also need to add an additional grant:
#GRANT SUPER ON *.* to backupuser@localhost IDENTIFIED BY 'CHANGEPASSHERE';FLUSH PRIVILEGES;
#+These lines may be useful for backing up a slave, do your research before using this and know how your servers are set up.
#$sshbin $sshuser@$mysqlsrv "mysqladmin --user='$mysqluser' --password='$mysqlpass' stop-slave" || _printerr "ERROR - $LINENO - Unable to stop MySQL slave replication on $mysqlsrv." 1>> $log #Only needed for slave servers,
#$sshbin $sshuser@$mysqlsrv "mysqladmin --user='$mysqluser' --password='$mysqlpass' start-slave" || _printerr "ERROR - $LINENO - Unable to start MySQL slave replication on $mysqlsrv." 1>> $log #Only needed for slave servers,
#mysqlrsyncfiles=( "/etc/my.cnf" "/var/lib/mysql/master.info" "/var/lib/mysql/relay-log.info")
#for eachfile in "${mysqlrsyncfiles[@]}";do
#scp -q $sshuser@$mysqlsrv:$eachfile /backup/someserver/$eachfile || _printerr "ERROR - $LINENO - Unable to scp MySQL slave file $eachfile on $mysqlsrv." 1>> $log
#done

#VMware Workstation option: -v
#+Dependencies: Bash, OpenSSH (client daemon), rsync (client), vmrun, VMware Workstation, sudo (Add to /etc/sudoers: backupuser backupclientname = (userwhorunsvms) NOPASSWD: /usr/bin/vmrun)

#Oracle VirtualBox option: -o
#+Client dependencies: Bash, Oracle Virtualbox, OpenSSH (server), rsync (client)
#+Server dependencies: Bash, rsync (daemon), OpenSSH (client)

#E-mail notification option: -n
#+Server dependencies: mail (already configured to be able to send mail, I use ssmtp for this but any MTA should work)

#To do: add Tomato (firewall) option: http://tomatousb.org/tut:backup-settings-logs-more-to-usb-drive-script

#Needed binaries: If you want to trust $PATH instead, just use "foo" instead of "/path/to/foo"
rsyncbin="rsync"
sedbin="sed"
datebin="date"
sshkeyscanbin="ssh-keyscan"
sshbin="ssh"
getmailbin="getmail"
sudobin="sudo"
findbin="find"
dirnamebin="dirname"
awkbin="/usr/bin/awk"
teebin="tee"
bcbin="bc"
grepbin="grep"
cutbin="cut"
catbin="cat"
mvbin="mv"
mkdirbin="mkdir"
rmbin="rm"
lsbin="ls"
sleepbin="sleep"
cpbin="cp"
xargsbin="xargs"
touchbin="touch"
vmrunbin="vmrun"
revbin="rev"
scpbin="scp"

#General configuration - you must set these no matter what option you are using!
script=${0##*/}
log=/var/log/backup/$($datebin +%Y-%m-%d)-$script.log
rsyncbkup="backupuser@192.168.10.150::Backup"  #This is where data will be backed up to.
rsyncopt="--stats --delete --exclude .gvfs --exclude .cache --exclude .thumbnails --exclude Cache --exclude cache --exclude tmp --exclude bricks"
rsynccl="$rsyncbin -alpEA $rsyncopt"
bkupdir="/media/Data/Backup" #Local path to the backup directory here.  This should match the directory that $rsyncbkup leads to.
sshuser="backupuser"
sshport="22"
email="jwhite530.auto@gmail.com" #E-mail used for notifications if enabled.
lockdir="/tmp/$script.lock" #Make sure your backup user can write to this directory.
numdailydumpfiles="8" #Number of daily policy files or MySQL dumps to keep.
numweeklydumpfiles="5" #Number of weekly policy files or MySQL dumps to keep.
nummonthlydumpfiles="13" #Number of monthly policy files or MySQL dumps to keep.
numyearlydumpfiles="5" #Number of yearly policy files or MySQL dumps to keep.
numrunlogfiles="365" #Number of script error logs to keep.

#Android configuration
androidbkupsrc=( "Peridot" "Umber" ) #Add Android backup sources here, double quoted, space delimited.
android_private_ssh_key="/home/backupuser/.ssh/id_rsa"
cat << EOF > /tmp/exclude_android
/sys
/proc
EOF

#WebOS configuration
webossrc=( "Tangelo" ) #Add Palm WebOS backup sources here, double quoted, space delimited.

#Linux OS configuration
linbkupsrc=( "Indigo" "Cyan" "Teal" "Skobeloff" "Vermilion" ) #Add Linux backup sources here, double quoted, space delimited.
cat << EOF > /tmp/exclude_linuxos
/proc
/sys
/selinux
/mnt
/afs
/dev/shm
/media
.gvfs
.cache
Cache
cache
.truecrypt*
pub
mysql
sql
tc
tc2
/bricks
EOF

#Getmail configuration
gmconfdir="/etc/getmail" #Location of the GetMail config files.
gmconffile=( "$gmconfdir/jwhite530.auto-gmail.com" "$gmconfdir/jwhite530-gmail.com" "$gmconfdir/patheticpurplepenguin-gmail.com" "$gmconfdir/jeffwhite530-gmail.com" ) #The GetMail config files, quoted and space delmited.

#VMware configuration
vmwrkstnsvr="Cyan" #The hostname of the VMware Workstation host.
#Most of this is custom to my environment so you'll have to adapt the code to yours.

#Oracle VirtualBox configuration
vboxsvr="Cyan"
vboxmanage="/usr/bin/VBoxManage"
vboxvmdir="/home/jaw171/VM"

#MySQL configuration
mysqlsrv="Skobeloff" #The hostname of the MySQL server.
mysqluser=$($awkbin -F'=' '$1 ~ /user/ { print $2 }' /etc/mysql/mysql.cred)
mysqlpass=$($awkbin -F'=' '$1 ~ /pass/ { print $2 }' /etc/mysql/mysql.cred)

#Apache2 configuration
apachesrv="Viridian" #The hostname of the Apache2 server.
apacheserverroot="/etc/apache2" #Where the config files are held.
apachedocroot="/www" #Where the Website files are held. Delimted by a space if using multiple directories.

#Custom settings for my network
rsyncdata="white@192.168.10.150::Data"

#You shouldn't need to change these
date="$datebin +%m-%d-%Y" #The date format to go into the log.
time="$datebin +%r" #The time format to go into the log.
bkupsrv=$(echo $rsyncbkup | $cutbin --delimiter="@" -f2 | $cutbin --delimiter=":" -f1)
startdate=$($date) #Usedn for logging
starttime=$($time) #Used for logging
btime=$($datebin -u +%s) #Used for time calculation
OPTSTRING=":cwanvmldghopPVD"
virtualboxopt=0;laptoplinopt=0;laptopwinopt=0;wosopt=0;apachehttpdopt=0;getmailopt=0;emailnotifyopt=0;vmwareopt=0;mysqlopt=0;linosopt=0 #Unset variables are icky
remotenason=0;fatalerrnum=0;errnum=0;logfail=0;bytessentrcvdtotal=0;scriptcanceled=0;lockfail=0;dataopt=0;verbosity=0;androidopt=0;datadeleteopt=0 #Unset variables are icky
PATH=/bin:/usr/bin:/sbin:/usr/sbin/:/usr/local/bin:/usr/local/sbin #Start with a known $PATH
umask 007

function _printerr {
echo "$1" 1>&2
}
function _handletrap {
scriptcanceled=1
_printoutput
exit 2
}
function _calctransmitteddata {
  bytessentrcvdtotal=$($awkbin -F': ' '(/bytes sent/||/bytes received/)&&(!/connection unexpectedly closed/) { SUM += $2 } END { printf "%.f\n", SUM }' $log)
  if [ "$bytessentrcvdtotal" -lt "1048576" ];then
    calcedtotalbytes=$(echo "scale=2;$bytessentrcvdtotal/1024" | $bcbin)
    unit="KB"
  elif [ "$bytessentrcvdtotal" -lt "1073741824" ];then
    calcedtotalbytes=$(echo "scale=2;$bytessentrcvdtotal/1024/1024" | $bcbin)
    unit="MB"
  elif [ "$bytessentrcvdtotal" -lt "1099511627776" ];then
    calcedtotalbytes=$(echo "scale=2;$bytessentrcvdtotal/1024/1024/1024" | $bcbin)
    unit="GB"
  elif [ "$bytessentrcvdtotal" -lt "1125899906842624" ];then
    calcedtotalbytes=$(echo "scale=2;$bytessentrcvdtotal/1024/1024/1024/1024" | $bcbin)
    unit="TB"
  fi
}
function _makeoutput {
  enddate=$($date) #Used for logging
  endtime=$($time) #Used for logging
  etime=$($datebin -u +%s) #Used for time calculation
  totalsec=$((etime - btime))
  durdays=$(($totalsec / 86400))
  durhours=$(( ($totalsec - ($durdays * 86400)) / 3600))
  durmin=$(( (($totalsec - ($durdays * 86400)) - ($durhours * 3600)) / 60))
  remsec=$(( (($totalsec - ($durdays * 86400)) - ($durhours * 3600)) - ($durmin * 60) ))
  if [ ! -w "$log" -o "$logfail" = "1" ];then
    fatalerrnum=1
    errtext="Log could not be accessed or could not be rotated: $log"
  else
    fatalerrnum=$($grepbin -c "FATAL ERROR " "$log")
    errnum=$($grepbin -c "ERROR " "$log")
    errtext=$($grepbin "ERROR " "$log")
  fi
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo "Server: $HOSTNAME"
  echo "Script name: $script"
  echo "Script location: $($dirnamebin $0)"
  if [ "$lockfail" != "1" -a "$logfail" != "1" ];then
    echo "Log: $log"
  fi
  [ "$androidopt" = 1 ] && echo "Android options enabled for: ${androidbkupsrc[*]}."
  [ "$linosopt" = 1 ] && echo "Linux OS option enabled for: ${linbkupsrc[*]}."
  [ "$wosopt" = 1 ] && echo "WebOS option enabled for: ${webossrc[*]}."
  [ "$apachehttpdopt" = 1 ] && echo "Apache2 option enabled for: $apachesrv."
  [ "$vmwareopt" = 1 ] && echo "VMware option enabled."
  [ "$virtualboxopt" = 1 ] && echo "Oracle VirtualBox enabled."
  [ "$mysqlopt" = 1 ] && echo "MySQL option enabled for: $mysqlsrv"
  [ "$emailnotifyopt" = 1 ] && echo "E-mail notification enabled for: $email."
  [ "$getmailopt" = 1 ] && echo "Getmail option enabled for ${gmconffile[*]}"
  [ "$datadeleteopt" = 1 ] && echo "Datastore options (with delete) enabled."
  [ "$dataopt" = 1 ] && echo "Datastore options (without delete) enabled."
  echo "Start: $startdate - $starttime"
  echo "End: $enddate - $endtime"
  echo "Duration: $durdays days, $durhours hours, $durmin minutes, $remsec seconds"
  if [ "$lockfail" != "1" -a "$logfail" != "1" ];then
    echo "Data transferred: $calcedtotalbytes $unit (excluding any transmisions that errored out and some forms of compression)"
  fi
  echo " "
  if [ "$lockfail" != "0" ]; then
    logger -t "$script" "FATAL error: Backup $script on $HOSTNAME failed with a FATAL error (Cannot acquire lock, $script may already be running.  If not, remove $lockdir)."
    echo "Failed with a FATAL error (Cannot acquire lock, $script may already be running.  If not, remove $lockdir)."
  elif [ "$fatalerrnum" != "0" ]; then
    logger -t "$script" "FATAL error: Backup $script on $HOSTNAME failed with a FATAL error."
    echo "Failed with a FATAL error."
    echo "$errtext"
  elif [ "$scriptcanceled" = "1" ]; then
    logger -t "$script" "Canceled: Backup $script on $HOSTNAME was canceled."
    echo "Canceled."
  elif [ "$errnum" = "0" ]; then
    logger -t "$script" "Success: Backup $script on $HOSTNAME completed successfully."
    echo "Completed successfully!"
  else
    logger -t "$script" "Errors: Backup $script on $HOSTNAME failed with $errnum errors."
    echo "Failed with $errnum error(s), check the log."
  fi
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}
function _mailoutput {
  if [ ! -w "$log" -o "$logfail" = "1" ];then
    fatalerrnum=1
    errtext="Logs could not be accessed."
  else
    fatalerrnum=$($grepbin -c "FATAL ERROR" "$log")
    errnum=$($grepbin -c "ERROR" "$log")
    errtext=$($grepbin "ERROR" "$log")
  fi
  if [ "$lockfail" != "0" ]; then
    _makeoutput|mail -s  "FATAL error: Backup $script on $HOSTNAME failed with a FATAL error (Cannot acquire lock, $script may already be running.  If not, remove $lockdir)." $email
  elif [ "$fatalerrnum" != 0 ]; then
    _makeoutput|mail -s "FATAL error: Backup $script on $HOSTNAME failed with a FATAL error." $email
  elif [ "$scriptcanceled" = "1" ]; then
    _makeoutput|mail -s "Canceled: Backup $script on $HOSTNAME was canceled." $email
  elif [ "$errnum" = 0 ]; then
    _makeoutput|mail -s "Success: Backup $script on $HOSTNAME completed successfully." $email
  elif [ "$errnum" = 1 ]; then
    _makeoutput|mail -s "Error: Backup $script on $HOSTNAME failed with 1 error." $email
  else
    _makeoutput|mail -s "Errors: Backup $script on $HOSTNAME failed with $errnum errors." $email
  fi 
}
function _printoutput {
  if [ "$emailnotifyopt" != 1 -a "$lockfail" = "1" ]; then
    _makeoutput
  elif [ "$emailnotifyopt" = 1 -a "$lockfail" = "1" ]; then
    _makeoutput | _mailoutput
    _makeoutput
  elif [ "$emailnotifyopt" != 1 -a "$logfail" = "1" ]; then
    _makeoutput
  elif [ "$emailnotifyopt" = 1 -a "$logfail" = "1" ]; then
    _makeoutput | _mailoutput
    _makeoutput
  elif [ "$emailnotifyopt" != 1 -a "$lockfail" != "1" ]; then
    _calctransmitteddata
    _makeoutput | $teebin -a $log
  elif [ "$emailnotifyopt" = 1 -a "$lockfail" != "1" ]; then
    _calctransmitteddata
    _makeoutput | _mailoutput
    _makeoutput | $teebin -a $log
  fi
  if [ "$lockfail" != "1" ]; then
    $rmbin -rf $lockdir #Remove the lockdir when exiting, but only if this iteration of the script created it.
  fi
}

trap _handletrap 1 2 3 15 # Terminate script when receiving signal

while getopts "$OPTSTRING" OPT; do #The remotenason and DATOPT options are custom for my network.
  case $OPT in
    c)
      androidopt=1 ;;
    w)
      wosopt=1 ;;
    a)
      apachehttpdopt=1 ;;
    g)
      getmailopt=1 ;;
    n)
      emailnotifyopt=1 ;;
    v)
      vmwareopt=1
      remotenason=1
      echo "WARNING - Your VMs will be paused and inaccessible during the backup when using the VMware Workstation option." ;;
    o)
      echo "WARING - $LINENO - The Oracle VirtualBox option has not been configured, disabling the option.  If it has, remove this from the script." | $teebin -a $log ;;
      #virtualboxopt=0 ;;
    m)
      mysqlopt=1 ;;
    l)
      linosopt=1 ;;
    d)
      dataopt=1
      remotenason=1;;
    D)
      datadeleteopt=1
      remotenason=1;;
    r)
      remotenason=1 ;;
    p)
      laptoplinopt=1 ;;
    P)
      laptopwinopt=1 ;;
    V)
      verbosity=1 ;;
    h)
      $catbin << EOF
Usage: $script {-c -w -a -v -m -l -d -D -p -P -n -V -h}
-c : Enabled the Android option
-w : Enables the Palm WebOS option
-g : Enables the getmail option
-a : Enables the Apache2 option
-v : Enables the VMware option
-o : Enables the Oracle VirtualBox option
-m : Enables the MySQL option
-l : Enables the Linux OS option
-d : Enables the datastore option without rsync's --delete
-D : Enabled the datastore option with rsync's --delete (overrides -d)
-p : Enables the laptop Linux option
-P : Enables the laptop Windows option
-n : Enables E-mail notifications
-V : Enables verbosity (stderr prints to the console, stdout still goes to the log)
-h : Shows this help
Note: Running this script with no options (or -V by itself) causes it to go through sanity checking then exit without backing anything up.
EOF
      exit 0 ;;
    \?)
      _printerr "FATAL ERROR: Invalid option \"$OPTARG\" (Use -h for help)"
      exit 192 ;;
  esac
done

if $mkdirbin "$lockdir" &> /dev/null;then
  echo "Successfully acquired lock: $lockdir"
else
  _printerr "FATAL ERROR - $LINENO - Cannot acquire lock, $script may already be running.  If not, remove $lockdir."
  lockfail=1
  _printoutput
  exit 1
fi

if [ -f $log ];then #Rotate logs
  numoldbak=$($lsbin $log* | $grepbin -c $log-*'[1-9]')
  while (( $numoldbak > 0 ));do
    $mvbin $log-$numoldbak $log-$(( $numoldbak + 1 )) 
    if [ $? != 0 ];then
      _printerr "ERROR - $LINENO - Unable to rotate old rotation of $log."
      logfail=1
      _printoutput
      exit 1
    fi
    numoldbak=$(( $numoldbak - 1 ))
  done
  $mvbin $log ${log}-1
  if [ $? != 0 ];then
    _printerr "ERROR - $LINENO - Unable to rotate $log."
    logfail=1
    _printoutput
    exit 1
  fi
fi

if [ $verbosity = 0 ];then
  exec 2>>$log #All errors go to the log from now on.
fi

echo "$($time) - Checking sanity" 1>>$log
if [ -z .$BASH. ]; then
   _printerr "FATAL ERROR - $LINENO - Please run this script with the BASH shell.  EXITING" 1>>$log
  exit 192
fi

if [ ! -w $($dirnamebin $log) ]; then
  _printerr "FATAL ERROR - $LINENO - Log directory not writable or could not be created.  EXITING" 1>>$log
  logfail=1
  _printoutput
  exit 1
fi

if [ ! -d $bkupdir ]; then
  _printerr "FATAL ERROR - $LINENO - $bkupdir does not exist or is not a directory.  EXITING" 1>>$log
  _printoutput
  exit 1
fi

if [ ! -f /home/$sshuser/.ssh/known_hosts ];then
 $touchbin /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to create known host key list for SSH." 1>>$log
fi

if [ "$remotenason" = 1 ]; then #Custom part just for my network.
  if ! $grepbin -i teal /home/$sshuser/.ssh/known_hosts > /dev/null; then
    echo "Host key for Teal:" 1>> /home/$sshuser/.ssh/known_hosts
    $sshkeyscanbin -t rsa,dsa teal 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for Teal to known host key list."
  fi
  $sshbin $sshuser@teal -p $sshport "{
    $grepbin "/media/Backup" /proc/mounts &> /dev/null || _printerr 'FATAL ERROR - $LINENO - Backup RAID not mounted on Teal (NAS).  EXITING'
  }" 1>>$log
  if $grepbin "Backup RAID not mounted" $log &> /dev/null; then
    _printoutput
    exit 1
  fi
fi

echo "$($date) - $($time) - Starting run of $script.  Additional details at the end of the log." | $teebin -a $log
echo "$($time) - Environment is sane, starting backup." | $teebin -a $log
logger -t "$script" "Starting run of $script."

if [ "$laptoplinopt" = 1 ];then
  echo "$($time) - Backing up Linux OS on Sangria" | $teebin -a $log
  echo "$($time) - Checking and creating required directories." 1>>$log
  reqdir=( "$bkupdir/Sangria" "$bkupdir/Sangria/Packages" "$bkupdir/Sangria/Packages/Temp" "$bkupdir/Sangria/Packages/Daily" "$bkupdir/Sangria/Packages/Weekly" "$bkupdir/Sangria/Packages/Monthly" "$bkupdir/Sangria/Packages/Yearly" )
  for eachreqdir in "${reqdir[@]}";do
    if [ ! -d "$eachreqdir" ]; then 
      $mkdirbin -p "$eachreqdir"  1>>$log || _printerr "ERROR - $LINENO - Unable to create $eachreqdir." 1>>$log
      if [ "$?" != "0" ];then
	_printerr "ERROR - $LINENO - Unable to create $eachreqdir on $bkupsrv for Sangria." 1>>$log
	continue
      fi
    fi
  done
  echo "$($time) - Checking and adding SSH keys." 1>>$log
  if ! $grepbin -i sangria /home/$sshuser/.ssh/known_hosts > /dev/null; then
    echo "Host key for Sangria:" 1>> /home/$sshuser/.ssh/known_hosts
    $sshkeyscanbin -t rsa,dsa sangria 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for Sagria to known host key list."
  fi
  echo "$($time) - Starting remote commands." 1>>$log
  if $sshbin $sshuser@Sangria -p $sshport : 1>>$log; then #Verify SSH works
      echo "$($time) - Creating package list." 1>>$log
      $sshbin $sshuser@Sangria -p $sshport "{
	if which dpkg &>/dev/null; then
	  dpkg --get-selections || echo "ERROR - $LINENO - Package creation with dpkg failed on Sangria!" 1>&2
	else
	  echo "ERROR - $LINENO - No package management binary dpkg, rpm, or ipkg found on Sangria, unable to create package list!" 1>&2
	fi
      }" 1> "${bkupdir}/Sangria/Packages/Temp/$($date)-Installed-Packages-Sangria.log"
      echo "$($time) - Starting rsync." 1>>$log
      $sudobin $rsyncbin -aDHAX --stats --delete --exclude-from=/tmp/exclude_linuxos -e "$sudobin -u $sshuser $sshbin -l $sshuser -p $sshport" --rsync-path="$sudobin $rsyncbin" Sangria:/ ${bkupdir}/Sangria/OS 1>>$log || _printerr "ERROR - $LINENO - Linux OS backup on Sangria failed."
    echo "$($time) - Checking and rotating package list." 1>>$log
    if [ -s "$bkupdir/Sangria/Packages/Temp/$($date)-Installed-Packages-Sangria.log" ];then #If the package dump exists and is non-zero in size, copy the daily and move on.
      $mvbin -f "$bkupdir/Sangria/Packages/Temp/$($date)-Installed-Packages-Sangria.log" "$bkupdir/Sangria/Packages/Daily/$($date)-Installed-Packages-Sangria.log" 1>>$log || _printerr "ERROR - $LINENO - Unable to copy new daily package list dump for Sangria." 1>>$log
      $lsbin -1 -t $bkupdir/Sangria/Packages/Daily/*-Installed-Packages-Sangria.log | $awkbin --assign=numdailydumpfiles=$numdailydumpfiles '{ if (NR > numdailydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ]  1>>$log || _printerr "ERROR - $LINENO - Unable to remove old daily package dump list for Sangria." 1>>$log
      if [ $($datebin +%a) = "Sat" ];then #Copy the weekly
	$cpbin -f "$bkupdir/Sangria/Packages/Daily/$($date)-Installed-Packages-Sangria.log" "$bkupdir/Sangria/Packages/Weekly/$($date)-Installed-Packages-Sangria.log" || _printerr "ERROR - $LINENO - Unable to copy new weekly package list dump for Sangria." 1>>$log
	$lsbin -1 -t $bkupdir/Sangria/Packages/Weekly/*-Installed-Packages-Sangria.log | $awkbin --assign=numweeklydumpfiles=$numweeklydumpfiles '{ if (NR > numweeklydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ]  1>>$log || _printerr "ERROR - $LINENO - Unable to remove old weekly package dump list for Sangria." 1>>$log
      fi
      if [ $($datebin +%d) = "01" ];then #Copy the monthly
	$cpbin -f "$bkupdir/Sangria/Packages/Daily/$($date)-Installed-Packages-Sangria.log" "$bkupdir/Sangria/Packages/Monthly/$($date)-Installed-Packages-Sangria.log" || _printerr "ERROR - $LINENO - Unable to copy new monthly package dump list for Sangria." 1>>$log
	$lsbin -1 -t "$bkupdir/Sangria/Packages/Monthly/*-Installed-Packages-Sangria.lo"g | $awkbin --assign=nummonthlydumpfiles=$nummonthlydumpfiles '{ if (NR > nummonthlydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ]  1>>$log || _printerr "ERROR - $LINENO - Unable to remove old monthly package dump list for Sangria." 1>>$log
      fi
      if [ $($datebin +%j) = "001" ];then #Copy the yearly
	$cpbin -f "$bkupdir/Sangria/PackagesL/Daily/$($date)-Installed-Packages-Sangria.log" "$bkupdir/Sangria/Packages/Yearly/$($date)-Installed-Packages-Sangria.log" || _printerr "ERROR - $LINENO - Unable to copy new yearly package dump list for Sangria." 1>>$log
	$lsbin -1 -t "$bkupdir/Sangria/Packages/Yearly/*-Installed-Packages-Sangria.log" | $awkbin --assign=numyearlydumpfiles=$numyearlydumpfiles '{ if (NR > numyearlydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ]  1>>$log || _printerr "ERROR - $LINENO - Unable to remove old yearly package dump list for Sangria." 1>>$log
      fi
    else
      _printerr "ERROR - $LINENO - Package list of Sangria failed (zero length backup file or it doesn't exist), keeping old list (if one exist)."
    fi
  else
    _printerr "ERROR - $LINENO - SSH to backup source Sangria failed.  Skipping client."
  fi
fi

if [ "$laptopwinopt" = 1 ];then
  echo "$($time) - Backing up Windows 7 on Sangria" | $teebin -a $log
  echo "$($time) - Checking and adding SSH keys." 1>>$log
  if ! $grepbin -i sangria /home/$sshuser/.ssh/known_hosts > /dev/null; then
    echo "Host key for Sangria:" 1>> /home/$sshuser/.ssh/known_hosts
    $sshkeyscanbin -t rsa,dsa sangria 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for Sangria to known host key list."
  fi
  if $sshbin $sshuser@Sangria -p $sshport : 1>>$log; then #Verify SSH works
    echo "$($time) - Checking and rotating dd images." 1>>$log
    if [ -f /media/Data/Backup/Sangria/sda3-win7.dd.gz.old ];then
      _printerr "ERROR - $LINENO - Old rotated windows partition dd image exists, cannot continue backing up Windows 7 on Sangria." 1>>$log
    else
      if [ -f /media/Data/Backup/Sangria/sda3-win7.dd.gz ];then
	$mvbin /media/Data/Backup/Sangria/sda3-win7.dd.gz /media/Data/Backup/Sangria/sda3-win7.dd.gz.old 1>>$log
      fi
      echo "$($time) - Creating new dd image." 1>>$log
      $sshbin $sshuser@Sangria -p $sshport "$sudobin dd if=/dev/sda3 | pigz 2>/dev/null" | dd of=/media/Data/Backup/Sangria/sda3-win7.dd.gz 2> /dev/null  1>>$log || _printerr "ERROR - $LINENO - Windows partition dump from Sangria failed." 1>>$log
      if [ ! -s /media/Data/Backup/Sangria/sda3-win7.dd.gz ];then
	_printerr "ERROR - $LINENO - Windows partition dd image does not exist or is zero bytes from Sangria." 1>>$log
      else
	echo "Total bytes received: $($lsbin -l /media/Data/Backup/Sangria/sda3-win7.dd.gz | $cutbin -d' ' -f5)" 1>>$log
      fi
    fi
  else
    _printerr "ERROR - $LINENO - SSH to backup source Sangria failed.  Skipping client." 1>>$log
  fi
fi

if [ "$androidopt" = 1 ]; then #Android section
  for androidclient in "${androidbkupsrc[@]}";do
    echo "$($time) - Backing up Android on $androidclient" | $teebin -a $log
    echo "$($time) - Checking and creating required directories." 1>>$log
    reqdir=( "$bkupdir/$androidclient" "$bkupdir/$androidclient/OS" )
    for eachreqdir in "${reqdir[@]}";do
      if [ ! -d "$eachreqdir" ]; then 
	$mkdirbin -p "$eachreqdir" 1>>$log || _printerr "ERROR - $LINENO - Unable to create $eachreqdir."
	if [ "$?" != "0" ];then
	  _printerr "ERROR - $LINENO - Unable to create $eachreqdir on $bkupsrv for $androidclient." 1>>$log
	  continue
	fi
      fi
    done
    echo "$($time) - Checking and adding SSH keys." 1>>$log
    if ! $grepbin -i $androidclient /home/$sshuser/.ssh/known_hosts 1> /dev/null; then
      echo "Host key for $androidclient:" 1>> /home/$sshuser/.ssh/known_hosts
      $sshkeyscanbin -t rsa,dsa $androidclient 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for $androidclient to known host key list."
    fi
    echo "$($time) - Starting remote commands." 1>>$log
    if $sshbin -i $android_private_ssh_key root@$androidclient -p $sshport : 1>>$log; then #Verify SSH works
     echo "$($time) - Starting rsync." 1>>$log
      $sudobin $rsyncbin -aDH --stats --delete --exclude-from=/tmp/exclude_android -e "$sshbin -l root -i $android_private_ssh_key -p $sshport" ${androidclient}:/ ${bkupdir}/${androidclient}/OS 1>>$log || _printerr "ERROR - $LINENO - Android backup on $androidclient failed."
    else
      _printerr "ERROR - $LINENO - SSH to backup source $androidclient failed.  Skipping client."
    fi
  done
fi

if [ "$wosopt" = 1 ]; then #WARNING - THIS OPTION IS OLD AND UNMAINTAINED.
  for wosclient in "${webossrc[@]}";do
    echo "$($time) - Backing up WebOS on $wosclient" | $teebin -a $log
      [ -d "$bkupdir/$wosclient/Packages" ] || $mkdirbin -p "$bkupdir/$wosclient/Packages" 1>>$log || _printerr "ERROR - $LINENO - Unable to create package list directory on $bkupsrv for $wosclient."
    if ! $grepbin -i $wosclient /home/$sshuser/.ssh/known_hosts > /dev/null; then
      echo "Host key for $wosclient:" 1>> /home/$sshuser/.ssh/known_hosts
      $sshkeyscanbin -t rsa,dsa $wosclient 1>> /home/$sshuser/.ssh/known_hosts
      if [ $? != 0 ];then
	$sedbin -e "/Host key for $wosclient:/d" /home/$sshuser/.ssh/known_hosts 1> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to remove hsot key header from /home/$sshuser/.ssh/known_hosts.  The real hostkey will not be automatically accepted next time!"
	_printerr "ERROR - $LINENO - Unable to add host key for $wosclient to known host key list."
      fi
    fi
    if $sshbin $sshuser@$wosclient -o ConnectionAttempts=1 -p $sshport : 1>>$log; then #Verify SSH works on all WebOS clients
      $sshbin $sshuser@$wosclient -p $sshport -o ConnectionAttempts=10 "{
	$sudobin mount -n -o remount,rw / || _printerr "ERROR - $LINENO - Unable to remount root directory on $wosclient to r/w."
	$mkdirbin /home/backupuser/.Packages || _printerr "ERROR - $LINENO - Unable to create working directory on $wosclient."
	ipkg status 1>/home/backupuser/.Packages/$($date)-Installed-Packages-$wosclient.log || (_printerr "ERROR - $LINENO - Package creation with ipkg on $wosclient failed!";$touchbin /home/backupuser/.Packages/FAIL)
	if [ ! -f /home/backupuser/.Packages/FAIL ]; then
	  $sudobin $rsyncbin -alpEh /home/backupuser/.Packages/ $rsyncbkup/$wosclient/Packages || _printerr "ERROR - $LINENO - Unable to transfer package list on $wosclient."
	else
	  _printerr "Error - $LINENO - Unable to create package list on $wosclient."
	fi
	$rmbin -rf /home/backupuser/.Packages || _printerr "ERROR - $LINENO - Unable to remove working directory on $wosclient."
	$sudobin mount -n -o remount,ro / || _printerr "ERROR - $LINENO - Unable to remount root directory on $wosclient to r/o."
	$sudobin $rsyncbin -alpEtR --stats --delete --exclude .gvfs /media/internal /opt/etc /var/luna/data/dbdata /home $rsyncbkup/$wosclient || _printerr "ERROR - $LINENO - rsync on $wosclient failed."
      }" 1>>$log
      else
	_printerr "ERROR - $LINENO - SSH to WebOS backup client $wosclient failed.  Skipping client." 1>>$log
      fi
  done
fi

if [ "$linosopt" = 1 ]; then #Linux OS section
  for linclient in "${linbkupsrc[@]}";do
    echo "$($time) - Backing up Linux OS on $linclient" | $teebin -a $log
    echo "$($time) - Checking and creating required directories." 1>>$log
    reqdir=( "$bkupdir/$linclient" "$bkupdir/$linclient/OS" "$bkupdir/$linclient/Packages" "$bkupdir/$linclient/Packages/Temp" "$bkupdir/$linclient/Packages/Daily" "$bkupdir/$linclient/Packages/Weekly" "$bkupdir/$linclient/Packages/Monthly" "$bkupdir/$linclient/Packages/Yearly" )
    for eachreqdir in "${reqdir[@]}";do
      if [ ! -d "$eachreqdir" ]; then 
	$mkdirbin -p "$eachreqdir" 1>>$log || _printerr "ERROR - $LINENO - Unable to create $eachreqdir."
	if [ "$?" != "0" ];then
	  _printerr "ERROR - $LINENO - Unable to create $eachreqdir on $bkupsrv for $linclient." 1>>$log
	  continue
	fi
      fi
    done
    echo "$($time) - Checking and adding SSH keys." 1>>$log
    if ! $grepbin -i $linclient /home/$sshuser/.ssh/known_hosts 1> /dev/null; then
      echo "Host key for $linclient:" 1>> /home/$sshuser/.ssh/known_hosts
      $sshkeyscanbin -t rsa,dsa $linclient 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for $linclient to known host key list."
    fi
    echo "$($time) - Starting remote commands." 1>>$log
    if $sshbin $sshuser@$linclient -p $sshport : 1>>$log; then #Verify SSH works
      echo "$($time) - Creating package list." 1>>$log
      $sshbin $sshuser@$linclient -p $sshport "{
	if which dpkg &>/dev/null; then
	  dpkg --get-selections || echo "ERROR - $LINENO - Package creation with dpkg failed on ${linclient}!" 1>&2
	elif which rpm &>/dev/null; then 
	  rpm -qa || echo "ERROR - $LINENO - Package creation with rpm failed on ${linclient}!" 1>&2
	elif which ipkg &>/dev/null; then
	  ipkg status || echo "ERROR - $LINENO - Package creation with ipkg failed on ${linclient}!" 1>&2
	else
	  echo "ERROR - $LINENO - No package management binary dpkg, rpm, or ipkg found on ${linclient}, unable to create package list!" 1>&2
	fi
      }" 1> "${bkupdir}/${linclient}/Packages/Temp/$($date)-Installed-Packages-${linclient}.log"
      echo "$($time) - Starting rsync." 1>>$log
      $sudobin $rsyncbin -aDHAX --stats --delete --exclude-from=/tmp/exclude_linuxos -e "$sudobin -u $sshuser $sshbin -l $sshuser -p $sshport" --rsync-path="$sudobin $rsyncbin" ${linclient}:/ ${bkupdir}/${linclient}/OS 1>>$log || _printerr "ERROR - $LINENO - Linux OS backup on $linclient failed."
      echo "$($time) - Checking and rotating package list." 1>>$log
      if [ -s $bkupdir/$linclient/Packages/Temp/$($date)-Installed-Packages-$linclient.log ];then #If the package dump exists and is non-zero in size, copy the daily and move on.
	$mvbin -f "$bkupdir/$linclient/Packages/Temp/$($date)-Installed-Packages-$linclient.log" "$bkupdir/$linclient/Packages/Daily/$($date)-Installed-Packages-$linclient.log" 1>>$log || _printerr "ERROR - $LINENO - Unable to copy new daily package list dump for $linclient." 1>>$log
	$lsbin -1 -t $bkupdir/$linclient/Packages/Daily/*-Installed-Packages-$linclient.log | $awkbin --assign=numdailydumpfiles=$numdailydumpfiles '{ if (NR > numdailydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] 1>>$log || _printerr "ERROR - $LINENO - Unable to remove old daily package dump list for $linclient." 1>>$log
	if [ $($datebin +%a) = "Sat" ];then #Copy the weekly
	  $cpbin -f "$bkupdir/$linclient/Packages/Daily/$($date)-Installed-Packages-$linclient.log" "$bkupdir/$linclient/Packages/Weekly/$($date)-Installed-Packages-$linclient.log" 1>>$log || _printerr "ERROR - $LINENO - Unable to copy new weekly package list dump for $linclient." 1>>$log
	  $lsbin -1 -t $bkupdir/$linclient/Packages/Weekly/*-Installed-Packages-$linclient.log | $awkbin --assign=numweeklydumpfiles=$numweeklydumpfiles '{ if (NR > numweeklydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] 1>>$log || _printerr "ERROR - $LINENO - Unable to remove old weekly package dump list for $linclient." 1>>$log
	fi
	if [ $($datebin +%d) = "01" ];then #Copy the monthly
	  $cpbin -f "$bkupdir/$linclient/Packages/Daily/$($date)-Installed-Packages-$linclient.log" "$bkupdir/$linclient/Packages/Monthly/$($date)-Installed-Packages-$linclient.log" 1>>$log || _printerr "ERROR - $LINENO - Unable to copy new monthly package dump list for $linclient." 1>>$log
	  $lsbin -1 -t $bkupdir/$linclient/Packages/Monthly/*-Installed-Packages-$linclient.log | $awkbin --assign=nummonthlydumpfiles=$nummonthlydumpfiles '{ if (NR > nummonthlydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] 1>>$log|| _printerr "ERROR - $LINENO - Unable to remove old monthly package dump list for $linclient." 1>>$log
	fi
	if [ $($datebin +%j) = "001" ];then #Copy the yearly
	  $cpbin -f "$bkupdir/$linclient/PackagesL/Daily/$($date)-Installed-Packages-$linclient.log" "$bkupdir/$linclient/Packages/Yearly/$($date)-Installed-Packages-$linclient.log" 1>>$log || _printerr "ERROR - $LINENO - Unable to copy new yearly package dump list for $linclient." 1>>$log
	  $lsbin -1 -t "$bkupdir/$linclient/Packages/Yearly/*-Installed-Packages-$linclient.log" | $awkbin --assign=numyearlydumpfiles=$numyearlydumpfiles '{ if (NR > numyearlydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] 1>>$log || _printerr "ERROR - $LINENO - Unable to remove old yearly package dump list for $linclient." 1>>$log
	fi
      else
	_printerr "ERROR - $LINENO - Package list of $linclient failed (zero length backup file or it doesn't exist), keeping old list (if one exist)."
      fi
    else
      _printerr "ERROR - $LINENO - SSH to backup source $linclient failed.  Skipping client."
    fi
  done
fi

if [ "$getmailopt" = "1" ];then
  echo "$($time) - Backing up email." | $teebin -a $log
  for eachgmconffile in "${gmconffile[@]}";do
    echo "Working on $eachgmconffile" | $teebin -a $log
    mboxfile=$($awkbin -F'=' '/^path/ {print $2}' $eachgmconffile) 1>>$log
    echo "$($time) - Making mail directory at $mboxfile." 1>>$log
    $mkdirbin -p $($dirnamebin $mboxfile) 1>>$log
    if [ ! -f $mboxfile ];then
      $touchbin $mboxfile 1>>$log
    fi
    echo "$($time) - Starting getmail." 1>>$log
    $getmailbin --getmaildir=$gmconfdir --rcfile=$eachgmconffile --dont-delete | $awkbin '/delivered to Mboxrd/ {print "bytes received: "$3}' | $sedbin -e 's/(//g' 1>>$log || _printerr "ERROR - $LINENO - Unable to backup mail for $eachgmconffile"
  done
fi

if [ "$mysqlopt" = 1 ]; then #MySQL section
  echo "$($time) - Backing up MySQL on $mysqlsrv" | $teebin -a $log
  echo "$($time) - Checking and creating required directories." 1>>$log
  for eachmysqldir in "MySQL" "MySQL/Temp" "MySQL/Daily" "MySQL/Weekly" "MySQL/Monthly" "MySQL/Yearly"; do
    if [ ! -d $bkupdir/$mysqlsrv/$eachmysqldir ];then
      $mkdirbin -p $bkupdir/$mysqlsrv/$eachmysqldir 1>>$log || _printerr "ERROR - $LINENO - Unable to create MySQL backup directory $eachmysqldir for $mysqlsrv in $bkupdir." 1>>$log
    fi
  done
  echo "$($time) - Checking and adding SSH keys." 1>>$log
  if ! $grepbin -i $mysqlsrv /home/$sshuser/.ssh/known_hosts > /dev/null; then
    echo "Host key for $mysqlsrv:" 1>> /home/$sshuser/.ssh/known_hosts
    $sshkeyscanbin -t rsa,dsa $mysqlsrv 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for $mysqlsrv to known host key list."
  fi
  if $sshbin $sshuser@$mysqlsrv : 1>> $log;then
    echo "$($time) - Getting database names and starting loop." 1>>$log
    $sshbin $sshuser@$mysqlsrv "echo 'show databases\g' | mysql --user=\"$mysqluser\" --password=\"$mysqlpass\" | $sedbin '/^information_schema\|^Database\|lost+found/d'" | while read -r eachdbname;do
    echo "Working on $eachdbname"
    dumpday=$($datebin +%F)
    dumptime=$($datebin +%H-%M-%S)
    echo "$($time) - Dumping the database." 1>>$log
    $sshbin $sshuser@$mysqlsrv -n "mysqldump --user=\"$mysqluser\" --password=\"$mysqlpass\" $eachdbname | gzip" 1> $bkupdir/$mysqlsrv/MySQL/Temp/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr "ERROR - $LINENO - Unable to back up MySQL database $eachdbname on $mysqlsrv."
    echo "$($time) - Checking and rotating the database dump." 1>>$log
    if [ -s $bkupdir/$mysqlsrv/MySQL/Temp/$eachdbname-on-$dumpday-at-$dumptime.sql.gz ];then #If the DB backup exists and is non-zero in size, copy the daily and move on.
      echo "Total bytes received for database $eachdbname: $($lsbin $bkupdir/$mysqlsrv/MySQL/Temp/$eachdbname-on-$dumpday-at-$dumptime.sql.gz -l | $cutbin -d' ' -f5)"
      $mvbin $bkupdir/$mysqlsrv/MySQL/Temp/$eachdbname-on-$dumpday-at-$dumptime.sql.gz $bkupdir/$mysqlsrv/MySQL/Daily/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr "ERROR - $LINENO - Unable to copy new daily MySQL backup for $mysqlsrv."
      $lsbin -1 -t $bkupdir/$mysqlsrv/MySQL/Daily/$eachdbname* | $awkbin --assign=numdailydumpfiles=$numdailydumpfiles '{ if (NR > numdailydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] || _printerr "ERROR - $LINENO - Unable to remove old daily MySQL backup for $mysqlsrv."
      if [ $($datebin +%a) = "Sat" ];then #Copy the weekly
	$cpbin $bkupdir/$mysqlsrv/MySQL/Daily/$eachdbname-on-$dumpday-at-$dumptime.sql.gz $bkupdir/$mysqlsrv/MySQL/Weekly/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr "ERROR - $LINENO - Unable to copy new weekly MySQL backup for $mysqlsrv."
	$lsbin -1 -t $bkupdir/$mysqlsrv/MySQL/Weekly/$eachdbname* | $awkbin --assign=numweeklydumpfiles=$numweeklydumpfiles '{ if (NR > numweeklydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] || _printerr "ERROR - $LINENO - Unable to remove old weekly MySQL backup for $mysqlsrv."
      fi
      if [ $($datebin +%d) = "01" ];then #Copy the monthly
	$cpbin $bkupdir/$mysqlsrv/MySQL/Daily/$eachdbname-on-$dumpday-at-$dumptime.sql.gz $bkupdir/$mysqlsrv/MySQL/Monthly/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr "ERROR - $LINENO - Unable to copy new monthly MySQL backup for $mysqlsrv."
	$lsbin -1 -t $bkupdir/$mysqlsrv/MySQL/Monthly/$eachdbname* | $awkbin --assign=nummonthlydumpfiles=$nummonthlydumpfiles '{ if (NR > nummonthlydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] || _printerr "ERROR - $LINENO - Unable to remove old monthly MySQL backup for $mysqlsrv."
      fi
      if [ $($datebin +%j) = "001" ];then #Copy the yearly
	$cpbin $bkupdir/$mysqlsrv/MySQL/Daily/$eachdbname-on-$dumpday-at-$dumptime.sql.gz $bkupdir/$mysqlsrv/MySQL/Yearly/$eachdbname-on-$dumpday-at-$dumptime.sql.gz || _printerr "ERROR - $LINENO - Unable to copy new yearly MySQL backup for $mysqlsrv."
	$lsbin -1 -t $bkupdir/$mysqlsrv/MySQL/Yearly/$eachdbname* | $awkbin --assign=numyearlydumpfiles=$numyearlydumpfiles '{ if (NR > numyearlydumpfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "0" ] || _printerr "ERROR - $LINENO - Unable to remove old yearly MySQL backup for $mysqlsrv."
      fi
    else
      _printerr "ERROR - $LINENO - Backup of DB $eachdbname failed (zero length backup file or it doesn't exist), keeping old backup (if one exist)."
    fi
    done 1>>$log
  else
    _printerr "ERROR - $LINENO - SSH to $mysqlsrv failed." 1>>$log
  fi
fi

if [ "$apachehttpdopt" = 1 ]; then #Apache httpd section
  echo "$($time) - Backing up Apache httpd on $apachesrv" | $teebin -a $log
  if $sshbin $sshuser@Teal -p $sshport : 1>>$log;then
    echo "$($time) - Checking and creating required directories." 1>>$log
    $mkdirbin -p $bkupdir/$apachesrv/Apache_httpd 1>>$log || _printerr "ERROR - $LINENO - Unable to create Apache httpd backup directory Apache_httpd for $apachesrv in $bkupdir." 1>>$log
    echo "$($time) - Checking and adding SSH keys." 1>>$log
    if ! $grepbin -i $apachesrv /home/$sshuser/.ssh/known_hosts > /dev/null; then
      echo "Host key for $apachesrv:" 1>> /home/$sshuser/.ssh/known_hosts
      $sshkeyscanbin -t rsa,dsa $apachesrv 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for $apachesrv to known host key list."
    fi
    echo "$($time) - Starting rsync." 1>>$log
    $sudobin $rsyncbin -aDHAXRvvv --stats --progress -e "$sudobin -u $sshuser $sshbin -l $sshuser -p $sshport" --rsync-path="$sudobin $rsyncbin" ${apachesrv}:$apacheserverroot ${bkupdir}/${apachesrv}/Apache_httpd$apacheserverroot
#    $sudobin $rsyncbin -aDHAXR --stats --progress --exclude pub -e "$sudobin -u $sshuser $sshbin -l $sshuser -p $sshport" --rsync-path="$sudobin $rsyncbin" ${apachesrv}:$apachedocroot ${bkupdir}/${apachesrv}/Apache_httpd$apachedocroot
  else
    _printerr "ERROR - $LINENO - SSH to $apachesrv failed, skipping Apache httpd section." 1>>$log
  fi
fi

if [ "$vmwareopt" = 1 ]; then #VMware Workstation section
  echo "$($time) - Backing up VMs on $vmwrkstnsvr" | $teebin -a $log
  echo "$($time) - Checking and adding SSH keys." 1>>$log
  if ! $grepbin -i teal /home/$sshuser/.ssh/known_hosts 1> /dev/null; then
    echo "Host key for Teal" 1>> /home/$sshuser/.ssh/known_hosts
    $sshkeyscanbin -t rsa,dsa teal 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for Teal to known host key list."
  fi
  echo "$($time) - Checking and creating required remote directories." 1>>$log
  if $sshbin $sshuser@Teal -p $sshport : 1>>$log;then
    $sshbin $sshuser@Teal -p $sshport "{
      $mkdirbin -p /media/Backup/VM/Dev || echo "ERROR - $LINENO - Unable to create required VM directory on Teal."
      $mkdirbin -p /media/Backup/VM/Prod || echo "ERROR - $LINENO - Unable to create required VM directory on Teal."
      $mkdirbin -p /media/Backup/VM/Retired || echo "ERROR - $LINENO - Unable to create required VM directory on Teal."
    }" 1>>$log
    echo "Starting on running VMs" | $teebin -a $log
    echo "$($time) - Getting list of VMs and starting loop." 1>>$log
    $sudobin -H -u white $vmrunbin -T ws list | $sedbin '1d' | while read -r eachrunvmx;do
      echo "Working on $eachrunvmx" | $teebin -a $log
      echo "$($time) - Pausing VM." 1>>$log
      $sudobin -H -u white $vmrunbin -T ws pause "$eachrunvmx" || _printerr "ERROR - $LINENO - Unable to pause $eachrunvmx" 1>>$log
      $sleepbin 5
      echo "$($time) - Starting rsync." 1>>$log
      #This section turns "/media/VM/Prod/Gamboge/Tails.vmx" into "/media/VM/Prod/Gamboge/" as the source of the VM to copy.
      #Then turns "/media/VM/Prod/Gamboge/Tails.vmx" into "Teal:/media/Backup/VM/Prod/Gamboge" as the destination of the VM to copy.
      $sudobin $rsyncbin -a --stats --delete-before -e "$sudobin -u $sshuser $sshbin -l $sshuser -p $sshport" --rsync-path="$sudobin $rsyncbin" $(dirname "$eachrunvmx")/ Teal:/media/Backup/VM/$(dirname "$eachrunvmx" | $sedbin 's/\/media\/VM\///g')/ 1>>$log || _printerr "ERROR - $LINENO - Failed to transfer $eachrunvmx" 1>>$log
      $sleepbin 5
      echo "$($time) - Unpausing VM." 1>>$log
      $sudobin -H -u white $vmrunbin -T ws unpause "$eachrunvmx" || _printerr "ERROR - $LINENO - Unable to unpause $eachrunvmx" 1>>$log
    done
    echo "Starting on non-running VMs" | $teebin -a $log
      echo "$($time) - Getting list of VMs and starting loop." 1>>$log
      $sudobin -H -u white $vmrunbin -T ws list 1> $lockdir/runvmlist.txt || _printerr "ERROR - $LINENO - Unable to determine running VMs"
      $findbin /media/VM -name '*.vmx' | while read -r eachvmx; do
      if ! $grepbin "$eachvmx" $lockdir/runvmlist.txt > /dev/null; then
	echo "Working on $eachvmx." | $teebin -a $log
	echo "$($time) - Starting rsync." >> $log
	#This section turns "/media/VM/Prod/Gamboge/Tails.vmx" into "/media/VM/Prod/Gamboge/" as the source of the VM to copy.
	#Then turns "/media/VM/Prod/Gamboge/Tails.vmx" into "Teal:/media/Backup/VM/Prod/Gamboge" as the destination of the VM to copy.
	$sudobin $rsyncbin -a --stats --delete-before -e "$sudobin -u $sshuser $sshbin -l $sshuser -p $sshport" --rsync-path="$sudobin $rsyncbin" $(dirname "$eachvmx")/ Teal:/media/Backup/VM/$(dirname "$eachvmx" | $sedbin 's/\/media\/VM\///g')/ 1>>$log || _printerr "ERROR - $LINENO - Failed to transfer $eachrunvmx" 1>>$log
      fi
    done
  else
    _printerr "ERROR - $LINENO - SSH to Teal failed, skipping VMware section."
  fi
fi

if [ "$virtualboxopt" = 1 ];then #This has not yet been fully integrated with the rest of the script, use with caution.
  echo "$($time) - Backing up Oracle VirtualBox VMs on $vboxsvr" | $teebin -a $log
  if ! $grepbin -i $vboxsvr /home/$sshuser/.ssh/known_hosts 1> /dev/null; then
    echo "Host key for $vboxsvr" 1>> /home/$sshuser/.ssh/known_hosts
    $sshkeyscanbin -t rsa,dsa $vboxsvr 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for Teal to known host key list."
  fi
  if $sshbin jaw171b.noc.pitt.edu : 1>>$log;then
    $vboxmanage list runningvms | $cutbin -d' ' -f1 | $sedbin 's/"//g' > $lockdir/vboxrunningvms.txt 1>>$log || _printerr "ERROR - $LINENO - Unable to determine running VMs." 1>>$log
    $vboxmanage list vms | $cutbin -d' ' -f1 | $sedbin 's/"//g' 1> $lockdir/vboxallvms.txt || _printerr "ERROR - $LINENO - Unable to determine list of VMs." 1>>$log
    echo "Starting on running VMs" | $teebin -a $log
    $catbin $lockdir/vboxrunningvms.txt | while read -r eachrunvm;do
      echo "Working on $eachrunvm" | $teebin -a $log
      $vboxmanage controlvm "$vboxvmdir/$eachrunvm/$eachrunvm.vbox" savestate || _printerr "ERROR - $LINENO - Unable to pause $eachrunvm"
      $sleepbin 5
      $rsyncbin -a -e "$sshbin -i /home/jaw171/.ssh/id_dsa" $vboxvmdir/$eachrunvm jaw171b.noc.pitt.edu:/VM_backup_from_jaw171a || _printerr "ERROR - $LINENO - Unable transfer $eachrunvm"
      $sleepbin 5
      $vboxmanage startvm "$vboxvmdir/$eachrunvm/$eachrunvm.vbox" || _printerr "ERROR - $LINENO - Unable to unpause $eachrunvm" 
    done 1>>$log
    echo "Starting on non-running VMs" | $teebin -a $log 
    $catbin $lockdir/vboxallvms.txt | while read -r eachvm; do
      if ! $grepbin "$eachvm" $lockdir/vboxrunningvms.txt > /dev/null; then
        echo "Working on $eachvm."
        $rsyncbin -a -e "$sshbin -i /home/jaw171/.ssh/id_dsa" $vboxvmdir/$eachvm jaw171b.noc.pitt.edu:/VM_backup_from_jaw171a || _printerr "ERROR - $LINENO - Unable transfer $eachrunvm"
      fi
    done 1>>$log
  else
    _printerr "ERROR - $LINENO - SSH to Teal failed, skipping VMware section." 1>>$log
  fi
fi

if [ "$dataopt" = 1 -o "$datadeleteopt" = 1 ];then #Datastore section
  echo "$($time) - Backing up Data on Cyan" | $teebin -a $log
  echo "$($time) - Checking and adding SSH keys." 1>>$log
  if ! $grepbin -i "teal" /home/$sshuser/.ssh/known_hosts > /dev/null; then
    echo "Host key for Teal:" 1>> /home/$sshuser/.ssh/known_hosts
    $sshkeyscanbin -t rsa,dsa teal 1>> /home/$sshuser/.ssh/known_hosts || _printerr "ERROR - $LINENO - Unable to add host key for Teal to known host key list."
  fi
  echo "$($time) - Starting remote commands." 1>>$log
  echo "$($time) - Starting rsync on main datastore." 1>>$log
  if [ "$datadeleteopt" = "1" ];then
    $sudobin $rsyncbin -a --stats --exclude "VM" --delete-before -e "$sudobin -u $sshuser $sshbin -l $sshuser -p $sshport" --rsync-path="$sudobin $rsyncbin" /media/Data/ Teal:/media/Backup 1>>$log || _printerr "ERROR - $LINENO - Data backup failed!"
  elif [ "$dataopt" = "1" ];then
    $sudobin $rsyncbin -a --stats --exclude "VM" -e "$sudobin -u $sshuser $sshbin -l $sshuser -p $sshport" --rsync-path="$sudobin $rsyncbin" /media/Data/ Teal:/media/Backup 1>>$log || _printerr "ERROR - $LINENO - Data backup failed!"
  fi
fi

echo "$($time) - Cleaning up." | $teebin -a $log
  $rmbin -f /tmp/exclude_linuxos
  $rmbin -f /tmp/exclude_android

echo "$($time) - Removing old backup logs." | $teebin -a $log
$lsbin -1 -t $($dirnamebin $log)/*-$script.log* | $awkbin --assign=numrunlogfiles=$numrunlogfiles '{ if (NR > numrunlogfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] 1>>$log || _printerr "ERROR - $LINENO - Unable to remove old script run logs."

_printoutput