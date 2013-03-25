#!/usr/bin/env python
# Description: Download images from a 4chan thread with original file names
# Written by: Jeff White (jwhite530@gmail.com)
# Version: 1.3.1
# Last change: Change where URL encoding is removed

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


import sys, signal, json, hashlib, os, time, re
from urllib import urlopen, unquote
from optparse import OptionParser


     
# How were we called?
parser = OptionParser(
    "%prog [options] url\n" + 
    "Download images from a 4chan thread with original file names.\n" + 
    "This program will create a directory named for the board given with\n" + 
    "a directory under that named for the thread number.\n" + 
    "\nExample: %prog http://boards.4chan.org/g/res/31432249"
)

(options, args) = parser.parse_args()



# Were we called correctly?
try:
    url = sys.argv[1]
    
except:
    sys.stderr.write("No URL specified, see `changet.py --help`.\n")
    sys.exit(2)
    
    

spliturl = url.split('/')
board = spliturl[3]
thread = re.sub("#.*$", "", spliturl[5])



try:
    int(thread)
except:
    
    sys.stderr.write("Failed to get thread number from URL, see `changet.py --help`.\n")
    sys.exit(2)


    
# Create the download directory
try:
    if not os.path.isdir(board):
        os.mkdir(board, 0750)
        
    if not os.path.isdir(board + "/" + thread):
        os.mkdir(board + "/" + thread, 0750)
        
except:
    e = sys.exc_info()[0]
    sys.stderr.write("Failed to create download directory " + board + "/" + thread + "\n")
    sys.exit(1)
    
os.chdir(board + "/" + thread)



# Now the real work
sys.stdout.write("Downloading images from thread " + thread + " of /" + board + "/\n")



downloads = {}
while True:
    try:
        
        # Get the JSON data
        json_handle = urlopen("https://api.4chan.org/" + board + "/res/" + thread + ".json")
        json_text = json_handle.read()
        json_handle.close()

        if not json_text:
            sys.stderr.write("No such thread or failed to download JSON data\n")
            sys.exit(1)
            
        
        # Loop through each post
        for post_data in json.loads(json_text)["posts"]:
            # The OP will tell us how many images are in the thread
            if "images" in post_data:
                num_remote_images = post_data["images"] + 1 # 4chan doesn't count OP's post as an image for some reason
                
                num_local_images = len([name for name in os.listdir(".") if os.path.isfile(name)])
                
                sys.stdout.write("Found " + str(num_remote_images) + " images in thread and " + str(num_local_images) + " already local\n\n")
            
            
            # Skip posts without images
            try:
                file_name = post_data["filename"] + post_data["ext"]
                
                # If the file_name is greater than 255 characters or we have a duplicate 
                # file name then set it to the post number instead
                if len(file_name) > 255:
                    file_name = str(post_data["no"]) + post_data["ext"]
                
                if file_name in downloads.values():
                    file_name = str(post_data["no"]) + post_data["ext"]
                
            except KeyError:
                continue


            # Skip posts and images we already have
            if post_data["no"] in downloads or os.path.exists(file_name):
                continue
            
            
            try:
                sys.stdout.write("Downloading file " + file_name + " (" + str(post_data["fsize"]/1024) + " KB) from post " + str(post_data["no"]) + "\n")
                
                remote_image_handle = urlopen("https://images.4chan.org/" + board + "/src/" + str(post_data["tim"]) + post_data["ext"])
                
                # Remove URL encoding many image names have
                file_name = unquote(file_name)
                
                local_image_handle = open(file_name, "w")
                local_image_handle.write(remote_image_handle.read())
                local_image_handle.close()
                
                downloads.update({
                    post_data["no"] : file_name
                })
                
            except Exception as err:
                sys.stderr.write("Failed to download " + file_name + ":\n" + str(err) + "\n")
                
                continue
        
        
        sys.stdout.write("Waiting 60 seconds until next check\n")
        time.sleep(60)
        sys.stdout.write("Checking for new images\n")
        
    except KeyboardInterrupt:
        sys.stderr.write("Caught signal, exiting\n")
        sys.exit()
