#!/usr/bin/env python
# Description: Create a capacity report of VMware clusters
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, re, syslog, time, json, locale
import atexit
import pyVim.connect
import pyVmomi
from optparse import OptionParser



target_vcenter = "pitt-dept-vc.cssd.example.edu"
target_clusters = ["Frank-Core", "Frank-App"]
username = "setme"
password = "setme"



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Create a capacity report of VMware clusters."
)

(options, args) = parser.parse_args()



locale.setlocale(locale.LC_ALL, 'en_US')



# Connect to vcenter
si = pyVim.connect.SmartConnect(host=target_vcenter, user=username, pwd=password, port=443)
atexit.register(pyVim.connect.Disconnect, si)
content = si.RetrieveContent()


# Get datacenter object, if there were more than 1 we would need to specify it
datacenter = content.rootFolder.childEntity[0]
vmfolder = datacenter.vmFolder


# Get the clusters in this datastore
hostfolder = datacenter.hostFolder
clusters = {}
for x in hostfolder.childEntity:
    if x.name:
        clusters[x.name] = x



for cluster in target_clusters:
    # Get the cluster usage statistics
    cluster_usage = {
        "memory_total" : 0,
        "memory_used" : 0,
        "memory_free" : 0,
        "memory_allocated" : 0,
        "cpu_cores_total" : 0,
        "cpu_cores_allocated" : 0,
    }
    for host in clusters[cluster].host:
        cluster_usage["cpu_cores_total"] += host.summary.host.hardware.cpuInfo.numCpuCores
        cluster_usage["memory_total"] += int(host.summary.host.hardware.memorySize / 1024 / 1024)
        cluster_usage["memory_used"] += host.summary.quickStats.overallMemoryUsage
        
    cluster_usage["memory_free"] = cluster_usage["memory_total"] - cluster_usage["memory_used"]
    
    
    # Get the datastore usage statistics
    datastore_usage = {}
    for datastore in clusters[cluster].datastore:
        # Skip local and heartbeat datastores
        if re.search("-local$", datastore.name) is not None or re.search("-HB[0-9]*$", datastore.name) is not None:
            continue
        
        datastore_usage[datastore.name] = {
            "capacity" : int(datastore.summary.capacity / 1024 / 1024 / 1024),
            "free_space" : int(datastore.summary.freeSpace / 1024 / 1024 / 1024)
        }
        
        datastore_usage[datastore.name]["used_space"] = datastore_usage[datastore.name]["capacity"] - datastore_usage[datastore.name]["free_space"]
        
        
    # Get the VM details
    vm_details = {}
    for vm in clusters[cluster].resourcePool.vm:
        ram = vm.summary.config.memorySizeMB
        cpu_cores = vm.summary.config.numCpu
        
        vm_details[vm.name.lower()] = {
            "ram" : ram,
            "cpu_cores" : cpu_cores,
        }
        
        cluster_usage["memory_allocated"] += ram
        cluster_usage["cpu_cores_allocated"] += cpu_cores
        
        
        
        
    # Print cluster and datacenter statistics
    print "Cluster statistics for " + cluster + ":"
    print "CPU Cores:"
    print "     Total: " + str(cluster_usage["cpu_cores_total"])
    print "     Allocated: " + str(cluster_usage["cpu_cores_allocated"])
    print "Memory:"
    print "     Total: " + locale.format("%d", cluster_usage["memory_total"] / 1024, grouping=True) + " GB"
    print "     Used: " + locale.format("%d", cluster_usage["memory_used"] / 1024, grouping=True) + " GB"
    print "     Free: " + locale.format("%d", cluster_usage["memory_free"] / 1024, grouping=True) + " GB"
    print "     Allocated: " + locale.format("%d", cluster_usage["memory_allocated"] / 1024, grouping=True) + " GB"
    print "Datastores:"
    for datastore in sorted(datastore_usage):
        print "     " + datastore + ":"
        print "          Capacity: " + locale.format("%d", datastore_usage[datastore]["capacity"], grouping=True) + " GB"
        print "          Used: " + locale.format("%d", datastore_usage[datastore]["used_space"], grouping=True) + " GB"
        print "          Free: " + locale.format("%d", datastore_usage[datastore]["free_space"], grouping=True) + " GB"
    print "Virtual Machines:"
    for vm in sorted(vm_details):
        print "     " + vm + ":"
        print "          CPU: " + locale.format("%d", vm_details[vm]["ram"], grouping=True) + " MB"
        print "          CPU Cores: " + str(vm_details[vm]["cpu_cores"])
    print ""
