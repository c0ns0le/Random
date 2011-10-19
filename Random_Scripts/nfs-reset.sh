#!/bin/sh
sudo service portmap stop
sleep 5
sudo service portmap status
sudo service portmap start
sudo service nfs-kernel-server restart
