#!/usr/bin/perl
#Description: Perl script to check for directories which are not in a backup policy.
#Written By: Jeff White of The Univeristy of Pittsburgh (jaw171@pitt.edu)

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.1 - 2012-01-23 - Initial version. - Jeff White
#
#####

use warnings; #Print warnings
use strict; #Enforce 'good' programming rules
use Sys::Syslog;

my $policy_list = <<END;
/data/home-login0/sam
/data/home-login0/abalazs
/data/home-login0/adaley
/data/home-login0/amahboobin
/data/home-login0/aschaefer
/data/home-login0/ato
/data/home-login0/azentner
/data/home-login0/balazs
/data/home-login0/bion
/data/home-login0/blee
/data/home-login0/bluna
/data/home-login0/byegneswaran
/data/home-login0/clo
/data/home-login0/cssd
/data/home-login0/dachary
/data/home-login0/dearl
/data/home-login0/dpratt
/data/home-login0/dswigon
/data/home-login0/dwaldeck
/data/home-login0/dzuckerman
/data/home-login0/eswanson
/data/home-login0/ghutchison
/data/home-login0/gleikauf
/data/home-login0/gold
/data/home-login0/grabe
/data/home-login0/gwang
/data/home-login0/hpetek
/data/home-login0/ibahar
/data/home-login0/jabad
/data/home-login0/jaw171
/data/home-login0/jboyle
/data/home-login0/jbrigham
/data/home-login0/jlweiler
/data/home-login0/jmccarthy
/data/home-login0/jrichard
/data/home-login0/jwiezorek
/data/home-login0/jyang
/data/home-login0/jzhao
/data/home-login0/kjohnson
/data/home-login0/kjordan
/data/home-login0/layton
/data/home-login0/lchong
/data/home-login0/ljianhua
/data/home-login0/lschaefer
/data/home-login0/mbarmada
/data/home-login0/mgrabe
/data/home-login0/mkurnikova
/data/home-login0/msussman
/data/home-login0/nagios
/data/home-login0/nessusscanner
/data/home-login0/netl
/data/home-login0/ngs_analysis
/data/home-login0/other
/data/home-login0/pgivi
/data/home-login0/pleu
/data/home-login0/pmoore
/data/home-login0/psy
/data/home-login0/qa
/data/home-login0/rcoalson
/data/home-login0/rrobinson
/data/home-login0/sasher
/data/home-login0/schennubhotla
/data/home-login0/securityscansvc-sam
/data/home-login0/slevitan
/data/home-login0/ssaxena
/data/home-login0/testgroup
/data/home-login0/testgroup2
/data/home-login0/to
/data/home-login0/walsaidi
/data/home-login0/wlayton
/data/home-login0/xliang
/data/home-login0/xlu
/data/home-login0/jabad
/data/home-login0/zentner
/data/pkg
/data/recovery
/data/root
END

my $num_missing_dirs = 0;
foreach my $each_local_dir (`ls -1d /data/home-login0/*`) {
  if ($policy_list !~ m/($each_local_dir)/) {
    print "Directory missing from backup policy: $each_local_dir";
    $num_missing_dirs++
  }
}

if ($num_missing_dirs > 0) {
  print "Missing $num_missing_dirs user directories [$0].\n"; 
  syslog("LOG_INFO", "CREATE TICKET FOR SE - $num_missing_dirs user directories are not in a backup policy [$0].");
}