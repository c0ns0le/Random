#!/usr/bin/python3.1
# -*- coding: utf-8 -*-


#somestring = "foo"
#someint = 7
#print("It is", somestring, "and", someint)
#print("It is {0} and {1}".format(somestring,someint)) # Prints the same thing


## Tuple (immutable)
#sometuple = (1,6,3,9,24)


## List
#somelist = [6,6,3,9,24,"q"]


## Show what class the object is
#print(type(sometuple))


## Change lists
#print("'somelist' has", len(somelist), "elements:", somelist)
#somelist.append(73)
#print("'somelist' now has", len(somelist), "elements:", somelist)


## Simple numeric comparison
#if somelist[0] == somelist[1]:
  #print("The first element of 'somelist' is equal to the second element.")
#elif somelist[0] < somelist[1]:
  #print("The first element of 'somelist' is smaller than the second element.")
#else:
  #print("The first element of 'somelist' is larger than the second element.")


## Sum the list
#sum = 0
#for each in somelist:
  #try:
    #sum += each
  #except TypeError as err:
    #print("Skipping '", each, "':", err)
    #continue
  
#print("Sum of 'somelist' is:", sum)


## Numeric high water mark
#def highwater(*nums):
  ## Returns a float of the highest number given
  
  #for each_num in nums:
    
    #try:
      #each_num = float(each_num) # Convert to a float
    #except Exception as err:
      #print("Skipping '", each_num, "';", err)
      #continue
    
    #try: 
      #high_num
    #except NameError:
      #high_num = each_num
      
    #if each_num > high_num:
      #high_num = each_num
      
  #return high_num
  

## Numeric low water mark
#def lowwater(*nums):
  ## Returns a float of the lowest number given
  
  #for each_num in nums:
    
    #try:
      #each_num = float(each_num) # Convert to a float
    #except Exception as err:
      #print("Skipping '", each_num, "';", err)
      #continue
    
    #try:
      #low_num
    #except NameError:
      #low_num = each_num
      
    #if each_num < low_num:
      #low_num = each_num
      
  #return low_num
  

## Grab user input and do some math
#num_entries = int()
#all_nums = []
#while True:
  #user_line = input("Enter a number (or blank to finish): ")
  
  #if user_line: # The line is not blank...
    
    #try:
      #user_line = float(user_line) # Convert 'user_line' to a float
    #except (TypeError, ValueError) as err: # Catch conversion errors
      #print("Skipping '", user_line, "', not a number;", err)
      #continue
    #except Exception as err: # Catch all other errors
      #print("Skipping '", user_line, "', unknown error;", err)
      #continue
    #else: # Not really needed as the exception would break out of this loop iteration
      #num_entries += 1
      #all_nums.append(user_line)
  
  #else: # The line is blank
    #break

#if num_entries:
  #print("Stats of the", num_entries, "number(s):")
  #print("Highest:", highwater(*all_nums))
  #print("Lowest:", lowwater(*all_nums))
  #print("Average:", sum(all_nums) / num_entries) # // would return an int instead of a float
  #print("Sum:", sum(all_nums))
#else:
  #print("You didn't enter anything.")
  
  
## Colors
#print("Foo", "\033[1;30mGray like Ghost", "Bar", "\033[1;m")
#print("\033[1;31mRed like Radish\033[1;m")
#print("\033[1;32mGreen like Grass\033[1;m")
#print("\033[1;33mYellow like Yolk\033[1;m")
#print("\033[1;34mBlue like Blood\033[1;m")
#print("\033[1;35mMagenta like Mimosa\033[1;m")
#print("\033[1;36mCyan like Caribbean\033[1;m")
#print("\033[1;37mWhite like Whipped Cream\033[1;m")
#print("\033[1;38mCrimson like Chianti\033[1;m")
#print("\033[1;41mHighlighted Red like Radish\033[1;m")
#print("\033[1;42mHighlighted Green like Grass\033[1;m")
#print("\033[1;43mHighlighted Brown like Bear\033[1;m")
#print("\033[1;44mHighlighted Blue like Blood\033[1;m")
#print("\033[1;45mHighlighted Magenta like Mimosa\033[1;m")
#print("\033[1;46mHighlighted Cyan like Caribbean\033[1;m")
#print("\033[1;47mHighlighted Gray like Ghost\033[1;m")
#print("\033[1;48mHighlighted Crimson like Chianti\033[1;m")


## Regular expression testing
#import re
#number = "4654656"
#number_reg = re.compile(r"[+-]?\d+") # The r before the quote makes it a raw string.  No need to double escapte backslashes.
#if number_reg.match(str(number)): # Test if the strings *starts* with the RE.  This would match '123abc' but not 'abc123'.
  #print("Yes, the string begins with a number.")
#elif number_reg.search(str(number)): # Test if the string *contains* the RE.  This would match 'abc123' and '123abc'.
  #print("Yes, the string contains a number.")
#else:
  #print("No, the string does not contain a number.")
  
#if number.isnumeric():
  #print("Yup, it's a number")


## Simple string testing
#path = "/var/spool/thing"
#if "/var" in path:
  #print("Yup, it's there.")
  

## Striding
#foo = "abcdefghijlkmnopqrstuvwxyz"
#print(foo) # abcdefghijlkmnopqrstuvwxyz
#print(foo[0:3]) # abc
#print(foo[:3]) # abc (same as above - 0 is the default)
#print(foo[3:]) # defghijlkmnopqrstuvwxyz
#print(foo[:3] + foo[-3:]) # abcxyz
#print(foo[::-2]) # zxvtrpnkjhfdb (every other, backwards)
#print(foo[::2]) # acegilmoqsuwy (every other, forwards)
#print(foo[::-1]) # zyxwvutsrqponmkljihgfedcba (full string, backwards)


# Split
zahl = "eins zwei drei vier"
print(zahl.split()) # ['eins', 'zwei', 'drei', 'vier']
print(zahl.split()[0]) # eins
print(zahl.split("i")) # ['e', 'ns zwe', ' dre', ' v', 'er'] 
print(zahl.split("Dgghtswerhtshghtrhry")) # ['eins zwei drei vier']


