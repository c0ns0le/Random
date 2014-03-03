#!/usr/bin/env python
# Description: Disable monthly password reminders on Mailman lists
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, subprocess
from optparse import OptionParser



def query_reminder(mlist):
    from Mailman import mm_cfg
    
    if mlist.send_reminders == 1:
        sys.stdout.write("List " + mlist.getListAddress() + " has password reminders enabled.  List owner(s): ")
        for owner in mlist.owner:
            sys.stdout.write(owner + " ")
        print ""



def set_reminder(mlist):
    import smtplib
    from email.MIMEMultipart import MIMEMultipart
    from email.MIMEBase import MIMEBase
    from email.MIMEText import MIMEText
    from email import Encoders
    from Mailman import mm_cfg
    
    if mlist.send_reminders == 1:
        sys.stdout.write("List " + mlist.getListAddress() + " has password reminders enabled.  List owner(s): ")
        for owner in mlist.owner:
            sys.stdout.write(owner + " ")
        print ""
        
        mlist.Lock()
        mlist.send_reminders = 0
        mlist.Save()
        mlist.Unlock()
        
        # Send the final CSV

        # Message
        msg = MIMEMultipart()
        msg["From"] = "null@pitt.edu"
        msg["To"] = mlist.owner[0]
        msg["Subject"] = "Mailman password reminder change notification"
        msg.attach(MIMEText("""You are receiving this messages because you are an owner
of the list """ + mlist.getListAddress() + """.

CSSD has recently made a minor change to the configuration of your 
Mailman List after a periodic review of all lists. The option to 
send monthly password reminder messages to list subscribers has 
been disabled. This change has been made consistent with CSSD 
policy to not support the transmission of messages that contain 
valid password strings for any university resource. Even though 
mailing list access passwords cannot be used to access to any 
other university resource, transmitting them via plain-text email 
represents a security risk that may encourage attacks on other 
University systems.

If you have any questions about this action, contact the Technology 
Help Desk at 412 624-HELP [4357]. You can also submit your question
online at http://technology.pitt.edu/helprequest.
                            """))
        smtp = smtplib.SMTP('localhost')
        smtp.sendmail("null@pitt.edu", mlist.owner, msg.as_string())
        smtp.quit()



if __name__ == "__main__":
    # How were we called?
    parser = OptionParser("%prog [options]\n" + 
        "Disable monthly password reminders on Mailman lists."
    )

    parser.add_option(
        "-c", "--change",
        action="store_true", dest="change", default=False,
        help="Instead of just showing which lists have the feature enabled, disable it on the list and notify the list owner(s)"
    )

    (options, args) = parser.parse_args()



    if options.change is False:
        print "NOTICE: Running in query-only mode."
        
        proc = subprocess.Popen(["/usr/local/mailman/bin/withlist", "--all", "--quiet", "--run", "disable_password_reminders.query_reminder"], stdin=None, shell=False)
        proc.wait()
        
    else:
        print "NOTICE: Running in change and notify mode"
        
        proc = subprocess.Popen(["/usr/local/mailman/bin/withlist", "--all", "--quiet", "--run", "disable_password_reminders.set_reminder"], stdin=None, shell=False)
        proc.wait()
