#!/usr/bin/env python
# Description: Check if IPs are on mail blacklists in DNS
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.1
# Last change: increased the scope of where the dns.resolver.NoAnswer exception is handled 

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, syslog, signal, smtplib, datetime, ConfigParser
import dns.resolver
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email import Encoders
from optparse import OptionParser



red = "\033[31m"
endcolor = '\033[0m' # end color



# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Check if IPs are on mail blacklists in DNS"
)

parser.add_option(
    "-c", "--config", dest="config_file",
    default="/usr/local/etc/email_blacklist_check.conf",
    help="Use FILE as the configuration file (default: /usr/local/etc/email_blacklist_check.conf)", metavar="FILE"
)

(options, args) = parser.parse_args()



# Prepare for timeouts
class Alarm(Exception):
    pass

def alarm_handler(signum, frame):
    raise Alarm

signal.signal(signal.SIGALRM, alarm_handler)




# Read the config file
config = ConfigParser.ConfigParser()
config.read(options.config_file)



# Loop through each IP
email_body = []
for _, ip in config.items("ip"):
    print "Checking IP " + ip
    
    # Reverse the IP
    ip_reversed = ".".join(ip.split(".")[::-1])
    
    
    # Loop through each RBL
    for _, rbl in config.items("rbl"):
        print "   Doing 'A' query for " + rbl
        
        # Query for the A record
        # Give up after 10 seconds
        signal.alarm(10)
        try:
            dns.resolver.query(ip_reversed + "." + rbl, "A")
                
            signal.alarm(0)
            
            # Get the TXT record for more information
            txt_record = []
            txt_record = dns.resolver.query(ip_reversed + "." + rbl, "TXT").response.answer
            
            if len(txt_record) == 0:
                email_body.append("Found blacklist of IP " + ip + " by RBL " + rbl + "\n")
                
            else:
                email_body.append("Found blacklist of IP " + ip + " by RBL " + rbl + "(" + txt_record[0].to_text() + ")\n")
            
        except Alarm:
            print "      Timed out - Skipping"
            
            continue
                
        except dns.resolver.NXDOMAIN:
            signal.alarm(0)
            
            print "      OK - Not blacklisted"
            
            continue

        except dns.resolver.NoAnswer:
            print "      No answer - Skipping"

            continue
            
            
        if len(txt_record) == 0:
            print red + "      BLACKLISTED" + endcolor
            
        else:
            print red + "      BLACKLISTED (" + txt_record[0].to_text() + ")" + endcolor
            
            
    email_body.append("\n")
    
    
    
#
# Send the results email
#
if len(email_body) != 0:
    # Message
    msg = MIMEMultipart()
    msg["From"] = "null@pitt.edu"
    msg["To"] = "jaw171@pitt.edu"
    msg["Subject"] = "Email blacklist check"
    msg.attach(MIMEText("".join(email_body)))

    # Send it
    smtp = smtplib.SMTP('localhost')
    smtp.sendmail("null@pitt.edu", ["jaw171@pitt.edu"], msg.as_string())
    smtp.quit()
