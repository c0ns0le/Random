#!/usr/bin/env python
# Description: Install NOC tools and perform post-install tasks for RHEL 6
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 2
# Last change: Re-write in Python of the shell version, now with a menu-driven interface

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, re, subprocess, traceback, shutil, glob, pwd, grp
from urllib import urlopen
from optparse import OptionParser



netcool_installer = "/root/netcool-ssm-4.0.0-1788-linux-x86.installer"
netbackup_installer = "/root/7.6.0.1_linux_nbu_clients.tgz"



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Install NOC tools and perform post-install tasks for RHEL 6"
)

(options, args) = parser.parse_args()





# Print a stack trace, exception, and an error string to STDERR
# then exit with the exit status given (default: 1) or don't exit
# if passed NoneType
def error(error_string, exit_status=1):
    red = "\033[31m"
    endcolor = "\033[0m"

    exc_type, exc_value, exc_traceback = sys.exc_info()

    traceback.print_exception(exc_type, exc_value, exc_traceback)

    sys.stderr.write("\n" + red + str(error_string) + endcolor + "\n")
    
    if exit_status is not None:
        sys.exit(int(exit_status))
        
        
        
        

# Determine if we are in a VMware VM
def is_vmware():
    # Returns True if we appear to be a VMware VM, False otherwise
    dmesg_handle = open("/var/log/dmesg", "r")
    
    dmesg_data = dmesg_handle.read()
    
    if re.search("Hypervisor detected: VMware", dmesg_data) is not None:
        dmesg_handle.close()
        return True
    
    else:
        dmesg_handle.close()
        return False
    




# Configure the network
def config_network():
    print "Configuring network..."
    
    # Determine which interface we have
    if os.path.isfile("/etc/sysconfig/network-scripts/ifcfg-eth0"):
        interface_file = "/etc/sysconfig/network-scripts/ifcfg-eth0"
        
    elif os.path.isfile("/etc/sysconfig/network-scripts/ifcfg-em1"):
        interface_file = "/etc/sysconfig/network-scripts/ifcfg-em1"
        
    else:
        error("Unable to find network interface (no eth0 or em1?)")
        
        
    hostname = raw_input("Hostname (FQDN): ")
    ip_addr = raw_input("IP address: ")
    netmask = raw_input("Subnet mask: ")
        
        
    interface_file_handle = open(interface_file, "r+")
    interface_file_data = interface_file_handle.read()
    
    # Set some defaults
    interface_file_data = re.sub("ONBOOT=no", "ONBOOT=\"yes\"", interface_file_data)
    interface_file_data = re.sub("NM_CONTROLLED=yes", "NM_CONTROLLED=\"no\"", interface_file_data)
    interface_file_data = re.sub("BOOTPROTO=dhcp", "BOOTPROTO=\"static\"", interface_file_data)
    
    # Add the IP and netmask
    interface_file_data += "IPADDR=\"" + ip_addr + "\"\n"
    interface_file_data += "NETMASK=\"" + netmask + "\"\n"
    
    # Done with the interfaces file
    interface_file_handle.seek(0)
    interface_file_handle.write(interface_file_data)
    interface_file_handle.close()
    
    
    # Determine the likely router address (1 above the network address)
    ip_addr_split = ip_addr.split(".")
    netmask_split = netmask.split(".")
    gateway_addr_split = [0, 0, 0, 0]

    for octet in range(0, 4):
        gateway_addr_split[octet] = str(int(ip_addr_split[octet]) & int(netmask_split[octet]))

    gateway_addr_split[3] = int(gateway_addr_split[3])
    gateway_addr_split[3] += 1
    gateway_addr_split[3] = str(gateway_addr_split[3])
    
    
    # Set the hostname and gateway then disable IPv6
    hostname_proc = subprocess.Popen(["hostname", hostname], shell=False)
    status = hostname_proc.wait()
    
    net_config_file_handle = open("/etc/sysconfig/network", "r+")
    net_config_file_data = net_config_file_handle.read()
    
    net_config_file_data += "GATEWAY=\"" + ".".join(gateway_addr_split) + "\"\n"
    net_config_file_data += "NETWORKING_IPv6=\"no\"\n"
    net_config_file_data = re.sub("HOSTNAME=localhost\.localdomain", "HOSTNAME=" + hostname, net_config_file_data)
    
    # Done with the network config file
    net_config_file_handle.seek(0)
    net_config_file_handle.write(net_config_file_data)
    net_config_file_handle.close()
    
    
    # Remove the IPv6 local address from /etc/hosts
    hosts_handle = open("/etc/hosts", "w")
    hosts_handle.write("127.0.0.1       localhost.localdomain   localhost.localdomain   localhost4      localhost4.localdomain4 localhost       " + hostname.split(".")[0] + "\n")
    hosts_handle.close()
    
    
    # Disable IPv6
    ipv6_conf_handle = open("/etc/modprobe.d/ipv6.conf", "w")
    ipv6_conf_handle.write("options ipv6 disable=1\n")
    ipv6_conf_handle.close()
    
    
    
    # Restart networking
    network_proc = subprocess.Popen(["service", "network", "restart"], shell=False)
    status = network_proc.wait()
    
    if status == 0:
        print "Success!"
        
    else:
        error("Failed to configure network")
    
    
    
    
    
