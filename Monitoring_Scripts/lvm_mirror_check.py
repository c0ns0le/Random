#!/usr/bin/env python



import sys
import os
import re
import traceback
import pickle
import subprocess
import syslog
from optparse import OptionParser



config_pickle = "/usr/local/etc/lvm_mirror_check.pck"



# How were we called?
parser = OptionParser("%prog [options]\n" +
    "Check the status of mirrored LVM logical volumes.\n\n" +
    "The first time this program runs it determines which LVs are mirrored \n" +
    "and on which devices.  Subsequent runs check those LVs to ensure they \n" +
    "are still mirrored (as they can turn into regular LVs when half of the mirror \n" +
    "is gone).  If a new mirrored LV is created, remove the program's pickle data file \n" +
    "at " + config_pickle + " and run the program again to re-learn the LVs."
)

(options, args) = parser.parse_args()



# Prepare syslog
syslog.openlog(os.path.basename(sys.argv[0]), syslog.LOG_NOWAIT, syslog.LOG_DAEMON)



def get_logical_volumes():
    current_logical_volumes = dict()

    # Example:
    #current_logical_volumes = {
        #"lv_root" : {
            #"name" : "lv_root",
            #"devices" : list(),
            #"is_mirrored" : True,
            #"volume_group" : "vg_system",
        #},
    #}

    lvs_proc = subprocess.Popen(["lvs", "-a", "--noheadings", "--separator", ",", "-o", "+devices"], stdin=None, stdout=subprocess.PIPE, shell=False)

    lvs_output = lvs_proc.communicate()[0]

    for line in lvs_output.split(os.linesep):
        line = line.rstrip()

        if line == "":
            continue

        logical_volume = line.split(",")[0]
        logical_volume = re.sub("^\s+", "", logical_volume)

        # Skip lines that are the pieces of mirrors
        if logical_volume.startswith("["):
            continue

        volume_group = line.split(",")[1]

        attributes_string = line.split(",")[2]
        attributes = {
            "volume_type" : attributes_string[0],
            "permissions" : attributes_string[1],
            "allocation_policy" : attributes_string[2],
            "fixed_minor" : attributes_string[3],
            "state" : attributes_string[4],
            "device" : attributes_string[5],
            "target_type" : attributes_string[6],
            "zero_first" : attributes_string[7],
            "volume_health" : attributes_string[8],
            #"skip_activation" : attributes_string[9],
        }

        if attributes["volume_type"] == "m" or attributes["volume_type"] == "M":
            current_logical_volumes[logical_volume] = {
                "name" : logical_volume,
                "devices" : list(),
                "volume_group" : volume_group,
                "is_mirrored" : True,
            }

            # Find the devices which make up the mirror
            for line in lvs_output.split(os.linesep):
                line = line.rstrip()

                if re.search("\[" + logical_volume + "_mimage_[0-9]\]", line) is not None:
                    device = line.split(",")[-1]
                    device = re.sub("\([0-9]+\)", "", device)

                    current_logical_volumes[logical_volume]["devices"].append(device)

            print "Found current mirrored LV " + logical_volume + " in volume group " + volume_group + " on devices " + str(current_logical_volumes[logical_volume]["devices"])

        else:
            device = line.split(",")[-1]
            device = re.sub("\([0-9]+\)", "", device)

            if logical_volume in current_logical_volumes:
                current_logical_volumes[logical_volume]["devices"].append(device)

            else:
                current_logical_volumes[logical_volume] = {
                    "name" : logical_volume,
                    "devices" : [device],
                    "volume_group" : volume_group,
                    "is_mirrored" : False,
                }


    return current_logical_volumes





if __name__ == "__main__":
    if os.path.exists(config_pickle) is False:
        print "No existing pickle data file found, searching for LVs and creating pickle file ..."

        current_logical_volumes = get_logical_volumes()

        pickle_handle = open(config_pickle, "w")
        pickle.dump(current_logical_volumes, pickle_handle)
        pickle_handle.close()

        print "Done!"

    else:
        print "Found pickle file, reading ..."

        pickle_handle = open(config_pickle, "r")
        previous_logical_volumes = pickle.load(pickle_handle)
        pickle_handle.close()

        print "Searching for current LVs ..."

        current_logical_volumes = get_logical_volumes()

        print "Comparing previous and current LVs ..."

        for logical_volume in previous_logical_volumes:
            if logical_volume not in current_logical_volumes:
                print "ERROR: Logical volume " + logical_volume + " disappeared!"

                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Logical volume " + logical_volume + " disappeared!")

                continue

        for logical_volume in current_logical_volumes:
            if logical_volume not in previous_logical_volumes:
                print "WARNING: Logical volume " + logical_volume + " is new, see --help and remove pickle file."

                syslog.syslog(syslog.LOG_WARNING, "NOC-NETCOOL-TICKET: Logical volume " + logical_volume + " is new, see --help and remove pickle file.")

                continue

            if previous_logical_volumes[logical_volume]["is_mirrored"] is True and current_logical_volumes[logical_volume]["is_mirrored"] is False:
                missing_devices = [x for x in current_logical_volumes[logical_volume]["devices"] if x not in previous_logical_volumes[logical_volume]["devices"]]

                print "ERROR: Logical volume " + logical_volume + " in volume group " + current_logical_volumes[logical_volume]["volume_group"] + " was previously mirrored but no longer is!  Missing devices: " + str(missing_devices)

                syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Logical volume " + logical_volume + " in volume group " + current_logical_volumes[logical_volume]["volume_group"] + " was previously mirrored but no longer is!  Missing devices: " + str(missing_devices))

            for device in current_logical_volumes[logical_volume]["devices"]:
                if not device.startswith("/dev/"):
                    print "ERROR: Logical volume " + logical_volume + " in volume group " + current_logical_volumes[logical_volume]["volume_group"] + " has invalid mirror device '" + device + "'"

                    syslog.syslog(syslog.LOG_ERR, "NOC-NETCOOL-TICKET: Logical volume " + logical_volume + " in volume group " + current_logical_volumes[logical_volume]["volume_group"] + " has invalid mirror device '" + device + "'")

        print "Done!"
