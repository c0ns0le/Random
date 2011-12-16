#!/bin/bash
#Written by: rdcwayx of unix.com

node_number=${NODE:=${1:?"Path must be an arguement"}}

find $1 -type f |awk  '{$NF="";a[$0]++}END{for (i in a) print a[i],i }' FS=\/ OFS=\/ | sort -rn | head
