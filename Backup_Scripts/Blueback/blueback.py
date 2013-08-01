#!/usr/bin/env python
# Description: Backup OS and other data
# Written by: Jeff White (jwhite530@gmail.com)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import os, re, sys, subprocess, ConfigParser, datetime, signal, time, syslog
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email import Encoders
from optparse import OptionParser



bold = "\033[1m"
red = "\033[31m"
end_esc_seq = '\033[0m'



# How were we called?
parser = OptionParser("%prog [options] policy0.conf policy1.conf ...\n\n" + \
    "Backup OS and other options.max_deletedata via policies."
)


parser.add_option("-v", "--verbose",
    action="count", dest="verbose", default=False,
    help="Verbose mode, specify multiple times to increase verbosity"
)


parser.add_option("-d", "--delete",
    action="store_true", dest="delete", default=False,
    help="Enable rsync's --delete (even if the policy file says not to)"
)


parser.add_option("-p", "--progress",
    action="store_true", dest="progress", default=False,
    help="Enable rsync's --progress (even if the policy file says not to)"
)


parser.add_option("-f", "--force",
    action="store_true", dest="force", default=False,
    help="Run the policy even if it is disabled"
)


parser.add_option("-m", "--max-delete", dest="max_delete",
    help="Set the maximum number of files to delete with --delete to NUM (overriding the policy)", metavar="NUM"
)

(options, args) = parser.parse_args()





# Return a "pretty" timestamp: 2013-07-04 13:58:47
def timestamp():
    return datetime.datetime.today().strftime("%Y-%m-%d %H:%M:%S")
    
    
    
    
    
# Handle SIGINT nicely
def signal_handler(signal, frame):
    sys.stderr.write(red + "\nKilled with signal: " + str(signal) + "\n" + end_esc_seq)
    
    if log_handle is not None:
        log_handle.write(timestamp() + " - ERROR - Killed with signal: " + str(signal) + "\n")
            
        log_handle.write(timestamp() + " - ##### - Ending run.\n\n")
    
    sys.exit(1)
    
    
signal.signal(signal.SIGINT, signal_handler)





