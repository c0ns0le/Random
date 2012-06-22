#!/bin/bash
#Description: Bash script to check for NetBackup policy changes.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.4.1
#Revision Date: 10-11-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

#Vocabulary:
#+Policy list file: A file which holds the list of policy names, one per line. Created with: $bppllistbin -allpolicies -L | $awkbin -F':' '/^Policy Name/ {gsub(/ */,"",$2); print $2}' | sort
#+Policy detail file: A file for each policy which contains the configuration details of each policy. Created with: $bppllistbin somepolicyname -L
#+Client list file: A file which holds the list of clients, one per line, which exist in any policy. Created with: /usr/openv/netbackup/bin/admincmd/bpplclients | $awkbin 'NR>2 {print $3}'
#This script will create a list of the current policy names using $bppllistbin then check that list against the last list it can find (based on mtime of the files). 
#+This is used to determine if a policy was added or removed. It will take these "policy list files" and keep an archive copy (daily, weekly, monthly, yearly), 
#+of them as well. The second part of the script will use the list of current policy names and call $bppllistbin again to create a file which contains the details of that policy. 
#+It will then do a $diffbin on that against the last policy detail file it can find (also based on mtime) to check for changes. In this way we can know when a 
#+policy was removed, added, or changed...at least as far as $bppllistbin can tell us.
#+ditto for the schedules now too.

#Note that this script should create all required directores...if you set up the variable correctly. If this script gets moved to a new server, ensure that 
#+the variables here are set correctly (e.g. if /opt/openv is no longer where NetBackup is installed, fix the variables). If starting from a clean slate 
#+(meaning $repodir is empty or does not exist) this script will complain about the fact that is cannot find old copies of the policy list to compare anything to. 
#+This is fine and expected since there is no "yesterday" files to compare against. Simply wait until the script runs one or two more days to create the files 
#+it needs and it should be fine.

#If you run this script twice in one day, the last run of the day will become tomorrows "last known good", or what the tomorrows policy files will be compared against.
#+In other words, if this script runs at 9AM then you run it at 3PM, the next run will compare against the 3PM version.

#This script can be ran with no options, but the -n option enables email notifications.

#Define our binaries
grepbin="/bin/grep"
awkbin="/bin/nawk"
catbin="/bin/cat"
rmbin="/bin/rm"
xargsbin="/bin/xargs"
datebin="/bin/date"
mvbin="/bin/mv"
diffbin="/bin/diff"
dirnamebin="/bin/dirname"
mailxbin="/bin/mailx"
sedbin="/bin/sed"
bppllistbin="/usr/openv/netbackup/bin/admincmd/bppllist"
bpschedulebin="/usr/openv/netbackup/bin/admincmd/bpschedule"