# Install Netcool
def netcool():
    print "Installing Netcool..."
    
    netcool_proc = subprocess.Popen([netcool_installer], shell=True)
    status = netcool_proc.wait()
    
    if status == 0:
        print "Success!"
        
        os.remove(netcool_installer)
        
    else:
        error("Failed to install Netcool")
        
        
        
        
        
# Install Netbackup
def netbackup():
    print "Installing Netbackup..."
    
    os.chdir("/tmp")
    
    netbackup_untar_proc = subprocess.Popen(["tar", "xzf", netbackup_installer], shell=False)
    status = netbackup_untar_proc.wait()
    
    os.chdir("/tmp/7.6.0.1_linux_nbu_clients")
    
    netbackup_install_proc = subprocess.Popen(["./install"], shell=True)
    status = netbackup_install_proc.wait()
    
    
    if status == 0:
        netbackup_conf_handle = open("/usr/openv/netbackup/bp.conf", "r+")
        netbackup_conf_data = netbackup_conf_handle.read()
        
        netbackup_conf_data += """
SERVER = nb-ms-01.cssd.pitt.edu
SERVER = nb-ms-02.cssd.pitt.edu
SERVER = nb-ms-03.cssd.pitt.edu
SERVER = nb-ms-04.cssd.pitt.edu
SERVER = nb-unixsnap-01.cssd.pitt.edu
SERVER = nb-winsnap-01.cssd.pitt.edu
SERVER = nb-winsnap-02.cssd.pitt.edu
"""
        
        netbackup_conf_handle.seek(0)
        netbackup_conf_handle.write(netbackup_conf_data)
        netbackup_conf_handle.close()
        
        netbackup_exclude_handle = open("/usr/openv/netbackup/exclude_list", "w")
        
        netbackup_exclude_data = """/proc
/sys
/selinux
/mnt
/media
/afs
/dev/shm
"""
        
        netbackup_exclude_handle.write(netbackup_exclude_data)
        netbackup_exclude_handle.close()
        
        os.chdir("/root")
        os.remove(netbackup_installer)
        shutil.rmtree("/tmp/7.6.0.1_linux_nbu_clients")
        
        
        # Disable the daemon if we're in a VM
        if is_vmware() is True:
            netbackup_service_proc = subprocess.Popen(["service", "netbackup", "stop"], shell=False)
            status = netbackup_service_proc.wait()
    
            netbackup_chkconfig_proc = subprocess.Popen(["chkconfig", "netbackup", "off"], shell=False)
            status = netbackup_chkconfig_proc.wait()
            
        
        print "Done!"
        
    else:
        error("Failed to install Netbackup")





# Configure GRUB
def config_grub():
    print "Configuring GRUB..."
    
    grub_handle = open("/boot/grub/grub.conf", "r+")
    grub_data = grub_handle.read()
    
    grub_data = re.sub(" rhgb", "", grub_data)
    grub_data = re.sub(" quiet", "", grub_data)
    grub_data = re.sub(" crashkernel=auto", " crashkernel=128M", grub_data)
    
    grub_handle.seek(0)
    grub_handle.write(grub_data)
    grub_handle.close()
    
    print "Done!"
    
    
    
    
    
# Configure authentication
def config_authentication():
    print "Configuring authentication..."
    
    username = raw_input("LDAP bind username: ")
    password = raw_input("LDAP bind password: ")
    
    ldap_handle = open("/etc/pam_ldap.conf", "w")
    ldap_data = """u                    ri ldaps://pittad.univ.pitt.edu
base ou=Accounts,dc=univ,dc=pitt,dc=edu
pam_login_attribute sAMAccountName
tls_checkpeer yes
binddn cn=REMOVED,ou=Processes,ou=Enterprise Resources,dc=univ,dc=pitt,dc=edu
bindpw REMOVED
tls_cacertfile /etc/openldap/cacerts/ca-bundle.crt
pam_password md5
"""
    
    ldap_data = re.sub("binddn cn=REMOVED", "binddn cn=" + username, ldap_data)
    ldap_data = re.sub("bindpw REMOVED", "bindpw " + password, ldap_data)
    
    ldap_handle.seek(0)
    ldap_handle.write(ldap_data)
    ldap_handle.close()
    
    
    # Set the root password
    print "Setting the root password"
    passwd_proc = subprocess.Popen(["passwd"], stdout=subprocess.PIPE, shell=False)
    passwd_proc.wait()
    
    
    print "Done!"
    
    
    
    
    