# Loop through each policy file given
for policy_file in sys.argv[1:]:
    if not os.path.isfile(policy_file):
        continue
    
    sys.stdout.write(bold + "Using policy file: " + policy_file + "\n" + end_esc_seq)
    
    run_start_time = time.time()

        
    #
    # Read in the configuration
    #

    config = ConfigParser.ConfigParser()
    config.read(policy_file)

    if options.verbose >= 1:
        sys.stdout.write("Reading policy file...\n")
        
    main_config = dict(config.items("main"))
    
    
    
    
    
    #
    # Should we log anything?
    #
    
    log_handle = None
    
    try:
        if main_config["log_file"] != "":
            # Create the directories if needed
            if os.sep in main_config["log_file"]:
                path = ""
                
                for each_dir in main_config["log_file"].split(os.sep)[:-1]:
                    path = path + os.sep + each_dir
                    
                    if not os.path.exists(path):
                        os.mkdir(path)
                        
            log_handle = open(main_config["log_file"], "a+")
            
    except KeyError:
        pass
        
    
    
    
    
    #
    # Is the policy enabled or forced?
    #
    
    try:
        if config.getboolean("main", "enabled") is False and options.force is False:
            sys.stdout.write("Skipping policy " + policy_file + " (disabled).\n")
            
            continue
            
    except:
        pass
    
    
    
    
    if log_handle is not None:
        log_handle.write("\n" + timestamp() + " - ##### - Starting run.\n")
    
        log_handle.write(timestamp() + " - INFO - Using policy file " + policy_file + "\n")





    #
    # Sanity checking
    #

    if options.verbose >= 1:
        sys.stdout.write("Checking sanity...\n")
        
        if log_handle is not None:
            log_handle.write(timestamp() + " - VERBOSE - Checking sanity...\n")
            

    # Ensure the config is not saying remote --> remote
    try:
        if main_config["source_host"] != "" and main_config["destination_host"] != "":
            sys.stderr.write(red + "Remote--> remote transfers not supported.  main: source_host and main: destination_host cannot both be set.\n" + end_esc_seq)
            
            if log_handle is not None:
                log_handle.write(timestamp() + " - ERROR - Remote--> remote transfers not supported.  main: source_host and main: destination_host cannot both be set.\n")
                
                log_handle.write(timestamp() + " - ##### - Ending run.\n\n")
            
            continue
            
    except KeyError:
        pass
        
        
    # Ensure source and destination directories are present in the config
    try:
        if main_config["source_dir"] == "" or main_config["destination_dir"] == "":
            sys.stderr.write(red + "Either main: source_dir or main: destination_dir or both is not set.\n" + end_esc_seq)
            
            if log_handle is not None:
                log_handle.write(timestamp() + " - ERROR - Either main: source_dir or main: destination_dir or both is not set.\n")
                
                log_handle.write(timestamp() + " - ##### - Ending run.\n\n")
            
            continue
            
    except KeyError:
        sys.stderr.write(red + "Either main: source_dir or main: destination_dir or both is not set.\n" + end_esc_seq)
        
        if log_handle is not None:
            log_handle.write(timestamp() + " - ERROR - Either main: source_dir or main: destination_dir or both is not set.\n")
            
            log_handle.write(timestamp() + " - ##### - Ending run.\n\n")
        
        continue





    #
    # Parse the rsync config and begin to build the rsync command line we will use
    #

    if options.verbose >= 1:
        sys.stdout.write("Parsing rsync configuration...\n")
        
        if log_handle is not None:
            log_handle.write(timestamp() + " - VERBOSE - Parsing rsync configuration.\n")
            

    rsync_command_line = list()

    # If no rsync binary is given, well just trust $PATH
    try:
        rsync_binary = config.get("rsync_options", "rsync_binary")

        if rsync_binary != "":
            rsync_command_line.append(rsync_binary)
            
        else:
            rsync_command_line.append("rsync")
            
    except ConfigParser.NoOptionError:
        rsync_command_line.append("rsync")
        
        
        
    # stats
    if options.verbose >= 1:
        rsync_command_line.append("--stats")

        

    # verbose
    if options.verbose >= 2:
        rsync_command_line.append("-v")
        
        
        
    # max_delete
    try:
        if options.max_delete is None:
            max_delete = config.get("rsync_options", "max_delete")
            
        else:
            max_delete = options.max_delete

        if max_delete != "":
            rsync_command_line.append("--max-delete=" + max_delete)
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # archive
    try:
        if config.getboolean("rsync_options", "archive") is True:
            rsync_command_line.append("--archive")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # inplace
    try:
        if config.getboolean("rsync_options", "inplace") is True:
            rsync_command_line.append("--inplace")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # delete
    try:
        if options.delete is True or config.getboolean("rsync_options", "delete") is True:
            rsync_command_line.append("--delete")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # hard_links
    try:
        if config.getboolean("rsync_options", "hard_links") is True:
            rsync_command_line.append("--hard-links")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # compress
    try:
        if config.getboolean("rsync_options", "compress") is True:
            rsync_command_line.append("--compress")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # devices
    try:
        if config.getboolean("rsync_options", "devices") is True:
            rsync_command_line.append("--devices")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # specials
    try:
        if config.getboolean("rsync_options", "specials") is True:
            rsync_command_line.append("--specials")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # one_file_system
    try:
        if config.getboolean("rsync_options", "one_file_system") is True:
            rsync_command_line.append("--one-file-system")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # xattrs
    try:
        if config.getboolean("rsync_options", "xattrs") is True:
            rsync_command_line.append("--xattrs")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # acls
    try:
        if config.getboolean("rsync_options", "acls") is True:
            rsync_command_line.append("--acls")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # human_readable
    try:
        if config.getboolean("rsync_options", "human_readable") is True:
            rsync_command_line.append("--human-readable")
            
    except ConfigParser.NoOptionError:
        pass

        
        
    # progress
    try:
        if options.progress is True or config.getboolean("rsync_options", "progress") is True:
            rsync_command_line.append("--progress")
            
    except ConfigParser.NoOptionError:
        pass

        
        
        
        
    #
    # Create the exclude list
    #

    if options.verbose >= 1:
        sys.stdout.write("Creating exclude list...\n")
        
        if log_handle is not None:
            log_handle.write(timestamp() + " - VERBOSE - Creating exclude list.\n")

    try:
        for key, val in config.items("excludes"):
            rsync_command_line.append("--exclude=" + val + "")
            
    except ConfigParser.NoSectionError:
        pass
        
        
        
        
        
    #
    # Configure SSH if needed
    #

    # Determine if we are even going to SSH
    do_ssh = False

    try:
        if main_config["source_host"] != "":
            do_ssh = True
            
    except KeyError:
        pass

    try:
        if main_config["destination_host"] != "":
            do_ssh = True
            
    except KeyError:
        pass
            

    # Set the SSH options
    if do_ssh is True:
        if options.verbose >= 1:
            sys.stdout.write("Setting SSH configuration...\n")
            
            if log_handle is not None:
                log_handle.write(timestamp() + " - VERBOSE - Setting SSH configuration.\n")
        
        ssh_opts = list()
        
        # SSH user
        try:
            if main_config["ssh_user"] != "":
                ssh_opts.append("-l " + main_config["ssh_user"])
                
        except KeyError:
            pass
        
        
        # SSH key
        try:
            if main_config["ssh_key"] != "":
                ssh_opts.append("-o PreferredAuthentications=publickey -i " + main_config["ssh_key"])
                
        except KeyError:
            pass
        
        
        # SSH port
        try:
            if main_config["ssh_port"] != "":
                ssh_opts.append("-p " + main_config["ssh_port"])
                
        except KeyError:
            pass
        
        
        # Disable host key checking
        ssh_opts.append("-o StrictHostKeyChecking=no")
        
        
        # SSH binary and put the SSH options together
        try:
            if main_config["ssh_binary"] != "":
                rsync_command_line.append("--rsh=" + main_config["ssh_binary"] + " " + " ".join(ssh_opts) + "")
                
            else:
                rsync_command_line.append("--rsh=ssh " + " ".join(ssh_opts) + "")
            
        except KeyError:
            rsync_command_line.append("--rsh=ssh " + " ".join(ssh_opts) + "")
            
    else:
        if options.verbose >= 1:
            sys.stdout.write("Skipping SSH configuration...\n")
            
            if log_handle is not None:
                log_handle.write(timestamp() + " - VERBOSE - Skipping SSH configuration.\n")
            
            
        


    #
    # rsync path with sudo (so SSH can connect as blueback but run rsync as root)
    #

    try:
        if config.getboolean("main", "use_sudo") is True:
            if options.verbose >= 1:
                sys.stdout.write("Setting sudo configuration...\n")
                
                if log_handle is not None:
                    log_handle.write(timestamp() + " - VERBOSE - Setting sudo configuration.\n")
            
            rsync_path_with_sudo = list()

            try:
                if main_config["sudo_binary"] == "":
                    rsync_path_with_sudo.append("sudo")
                    
                else:
                    rsync_path_with_sudo.append(main_config["sudo_binary"])
                    
            except KeyError:
                rsync_path_with_sudo.append("sudo")

            try:
                if main_config["rsync_binary"] == "":
                    rsync_path_with_sudo.append("rsync")
                    
                else:
                    rsync_path_with_sudo.append(main_config["rsync_binary"])
                    
            except KeyError:
                rsync_path_with_sudo.append("rsync")
            
            rsync_command_line.append("--rsync-path=" + " ".join(rsync_path_with_sudo) + "")
            
        else:
            if options.verbose >= 1:
                sys.stdout.write("Skipping sudo configuration...\n")
                
                if log_handle is not None:
                    log_handle.write(timestamp() + " - VERBOSE - Skipping sudo configuration.\n")
            
    except ConfigParser.NoOptionError:
        pass
        
        
        
        
        
    #
    # Add the source and desintation
    #

    if options.verbose >= 1:
        sys.stdout.write("Adding source and destination to the rsync command line...\n")
        
        if log_handle is not None:
            log_handle.write(timestamp() + " - VERBOSE - Adding source and destination to the rsync command line.\n")

    try:
        if main_config["source_host"] == "":
            rsync_command_line.append(main_config["source_dir"])
            
        else:
            rsync_command_line.append(main_config["source_host"] + ":" + main_config["source_dir"])
        
    except KeyError:
        rsync_command_line.append(main_config["source_dir"])

        
    try:
        if main_config["destination_host"] == "":
            rsync_command_line.append(main_config["destination_dir"])
            
        else:
            rsync_command_line.append(main_config["destination_host"] + ":" + main_config["destination_dir"])
        
    except KeyError:
        rsync_command_line.append(main_config["destination_dir"])
        
        
        
    #
    # Create the destination directories is needed
    #

    try:
        if main_config["destination_host"] == "":
            path = ""
            
            for each_dir in main_config["destination_dir"].split(os.sep):
                path = path + os.sep + each_dir
                
                if not os.path.exists(path):
                    os.mkdir(path)
            
    except KeyError:
        pass
        



    #
    # Do the rsync
    #

    sys.stdout.write("\nrsync command line to be used: " + " ".join(rsync_command_line) + "\n\n")
    
    if log_handle is not None:
        log_handle.write(timestamp() + " - INFO - rsync command line to be used: " + " ".join(rsync_command_line) + "\n")

    try:
        sys.stdout.write("Starting transfer: " + rsync_command_line[-2] + " --> " + rsync_command_line[-1] + "\n")
        
        if log_handle is not None:
            log_handle.write(timestamp() + " - INFO - Starting transfer: " + rsync_command_line[-2] + " --> " + rsync_command_line[-1] + "\n")
        
        rsync_process = subprocess.Popen(rsync_command_line, shell=False)
        
        status = rsync_process.wait()
            
        if status == 0:
            sys.stdout.write("Success!\n")
            
            if log_handle is not None:
                log_handle.write(timestamp() + " - INFO - Success!\n")
            
        else:
            raise Exception("Non-zero exit status: " + str(status) + "\n")
        
    except Exception as err:
        sys.stderr.write(red + "Call to rsync failed: " + str(err) + "\n" + end_esc_seq)
        
        if log_handle is not None:
            log_handle.write(timestamp() + " - ERROR - Call to rsync failed: " + str(err) + "\n")
            
            log_handle.write(timestamp() + " - ##### - Ending run.\n\n")
        
        continue
        
        
        
    
    
    #
    # Display the final stats
    #
    
    sys.stdout.write(bold + "\nTransfer complete, duration: " + time.strftime('%H:%M:%S', time.gmtime(time.time() - run_start_time)) + " (HH:MM:SS)\n\n" + end_esc_seq)
    
    if log_handle is not None:
        log_handle.write(timestamp() + " - INFO - Transfer complete, duration: " + time.strftime('%H:%M:%S', time.gmtime(time.time() - run_start_time)) + " (HH:MM:SS)\n")
        
        log_handle.write(timestamp() + " - ##### - Ending run.\n\n")
    
    
    
    
    
    





##
## Send the notification email
##

## Message
#msg = MIMEMultipart()
#msg["From"] = "blueback@jealwh.me"
#msg["To"] = "jwhite530@gmail.com"
#msg["Subject"] = "Blueback job report"
#msg.attach(MIMEText("Attached...\n"))


## Send it
#smtp = smtplib.SMTP('localhost')
#smtp.sendmail("blueback@jealwh.me", ["jwhite530@gmail.com"], msg.as_string())
#smtp.quit()