script=${0##*/} #The name of the script.
emailrcp="jaw171@pitt.edu mlk55@pitt.edu backup-team@list.pitt.edu" #Seperate emails with a space.
repodir="/usr/openv/var/nbpolicychangewatch" #Location to keep the policy files in.
scriptrunlog="/var/log/nbpolicychangewatch/$($datebin +%Y-%m-%d)-$script.log" #Name and location of the error log for this script.
#+At the end of the script, this log is parsed for errors encountered e.g. if a command in the script failed.
tmpdir="/tmp/netbackup_policy_check" #A working directy used by this script.
policyreviewlog="$tmpdir/policyreview.log" #Name and location of the policy review log.
#+At the end of the script, this log is parsed to gather information on policy changes.
policylistdir="$repodir/Policy_Lists" #Directory to keep the list of policies in.
clientlistdir="$repodir/Client_Lists" #Directory to keep the list of clients in.
schedlistdir="$repodir/Schedule_Lists" #Directory to keep the list of schedules in.
scheddetaildir="$repodir/Schedule_Lists_Details" #Directory to keep the details of schedules in.
numolddailypolfiles="8" #Number of daily policy files to keep.
numoldweeklypolfiles="5" #Number of weekly policy files to keep.
numoldmonthylpolfiles="13" #Number of monthly policy files to keep.
numoldyearlypolfiles="5" #Number of yearly policy files to keep.
numrunlogfiles="90" #Number of script error logs to keep.

#You shouldn't need to change these
curpollistfile="Known_policy_list.$($datebin +%F)"
curclientlistfile="Known_client_list.$($datebin +%F)"
curschedlistfile="Known_schedule_list.$($datebin +%F)"
OPTSTRING=':nh'
PATH=/bin:/usr/bin:/sbin:/usr/sbin/:/usr/local/bin:/usr/local/sbin:/usr/openv/netbackup/bin:/usr/openv/volmgr/bin:/usr/openv/volmgr/bin:/usr/openv/netbackup/bin/admincmd
umask 027

#Sanity checking
if [ -z $BASH ]; then
  echo "FATAL ERROR - $LINENO - Please run this script with the BASH shell.  EXITING"
  exit 192
elif [ $UID != 0 ]; then
  echo "FATAL ERROR - $LINENO - This script must be ran as root, your UID is $UID.  EXITING"
  exit 1
fi

function _handletrap {
scriptcanceled=1
_printfinaloutput
exit 2
}
function _makepolicystats {
  if [ ! -w "$scriptrunlog" -o "$logfail" = "1" ];then
    errnum=1
  else
    errnum=$($grepbin -c "ERROR" "$scriptrunlog")
    numnewclients=$($grepbin -c "Possible new client" "$policyreviewlog")
    numremclients=$($grepbin -c "Possible removed client" "$policyreviewlog")
    numnewpolicies=$($grepbin -c "Possible new policy" "$policyreviewlog")
    numrempolicies=$($grepbin -c "Possible removed policy" "$policyreviewlog")
    numdispolicies=$($grepbin -c "Policy has been disabled" "$policyreviewlog")
    numchangepolicies=$($grepbin -c "Policy details have changed" "$policyreviewlog")
    numnewsched=$($grepbin -c "Possible new schedule" "$policyreviewlog")
    numremsched=$($grepbin -c "Possible removed schedule" "$policyreviewlog")
    numchangesched=$($grepbin -c "Schedule details have changed" "$policyreviewlog")
  fi
}
function _makefinaloutput {
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo "Server: $HOSTNAME"
  echo "Date: $($datebin)"
  echo "Script name: $script"
  echo "Script location: $($dirnamebin $0)"
  echo "Script error log: $scriptrunlog"
  echo "Location of policy files: $repodir"
  echo "Location of policy list files: $policylistdir"
  echo "Location of client list files: $clientlistdir"
  echo "Location of schedule list files: $schedlistdir"
  echo "Location of schedule detail files: $scheddetaildir"
  echo " "
  echo "Number of new clients: $numnewclients"
  echo "Number of removed clients: $numremclients"
  echo "Number of new polices: $numnewpolicies"
  echo "Number of removed policies: $numrempolicies"
  echo "Number of disabled polcies: $numdispolicies"
  echo "Number of changed policies: $numchangepolicies"
  echo "Number of new schedules: $numnewsched"
  echo "Number of removed schedules: $numremsched"
  echo "Number of changed schedules: $numchangesched"
  echo " "
  if [ "$scriptcanceled" = "1" ]; then
    #logger -t "$script" "Canceled: Script$script on $HOSTNAME was canceled/killed."
    echo "Script ${0##*/} on $HOSTNAME was canceled/killed."
    exitstat=1
  elif [ "$errnum" != "0" ]; then
    #logger -t "$script" "Error: Script $script on $HOSTNAME failed to run correctly."
    echo "Error: Script ${0##*/} on $HOSTNAME failed to run correctly, check the log."
    exitstat=1
  else
    if [ "$numnewpolicies" = "0" -a "$numrempolicies" = "0" -a "$numchangepolicies" = "0" -a "$numdispolicies" = "0" -a  "$numnewclients" = "0" -a "$numremclients" = "0" -a "$numnewsched" = "0" -a "$numremsched" = "0" -a "$numchangesched" = "0" ];then
      echo "No policy changes found."
    else
      if [ "$numnewclients" != "0" ]; then
	echo "***** $numnewclients new clients were found:"
	$awkbin -F':' '/Possible new client/ {print $2}' "$policyreviewlog"
	printf "***** End of new clients.\n\n"
      fi
      if [ "$numremclients" != "0" ]; then
	echo "***** $numremclients removed clients were found:"
	$awkbin -F':' '/Possible removed client/ {print $2}' "$policyreviewlog"
	printf "***** End of removed clients.\n\n"
      fi
      if [ "$numnewpolicies" != "0" ]; then
	echo "***** $numnewpolicies new policies were found:"
	$awkbin -F':' '/Possible new policy/ {print $2}' "$policyreviewlog"
	printf "***** End of new policies.\n\n"
      fi
      if [ "$numrempolicies" != "0" ]; then
	echo "***** $numrempolicies removed policies were found:"
	$awkbin -F':' '/Possible removed policy/ {print $2}' "$policyreviewlog"
	printf "***** End of removed policies.\n\n"
      fi
      if [ "$numdispolicies" != "0" ]; then
	echo "***** $numdispolicies disabled policies were found:"
	$awkbin -F':' '/Policy has been disabled/ {print $2}' "$policyreviewlog"
	printf "***** End of disabled policies.\n\n"
      fi
      if [ "$numchangepolicies" != "0" ];then
	echo "***** $numchangepolicies changed policies were found:"
	for eachchangedpol in $($awkbin -F':' '/Policy details have changed/ {print $2}' "$policyreviewlog");do
	  echo "#"
	  echo "$eachchangedpol:"
	  $catbin $tmpdir/diffs/$eachchangedpol.diff
	  echo "#"
	done
	printf "***** End of changed policies.\n\n"
      fi
      if [ "$numnewsched" != "0" ]; then
	echo "***** $numnewsched new schedules were found:"
	$awkbin -F':' '/Possible new schedule/ {print $2}' "$policyreviewlog"
	printf "***** End of new schedules.\n\n"
      fi
      if [ "$numremsched" != "0" ]; then
	echo "***** $numremsched removed schedules were found:"
	$awkbin -F':' '/Possible removed schedule/ {print $2}' "$policyreviewlog"
	printf "***** End of removed schedules.\n\n"
      fi
      if [ "$numchangesched" != "0" ];then
	echo "***** $numchangesched changed schedules were found:"
	for eachchangedsched in $($awkbin -F':' '/Schedule details have changed/ {print $2}' "$policyreviewlog");do
	  echo "#"
	  echo "$eachchangedsched:"
	  $catbin $tmpdir/diffs/$eachchangedsched.diff
	  echo "#"
	done
	printf "***** End of changed policies.\n\n"
      fi
    fi
  fi
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}
function _printfinaloutput {
  if [ "$logfail" = "1" ]; then
    _makepolicystats
    _makefinaloutput
  elif [ "$emailnotifyopt" = "1" ]; then
    _makepolicystats
    _makefinaloutput | $mailxbin -s "NetBackup policy change review." $emailrcp
    _makefinaloutput | tee -a $scriptrunlog
  else    
    _makepolicystats
    _makefinaloutput | tee -a $scriptrunlog
  fi
}

trap _handletrap 1 2 3 15 # Terminate script when receiving signal

while getopts "$OPTSTRING" OPT; do
  case $OPT in
    n)
      emailnotifyopt=1 ;;
    h)
      echo -e "This script will always print output to STDOUT/STDERR regardless to the options used.Usage:\n-n : Enables E-mail notifications\n-h : Shows this help"
      exit 0 ;;
    \?)
      echo "FATAL ERROR: Invalid option \'$OPTARG\' (Use -h for help)"
      exit 192 ;;
  esac
