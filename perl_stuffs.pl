#!/usr/bin/perl
use warnings; #Print warnings
use strict; #Enforce 'good' programming rules

#Name: perl_stuffs.pl
#Description: Perl script to learn and test perl features.
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
# 0.1 - 2011-12-31 - Initial version. - Jeff White
#
#####

#Define some scalar variables
# my $some_number = 22;
# my $other_number = $some_number + 3; #Becomes 25
# my $some_string = 'hello';
# my $other_string = "$some_string world";

#Print those variables
# print "some_number is $some_number\n";
# print "other_number is $other_number\n";
# print "some_string is $some_string\n";
# print "other_string is $other_string\n";

#Grab an environmental variable and test it against an internal scalar variable
# my $current_user = $ENV{'USER'};
# my $expected_user = "white";
# if ($current_user =~ m/($expected_user)/) { #Compare strings with regex
#   print "Environmental variable \$USER is set to '$expected_user' as expected.\n"
# } else {
#   print "Environmental variable \$USER was set to '$current_user' which I didn't expect.\n" #The variable in single quotes will still expand as it is all within double quotes
# }

#if;then;else with integer testing
# if ($some_number == $other_number) {
#   print "The variable \$some_number is equal to the variable \$other_number.\n";
# } elsif ($some_number > $other_number) {
#   print "The variable \$some_number is greater than the variable \$other_number.\n";
# } elsif ($some_number < $other_number) {
#   print "The variable \$some_number is less than the variable \$other_number.\n";
# }

#Grabbing user input a simpler way
# print "Type a number between 0 and 100 (inclusive).\n";
# chomp(my $users_number = <STDIN>); #Get one line of input, hold it as a scalar variable, and remove the last newline character
# if (! $users_number) {
#   print "You didn't type anything!\n";
# } elsif ($users_number !~ m/^[+-]?\d+$/) {
#   print "Cheater, that wasn't a number!\n"
# } elsif ($users_number > 100) {
#   print "Cheater, your number was above 100!\n";
# } elsif (($users_number >= 0) && ($users_number <= 49)) { #logical 'and'
#   print "Your number was between 0 and 49.\n";
# } elsif (($users_number >= 50) && ($users_number <= 100)) {
#   print "Your number was between 50 and 100.\n";
# }

#A simple while loop with an incrementing count
# my $count = 0;
# while ($count < 3) {
#   print "Count is currently $count.\n";
#   $count++
# }

#Create an array
# my @some_array = ("foo", "bar", "roo", "dar" );
# print "The first element of the array is: $some_array[0]\n";
# print "The second element of the array is: $some_array[1]\n";
# shift @some_array; #Remove the first element.  We could assign it to a variable instead of just removing it.
# pop @some_array; #Remove the last element.  We could assign it to a variable instead of just removing it.
# push @some_array, "woo"; #Add another element to the end of array
# print "The last element of the array is: $some_array[-1]\n";
# 
# #Loop through an array
# foreach my $object (@some_array) {
#   print "The current array element of this loop is: $object\n";
# }

#A subroutine which takes arguments
# sub find_highest_integer { #This subroutine's return value is the largest integer given as an argument
# #  state $highest_arg #Broken...
#   my $highest_arg = shift @_; #The first argument is the highest so far
#   foreach my $eacharg (@_) {
#     if ($eacharg !~ /^[+-]?\d+$/) {
#       print "WARNING: Improper usage of subroutine &find_highest_integer with argument '$eacharg', only integers are acceptable arguments.\n";
#       #return; #If this line was uncommented, we would break out of the loop when we hit a non-integer argument.
#     } elsif ( $eacharg > $highest_arg ) {
# 	$highest_arg = $eacharg;
#     }
#   }
# $highest_arg; #This is the return value
# }
# print "The highest value of the arguments to &find_highest_integer was: ", &find_highest_integer(7,5,27,7), "\n";

#Print a generic error, then immediately exit
#die "Some error text, exiting,/n"; #Some error text, exiting at /media/Data/Scripts/Git-public/perl_stuffs.pl line 113, <STDIN> line 1.

