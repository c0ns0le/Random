#!/bin/bash

SCRIPT=${0##*/}
LOG=/var/log/backup/$(date +%Y-%m-%d)-$SCRIPT.log

for EACHFILE in /etc/network/interfaces /etc/fstab /etc/timezone /etc/ssmtp/ssmtp.conf;do
  if [ -f $EACHFILE ];then
    NUMOLDBAK=$(ls | grep -c $EACHFILE.bak-`date +%m-%d-%Y`-)
    while (( $NUMOLDBAK > 0 ));do
      mv $EACHFILE.bak-$(date +%m-%d-%Y)-$NUMOLDBAK $EACHFILE.bak-$(date +%m-%d-%Y)-$(( $NUMOLDBAK + 1 )) || echo "#ERROR - $LINENO - Unable to rotate old backup of $EACHFILE."
      NUMOLDBAK=$(( $NUMOLDBAK - 1 ))
    done
      if [ -f $EACHFILE.bak-$(date +%m-%d-%Y) ]; then
	mv $EACHFILE.bak-$(date +%m-%d-%Y) $EACHFILE.bak-$(date +%m-%d-%Y)-1 || echo "#ERROR - $LINENO - Unable to rotate previous backup of $EACHFILE."
      fi
    cp $EACHFILE $EACHFILE.bak-$(date +%m-%d-%Y) || echo "#ERROR - $LINENO - Unable to create backup of $EACHFILE."
  fi
done

if [ -f $LOG ];then #Rotate logs
  NUMOLDBAK=$(ls $LOG* | grep -c $LOG-*'[1-9]')
  while (( $NUMOLDBAK > 0 ));do
    mv $LOG-$NUMOLDBAK $LOG-$(( $NUMOLDBAK + 1 )) || printerr "# ERROR - $LINENO - Unable to rotate old backup of $LOG."
    NUMOLDBAK=$(( $NUMOLDBAK - 1 ))
  done
  mv $LOG $LOG-1 || printerr "# ERROR - $LINENO - Unable to rotate of $LOG."
fi