done

#Rotate logs
if [ -f $scriptrunlog ];then
  numoldbak=$(ls $scriptrunlog* | $grepbin -c $(basename $scriptrunlog)-*'[1-9]')
  while (( $numoldbak > 0 ));do
    $mvbin $scriptrunlog-$numoldbak $scriptrunlog-$(( $numoldbak + 1 )) 
    if [ $? != 0 ];then
      echo "# ERROR - $LINENO - Unable to rotate old backup of $scriptrunlog."
      logfail=1
      _printfinaloutput
      exit 1
    fi
    numoldbak=$(( $numoldbak - 1 ))
  done
  $mvbin $scriptrunlog $scriptrunlog-1
  if [ $? != 0 ];then
    echo "# ERROR - $LINENO - Unable to rotate of $scriptrunlog."
    logfail=1
    _printfinaloutput
    exit 1
  fi
fi

exec 2>> $scriptrunlog #All errors go to the log from now on.  Always.

#Make preparations
for eachprepdir in "$($dirnamebin $scriptrunlog)" "$schedlistdir" "$schedlistdir/Daily" "$schedlistdir/Weekly" "$schedlistdir/Monthly" "$schedlistdir/Yearly" "$clientlistdir" "$clientlistdir/Daily" "$clientlistdir/Weekly" "$clientlistdir/Monthly" "$clientlistdir/Yearly" "$tmpdir" "$tmpdir/diffs" "$repodir" "$policylistdir" "$policylistdir/Daily" "$policylistdir/Weekly" "$policylistdir/Monthly" "$policylistdir/Yearly"; do
  if [ ! -d $eachprepdir ];then
    mkdir $eachprepdir 1>>$scriptrunlog 2>>$scriptrunlog
  fi
done

#Additional sanity checking
if [ ! -d $($dirnamebin $scriptrunlog) -o ! -w $($dirnamebin $scriptrunlog) ];then
  echo "ERROR - $LINENO - Log directory ($($dirnamebin $scriptrunlog)) not writable or could not be created.  EXITING"
  logfail=1
  _printfinaloutput
  exit 1
fi
for eachprepdir in "$($dirnamebin $scriptrunlog)" "$tmpdir" "$tmpdir/diffs" "$repodir" "$policylistdir" "$policylistdir/Daily" "$policylistdir/Weekly" "$policylistdir/Monthly" "$policylistdir/Yearly"; do
  if [ ! -d $eachprepdir -o ! -w $eachprepdir ];then
    echo "ERROR - $LINENO - Required directory ($eachprepdir) not writable or could not be created.  EXITING" 1>>$scriptrunlog 2>>$scriptrunlog
    _printfinaloutput
    exit 1
  fi
done

echo "***START***" > $scriptrunlog
echo "***START***" > $policyreviewlog

####

#If a client list file with today's $datebin exists, kill it.
if [ -f $clientlistdir/$curclientlistfile ];then
  $rmbin -f $clientlistdir/$curclientlistfile || echo "ERROR - $LINENO - Unable to remove existing current client list file, it was not created by this run of the script." 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Create a current list of clients
if [ -f $clientlistdir/$curclientlistfile ];then
  echo "ERROR - $LINENO - A client list file with today's $datebin already exists, cannot continue!" 1>>$scriptrunlog 2>>$scriptrunlog
  _printfinaloutput
  exit 1
else
  /usr/openv/netbackup/bin/admincmd/bpplclients | $awkbin 'NR>2 {print $3}' > $clientlistdir/$curclientlistfile || "ERROR - $LINENO - Error while creating client list file." 1>>$scriptrunlog 2>>$scriptrunlog
fi

if ls -1 -t $clientlistdir/Daily/Known_client_list.* &> /dev/null ;then
  lastknownclientlistfile=$(cd $clientlistdir/Daily ; ls -1 -t Known_client_list.* | $awkbin 'NR==1')
fi

