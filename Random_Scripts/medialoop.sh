#!/bin/bash

while [ 1 ]; do
  echo "1) XBMC"
  echo "2) FoFix"
  echo "3) NES"
  echo "q) Quit"
  read -p "# Select an option: " MEDIAANSWER
  case $MEDIAANSWER in
  1)
    echo "# Starting XBMC"
    xbmc&
    status=0
    while [ $status -eq 0 ];do
      sleep 1
      status=`wmctrl -x -l | grep "XBMC Media Center" | wc -l | awk '{print $1}'`
    done
    # Force XBMC window to fullscreen
    wmctrl -x -r XBMC Media Center -b toggle,fullscreen ;;
  2)
    echo "# Starting FoFix"
    cd /home/xbmc/FoFix/src && python FoFiX.py ;;
  3)
    echo "# Starting VirtuaNES"
    wine "/media/Data/Video Game Emulators/NES/VirtuaNES/VirtuaNES.exe" ;;
  4)
  ;;
  q | Q)
    exit ;;
  *)
    echo "# I don't understand that option!"
  esac
done