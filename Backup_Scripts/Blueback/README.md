Blueback
======

Blueback is a policy-based backup application which utilizes the rsync binary.  Each policy file 
specifies a source, destination, logging, exclude list and various rsync options.


License
-------

Except where otherwise noted, this software is released under version three of the GNU General Public License (GPL) of the
Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
Use or modification of this software implies your acceptance of this license and its terms.
This is free software, you are free to change and redistribute it with the terms of the GNU GPL.
There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


Client SSH and sudo preparation
-------------

* Create the blueback user: useradd -m -s /bin/bash blueback
* Create an SSH key: ssh-keygen -t rsa
* Save the private key to the backup host
* Add the public key to authorized_hosts on the client(s)
* Allow the blueback user to run rsync as root, add this to sudoers: blueback localhost = NOPASSWD: /usr/bin/rsync