if [ ! -s $clientlistdir/$curclientlistfile ];then
  echo "ERROR - $LINENO - The current client list file does not exist or is empty, cannot continue!" 1>>$scriptrunlog 2>>$scriptrunlog
  echo "$clientlistdir/$curclientlistfile" 1>>$scriptrunlog 2>>$scriptrunlog
  _printfinaloutput
  exit 1
fi

#Check for removed clients
if [ -f $clientlistdir/Daily/$lastknownclientlistfile ];then
  for eacholdclientname in $($catbin $clientlistdir/Daily/$lastknownclientlistfile);do
    if ! $grepbin $eacholdclientname $clientlistdir/$curclientlistfile &> /dev/null;then
      echo "Unable to find a current client in the client list.  Possible removed client.:$eacholdclientname" >> $policyreviewlog 2>>$scriptrunlog
    fi
  done
else
  echo "ERROR - $LINENO - Unable to find previous list of clients ($clientlistdir/Daily/$lastknownclientlistfile), can not check for removed clients!" 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Check for new clients
if [ -f $clientlistdir/Daily/$lastknownclientlistfile ];then
  for eachcurclientname in $($catbin $clientlistdir/$curclientlistfile);do
    if ! $grepbin $eachcurclientname $clientlistdir/Daily/$lastknownclientlistfile &> /dev/null;then
      echo "Unable to find a client in the last known client list.  Possible new client.:$eachcurclientname" >> $policyreviewlog 2>>$scriptrunlog
    fi
  done
else
  echo "ERROR - $LINENO - Unable to find previous list of clients ($clientlistdir/Daily/$lastknownclientlistfile), can not to check for new clients!" 1>>$scriptrunlog 2>>$scriptrunlog
fi

####

#If a policy list file with today's $datebin exists, kill it.
if [ -f $policylistdir/$curpollistfile ];then
  $rmbin -f $policylistdir/$curpollistfile || echo "ERROR - $LINENO - Unable to remove existing current policy list file, it was not created by this run of the script." 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Create the current list of policies
if [ -f $policylistdir/$curpollistfile ];then
  echo "ERROR - $LINENO - A policy list file with today's $datebin already exists, cannot continue!" 1>>$scriptrunlog 2>>$scriptrunlog
  _printfinaloutput
  exit 1
else
  $bppllistbin -allpolicies -L | $awkbin -F':' '/^Policy Name/ {gsub(/ */,"",$2); print $2}' | sort > $policylistdir/$curpollistfile || "ERROR - $LINENO - Error while creating policy list file." 1>>$scriptrunlog 2>>$scriptrunlog
fi

if ls -1 -t $policylistdir/Daily/Known_policy_list.* &> /dev/null ;then
  lastknownpollistfile=$(cd $policylistdir/Daily ; ls -1 -t Known_policy_list.* | $awkbin 'NR==1')
fi

if [ ! -s $policylistdir/$curpollistfile ];then
  echo "ERROR - $LINENO - The current policy list file does not exist or is empty, cannot continue!" 1>>$scriptrunlog 2>>$scriptrunlog
  echo "$policylistdir/$curpollistfile" 1>>$scriptrunlog 2>>$scriptrunlog
  _printfinaloutput
  exit 1
fi

#Check for removed policies
if [ -f $policylistdir/Daily/$lastknownpollistfile ];then
  for eacholdpolname in $($catbin $policylistdir/Daily/$lastknownpollistfile);do
    if ! $grepbin $eacholdpolname $policylistdir/$curpollistfile &> /dev/null;then
      echo "Unable to find a current policy in the policy list.  Possible removed policy.:$eacholdpolname" >> $policyreviewlog 2>>$scriptrunlog
    fi
  done
else
  echo "ERROR - $LINENO - Unable to find previous list of policies ($policylistdir/Daily/$lastknownpollistfile), can not check for removed policies!" 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Check for new policies
if [ -f $policylistdir/Daily/$lastknownpollistfile ];then
  for eachcurpolname in $($catbin $policylistdir/$curpollistfile);do
    if ! $grepbin $eachcurpolname $policylistdir/Daily/$lastknownpollistfile &> /dev/null;then
      echo "Unable to find a last known policy in the last known policy list.  Possible new policy.:$eachcurpolname" >> $policyreviewlog 2>>$scriptrunlog
    fi
  done
else
  echo "ERROR - $LINENO - Unable to find previous list of policies ($policylistdir/Daily/$lastknownpollistfile), can not to check for new policies!" 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Begin the loop for each current policy
$catbin $policylistdir/$curpollistfile | while read -r eachcurpolname; do
  echo "Working on policy: $eachcurpolname"
  #Create the required directories
  for eachprepdir in "$repodir/$eachcurpolname" "$repodir/$eachcurpolname/Daily" "$repodir/$eachcurpolname/Weekly" "$repodir/$eachcurpolname/Monthly" "$repodir/$eachcurpolname/Yearly";do
    if [ ! -d $eachprepdir ];then
      mkdir $eachprepdir 1>>$scriptrunlog 2>>$scriptrunlog
    fi
    if [ ! -d $eachprepdir -o ! -w $eachprepdir ];then
      echo "ERROR - $LINENO - Required policy detail directory $eachprepdir could not be created or is not writable, skipping policy $eachcurpolname." 1>>$scriptrunlog 2>>$scriptrunlog
      continue 2 #Break out of the loops for this iteration only.
    fi
  done

