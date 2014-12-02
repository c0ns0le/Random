#!/usr/bin/env python
# Description: Sync LDAP groups from Active Directory to an OpenLDAP server
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.1
# Last change: Fixed a crash caused by empty groups

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys
import os
import traceback
import ldap
import ConfigParser
import re
import smtplib
import ldap.modlist as modlist
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email import Encoders
from optparse import OptionParser





config_file = "/usr/local/etc/sam_sync_ldap_groups.conf"





# How were we called?
parser = OptionParser("%prog [options]\n" + 
    "Sync LDAP groups from Active Directory to an OpenLDAP server"
)

parser.add_option(
    "-d", "--dryrun",
    action="store_true", dest="dryrun", default=False,
    help="Show what changes would be made but make no changes."
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
        
        
        
        
        
# Get our config
config = ConfigParser.ConfigParser()
config.read(config_file)

auth_config = dict(config.items("auth"))
        
        
ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
        

# Connect to the LDAP servers
try:
    ad_ldap_obj = ldap.initialize(auth_config["ad_server_uri"])
    ad_ldap_obj.simple_bind_s(auth_config["ad_bind_dn"], auth_config["ad_bind_pasword"])
    
except:
    error("Failed to connect or bind to Active Directory server " + auth_config["ad_server_uri"])

try:
    sam_ldap_obj = ldap.initialize(auth_config["sam_ldap_uri"])
    sam_ldap_obj.simple_bind_s(auth_config["sam_ldap_bind_dn"], auth_config["sam_ldap_bind_password"])

except:
    error("Failed to connect or bind to SaM LDAP server " + auth_config["sam_ldap_uri"])
    


notification_email_body = ""
for _, group in config.items("groups"):
    # Get the group from Active Directory
    print "Searching Active Directory for group: " + group
    ad_result = ad_ldap_obj.search_s("OU=Groups,DC=univ,DC=pitt,DC=edu", ldap.SCOPE_SUBTREE, "(cn=" + group + ")", ["member"])
    
    if len(ad_result) == 0:
        print "No such group in Active Directory\n"
        continue
    
    ad_group_dn = ad_result[0][0]
        
    ad_group_members = []
        
    for member_dn in ad_result[0][1]["member"]:
        member = re.sub("cn=", "", ldap.dn.explode_dn(member_dn)[0].lower())
        ad_group_members.append(member)
        
    print "Active Directory group members: " + str(ad_group_members)
    
    
    
    # Get the group from SaM LDAP
    print "Searching SaM LDAP for group: " + group
    sam_ldap_result = sam_ldap_obj.search_s("ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu", ldap.SCOPE_SUBTREE, "(cn=" + group + ")", ["memberUid"])
    
    if len(sam_ldap_result) == 0:
        print "No such group in SaM LDAP\n"
        continue
    
    sam_group_dn = sam_ldap_result[0][0]
        
    sam_ldap_group_members = []
    
    try:
        for member in sam_ldap_result[0][1]["memberUid"]:
            sam_ldap_group_members.append(member)
            
    except KeyError:
        # For empty groups
        pass
        
    print "SaM LDAP group members: " + str(sam_ldap_group_members)
    
    
    
    # Get data on how the groups differ
    missing_members = []
    for member in ad_group_members:
        if member not in sam_ldap_group_members:
            missing_members.append(member)
            
    print "Members missing from the SaM LDAP group: " + str(missing_members)
    
    extra_members = []
    for member in sam_ldap_group_members:
        if member not in ad_group_members:
            extra_members.append(member)
            
    print "Extra members in the SaM LDAP group: " + str(extra_members)
    
    
    
    
    # Now sync the groups if needed
    if options.dryrun is True:
        print "Dry-run mode detected, making no changes."
        
    elif len(missing_members) == 0 and len(extra_members) == 0:
        print "Groups match, no sync needed."
        
    else:
        print "Syncing group " + group
        
        try:
            ldif = modlist.modifyModlist({"memberUid" : sam_ldap_group_members}, {"memberUid" : ad_group_members})
            sam_ldap_obj.modify_s(sam_group_dn, ldif)
            
        except:
            error("Failed to modify SaM LDAP")
            
            
            
    # Check for users who don't exist on Frank
    print "Checking for users missing in SaM LDAP."
    missing_users = []
    
    for member in ad_group_members:
        sam_ldap_user_result = sam_ldap_obj.search_s("ou=people,dc=frank,dc=sam,dc=pitt,dc=edu", ldap.SCOPE_SUBTREE, "(cn=" + member + ")", ["uid"])
    
        if len(sam_ldap_user_result) == 0:
            missing_users.append(member)
        
        
    if len(missing_users) == 0:
        print "No missing users detected."
        
    else:
        notification_emails = []
        notification_emails_string = ""
        
        for _, email in config.items("notifications"):
            notification_emails.append(email)
            
            # This builds a "pretty" string of multiple notification emails for the header "To" field in the email
            if notification_emails_string == "":
                notification_emails_string += email
                
            else:
                notification_emails_string += ", "
                notification_emails_string += email
            
        print "Found " + str(len(missing_users)) + " missing users " + str(missing_users) + " that need added to SaM LDAP, sending notifications to " + str(notification_emails) + "."
        
        notification_email_body += "Missing user(s) from group " + group + ":" + str(missing_users) + "\n"
        
        
    print ""
    
    
    
# Send the notification email if needed
if notification_email_body != "":
    msg = MIMEMultipart()
    msg["From"] = "null@pitt.edu"
    msg["To"] = notification_emails_string
    msg["Subject"] = "Missing user(s) in SaM LDAP"
    msg.attach(MIMEText(notification_email_body))

    smtp = smtplib.SMTP("localhost")
    smtp.sendmail("null@pitt.edu", notification_emails, msg.as_string())
    smtp.quit()



ad_ldap_obj.unbind_s()
sam_ldap_obj.unbind_s()