# Configure startup daemons
def startup_daemons():
    print "Configuring startup daemons..."
    
    # Daemons to be enabled, all others will be disabled
    good_daemons = ["acpid", "auditd", "crond", "dsm_om_connsvc", "dsm_om_shrsvc", "dataeng", "kdump", "irqbalance", \
        "lvm2-monitor", "microcode-ctl", "multipathd", "network", "postfix", "ntpd", "rsyslog", "sshd", "cpuspeed", \
        "sysstat", "udev-post", "vmware-tools", "xinetd", "netbackup", "vxpbx_exchanged", "mcelogd", \
        "blk-availability", "rhnsd", "rngd"]
    
    
    chkconfig_proc = subprocess.Popen(["chkconfig", "--list", "--type=sysv"], stdout=subprocess.PIPE, shell=False)
    out = chkconfig_proc.communicate("\n")[0]
    out = out.rstrip()
    
    for line in out.split(os.linesep):
        line = line.rstrip()
        
        is_enabled = False
        
        if re.search(":on", line) is not None:
            is_enabled = True
            
        daemon = line.split()[0]
        
        if daemon in good_daemons and is_enabled is False:
            enable_choice = raw_input("Would you like to enable " + daemon + "? y or n: ")
            
            if enable_choice.lower() == "y":
                chkconfig_change_proc = subprocess.Popen(["chkconfig", daemon, "on"], shell=False)
                chkconfig_change_proc.wait()
                
        if daemon not in good_daemons and is_enabled is True:
            enable_choice = raw_input("Would you like to disable " + daemon + "? y or n: ")
            
            if enable_choice.lower() == "y":
                chkconfig_change_proc = subprocess.Popen(["chkconfig", daemon, "off"], shell=False)
                chkconfig_change_proc.wait()
        
    
    print "Done!"
        
        
        
        
        
# Subscribe to Redhat Satellite, install packages and updates
def satellite_and_packages():
    print "Subscribing to Red Hat Satellite and installing packages..."
    
    # Subscribe to Satellite
    remote_image_handle = urlopen("https://rhn.cssd.pitt.edu/pub/rhnbootstrap.sh")

    local_image_handle = open("/tmp/rhnbootstrap.sh", "w")
    local_image_handle.write(remote_image_handle.read())
    local_image_handle.close()
    
    os.chmod("/tmp/rhnbootstrap.sh", 755)
    
    rhnbootsrap_proc = subprocess.Popen(["/tmp/rhnbootstrap.sh"], shell=True)
    status = rhnbootsrap_proc.wait()
    
    if status != 0:
        error("Failed to subscribe to Red Hat Satellite")
        
        
    # Install Dell OMSA if we are on a Dell box
    if is_vmware() is False:
        omsa_choice = raw_input("Install Dell OMSA? y or n: ")
        
        if omsa_choice.lower() == "y":
            # Add Dell's GPG keys
            omsa_key1_proc = subprocess.Popen(["rpm", "--import", "https://rhn.cssd.pitt.edu/pub/RPM-GPG-KEY-dell"], shell=False)
            status = omsa_key1_proc.wait()
            
            omsa_key2_proc = subprocess.Popen(["rpm", "--import", "https://rhn.cssd.pitt.edu/pub/RPM-GPG-KEY-libsmbios"], shell=False)
            status = omsa_key2_proc.wait()
            
            omsa_install_proc = subprocess.Popen(["yum", "-y", "install", "srvadmin-all"], shell=False)
            status = omsa_install_proc.wait()
            
            
            omsa_pam_handle = open("/opt/dell/srvadmin/etc/omauth/omauth.el6", "w")
            omsa_pam_handle.write("#%PAM-1.0\nauth       sufficient   pam_ldap.so\n")
            omsa_pam_handle.close()
            
            
            disable_snmp_proc = subprocess.Popen(["/etc/init.d/dataeng", "disablesnmp"], shell=False)
            status = disable_snmp_proc.wait()
            
            
            omsa_start_proc = subprocess.Popen(["/opt/dell/srvadmin/sbin/srvadmin-services.sh", "start"], shell=False)
            status = omsa_start_proc.wait()
            
            
    # Install the EPEL keys since we might use the repo later
    epel_key1_proc = subprocess.Popen(["rpm", "--import", "https://rhn.cssd.pitt.edu/pub/RPM-GPG-KEY-EPEL"], shell=False)
    status = epel_key1_proc.wait()
    
    epel_key2_proc = subprocess.Popen(["rpm", "--import", "https://rhn.cssd.pitt.edu/pub/RPM-GPG-KEY-EPEL-6"], shell=False)
    status = epel_key2_proc.wait()
            
            
    # Update all packages
    yum_update_proc = subprocess.Popen(["yum", "-y", "update"], shell=False)
    status = yum_update_proc.wait()
    
    
    if status == 0:
        print "Success!"
        
    else:
        error("Failed to install OS updates")
            
            
        
    
