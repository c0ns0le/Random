#!/bin/bash
#Name: ssh_auto_login_loop.sh
#Description: Bash script to perform command(s) via SSH with automatic logins via expect.
#Written by: Jeff White (jaw171@pitt.edu) of the University of Pittsburgh

##### License
# This script is released under version three (3) of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by U.S. law.
#####

##### Revision history
#
# 0.1 - 2011-12-09 - Initial version. - Jeff White
#
#####

script=${0##*/} #The name of the script.
expect_script="/tmp/ssh-expect.sh"
servers_file=${1:?"A file with hostnames or IPs to SSH to needs to be an argument."}

#Create the expect script and make it executable...I did not write the expect script, I found it.
cat << EOF_expect-script > $expect_script
#!/usr/bin/expect -f
set timeout 30
set log_user 0

#example of getting arguments passed from command line..
#not necessarily the best practice for passwords though...
set server [lindex \$argv 0]
set user [lindex \$argv 1]
set pass [lindex \$argv 2]
set command [lindex \$argv 3]

# connect to server via ssh and login
spawn ssh -o NumberOfPasswordPrompts=1 -q \$user@\$server

#login handles cases:
#   login with keys (no user/pass)
#   user/pass
#   login with keys (first time verification)
expect {
  "> " { }
  "$ " { }
  "assword: " { 
        send "\$pass\n" 
        expect {
          "> " { }
          "$ " { }
        }
  }
  "(yes/no)? " { 
        send "yes\n"
        expect {
          "> " { }
          "$ " { }
        }
  }
  default {
        send_user "Login failed\n"
        exit
  }
}

#example command
send "\$command\n"

expect {
    "$ " {}
    default {}
}

#login out
send "exit\n"

expect {
    "$ " {}
    default {}
}

send_user "finished\n"
EOF_expect-script
chmod +x $expect_script

read -p "User: " ssh_user
echo "Password:"
stty -echo
read ssh_pass
stty echo
read -p "Remote command: " remote_command

if [ -z "$ssh_user" -o -z "$ssh_pass" -o -z "$remote_command" ];then
  echo "ERROR: User, password, or remote command was null."
fi

cat $servers_file | while read -r each_box;do
  echo "$each_box:"
  $expect_script $each_box "$ssh_user" "$ssh_pass" "$remote_command && \"echo $each_box: yes\" || echo \"$each_box: no\""
done

rm -f $expect_script