currentpoldetailfile=$eachcurpolname.$($datebin +%F)

#Create a new policy file
  echo "***START***" > $repodir/$eachcurpolname/$currentpoldetailfile
  $bppllistbin $eachcurpolname -L | $sedbin '/^Generation/d' >> $repodir/$eachcurpolname/$currentpoldetailfile || echo "ERROR - $LINENO - Error while creating policy detail file for $eachcurpolname" 1>>$scriptrunlog 2>>$scriptrunlog
  echo "***END***" >> $repodir/$eachcurpolname/$currentpoldetailfile

#Only do a $diffbin if we can find an old file to compare against.
  if ls -1 -t $repodir/$eachcurpolname/Daily/$eachcurpolname.* &> /dev/null;then
    lastknownpoldetailfile=$(cd $repodir/$eachcurpolname/Daily ; ls -1 -t $eachcurpolname.* | $awkbin 'NR==1')
#Create the diffs and check it
    if [ -f $repodir/$eachcurpolname/Daily/$lastknownpoldetailfile ];then #If this is a new policy, skip the checks.  Earlier we already checked for new policies.
      $diffbin -U 0 -s $repodir/$eachcurpolname/Daily/$lastknownpoldetailfile $repodir/$eachcurpolname/$currentpoldetailfile > $tmpdir/diffs/${eachcurpolname}.diff 2>>$scriptrunlog
      if ! $grepbin "No differences encountered" $tmpdir/diffs/${eachcurpolname}.diff &> /dev/null;then
	echo "Policy details have changed.:$eachcurpolname" >> $policyreviewlog 2>>$scriptrunlog
	$grepbin "Active:            no" $tmpdir/diffs/$eachcurpolname.diff > /dev/null && echo "Policy has been disabled.:$eachcurpolname" >> $policyreviewlog 2>>$scriptrunlog
      fi
    fi
  fi