#Print a generic error, but don't exit
#warn "Some error text,/n";

#Open a file handle for reading
# if (! open CPUINFO, "</proc/cpuinfo") { #We could also use > and >> for output.
#   die "Unable to open /proc/cpuinfo for reading: $!"; #The $! is the human-readable error from the system.
# }

#Read a file line by line (not all of it into memory at once)
# while (my $eachline = <CPUINFO>) { #We could use <> to mean to use the files given as arguements.
#  print "The first line from the file handle CPUINFO is: $eachline"; #We don't need a newline since each line of the file has one and we didn't chomp it.
#  last; #Just end the loop after the first iteration, similar to break in other languages.  'next' is like 'continue'.  There's also 'redo'.
# }
# close CPUINFO; #Close the file handle we opened.

#Split a line into an array
# my @include_dir = split(/ /, $_, 2);

#Split a line into separate variables
# ($username_and_service,$junk,$junk,$junk,$junk,$ip_in_hex,$junk,$last_operation_date) = split(/ /, $eachline, 8);

#Call an external command and loop through each line of its output
# open (POLICYDETAILS, "/usr/openv/netbackup/bin/admincmd/bppllist $each_policy_name -l |") || die "Failed to run bppllist for policy name $each_policy_name: $!";
# while (<POLICYDETAILS>) {
#  if ("$_" =~ m/^INCLUDE/ ) {
#    my @include_dir = split(/ /, $_, 2);
#    $dirs_included_in_a_policy = "$dirs_included_in_a_policy" . "$include_dir[1]";
#  }
# }
# close POLICYDETAILS;

#Redirect STDERR to a file
# if (! open STDERR, ">>/tmp/somelog.err") {
#  die "Unable to open error log: $!";
# }
# 
# Print to a file handle
# print STDERR "Foo.\n";

#Redirect output to a filehandle
# open (OUTLOG, ">>/tmp/thing.out") || die "Failed to open output log: $!";
# select OUTLOG; #This file handle must be valid or else all output will fail
# $| = 1; #Don't keep output in a buffer, write to the log immediately
# print "Some text\n";
# select STDOUT; #Switch output back back to the normal STDOUT
# print "Other text\n";

#Redirect output to a both STDOUT and a file
# open (STDOUT, "| tee -a /tmp/thing.out");
# print "Some text\n";
# close (STDOUT);

#Log a message with syslog
# use Sys::Syslog;
# syslog("LOG_ERR", "NOC-NETCOOL-TICKET: $num_missing_dirs user directories are not in a backup policy -- $0.");

#Get the hostname from the IP
# use Socket;
# my $iaddr = inet_aton("136.142.3.145");
# my $hostname = gethostbyaddr($iaddr, AF_INET);
# print "$hostname\n";

#Get the IP from a hostname
# use Socket;
# my $ipaddr_binary = gethostbyname("jaw171.noc.pitt.edu");
# my $ipaddr = inet_ntoa($ipaddr_binary);
# print "$ipaddr\n";

#A simple hash
# my %ipaddr;
# $ipaddr{"indigo.jealwh.local"} = "192.168.10.152";
# $ipaddr{"cyan.jealwh.local"} = "192.168.10.150";
# print "The IP of Indigo is $ipaddr{\"indigo.jealwh.local\"}\n";

#Another way to do a simple hash
# my %ipaddr = ( 
#   "indigo.jealwh.local" => "192.168.10.152",
#   "cyan.jealwh.local" => "192.168.10.150",
#   "teal.jealwh.local" => "192.168.10.156",
# );
# print "The IP of Indigo is $ipaddr{\"indigo.jealwh.local\"}\n";

#Get keys from a hash into an array
# my @ipaddr_keys = keys(%ipaddr);

#Get the values from a hash into an array
# my @ipaddr_values = values(%ipaddr);

#Get a count of how many key:value pairs a hash has
# my $num_pairs = keys(%ipaddr);
# print "Hash \%ipaddr has $num_pairs key:value pairs\n";

