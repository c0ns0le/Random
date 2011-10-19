#!/bin/bash

#Description: N-able agent installer
#Written By: Jeff White (jwhite@netserve365.com) of NetServe365 (www.NetServe365.com)
#Version Number: 0.7
#Revision Date: 12-9-2010
#License: This script is released under version three (3) of the GNU General Public License (GPL) of the FSF, the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html
##This is a free script, you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.

function printerr {
echo "$1" 1>&2
}

#nagent tar.gz locations.
NAGENTDLRHEL34='https://portal.netserve365.com/download/7.1.0.1085/rhel3.0/N-central/nagent-rhel3.0.tar.gz'
NAGENTDLRHEL5='https://portal.netserve365.com/download/7.1.0.1085/rhel5.1/N-central/nagent-rhel5.1.tar.gz'
#nagent tar.gz md5sums (to verify they were downloaded correctly, use md5sum to generate the new hash if needed)
NAGENTPKGHASHRHEL34="979308cbcf7ec05bde0f6687ce262ea6"
NAGENTPKGHASHRHEL5="029c72ba4d155cbcf2ad1c271f54bde9"
#Full rpm file name, ordered by what to install first.
RPMNAMELIST_INSTALL_5=( "nable-32bitodbc-1RHEL5-1.i386.rpm" "libmodule-7.1.0.*.i686.rpm" "libmodule-devel-7.1.0.*.i686.rpm" "libcachemanager-7.1.0.*.i686.rpm" "libcachemanager-devel-*.i686.rpm" "libnable2-7.1.0.*.i686.rpm" "libnable2-devel-7.1.0.*.i686.rpm" "libsoapdata-7.1.0.*.i686.rpm" "libsoapdata-devel-7.1.0.1085-*.i686.rpm" "libstdsoap2-7.1.0.1085-*.i686.rpm" "libstdsoap2-devel-*.i686.rpm" "libgsoap-7.1.0.*.i686.rpm" "libgsoap-devel-*i686.rpm" "nagent-rhel5.1-*.i686.rpm" )
RPMNAMELIST_INSTALL_34=( "nable-32bitodbc-0-1RHEL3.i386.rpm" "libmodule-7.1.0.*.i686.rpm" "libmodule-devel-*.i686.rpm" "libcachemanager-7.1.0.*.i686.rpm" "libcachemanager-devel-*.i686.rpm" "libnable2-*.i686.rpm" "libnable2-devel-*.i686.rpm" "libsoapdata-*.i686.rpm" "libsoapdata-devel-*.i686.rpm" "libstdsoap2-*.i686.rpm" "libstdsoap2-devel-*.i686.rpm" "libgsoap-*.i686.rpm" "libgsoap-devel-*.i686.rpm" "EasySoap++-0.6.2-RHEL3_4Nable.i386.rpm" "nagent-rhel3.0-*.i686.rpm" )

#Just the package name, not the file name, ordered by what to remove first.
RPMNAMELIST_REMOVE=( "nagent-rhel5.1" "nagent-rhel3.0" "libgsoap-devel" "libgsoap" "libstdsoap2-devel" "libstdsoap2" "libsoapdata-devel" "libsoapdata" "libnable2-devel" "libnable2" "libcachemanager-devel" "libcachemanager" "libmodule-devel" "libmodule" "nable-32bitodbc-1RHEL5-1" "nable-32bitodbc-1RHEL3" "nable-32bitodbc-0-1RHEL3" )

#Is this box a supported OS?  This bit of awk won't work on every system but is good enough.
if [ -f /etc/redhat-release ];then
	ISRHEL34=$(awk -F'.' '{if ($1 ~ (/3/||/4/)) { print "1";nextfile } else if (/Taroon/||/Nahant/) { print "1";nextfile } else { print "0" }}' /etc/redhat-release)
	ISRHEL5=$(awk -F'.' '{if ($1 ~ (/5/)) { print "1";nextfile } else if (/Tikanga/) { print "1";nextfile } else { print "0" }}' /etc/redhat-release)
else
	echo "# $LINENO Error - This box does not appear to be RedHat or VMware ESX."
	exit 1
fi

#Can we find the rpm executable?
if which rpm &> /dev/null;then
	rpm=rpm
elif [ -f /sbin/rpm ];then
	rpm=/sbin/rpm