# Install VMware Tools
def vmware_tools():
    print "Installing VMware Tools..."
        
    raw_input("Insert the VMware Tools ISO via vCenter then hit enter.")
    
    
    # Mount the ISO
    mount_proc = subprocess.Popen(["mount", "/dev/cdrom", "/mnt"], shell=False)
    status = mount_proc.wait()
    
    
    # Extract the files
    os.chdir("/tmp")
    vmware_tar = glob.glob("/mnt/VMwareTools*")[0]
    
    vmware_tar_proc = subprocess.Popen(["tar", "xzf", vmware_tar], shell=False)
    status = vmware_tar_proc.wait()
    
    
    # Install it
    os.chdir("/tmp/vmware-tools-distrib")
    vmware_install_proc = subprocess.Popen(["./vmware-install.pl", "--default"], shell=False)
    status = vmware_install_proc.wait()
    
    
    os.chdir("/root")
    shutil.rmtree("/tmp/vmware-tools-distrib")
    
    print "Done!"
    
    
    
    
    
# Configure kdump
def config_kdump():
    print "Configuring kdump..."
    
    print "Paste kdumper's private SSH key (/home/kdumper/.ssh/id_rsa on kdump.cssd.pitt.edu) then hit ^d."
    key_data = sys.stdin.read()
    os.mkdir("/home/kdumper/.ssh", 0700)
    key_file_handle = open("/home/kdumper/.ssh/id_rsa", "w")
    key_file_handle.write(key_data)
    key_file_handle.close()
    os.chown("/home/kdumper/.ssh", pwd.getpwnam("kdumper").pw_uid, grp.getgrnam("kdumper").gr_gid)
    os.chown("/home/kdumper/.ssh/id_rsa", pwd.getpwnam("kdumper").pw_uid, grp.getgrnam("kdumper").gr_gid)
    os.chmod("/home/kdumper/.ssh/id_rsa", 0600)
    
    kdump_prop_proc = subprocess.Popen(["service", "kdump", "propagate"], shell=False)
    status = kdump_prop_proc.wait()
    
    
    


# Run the main interface
def make_choice():
    choice = raw_input("""
0 : Do it all (Recommended)
1 : Configure network
2 : Install Netcool
3 : Install Netbackup
4 : Configure GRUB
5 : Configure authentication
6 : Configure startup daemons
7 : Subscribe to Red Hat Satellite, install packages and updates
8 : Install VMware Tools
9 : Configure kdump
q : Quit

What would you like to do? """)
                       
    if choice == "0": # Do it all for me (Recommended)
        config_network()
        netcool()
        netbackup()
        config_grub()
        config_authentication()
        startup_daemons()
        satellite_and_packages()
        vmware_tools()
        config_kdump()
        sys.exit(0)
        
    elif choice == "1": # Configure network
        config_network()
        
    elif choice == "2": # Install Netcool
        netcool()
        
    elif choice == "3": # Install Netbackup
        netbackup()
        
    elif choice == "4": # Configure GRUB
        config_grub()
        
    elif choice == "5": # Configure authentication
        config_authentication()
        
    elif choice == "6": # Configure startup daemons
        startup_daemons()
        
    elif choice == "7": # Subscribe to Red Hat Satellite, install packages and updates
        satellite_and_packages()
        
    elif choice == "8": # Install VMware Tools
        vmware_tools()
        
    elif choice == "9": # Configure kdump
        config_kdump()
        
    elif choice.lower() == "q": # Quit
        # By creating this file root's .bashrc won't run this program at login any more
        open("/root/.firstbootconfigdone", "w")
        sys.exit(0)
        




if __name__ == "__main__":
    try:
        while True:
            make_choice()
    
    except KeyboardInterrupt:
        sys.exit(0)
        