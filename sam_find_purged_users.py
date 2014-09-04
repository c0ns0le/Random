#!/usr/bin/env python
# Description: Create a report of users who exist in the SaM LDAP server but the university account is purged
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.



import sys, os, re, syslog, signal, traceback, ldap, ConfigParser, smtplib
from email.MIMEMultipart import MIMEMultipart
from email.MIMEBase import MIMEBase
from email.MIMEText import MIMEText
from email import Encoders
from optparse import OptionParser





config_file = "/usr/local/etc/sam_find_purged_users.conf"





# How were we called?
parser = OptionParser("%prog [options]\n" +
    "Create a report of users who exist in the SaM LDAP server but the university account is purged"
)

(options, args) = parser.parse_args()





# Print a stack trace, exception, and an error string to STDERR
# and exit with the exit status given or don't exit
# if passed NoneType
def error(error_string, exit_status=1):
    red = "\033[31m"
    endcolor = "\033[0m"

    exc_type, exc_value, exc_traceback = sys.exc_info()
    if exc_type is not None:
        traceback.print_exception(exc_type, exc_value, exc_traceback)

    sys.stderr.write(red + str(error_string) + endcolor)

    if exit_status is not None:
        sys.exit(int(exit_status))





# Get our config
config = ConfigParser.ConfigParser()
config.read(config_file)

auth_config = dict(config.items("auth"))





print "Getting list of users from SaM LDAP"
sam_ldap_users = {}

try:
    sam_ldap_obj = ldap.initialize("ldap://sam-ldap-prod-01.cssd.pitt.edu")

except:
    error("Failed to connect or bind to SaM LDAP server sam-ldap-prod-01.cssd.pitt.edu, exiting.\n")


# Get the user information
user_results = sam_ldap_obj.search_s("ou=person,ou=people,dc=frank,dc=sam,dc=pitt,dc=edu", ldap.SCOPE_SUBTREE, "(objectClass=posixAccount)", None)

for result in user_results:
    username = result[1]["uid"][0]
    home_directory = result[1]["homeDirectory"][0]
    gid_number = result[1]["gidNumber"][0]
    #print username
    #print home_directory
    #print gid_number


    # Get what primary group the user belongs to
    group_results = sam_ldap_obj.search_s("ou=groups,dc=frank,dc=sam,dc=pitt,dc=edu", ldap.SCOPE_SUBTREE, "(gidNumber=" + gid_number + ")", None)

    groupname = group_results[0][1]["cn"][0]
    #print groupname
    #print


    sam_ldap_users[username] = {}
    sam_ldap_users[username]["home_directory"] = home_directory
    sam_ldap_users[username]["groupname"] = groupname





print "Looking for user accounts in Active Directory"
try:
    ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
    ad_ldap_obj = ldap.initialize("ldaps://pittad.univ.pitt.edu")
    ad_ldap_obj.simple_bind_s(auth_config["ad_bind_dn"], auth_config["ad_bind_pasword"])

except:
    error("Failed to connect or bind to Active Directory, exiting.\n")


notification_email_body = ""
for username in sam_ldap_users:
    ad_results = ad_ldap_obj.search_s("OU=Accounts,DC=univ,DC=pitt,DC=edu", ldap.SCOPE_SUBTREE, "(sAMAccountName=" + username + ")", None)

    if len(ad_results) == 0:
        print "Found missing user " + username + " with primary group of " + sam_ldap_users[username]["groupname"] + " and home directory of " + sam_ldap_users[username]["home_directory"] + "."
        notification_email_body += "Found missing user " + username + " with primary group of " + sam_ldap_users[username]["groupname"] + " and home directory of " + sam_ldap_users[username]["home_directory"] + ".\n"


ad_ldap_obj.unbind_s()





# Send the notification email
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



msg = MIMEMultipart()
msg["From"] = "null@pitt.edu"
msg["To"] = notification_emails_string
msg["Subject"] = "Purged users still in SaM LDAP summary"
if notification_email_body == "":
    msg.attach(MIMEText("No purged users found."))
else:
    msg.attach(MIMEText(notification_email_body))

smtp = smtplib.SMTP("localhost")
smtp.sendmail("null@pitt.edu", notification_emails, msg.as_string())
smtp.quit()