#Rotate the policy info files
  if [ -s $repodir/$eachcurpolname/$currentpoldetailfile ];then #If the current detail file exists and is non-zero in size, copy it to daily and move on.
    $mvbin $repodir/$eachcurpolname/$currentpoldetailfile $repodir/$eachcurpolname/Daily || echo "ERROR - $LINENO - Unable to copy new daily policy detail file for $eachcurpolname." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $repodir/$eachcurpolname/Daily/* | $awkbin -v numolddailypolfiles=$numolddailypolfiles '{ if (NR > numolddailypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old daily policy detail file for $eachcurpolname." 1>>$scriptrunlog 2>>$scriptrunlog
    if [ $($datebin +%a) = "Sat" ];then #Copy the weekly
      cp $repodir/$eachcurpolname/Daily/$currentpoldetailfile $repodir/$eachcurpolname/Weekly/$currentpoldetailfile || echo "ERROR - $LINENO - Unable to copy new weekly policy file for $eachcurpolname." 1>>$scriptrunlog 2>>$scriptrunlog
      ls -1 -t $repodir/$eachcurpolname/Weekly/* | $awkbin -v numoldweeklypolfiles=$numoldweeklypolfiles '{ if (NR > numoldweeklypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old weekly policy file for $eachcurpolname." 1>>$scriptrunlog 2>>$scriptrunlog
    fi
    if [ $($datebin +%d) = "31" ];then #Copy the monthly
      cp $repodir/$eachcurpolname/Daily/$currentpoldetailfile $repodir/$eachcurpolname/Monthly/$currentpoldetailfile || echo "ERROR - $LINENO - Unable to copy new monthly policy file for $eachcurpolname." 1>>$scriptrunlog 2>>$scriptrunlog
      ls -1 -t $repodir/$eachcurpolname/Monthly/* | $awkbin -v numoldmonthylpolfiles=$numoldmonthylpolfiles '{ if (NR > numoldmonthylpolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old monthly policy file for $eachcurpolname." 1>>$scriptrunlog 2>>$scriptrunlog
    fi
    if [ $($datebin +%j) = "365" ];then #Copy the yearly
      cp $repodir/$eachcurpolname/Daily/$currentpoldetailfile $repodir/$eachcurpolname/Yearly/$currentpoldetailfile || echo "ERROR - $LINENO - Unable to copy new yearly policy file for $eachcurpolname." 1>>$scriptrunlog 2>>$scriptrunlog
      ls -1 -t $repodir/$eachcurpolname/Yearly/* | $awkbin -v numoldyearlypolfiles=$numoldyearlypolfiles '{ if (NR > numoldyearlypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old yearly policy  file for $eachcurpolname." 1>>$scriptrunlog 2>>$scriptrunlog
    fi
  else
    echo "ERROR - $LINENO - Zero length policy detail file for $eachcurpolname or the file doesn't exist, skipping rotation and keeping old file (if one exist)." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
done

####

#If a client list file with today's $datebin exists, kill it.
if [ -f $schedlistdir/$curschedlistfile ];then
  $rmbin -f $schedlistdir/$curschedlistfile || echo "ERROR - $LINENO - Unable to remove existing current schedule list file, it was not created by this run of the script." 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Create a current list of schedules:
if [ -f $schedlistdir/$curschedlistfile ];then
  echo "ERROR - $LINENO - A schedule list file with today's $datebin already exists, cannot continue!" 1>>$scriptrunlog 2>>$scriptrunlog
  _printfinaloutput
  exit 1
else
  $bpschedulebin -L | $awkbin '/Schedule/ { print $2}' > $schedlistdir/$curschedlistfile
  if [ ${PIPESTATUS[0]} != 0 -o ${PIPESTATUS[1]} != 0 ];then
    echo "ERROR - $LINENO - Error while creating schedule list file." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
fi

if [ ! -s $schedlistdir/$curschedlistfile ];then
  echo "ERROR - $LINENO - The current schedule list file does not exist or is empty, cannot continue!" 1>>$scriptrunlog 2>>$scriptrunlog
  echo "$schedlistdir/$curschedlistfile" 1>>$scriptrunlog 2>>$scriptrunlog
  _printfinaloutput
  exit 1
fi

#Get the last known schedule list file:
if ls -1 -t $schedlistdir/Daily/Known_schedule_list.* &> /dev/null ;then
  lastknownschedlistfile=$(cd $schedlistdir/Daily ; ls -1 -t Known_schedule_list.* | $awkbin 'NR==1')
fi

#Check for removed schedules:
if [ -f $schedlistdir/Daily/$lastknownschedlistfile ];then
  for eacholdschedname in $($catbin $schedlistdir/Daily/$lastknownschedlistfile);do
    if ! $grepbin $eacholdschedname $schedlistdir/$curschedlistfile &> /dev/null;then
      echo "Unable to find a current schedule in the client list.  Possible removed schedule.:$eacholdschedname" >> $policyreviewlog 2>>$scriptrunlog
    fi
  done
else
  echo "ERROR - $LINENO - Unable to find previous list of schedules ($schedlistdir/Daily/$lastknownschedlistfile), can not check for removed schedules!" 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Check for new schedules:
if [ -f $schedlistdir/Daily/$lastknownschedlistfile ];then
  for eachcurschedname in $($catbin $schedlistdir/$curschedlistfile);do
    if ! $grepbin $eachcurschedname $schedlistdir/Daily/$lastknownschedlistfile &> /dev/null;then
      echo "Unable to find a schedule in the last known schedule list.  Possible new schedule.:$eachcurschedname" >> $policyreviewlog 2>>$scriptrunlog
    fi
  done
else
  echo "ERROR - $LINENO - Unable to find previous list of schedules ($schedlistdir/Daily/$lastknownschedlistfile), can not to check for new schedules!" 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Create a seperate detail file for each schedule.
mkdir -p $tmpdir/eachscheddetail
cd $tmpdir/eachscheddetail
$bpschedulebin -L > $tmpdir/allscheddetails.txt
$awkbin '/^Schedule:/ && $2 != f {close(f); f=$2} f{print >> f}' $tmpdir/allscheddetails.txt

#Begin the loop for each current schedule
ls -1 $tmpdir/eachscheddetail | while read -r eachcurschedname; do
  echo "Working on schedule: $eachcurschedname"
  #Create the required directories
  for eachprepdir in "$scheddetaildir/$eachcurschedname" "$scheddetaildir/$eachcurschedname/Daily" "$scheddetaildir/$eachcurschedname/Weekly" "$scheddetaildir/$eachcurschedname/Monthly" "$scheddetaildir/$eachcurschedname/Yearly";do
    if [ ! -d $eachprepdir ];then
      mkdir -p $eachprepdir 1>>$scriptrunlog 2>>$scriptrunlog
    fi
    if [ ! -d $eachprepdir -o ! -w $eachprepdir ];then
      echo "ERROR - $LINENO - Required schedule detail directory $eachprepdir could not be created or is not writable, skipping schedule $eachcurschedname." 1>>$scriptrunlog 2>>$scriptrunlog
      continue 2 #Break out of the loops for this iteration only.
    fi
  done

#Move the current schedule detail file out of the temporary directory.
  currentscheddetailfile=$eachcurschedname.$($datebin +%F)
  $mvbin $tmpdir/eachscheddetail/$eachcurschedname $scheddetaildir/$eachcurschedname/$currentscheddetailfile || echo "ERROR - $LINENO - Unable to move $eachcurschedname out of the temporary directory."

#Only do a $diffbin if we can find an old file to compare against.
  if ls -1 -t $scheddetaildir/$eachcurschedname/Daily/$eachcurschedname.* &> /dev/null;then
    lastknownscheddetailfile=$(cd $scheddetaildir/$eachcurschedname/Daily ; ls -1 -t $eachcurschedname.* | $awkbin 'NR==1')
#Create the diffs and check it
    if [ -f $scheddetaildir/$eachcurschedname/Daily/$lastknownscheddetailfile ];then #If this is a new schedule, skip the checks.  Earlier we already checked for new schedules.
      $diffbin -U 0 -s $scheddetaildir/$eachcurschedname/Daily/$lastknownscheddetailfile $scheddetaildir/$eachcurschedname/$currentscheddetailfile > $tmpdir/diffs/${eachcurschedname}.diff 2>>$scriptrunlog
      if ! $grepbin "No differences encountered" $tmpdir/diffs/${eachcurschedname}.diff &> /dev/null;then
	echo "Schedule details have changed.:$eachcurschedname" >> $policyreviewlog 2>>$scriptrunlog
      fi
    fi
  fi

#Rotate the schedule detail files
  if [ -s $scheddetaildir/$eachcurschedname/$currentscheddetailfile ];then #If the current detail file exists and is non-zero in size, copy it to daily and move on.
    $mvbin $scheddetaildir/$eachcurschedname/$currentscheddetailfile $scheddetaildir/$eachcurschedname/Daily || echo "ERROR - $LINENO - Unable to copy new daily policy detail file for $eachcurschedname." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $scheddetaildir/$eachcurschedname/Daily/* | $awkbin -v numolddailypolfiles=$numolddailypolfiles '{ if (NR > numolddailypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old daily schedule detail file for $eachcurschedname." 1>>$scriptrunlog 2>>$scriptrunlog
    if [ $($datebin +%a) = "Sat" ];then #Copy the weekly
      cp $scheddetaildir/$eachcurschedname/Daily/$currentscheddetailfile $scheddetaildir/$eachcurschedname/Weekly/$currentscheddetailfile || echo "ERROR - $LINENO - Unable to copy new weekly policy file for $eachcurschedname." 1>>$scriptrunlog 2>>$scriptrunlog
      ls -1 -t $scheddetaildir/$eachcurschedname/Weekly/* | $awkbin -v numoldweeklypolfiles=$numoldweeklypolfiles '{ if (NR > numoldweeklypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old weekly schedule file for $eachcurschedname." 1>>$scriptrunlog 2>>$scriptrunlog
    fi
    if [ $($datebin +%d) = "31" ];then #Copy the monthly
      cp $scheddetaildir/$eachcurschedname/Daily/$currentscheddetailfile $scheddetaildir/$eachcurschedname/Monthly/$currentscheddetailfile || echo "ERROR - $LINENO - Unable to copy new monthly policy file for $eachcurschedname." 1>>$scriptrunlog 2>>$scriptrunlog
      ls -1 -t $scheddetaildir/$eachcurschedname/Monthly/* | $awkbin -v numoldmonthylpolfiles=$numoldmonthylpolfiles '{ if (NR > numoldmonthylpolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old monthly schedule file for $eachcurschedname." 1>>$scriptrunlog 2>>$scriptrunlog
    fi
    if [ $($datebin +%j) = "365" ];then #Copy the yearly
      cp $scheddetaildir/$eachcurschedname/Daily/$currentscheddetailfile $scheddetaildir/$eachcurschedname/Yearly/$currentscheddetailfile || echo "ERROR - $LINENO - Unable to copy new yearly policy file for $eachcurschedname." 1>>$scriptrunlog 2>>$scriptrunlog
      ls -1 -t $scheddetaildir/$eachcurschedname/Yearly/* | $awkbin -v numoldyearlypolfiles=$numoldyearlypolfiles '{ if (NR > numoldyearlypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old yearly schedule file for $eachcurschedname." 1>>$scriptrunlog 2>>$scriptrunlog
    fi
  else
    echo "ERROR - $LINENO - Zero length schedule detail file for $eachcurschedname or the file doesn't exist, skipping rotation and keeping old file (if one exist)." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
done

#Rotate the policy list files
if [ -s $policylistdir/$curpollistfile ];then #If the current list exists and is non-zero in size, copy it to daily and move on.
  $mvbin $policylistdir/$curpollistfile $policylistdir/Daily || echo "ERROR - $LINENO - Unable to copy new daily policy list." 1>>$scriptrunlog 2>>$scriptrunlog
  ls -1 -t $policylistdir/Daily/* | $awkbin -v numolddailypolfiles=$numolddailypolfiles '{ if (NR > numolddailypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old daily policy lists." 1>>$scriptrunlog 2>>$scriptrunlog
  if [ $($datebin +%a) = "Sat" ];then #Copy the weekly
    cp $policylistdir/Daily/$curpollistfile $policylistdir/Weekly/$curpollistfile || echo "ERROR - $LINENO - Unable to copy new weekly policy list." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $policylistdir/Weekly/* | $awkbin -v numoldweeklypolfiles=$numoldweeklypolfiles '{ if (NR > numoldweeklypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old weekly policy lists." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
  if [ $($datebin +%d) = "31" ];then #Copy the monthly
    cp $policylistdir/Daily/$curpollistfile $policylistdir/Monthly/$curpollistfile || echo "ERROR - $LINENO - Unable to copy new monthly policy list." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $policylistdir/Monthly/* | $awkbin -v numoldmonthylpolfiles=$numoldmonthylpolfiles '{ if (NR > numoldmonthylpolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old monthly policy lists." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
  if [ $($datebin +%j) = "365" ];then #Copy the yearly
    cp $policylistdir/Daily/$curpollistfile $policylistdir/Yearly/$curpollistfile || echo "ERROR - $LINENO - Unable to copy new yearly policy list." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $policylistdir/Yearly/* | $awkbin -v numoldyearlypolfiles=$numoldyearlypolfiles '{ if (NR > numoldyearlypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old yearly policy lists." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
else
  echo "ERROR - $LINENO - Zero length policy list file or the file doesn't exist, skipping rotation and keeping old list (if one exist)." 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Rotate the client list files
if [ -s $clientlistdir/$curclientlistfile ];then #If the current list exists and is non-zero in size, copy it to daily and move on.
  $mvbin $clientlistdir/$curclientlistfile $clientlistdir/Daily || echo "ERROR - $LINENO - Unable to copy new daily client list." 1>>$scriptrunlog 2>>$scriptrunlog
  ls -1 -t $clientlistdir/Daily/* | $awkbin -v numolddailypolfiles=$numolddailypolfiles '{ if (NR > numolddailypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old daily client lists." 1>>$scriptrunlog 2>>$scriptrunlog
  if [ $($datebin +%a) = "Sat" ];then #Copy the weekly
    cp $clientlistdir/Daily/$curclientlistfile $clientlistdir/Weekly/$curclientlistfile || echo "ERROR - $LINENO - Unable to copy new weekly client list." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $clientlistdir/Weekly/* | $awkbin -v numoldweeklypolfiles=$numoldweeklypolfiles '{ if (NR > numoldweeklypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old weekly client lists." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
  if [ $($datebin +%d) = "31" ];then #Copy the monthly
    cp $clientlistdir/Daily/$curclientlistfile $clientlistdir/Monthly/$curclientlistfile || echo "ERROR - $LINENO - Unable to copy new monthly client list." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $clientlistdir/Monthly/* | $awkbin -v numoldmonthylpolfiles=$numoldmonthylpolfiles '{ if (NR > numoldmonthylpolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old monthly client lists." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
  if [ $($datebin +%j) = "365" ];then #Copy the yearly
    cp $clientlistdir/Daily/$curclientlistfile $clientlistdir/Yearly/$curclientlistfile || echo "ERROR - $LINENO - Unable to copy new yearly client list." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $clientlistdir/Yearly/* | $awkbin -v numoldyearlypolfiles=$numoldyearlypolfiles '{ if (NR > numoldyearlypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old yearly client lists." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
else
  echo "ERROR - $LINENO - Zero length client list file or the file doesn't exist, skipping rotation and keeping old list (if one exist)." 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Rotate the schedule list files
if [ -s $schedlistdir/$curschedlistfile ];then #If the current list exists and is non-zero in size, copy it to daily and move on.
  $mvbin $schedlistdir/$curschedlistfile $schedlistdir/Daily || echo "ERROR - $LINENO - Unable to copy new daily schedule list." 1>>$scriptrunlog 2>>$scriptrunlog
  ls -1 -t $schedlistdir/Daily/* | $awkbin -v numolddailypolfiles=$numolddailypolfiles '{ if (NR > numolddailypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old daily schedule lists." 1>>$scriptrunlog 2>>$scriptrunlog
  if [ $($datebin +%a) = "Sat" ];then #Copy the weekly
    cp $schedlistdir/Daily/$curschedlistfile $schedlistdir/Weekly/$curschedlistfile || echo "ERROR - $LINENO - Unable to copy new weekly schedule list." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $schedlistdir/Weekly/* | $awkbin -v numoldweeklypolfiles=$numoldweeklypolfiles '{ if (NR > numoldweeklypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old weekly schedule lists." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
  if [ $($datebin +%d) = "31" ];then #Copy the monthly
    cp $schedlistdir/Daily/$curschedlistfile $schedlistdir/Monthly/$curschedlistfile || echo "ERROR - $LINENO - Unable to copy new monthly schedule list." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $schedlistdir/Monthly/* | $awkbin -v numoldmonthylpolfiles=$numoldmonthylpolfiles '{ if (NR > numoldmonthylpolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old monthly schedule lists." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
  if [ $($datebin +%j) = "365" ];then #Copy the yearly
    cp $schedlistdir/Daily/$curschedlistfile $schedlistdir/Yearly/$curschedlistfile || echo "ERROR - $LINENO - Unable to copy new yearly schedule list." 1>>$scriptrunlog 2>>$scriptrunlog
    ls -1 -t $schedlistdir/Yearly/* | $awkbin -v numoldyearlypolfiles=$numoldyearlypolfiles '{ if (NR > numoldyearlypolfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old yearly schedule lists." 1>>$scriptrunlog 2>>$scriptrunlog
  fi
else
  echo "ERROR - $LINENO - Zero length schedule list file or the file doesn't exist, skipping rotation and keeping old list (if one exist)." 1>>$scriptrunlog 2>>$scriptrunlog
fi

#Remove old log files
ls -1 -t $($dirnamebin $scriptrunlog)/*-$script.log* | $awkbin -v numrunlogfiles=$numrunlogfiles '{ if (NR > numrunlogfiles) {print}}' | $xargsbin $rmbin -f ; [ $(echo "${PIPESTATUS[*]}" | $sedbin 's/ //g') -eq "000" ] || echo "ERROR - $LINENO - Unable to remove old script run logs." 1>>$scriptrunlog 2>>$scriptrunlog

_printfinaloutput

echo "***END***" >> $policyreviewlog
echo "***END***" >> $scriptrunlog

cd ~
$rmbin -rf $tmpdir || echo "ERROR - $LINENO - Unable to remove $tmpdir." 1>>$scriptrunlog 2>>$scriptrunlog

exit $exitstat