elif [ -f /usr/sbin/rpm ];then
	rpm=/usr/sbin/rpm
else
	printerr "# $LINENO Error - Unable to find rpm executable.  Exiting."
	exit 1
fi

#Remove the old packages if they exist.
function removeallnablepkgs {
echo "# Removing old packages."
for package in "${RPMNAMELIST_REMOVE[@]}";do
	if $rpm -q $package &> /dev/null;then
		echo "# Removing package $package."
		$rpm -e --nodeps --allmatches $package || printerr "# $LINENO Error - Unable to remove $package."
	fi
done
}

#Fix the binary for 7.1.0.1060
function nagentbinaryreplace {
if [ -f /usr/sbin/nagent ];then
	CURNAGENTHASH=$(md5sum /usr/sbin/nagent | cut -d' ' -f1)
else
	echo "# $LINE Error - Unable to find existing nagent binary, you will have to check if it the 'bad' 7.1.0.1060 or not."
	CURNAGENTHASH=0
fi
if [ "$CURNAGENTHASH" = "83995b6e341e3ef093d1e1c5de5eefa3" -a "$ISRHEL5" = "1" ];then #That's the hash of the bad binary (RHEL5)
	echo "# Found existing 'bad' nagent binary for 7.1.0.1060, replacing it with the patched nagent binary."
	/sbin/service nagent stop
	cp -b ../nagent.fixedbinary /usr/sbin/nagent
	chmod 755 /usr/sbin/nagent
	/sbin/service nagent start
elif  [ "$CURNAGENTHASH" = "83995b6e341e3ef093d1e1c5de5eefa3" -a "$ISRHEL34" = "1" ];then #That's the hash of the bad binary (RHEL3/4)
	echo "# Found existing 'bad' nagent binary for 7.1.0.1060, replacing it with the patched nagent binary."
	/sbin/service nagent stop
	cp -b ../nagent.fixedbinary /usr/sbin/nagent
	chmod 755 /usr/sbin/nagent
	/sbin/service nagent start
else
	echo "# Found nagent binary and it appears to be the correct version."
fi
}

#Here we try to pull down the tar.gz
function getnagentpackage {
if [ "$ISRHEL34" = "1" ];then
	FILE=$(echo "$NAGENTDLRHEL34" | awk -F'/' '{ print $NF }')
	if [ -f $FILE ];then
		echo "# The nagent tar.gz file already exists, I'll just leave it alone."
		checkandextractnagentpackage
	elif which wget &> /dev/null;then
		wget $NAGENTDLRHEL34 || echo "# $LINENO Error - Unable to download the nagent tar.gz."
		checkandextractnagentpackage
	elif which curl &> /dev/null;then
		curl $NAGENTDLRHEL34 > $FILE || echo "# $LINENO Error - Unable to download the nagent tar.gz."
		checkandextractnagentpackage
	else
		echo "# $LINENO Error - Unable find wget or curl to pull down the files I need, you'll have to download the agent manually."
		exit 1
	fi
elif [ "$ISRHEL5" = "1" ];then
	FILE=$(echo "$NAGENTDLRHEL5" | awk -F'/' '{ print $NF }')
	if [ -f $FILE ];then
		echo "# The nagent tar.gz file already exists, I'll just leave it alone."
		checkandextractnagentpackage
	elif which wget &> /dev/null;then
		wget $NAGENTDLRHEL5 || echo "# $LINENO Error - Unable to download the nagent tar.gz."
		checkandextractnagentpackage
	elif which curl &> /dev/null;then
		curl $NAGENTDLRHEL5 > $FILE || echo "# $LINENO Error -Unable to download the nagent tar.gz."
		checkandextractnagentpackage
	else
		echo "# $LINENO Error - Unable to find wget or curl to pull down the files I need, you'll have to download the agent manually."
		exit 1
	fi
fi
}

#Extract the nagent package and move into the correct directory.
function checkandextractnagentpackage {
if [ "$ISRHEL5" = "1" -a "$(md5sum $FILE | cut -d' ' -f1)" = "$NAGENTPKGHASHRHEL5" ];then
	tar xzf "$FILE"
	cd $(echo "$FILE" | cut --delimiter='.' -f1,2)
elif [ "$ISRHEL34" = "1" -a "$(md5sum $FILE | cut -d' ' -f1)" = "$NAGENTPKGHASHRHEL34" ];then
	tar xzf "$FILE"
	cd $(echo "$FILE" | cut --delimiter='.' -f1,2)
else #...and if we did not pull down the tar.gz or the hash is bad...
	echo "# $LINENO Error - Unable to find the nagent tar.gz or it appears to be corrupted.\
Try to download it again, adjust the hash values in the script of they are outdated, or download the agent manually."
	exit 1
fi
}

