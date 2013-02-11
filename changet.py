#!/usr/bin/env python
# Description: Download images from a 4chan thread with original file names
# Written by: Jeff White (jwhite530@gmail.com)
# Version: 1
# Last change: Initial version

# License:
# This software is released under version three of the GNU General Public License (GPL) of the
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this software implies your acceptance of this license and its terms.
# This is a free software, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.


import sys, getopt, signal, json, hashlib, os, time
from urllib import urlopen


def main(argv):
  try:
    opts, args = getopt.getopt(argv,"h",["help"])
  except getopt.GetoptError:
    sys.stderr.write("Unknown option specified, see `changet.py --help`\n")
    sys.exit(2)
  for opt, arg in opts:
    if opt == "-h" or opt == "--help":
      print "Download images from a 4chan thread with original file names.\n"
      print "This program will create a directory named for the board given with"
      print "a directory under that named for the thread number.\n"
      print "Usage: changet.py url\n"
      print "Example: changet.py http://boards.4chan.org/g/res/31432249"
      sys.exit()

         
if __name__ == "__main__":
   main(sys.argv[1:])


# Were we called correctly?
try:
  url = sys.argv[1]
except:
  sys.stderr.write("No URL specified, see `changet.py --help`.\n")
  sys.exit(2)
  

spliturl = url.split('/')
board = spliturl[3]
thread = spliturl[5]


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
print "Downloading images from thread", thread, "on", board

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
        num_remote_images = post_data["images"]
        num_local_images = len([name for name in os.listdir(".") if os.path.isfile(name)])
        sys.stdout.write("Found " + str(num_remote_images) + " images in thread and " + str(num_local_images - 1) + " already local\n")
      
      # Skip posts without images
      if not post_data.get("filename"):
        continue
      
      filename = post_data["filename"] + post_data["ext"]

      # Download the image if we don't already have it
      local_size = int()
      try:
        local_size = os.path.getsize(filename)
      except:
        local_size = 0
        
      if not local_size > 0:
        sys.stdout.write("Downloading file " + filename + " (" + str(post_data["fsize"]/1024) + " KB) from post " + str(post_data["no"]) + "\n")
        
        remote_image_handle = urlopen("https://images.4chan.org/" + board + "/src/" + str(post_data["tim"]) + post_data["ext"])
        local_image_handle = open(filename, "w")
        local_image_handle.write(remote_image_handle.read())
        local_image_handle.close()
    
    
    print "Waiting 60 seconds until next check"
    time.sleep(60)
    print "Checking for new images"
    
  except KeyboardInterrupt:
    sys.stderr.write("Caught signal, exiting\n")
    sys.exit()