Showquota
=========

Showquota is an application to allow user's of Simulation and Modeling's clusters at the 
University of Pittsburgh to view their disk usage and quotas accross the various storage 
systems available to the clusters.


Example
-------
> $ showquota
> 
> User quota on /ihome: None (Usage: Unknown)
> Group quota on /ihome: 2,099 GB (Usage: 127 GB)
> 
> User quota on /home: 100 GB (Usage: 13 GB)
> Group quota on /home: None (Usage: Unknown)
> 
> User quota on /home1: None (Usage: Unknown)
> Group quota on /home1: None (Usage: Unknown)
> 
> User quota on /home2: None (Usage: Unknown)
> Group quota on /home2: None (Usage: Unknown)
> 
> User quota on /gscratch2: None (Usage: Unknown)
> Group quota on /gscratch2: None (Usage: Unknown)
> 
> User quota on /mnt/mobydisk: None (Usage: 0 GB)
> Group quota on /mnt/mobydisk: None (Usage: 0 GB)


How it works
------------
**showquota** is the main program.  When called by a user it determines the user 
and group usage of NFS and Lustre storage systems.  This program then calls the C
program **call_isilon_quota** which is SETUID and owned by root.  This program, 
running as root and not the user when executed, then calls **isilon_quota** which
uses Isilon's REST API to get user and group usage and quota information and passes
is back to showquota (via JSON) who displays the relevant information to the user.  The reason
for this odd design is that Isilon (at the time of this writing) does not support
standard methods of retrieving quota information from an NFS mount point.  Instead
the API (or Web interface or command line) must be used to get this information.
However, to log into the API one must have credentails to do so and rights to view
quota and usage information.  In this program that is done by **isilon_quota**
reading a file with stashed credentails.  These credentails should not be available
to users, hence the SETUID root program.  An interpreted program (e.g. Python) cannot
be SETUID so the C program is required as a middle-man simply to change the EUID
to root and call the Python script which must run as root to read the stashed credentails.


Credit
------
Credit for the original C code for **call_isilon_quota** goes to by Ben Carter
of the University of Pittsburgh.