while [ 1 ];do #Display a choice of actions.
	echo "1) Install/upgrade nagent using custom installer (recommended - also includes option 4)"
	echo "2) Uninstall nagent (and related files) using custom installer"
	echo "3) Install/uninstall nagent using N-able installer"
	echo "4) Replace nagent binary for 7.1.0.1060 with the patched version"
	echo "q) Go back/quit"
	read -p "# Please select an option: " CHOICE
    case "$CHOICE" in
		1) #Install/upgrade nagent using custom installer (recommended)
		
getnagentpackage

#Make sure all the rpm files exist
if [ "$ISRHEL34" = "1" ];then
	for packagefile in "${RPMNAMELIST_INSTALL_34[@]}"; do
		if [ ! -f $packagefile ];then
			printerr " $LINENO Error - Unable to find $packagefile."
			cd ..; exit 1
		fi
	done
elif [ "$ISRHEL5" = "1" ];then
	for packagefile in "${RPMNAMELIST_INSTALL_5[@]}"; do
		if [ ! -f $packagefile ];then
			printerr " $LINENO Error - Unable to find $packagefile."
			cd ..; exit 1
		fi
	done
fi

read -p "Please enter the activation key for the agent: " ACTIVATIONKEY

#Uninstall the agent if it already exists.
if [ -f /etc/init.d/nagent ];then #I don't trust the RPMs alone...
	echo "# nagent appears to already be installed, uninstalling."
	./install.sh -u
elif rpm -q nagent-rhel5.1 &>/dev/null;then
	echo "# nagent appears to already be installed, uninstalling."
	./install.sh -u
elif rpm -q nagent-rhel3.0 &>/dev/null;then
	echo "# nagent appears to already be installed, uninstalling."
	./install.sh -u
fi

#Remove the old packages if they exist.  This is somewhat dangerous as it blindly removes them.
removeallnablepkgs

#Install the new packages.
echo "# Installing new packages."
if [ "$ISRHEL34" = "1" ];then
	for packagefile in "${RPMNAMELIST_INSTALL_34[@]}"; do
		$rpm -Uhv $packagefile 1> /dev/null || printerr "# $LINENO Error - Unable to install $packagefile."
	done
elif [ "$ISRHEL5" = "1" ];then
	for packagefile in "${RPMNAMELIST_INSTALL_5[@]}"; do
		$rpm -Uhv $packagefile 1> /dev/null || printerr "# $LINENO Error - Unable to install $packagefile."
	done
fi

nagentbinaryreplace

#Make the config file
./install.sh -r $ACTIVATIONKEY

#Make sure the config file exists
if [ ! -f /home/nagent/nagent.conf ];then
	printerr "# $LINENO Error - Unable to find nagent config file."
	cd ..; exit 1
fi

cd ..

/sbin/service nagent start ;;

		2) #Uninstall nagent (and related files) using custom installer
		
getnagentpackage
checkandextractnagentpackage

#Call n-able's installer to uninstall itself first.
./install.sh -u || printerr "# $LINENO Error - Uninstallation of the agent with N-able's installer failed!"
		
#Remove the old packages if they exist.
removeallnablepkgs

#Remove the nagent user if it exists.
if grep nagent /etc/passwd &>/dev/null;then
	echo "# Removing nagent user and home directory."
	/usr/sbin/userdel -r nagent || printerr "# $LINENO Error - Removal of the nagent user and home directory failed!"
fi ;;

		3) #Call N-able nagent installer
		
getnagentpackage
checkandextractnagentpackage

./install.sh 

cd .. ;;

		4) #Replace the bad 7.1.0.1060 binary with the good one.
		
nagentbinaryreplace ;;

		q | Q)
		if [ $(pwd | awk -F'/' '{ print $NF }') != "netview" ];then #Since we went into the nagent folder (or at least tried to) we need to get back to the netview folder
			cd ..
		fi
		break ;;
		*)
		echo "# Huh, I only only understand these options:" ;;
esac
done