#Loop through a hash
# while ( (my $ipaddr_key, my $ipaddr_value) = each %ipaddr ) {
#   print "The IP of $ipaddr_key is $ipaddr_value\n";
# }

#Loop through a hash, v2
# foreach my $hostname (keys %ipaddr){
#   print "The key is $hostname.\n";
# }

#Test if an element of a hash has a values
# if ($ipaddr{"cyan.jealwh.local"}) {
#   print "Yes, the key zaffre.jealwh.local has a value.\n";
# }

#Test if a key exists in a hash
# if (exists $ipaddr{"cyan.jealwh.local"}) {
#   print "Yes, the key zaffre.jealwh.local exists in the hash.\n";
# }

# Remove an element from a hash
# delete $ipaddr{"cyan.jealwh.local"};
# 
# Get an enviroment variable
# print "Your PATH is $ENV{PATH}\n";
# 
# Regular expression
# my $foo = "some text is here";
# if ($foo =~ m/
#   ^ 	#The start of the line
#   s[oa]me  #String to match, could match: some same
# /x) { #The x here allows extra whitespace and quoting in the expression
#   print "Yup, it matched.\n";
# }
# 
# Pattern match a user's input string
# print "What is your favorite color?\n";
# my $fav_color = (<STDIN> =~ m/blue/i);
# #Blah, blah, things happen...
# if ($fav_color) {
#   print "I like blue too!\n";
# }
# 
# Pulling things out of a string with parens in a regex
# if ("foo bar roo" =~ m/(^foo).*(roo$)/) { #Don't do this outside of a conditional expression
#   print "The first pattern match was '$1' and the second was '$2'\n";
# }
# 
# Same as above, but name the parens...Don't do this outside of a conditional expression
# if ("foo bar roo" =~ m/
#   (?<first>^\w+) #Begins with any word, labeled 'first'
#   \ .*\ #space, 0 or more of any non-newline, space
#   (?<last>\w+$) #Ends with any word, labeled 'last'
# /x
# ) {
#   print "The first pattern match was '$+{first}' and the second was '$+{last}'\n"; #This the array %+ with keys of whatever we named in the regex
# }
# 
# Automatic match variables
# if ("foo bar roo" =~ m/bar/) {
#   print "The match was '$&' with '$`' before the match and '$'' after the match.\n";
# }

#Quantifiers in a regex
# if ("foo bar" =~ m/o{2}/) { #Exactly two 'o'
#   print "I saw '$&'\n"; #I saw 'oo'
# }
# 
# if ("fooooo bar" =~ m/o{2,}/) { #At least two 'o'
#   print "I saw '$&'\n"; #I saw 'ooooo'
# }
# 
# if ("foooooooo bar" =~ m/o{2,5}/) { #Between two and five 'o'
#   print "I saw '$&'\n"; #I saw 'ooooo'
# }

#sed-like string substitution
# my $foo = "foo bar roo";
# $foo =~ s/roo/poo/; #Must be a variable, not a raw string
# print "$foo\n"; #foo bar poo

# my $foo = "Let's go to a bar";
# $foo =~ s/( bar( |$))/ gay$1/; #$1 is what was matched by the first () in the regex
# print "$foo\n"; #Let's go to a gay bar

#Using split to pull apart strings
# my $foo = "foo:bar:roo";
# my @data = split /:/,$foo; #Use \s+ as the delimeter for whitespace
# print "It was: @data\n";

# my $foo = "foo:bar:roo";
# my ($first,$second,$third) = split /:/,$foo;
# print "It was: $first, $second, $third\n";

#Pulling text out of a string without split
# my $foo = "foo bar roo";
# my ($first,$last) = ($foo =~ m/(^foo).*(roo$)/); #An array such as @matches could be used instead
# print "First I saw '$first' then possibly other stuff and last I saw '$last'\n";

