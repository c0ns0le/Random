#!/bin/bash
#Description: Bash script to parse the output of senddiskstats.sh.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.1
#Revision Date: 5-26-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o nounset

#HOW TO:
#1. Each server will send a "df -k" and if it is Sol10 or higher, a "zpool list" to the list unix-san-stats@list.pitt.edu.
#2. In Thunderbird: Select each email and "save selected messages" as txt to a directory defined in $originalemailsdir.  You may need the "ImportExportTools" extension.
#3. It should create one file for each message with a name like: 20110520-[Unix-san-stats] Disk stats from_ p3dbmgt.p3.pitt.edu-11.txt
#4. This script will convert these "raw" emails into "body only" (no headers) with a file name of just the server name then a .df and .zpool for the different outputs.
#5. This script will remove all "known ignorable" mount points such as /var and print out the remaining entries in a particular format.
#6. This script will then check if it needs to calculate the parsed df output, parsed zpool output, or both then print a summary of usage for that server.
#At the start of the final loop (line 70), you can add server-specific parsing to get rid of mount points or zpools.
#If you want to get rid of a moint point or zpool globally, do that on lines 58 or 65 respectively.

originalemailsdir="/tmp/sanstats/originalemails" #The text version of the emails goes here.
fulldiskstatsdir="/tmp/sanstats/fulldiskstats" #The raw df and zpool outputs for each server end up here in seperate files.
parseddiskstatsdir="/tmp/sanstats/parseddiskstats" #The parsed df and zpool outputs for each server end up here in seperate files.

#Define our binaries
lsbin="/bin/ls"
awkbin="/usr/bin/awk"
sedbin="/bin/sed"
catbin="/bin/cat"
bcbin="/usr/bin/bc"
sortbin="/usr/bin/sort"
uniqbin="/usr/bin/uniq"

#Sanity checking
if [ ! -d $originalemailsdir ];then
  echo "$originalemailsdir does not exist, which means you didn't read the instructions in this script.  Stop being lazy and go read the script."
  exit 0
fi

mkdir -p $fulldiskstatsdir
mkdir -p $parseddiskstatsdir

#Loop through each email as they were sent from the servers and remove the headers and footer then rename the files to only be the name of the server.
ls -1 "$originalemailsdir" | while read -r eachmailfile;do
  newfilename=$(echo "$eachmailfile" | $sedbin 's/.*Disk stats from_ //;s/\.edu.*/.edu/')
  #Get the df output.
  $awkbin 'FNR==1 || (/^~~~~/||/^____/) {p=0} p; /^$/{p=1}' "$originalemailsdir/$eachmailfile" > "$fulldiskstatsdir/${newfilename}.df"
  #Get the zpool output.
  $awkbin 'FNR==1 || /^____/ {p=0} p; /^~~~~/{p=1}' "$originalemailsdir/$eachmailfile" > "$fulldiskstatsdir/${newfilename}.zpool"
done

