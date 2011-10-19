#!/bin/bash                                                                                                                                                                         
#Description: Bash script to have servers send out their disk stats to a list.                                                                                                      
#Written By: Jeff White of The University of Pittsburgh (jaw171@pitt.edu)
#Version Number: 0.1
#Revision Date: 5-19-11
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, 
#+the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
shopt -s -o noclobber
shopt -s -o nounset

email="unix-san-stats@list.pitt.edu"
dfbin="/bin/df"
mailxbin="/bin/mailx" #This could call sendmail directly instead.
sedbin="/bin/sed"