#Edit a file in place
# Create a file called foo.txt:
# 1: eins
# 2: zwei
# 3: drei
# $^I = ".orig";
# while (<>) {
#   s/^2:.*\n//;
#   print;
# }
#You will have two files
# foo.txt:
# 1: eins
# 3: drei
# foo.txt.orig:
# 1: eins
# 2: zwei
# 3: drei

#C style incrementing loop
# for (my $count=1; $count <=10; $count++) {
#   print "Count is $count\n";
# }

#Simple file operations
# my $file = "/proc/cpuinfo";
# if ( -r $file && -w _ ) { # _ is the information from the last lookup
#   print "$file is both readable and writable.\n";
# } elsif ( -r _ ) {
#   print "$file is only readable.\n"
# }

#Get the system time
# my @time = localtime; #$sec, $min, $hour, $day, $mon, $year, $wday, #yday, $isdst
# my $time = localtime; # Scalar context
# print "The scalar time is $time\n"; #The time is Thu Mar  1 21:33:52 2012
# print "The list time is @time\n"; #The time is 44 34 21 1 2 112 4 60 0

#Shell-like globbing
# my @procfiles = glob "/proc/*"; #Also: my @procfiles = </proc/*>;
# print "I see the files: @procfiles\n";

#Rename files
# foreach my $oldfile (glob "/var/tmp/foo*.txt") {
#   (my $newfile = $oldfile ) =~ s/\.txt$/.txt.old/;
#   if (-e $newfile) {
#     warn "Skipping rename of $oldfile.  File $newfile already exists.\n";
#   } elsif (rename $oldfile, $newfile) {
#     #Success
#   } else {
#     warn "Failed to rename $oldfile to $newfile: $!\n";
#   }
# }

#Make a directory
# mkdir "/tmp/foo", 0750; #Must be octal with the leading zero!  Don't do 'my $perm = 0770' as that is a string, not octal.  umask is still used.
# mkdir "/tmp/bar";

#Set permissions
# chmod 0770, "/tmp/foo", "/tmp/bar"; #Must be octal with the leading zero!

#Set ownership
# defined (my $user = getpwnam "white") || die "User does not exist."; #Get the UID
# defined (my $group = getgrnam "myself") || die "Group does not exist."; #Get the GID
# chown $user, $group, "/tmp/foo"; #Must be UID and GID, not username and group name

#Sort - Case sensive
# my @things = ("Foo", "bar", "foo", "Bar");
# my @sorted_things = sort @things;
# print "Case sensitive: @sorted_things\n";

#Sort - Case insensitive
# my @stuff = ("Foo", "bar", "foo", "Bar");
# sub case_insensitive { "\L$a" cmp "\L$b" }
# my @sorted_stuff = sort case_insensitive @stuff;
# or:
# my @sorted_stuff = sort { "\L$a" cmp "\L$b" } @stuff;
# print "Case insensitive: @sorted_stuff\n";

#Sort - By number
# my @numbers = ("7", "12", "3", "2");
# sub by_number { $a <=> $b } #The spaceship operator gives three possible return values: -1, 0, 1
# my @sorted_numbers = sort by_number @numbers;
# ... or ...
# my @sorted_numbers = sort { $a <=> $b } @numbers; #Add 'reverse' before sort to reverse it or use '$b <=> $a'
# print "Numeric: @sorted_numbers\n";

#The 'given' statement
# use 5.010;
# if (@ARGV == 0) {
#   die "Usage: $0 some_string\n";
# }
# given($ARGV[0]) { #What to compare.  If this was be an array it would loop through each element.
#   when(/^foo$/i) { say "It was exactly some sort of 'foo'";continue } #Don't continue before the default
#   when(/^foo/i) { say "It started with some sort of 'foo'";continue }
#   when(/foo/i) { say "It was some sort of 'foo'";break } #continue makes to check the others even if this one is true
#   default { say "No foo here." }
# }

#Run an external command
system "date" || warn "Warning: Could not get current date from the system.\n"; #Inherits STDOUT, STDIn, and STDERR from the Perl script
# system "date", "+%F" ; #Multi-paramter calls like this never use a subshell
