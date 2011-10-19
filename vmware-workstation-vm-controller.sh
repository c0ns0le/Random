#!/bin/bash
shopt -s -o noclobber
# Description: Bash script to start, stop, or suspend VMs with VMware Workstation.
# Written By: Jeff White (jwhite530@gmail.com)
# Version Number: 0.4
# Revision Date: 8-26-2010
# License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
# # This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

# You must run this script as the user running VMware Workstation

VMRUNCL="/usr/bin/vmrun -T ws"

$VMRUNCL list

echo "1) Select all VMs"
echo "2) Select all development VMs"
echo "3) Select all production VMs"
echo "4) Select all running VMs"
echo "5) Type the name of the VM"
echo "6) Enter path to VMX file manually"
echo "q) Quit"
read -p "# Which VM do you want to work with? " VMCHOICE
case "$VMCHOICE" in
  1)
    ALLVM=1
    echo "# I found the following VMs:"
    find /media/VM -name *.vmx ;;
  2)
    ALLDEV=1
    echo "# I found the following VMs:"
    find /media/VM/Dev -name *.vmx ;;
  3)
    ALLPROD=1
    echo "# I found the following VMs:"
    find /media/VM/Prod -name *.vmx ;;
  4)
    ALLRUN=1
    echo "# I found the following VMs:"
    $VMRUNCL list | awk '{if (NR!=1) {print}}' ;;
  5)
    read -p "# Please enter the name of the VM to search for: " VMNAME
    VMSEARCHDIR=$(find /media/VM -iname "$VMNAME")
    VMXFILE=$(find "$VMSEARCHDIR" -name "*.vmx")
    echo "# I found: $VMXFILE"
    read -p "# Is that correct? y or n: " ANSWERCORRECTVMX
    if [[ "$ANSWERCORRECTVMX" = "n" ]];then
      echo "# Exiting."
      exit 1
    elif [[ "$ANSWERCORRECTVMX" = "y" ]];then
      :
    else
      echo "# I only undestand y or n."
      exit 1
    fi ;;
  6) 
    echo "# Here are all the VMX files I could find:"
    find /media/VM -name *.vmx
    read -p "# Enter the full path to the VMX file: " VMXFILE ;;
  q) 
    exit ;;
  *)
    echo "Huh? I only understand the options above."
    exit 1 ;;
esac

echo "1) Start"
echo "2) Stop"
echo "3) Reset"
echo "4) Suspend"
echo "5) Create Snapshot"
echo "6) List Snapshots"
echo "7) Delete Snapshot"
echo "8) Revert to Snapshot"
echo "9) Install VMware Tools in Guest OS"
echo "q) Quit"
read -p "# What do you want to do with the VM? " ACTIONCHOICE
case "$ACTIONCHOICE" in
  1)
    VMACTION="start"
    NOGUI="nogui" ;;
  2)
    VMACTION="stop"
    read -p "# Hard shutdown (without letting the guest OS shut down)? y or n" HARDORSOFTCHOICE
    if [ "$HARDORSOFTCHOICE" = "y" ];then
      HARDORSOFT="hard"
    elif [ "$HARDORSOFTCHOICE" = "n" ];then
      HARDORSOFT="soft"
    else
      echo "# Huh? I only understand y or n."
    fi ;;
  3)
    VMACTION="reset" 
    read -p "# Hard reset (without letting the guest OS shut down)? y or n" HARDORSOFTCHOICE
    if [ "$HARDORSOFTCHOICE" = "y" ];then
      HARDORSOFT="hard"
    elif [ "$HARDORSOFTCHOICE" = "n" ];then
      HARDORSOFT="soft"
    else
      echo "# Huh? I only understand y or n."
      exit 1
    fi ;;
  4)
    VMACTION="suspend"
    read -p "# Hard suspend (without letting the guest OS hibernate)? y or n" HARDORSOFTCHOICE
    if [ "$HARDORSOFTCHOICE" = "y" ];then
      HARDORSOFT="hard"
    elif [ "$HARDORSOFTCHOICE" = "n" ];then
      HARDORSOFT="soft"
    else
      echo "# Huh? I only understand y or n."
      exit 1
    fi ;;
  5)
    VMACTION="snapshot"
    read -p "# Please enter the snapshot name: " SNAPNAME ;;
  6)
    VMACTION="listSnapshots" ;;
  7)
    VMACTION="deleteSnapshot"
    $VMRUNCL listSnapshots "$VMXFILE"
    read -p "# Please enter the snapshot name: " SNAPNAME ;;
  8)
    VMACTION="revertToSnapshot"
    $VMRUNCL listSnapshots "$VMXFILE"
    read -p "# Please enter the snapshot name: " SNAPNAME ;;
  9)
    VMACTION="installTools" ;;
  q)
    exit ;;
  *)
    echo "Huh? I only understand the options above."
    exit 1 ;;
esac

# Put it all together and run it.
if [ "$ALLVM" = "1" ];then
  find /media/VM -name "*.vmx" | (while read -r EACHVMX;do
  echo "Working on $EACHVMX"
  $VMRUNCL $VMACTION "$EACHVMX" $NOGUI $HARDORSOFT $SNAPNAME
  done)
elif [ "$ALLDEV" = "1" ];then
  find /media/VM/Dev -name "*.vmx" | (while read -r EACHVMX;do
  echo "Working on $EACHVMX"
  $VMRUNCL $VMACTION "$EACHVMX" $NOGUI $HARDORSOFT $SNAPNAME
  done)
elif [ "$ALLPROD" = "1" ];then
  find /media/VM/Prod -name "*.vmx" | (while read -r EACHVMX;do
  echo "Working on $EACHVMX"
  $VMRUNCL $VMACTION "$EACHVMX" $NOGUI $HARDORSOFT $SNAPNAME
  done)
elif [ "$ALLRUN" = "1" ];then
  $VMRUNCL list | awk '{if (NR!=1) {print}}' | (while read -r EACHVMX;do
  echo "Working on $EACHVMX"
  $VMRUNCL $VMACTION "$EACHVMX" $NOGUI $HARDORSOFT $SNAPNAME
  done)
else
  echo "Working on $VMXFILE"
  $VMRUNCL $VMACTION "$VMXFILE" $NOGUI $HARDORSOFT $SNAPNAME
fi