#Parse the df output.
#This section will take each file without the email headers and remove the /r character Exchange adds, then gets rid of any lines where the first field does start with a /, 
#+then gets rid of the globally ignorable mountpoints such as /var, then prints out the remaining information as: "device path:mount point:total space:used space" 
#You can add more ignored mount points by adding this in sed below: ;/\/usr$/d #Don't forget to escape your forward slashed and use ^ or $ as needed!
ls -1 ${fulldiskstatsdir}/*.df | while read -r eachfile;do
  if [ -s $eachfile ];then #If the file is non-zero in size... 
    $catbin "$eachfile" | $sedbin -e 's/\r$//;/^\//!d;/\/global\/.devices/d;/^\/platform/d;/^\/dev\/sd[a-z][0-9]/d;/:/d;/\/$/d;/\/var$/d;/\/usr$/d;/\opt$/d;/\usr\/vice\/cache$/d;/\/afs$/d;/\/proc$/d;/^\/devices/d' | $awkbin '{ print $1":"$6":"$2":"$3 }' > $parseddiskstatsdir/$(basename $eachfile)
  fi
done

#Parse the zpool output.
ls -1 ${fulldiskstatsdir}/*.zpool | while read -r eachfile;do
  if [ -s $eachfile ];then #If the file is non-zero in size...
    $catbin "$eachfile" | $sedbin 's/\r$//' | $awkbin '{ print $1":ZPOOL:"$2":"$3 }' > $parseddiskstatsdir/$(basename $eachfile)
  fi
done

#Calculate and print the summary for each server.
ls -1 $parseddiskstatsdir | $sedbin 's/\.edu.*/.edu/' | $sortbin | $uniqbin | while read -r eachserver;do
  if [ "$eachserver" = "someservername" ];then #This is where server-specific parsing goes.  Add an elif for each server.
    $sedbin -e '/example/d;' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
    $sedbin -e '/example/d' ${parseddiskstatsdir}/${eachserver}.zpool > ${parseddiskstatsdir}/${eachserver}.zpool.new
    mv ${parseddiskstatsdir}/${eachserver}.zpool.new ${parseddiskstatsdir}/${eachserver}.zpool
  elif [ "$eachserver" = "cw-db01.cssd.pitt.edu" -o "$eachserver" = "cw-db02.cssd.pitt.edu" ];then
    $sedbin -e '/c1t0d0s6/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "devrac-a-01.cssd.pitt.edu" -o "$eachserver" = "devrac-a-02.cssd.pitt.edu" -o "$eachserver" = "devrac-a-03.cssd.pitt.edu" -o "$eachserver" = "devrac-a-04.cssd.pitt.edu" ];then
    $sedbin -e '/asm/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "dwdd01.cssd.pitt.edu" -o "$eachserver" = "dwdd02.cssd.pitt.edu" ];then
    $sedbin -e '/d60:/d;/d160:/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "dwpd01.cssd.pitt.edu" -o "$eachserver" = "dwpd02.cssd.pitt.edu" ];then
    $sedbin -e '/d3:/d;/d10:/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "mailman-dev.cssd.pitt.edu" ];then
    $sedbin -e '/d4:/d;/\/mnt:/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "net-log-01.ns.pitt.edu" -o "$eachserver" = "net-log-02.ns.pitt.edu" ];then
    $sedbin -e '/\/sun1/d;/odm/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "sis-pw01.cssd.pitt.edu" ];then
    $sedbin -e '/c0t0d0s6/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "sis-ta01.cssd.pitt.edu" ];then
    $sedbin -e '/c1t3d0s1/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "sis-ta02.cssd.pitt.edu" -o "$eachserver" = "sis-ta03.cssd.pitt.edu" ];then
    $sedbin -e '/c1t2d0s1/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "sis-td02.cssd.pitt.edu" ];then
    $sedbin -e '/sis-pd01-db01/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "sisdb-test-01.cssd.pitt.edu" ];then
    $sedbin -e '/sisdb-prod/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "sis-tw01.cssd.pitt.edu" -o "$eachserver" = "sis-tw02.cssd.pitt.edu" -o "$eachserver" = "sis-tw03.cssd.pitt.edu" ];then
    $sedbin -e '/d5:/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  elif [ "$eachserver" = "vm03.rods.pitt.edu" ];then
    $sedbin -e '/vm03VolGroup01/d' ${parseddiskstatsdir}/${eachserver}.df > ${parseddiskstatsdir}/${eachserver}.df.new
    mv ${parseddiskstatsdir}/${eachserver}.df.new ${parseddiskstatsdir}/${eachserver}.df
  fi
  if [ -s ${parseddiskstatsdir}/${eachserver}.df -a -s ${parseddiskstatsdir}/${eachserver}.zpool ];then #If both files are non-zero...
    #Show both the df and zpool parsed output and calculate usage of them both.
    printf "\n##### Stats for $eachserver #####\n## Device path : Mount point : Total space : Used space ##\n"
    $catbin ${parseddiskstatsdir}/${eachserver}.df
    $catbin ${parseddiskstatsdir}/${eachserver}.zpool
    df_totalsize_ingb=$($awkbin -F':' '{ SUM += $3 } END { printf "%.2f\n", SUM/1024/1024 }' ${parseddiskstatsdir}/${eachserver}.df)
    df_usedsize_ingb=$($awkbin -F':' '{ SUM += $4 } END { printf "%.2f\n", SUM/1024/1024 }' ${parseddiskstatsdir}/${eachserver}.df)
    #This part is needed to have all the number in GB and not TB or whatever.  Why oh why can't "zpool list" have a -k like df?
    pb_totalsize_ingb=$($awkbin -F':' '$3 ~ /[0-9]P/ { SUM += $3*1024*1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    tb_totalsize_ingb=$($awkbin -F':' '$3 ~ /[0-9]T/ { SUM += $3*1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    gb_totalsize_ingb=$($awkbin -F':' '$3 ~ /[0-9]G/ { SUM += $3 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    mb_totalsize_ingb=$($awkbin -F':' '$3 ~ /[0-9]M/ { SUM += $3/1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    pb_usedsize_ingb=$($awkbin -F':' '$4 ~ /[0-9]P/ { SUM += $4*1024*1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    tb_usedsize_ingb=$($awkbin -F':' '$4 ~ /[0-9]T/ { SUM += $4*1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    gb_usedsize_ingb=$($awkbin -F':' '$4 ~ /[0-9]G/ { SUM += $4 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    mb_usedsize_ingb=$($awkbin -F':' '$4 ~ /[0-9]M/ { SUM += $4/1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    echo "** Total space allocated: $(echo "scale=2;$df_totalsize_ingb+$pb_totalsize_ingb+$tb_totalsize_ingb+$gb_totalsize_ingb+$mb_totalsize_ingb" | $bcbin) GB"
    echo "** Total space used: $(echo "scale=2;$df_usedsize_ingb+$pb_usedsize_ingb+$tb_usedsize_ingb+$gb_usedsize_ingb+$mb_usedsize_ingb" | $bcbin) GB"
  elif [ -s ${parseddiskstatsdir}/${eachserver}.df ];then
    #Show the df parsed output and calculate space for us.
    printf "\n##### Stats for $eachserver #####\n## Device path : Mount point : Total space : Used space ##\n"
    $catbin ${parseddiskstatsdir}/${eachserver}.df
    echo "** Total space allocated: $($awkbin -F':' '{ SUM += $3 } END { printf "%.2f\n", SUM/1024/1024 }' ${parseddiskstatsdir}/${eachserver}.df) GB"
    echo "** Total space used: $($awkbin -F':' '{ SUM += $4 } END { printf "%.2f\n", SUM/1024/1024 }' ${parseddiskstatsdir}/${eachserver}.df) GB"
  elif [ -s ${parseddiskstatsdir}/${eachserver}.zpool ];then
    #Show the zpool parsed output and calculate space for us.
    printf "\n##### Stats for $eachserver #####\n## Device path : Mount point : Total space : Used space ##\n"
    $catbin ${parseddiskstatsdir}/${eachserver}.zpool 
    #This part is needed to have all the number in GB and not TB or whatever.  Why oh why can't "zpool list" have a -k like df?
    pb_totalsize_ingb=$($awkbin -F':' '$3 ~ /[0-9]P/ { SUM += $3*1024*1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    tb_totalsize_ingb=$($awkbin -F':' '$3 ~ /[0-9]T/ { SUM += $3*1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    gb_totalsize_ingb=$($awkbin -F':' '$3 ~ /[0-9]G/ { SUM += $3 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    mb_totalsize_ingb=$($awkbin -F':' '$3 ~ /[0-9]M/ { SUM += $3/1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    pb_usedsize_ingb=$($awkbin -F':' '$4 ~ /[0-9]P/ { SUM += $4*1024*1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    tb_usedsize_ingb=$($awkbin -F':' '$4 ~ /[0-9]T/ { SUM += $4*1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    gb_usedsize_ingb=$($awkbin -F':' '$4 ~ /[0-9]G/ { SUM += $4 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    mb_usedsize_ingb=$($awkbin -F':' '$4 ~ /[0-9]M/ { SUM += $4/1024 } END { printf "%.2f\n", SUM }' ${parseddiskstatsdir}/${eachserver}.zpool)
    echo "** Total space allocated: $(echo "scale=2;$pb_totalsize_ingb+$tb_totalsize_ingb+$gb_totalsize_ingb+$mb_totalsize_ingb" | $bcbin) GB"
    echo "** Total space used: $(echo "scale=2;$pb_usedsize_ingb+$tb_usedsize_ingb+$gb_usedsize_ingb+$mb_usedsize_ingb" | $bcbin) GB"
  else
    printf "\nWARNING - Both the df and zpool parsed output for $eachserver are null!\n"
  fi
done

printf "\nDon't forget add the Oracle RAC space used and don't count clustered filesystems twice!\n"