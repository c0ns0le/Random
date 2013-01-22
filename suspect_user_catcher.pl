#!/usr/bin/env perl
use strict;
use warnings;
# Description: Find users on a system doing possibly nasty things (sending SPAM, controlling bots, etc.)
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Includes code written by Ben Carter of the University of Pittsburgh
# Version: 1.0
# Last change: Initial version

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

use Getopt::Long;
Getopt::Long::Configure("bundling");
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use Time::Local;
use Socket;
use Geo::IP;

# Define our whitelists
# The source whitelist is used to check how many non-whitelisted IPs a 
my %whitelisted_source_ips = (
  "136.142.0.0/16" => "Pittnet",
  "130.49.0.0/16" => "Pittnet",
  "10.0.0.0/8" => "Pittnet",
  "150.212.0.0/16" => "Pittnet",
);

my %whitelisted_dest_ips = (
  "136.142.0.0/16" => "Pittnet",
  "130.49.0.0/16" => "Pittnet",
  "10.0.0.0/8" => "Pittnet",
  "150.212.0.0/16" => "Pittnet",
);

my %whitelisted_users = (
  "root" => "root",
);

# Define what we deem suspicious
my %suspicious_ports = (
  25 => "SMTP",
  6667 => "IRC",
  22 => "SSH",
  21 => "Telnet",
);

my $netstat = "/usr/bin/netstat";
my $lsof = "/usr/local/bin/lsof";
my $ps = "/usr/bin/ps";
my $lastx = "/var/tmp/lastx";

# Don't change these
my $verbose = 0;
$| = 1;
my %BinarySourceWhitelistedNetworks;
my %BinarySourceWhitelistedMasks;
my %BinaryDestWhitelistedNetworks;
my %BinaryDestWhitelistedMasks;

GetOptions('h|help' => \my $helpopt,
           'v|verbose+' => \$verbose,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Find users on a system doing possibly nasty things (sending SPAM, controlling bots, etc.).\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  print "-v | --verbose : Enable verbosity\n";
  exit;
}


# Get a pretty datetime
sub datetime {
  # Returns a scalar string with a pretty datetime:
  # Usage: datetime()
  
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year += 1900;
  
  return "$year-$mon-$mday $hour:$min:$sec";
}


# Convert a decimal IP to a binary IP
sub convert_ip {
  # In a scalar context returns a binary IP string or undef on error
  # Usage: convertip($ip)
  
  my $B1 = 256;
  my $B2 = 256;
  my $B3 = 256;
  my $B4 = 256;
  my $IP = shift;

  ( $B1, $B2, $B3, $B4 ) = split("[.]",$IP,4);

  return if ( $B1 < 0 || $B1 > 255 );
  return if ( $B2 < 0 || $B2 > 255 );
  return if ( $B3 < 0 || $B3 > 255 );
  return if ( $B4 < 0 || $B4 > 255 );

  return ( $B1 << 24 | $B2 << 16 | $B3 << 8 | $B4 );
}


# Check if an IP is whitelisted
sub whitelisted_source_ip {
  # Returns 1 if an IP is whitelisted, 0 if it is not whitelisted, undef on error
  # Usage whitelisted($ip)
  
  my $ip = shift;
  
  # Check if the IP is individually listed
  if ($whitelisted_source_ips{$ip}) {
    return 1;
  }
  
  # Check if the IP is within a whitelisted subnet
  my $BinaryIP = convert_ip( $ip );

  for my $ExternalAuthNetwork (keys(%whitelisted_source_ips)) {
  
    # Skip the entry if it is not a CIDR notation
    next unless ($ExternalAuthNetwork =~ m|/|);
    
    my $ExternalAuthIP = $BinarySourceWhitelistedNetworks{ $ExternalAuthNetwork };
    my $Mask = $BinarySourceWhitelistedMasks{ $ExternalAuthNetwork };

    if ( ( $BinaryIP & $Mask ) == ( ( $ExternalAuthIP & $Mask ) ) ) {
      return 1;
    }
  }
   
  # We're still running?  Must not be whitelisted...
  return 0;
}


# Check if a destination IP is whitelisted
sub whitelisted_dest_ip {
  # Returns 1 if an IP is whitelisted, 0 if it is not whitelisted, undef on error
  # Usage whitelisted($ip)
  
  my $ip = shift;
  
  # Check if the IP is individually listed
  if ($whitelisted_dest_ips{$ip}) {
    return 1;
  }
  
  # Check if the IP is within a whitelisted subnet
  my $BinaryIP = convert_ip( $ip );

  for my $ExternalAuthNetwork (keys(%whitelisted_dest_ips)) {
  
    # Skip the entry if it is not a CIDR notation
    next unless ($ExternalAuthNetwork =~ m|/|);
    
    my $ExternalAuthIP = $BinaryDestWhitelistedNetworks{ $ExternalAuthNetwork };
    my $Mask = $BinaryDestWhitelistedMasks{ $ExternalAuthNetwork };

    if ( ( $BinaryIP & $Mask ) == ( ( $ExternalAuthIP & $Mask ) ) ) {
      return 1;
    }
  }
   
  # We're still running?  Must not be whitelisted...
  return 0;
}


# Build the hashes of the binary whitelisted networks
for my $ExternalAuthNetwork (keys(%whitelisted_source_ips)) {

  # Skip the entry if it is not a CIDR notation
  next unless ($ExternalAuthNetwork =~ m|/|);

  my ( $Network, $MaskSize ) = split("[/]",$ExternalAuthNetwork);

  my $Mask = ( ( 0xffffffff << ( 32 - $MaskSize ) ) & 0xffffffff );

  my $IP;
  unless ($IP = convert_ip( $Network )) {
    print STDERR ("Invalid IP address: $IP in whitelisted IPs");
    next;
  }

  my $HexNetwork = sprintf( "%08x", $IP );
  my $HexMask = sprintf( "%08x", $Mask );

  $BinarySourceWhitelistedNetworks{ $ExternalAuthNetwork } = $IP;
  $BinarySourceWhitelistedMasks{ $ExternalAuthNetwork } = $Mask;
}

for my $ExternalAuthNetwork (keys(%whitelisted_dest_ips)) {

  # Skip the entry if it is not a CIDR notation
  next unless ($ExternalAuthNetwork =~ m|/|);

  my ( $Network, $MaskSize ) = split("[/]",$ExternalAuthNetwork);

  my $Mask = ( ( 0xffffffff << ( 32 - $MaskSize ) ) & 0xffffffff );

  my $IP;
  unless ($IP = convert_ip( $Network )) {
    print STDERR ("Invalid IP address: $IP in whitelisted IPs");
    next;
  }

  my $HexNetwork = sprintf( "%08x", $IP );
  my $HexMask = sprintf( "%08x", $Mask );

  $BinaryDestWhitelistedNetworks{ $ExternalAuthNetwork } = $IP;
  $BinaryDestWhitelistedMasks{ $ExternalAuthNetwork } = $Mask;
}


# We will use this output several times later...
my @full_lsof_output = `$lsof -n 2>/dev/null`;


print BOLD GREEN "Checking for suspicious TCP/UDP connections...\n";

for my $netstat_line (`$netstat -f inet -n`) {
  chomp $netstat_line;
  print "Checking: $netstat_line\n" if ($verbose);
  
  my ($source, $dest, $state) = (split(m/\s+/, $netstat_line))[0,1,6];
  
  # Skip non-established connections (and header lines)
  next if ((!$state) or ($state ne "ESTABLISHED"));
  
  # Split the source and dest into IPs and port numbers
  my @source_ip = (split(m/\./, $source))[0..3];
  my $source_ip = join(".", @source_ip);
  my $source_port = (split(m/\./, $source))[4];

  print "Source: $source\n" if ($verbose);
  print "Source IP: $source_ip\n" if ($verbose);
  print "Source port: $source_port\n" if ($verbose);

  my @dest_ip = (split(m/\./, $dest))[0..3];
  my $dest_ip = join(".", @dest_ip);
  my $dest_port = (split(m/\./, $dest))[4];
  
  print "Dest: $dest\n" if ($verbose);
  print "Dest IP: $dest_ip\n" if ($verbose);
  print "Dest port: $dest_port\n" if ($verbose);
  
  # Skip whitelisted IPs
  if (whitelisted_dest_ip($dest_ip)) {
    print "Skipping whitelisted IP: '$dest_ip'\n" if ($verbose);
    next;
  }
  
  # Is the destination port a naughty one?
  if ($suspicious_ports{$dest_port}) {
    print "Destination port '$dest_port' is suspicious: $source_ip:$source_port => $dest_ip:$dest_port\n" if ($verbose);
    
    # Determine the process and user with the suspicious connection
    for my $lsof_line (@full_lsof_output) {
    
      if ($lsof_line =~ m/\Q$source_ip:$source_port->$dest_ip:$dest_port\E/) {
        my ($prog, $pid, $user) = (split(/\s+/, $lsof_line))[0..2];
        
        print BOLD RED datetime(), "Found suspicious destination port: PID => $pid, User => $user, Program => $prog, Connection: $source_ip:$source_port -> $dest_ip:$dest_port\n";
        system("/usr/bin/logger -p user.err -t NOC-NETCOOL-TICKET 'Found suspicious destination port: PID => $pid, User => $user, Program => $prog, Connection: $source_ip:$source_port -> $dest_ip:$dest_port'");
        
        last;
      }
      
    }

  }
  
}


print BOLD GREEN "Checking for suspicious running scripts...\n";

# This looks through the full output of lsof, finds a program using a perl library, then checks if that
# process looks suspicious.  We do it this way because a user could copy the perl binary somewhere, chnage
# its name to "pine" or whatever then the process list would never show the user was actualyl running perl.
# It's still possible to get around this library check but it's less likely a user would figure it out and
# do the work to get around it.
my %known_proccesses;
for my $lsof_line (@full_lsof_output) {
  chomp $lsof_line;
  
  my ($command, $pid, $user, $fd, $type, $device, $size_off, $node, $lsof_name) = (split(m/\s+/, $lsof_line));
  
  if ( # If we...
    ($lsof_name) and # got a valid name from lsof
    (!$known_proccesses{$pid}) and # it isn't a pid we already looked at
    (!$whitelisted_users{$user}) and # it isn't a whitelisted user
    ($lsof_name =~ m|/lib/.*perl|i)) { # it lookes like a perl library
      print "Found perl process: User => $user, PID => $pid\n" if ($verbose);
      $known_proccesses{$pid} = $command;
      
      # Get the command line with args
      my @ps_out = `$ps -eo pid,args`;
      my @ps_line = grep(m/^\s*\Q$pid\E\s+/, @ps_out);
      my $arg = $ps_line[0];
      chomp $arg;
      $arg =~ s/\Q$pid\E\s+//;
      
      # Get the current working directory
      my @cwd_lines = grep(m/^\Q$command\E\s+\Q$pid\E\s+\Q$user\E\s+cwd/, @full_lsof_output);
      my $cwd = (split(m/\s+/, $cwd_lines[0]))[8];

      # Is the CWD /tmp or /var/tmp?
      if ($cwd =~ m/^\/tmp|^\/var\/tmp/) {
        print BOLD RED datetime(), "Found perl script with a CWD of /tmp or /var/tmp: User => $user, PID => $pid, CWD => $cwd, Arg => $arg\n";
        system("/usr/bin/logger -p user.err -t NOC-NETCOOL-TICKET 'Found perl script with a CWD of /tmp or /var/tmp: User => $user, PID => $pid, CWD => $cwd, Arg => $arg'");
      }
      
      # Are any of the args a file within /tmp or /var/tmp?
      if ($arg =~ m/\/tmp|^\/var\/tmp/) {
        print BOLD RED datetime(), "Found perl script with an arg of /tmp or /var/tmp: User => $user, PID => $pid, CWD => $cwd, Arg => $arg\n";
        system("/usr/bin/logger -p user.err -t NOC-NETCOOL-TICKET 'Found perl script with an arg of /tmp or /var/tmp: User => $user, PID => $pid, CWD => $cwd, Arg => $arg'");
      }
      
#       # Find each arg that looks like a script with an extension that is not .pl
#       
#       # First, remove any switches
#       $arg =~ s/-[a-z]+//i;
#             print "New arg: $arg\n";
#       
#       # Loop through each arg
#       for my $each_arg (split(m/\s+/, $arg)) {
#         # Skip the arg if it ends in .pl
#         next if ($arg =~ m/\.pl$/i);
# 
#         # Skip the arg if it has no extension
#         next unless ($arg =~ m/\.[a-z]+/i);
#         
# #         if ($each_arg =~ m/[a-z]\.[a-z{1..4}]/i) {
# #         
# #         }
#       }
   
  }
}


# Look through the logins of the last 7 days and find suspect users
print BOLD GREEN "Checking for suspicious login history...\n";

# Hash of hashes.  Key is each username, value is a reference to a hash of source IPs.
my %user_login_sources;

# Look through the login history and build a hash of hashes
for my $entry (`$lastx -d 7`) {
  chomp $entry;
  next if ($entry =~ m/^Username/);
  
  my ($user, $term, $source, $dow, $mon, $dom, $human_time, $year) = split(m/\s+/, $entry);

#   # Convert the date to epoch  
#   my ($hour, $minute, $second) = split(m/:/, $human_time);
#   my $epoch_time = timelocal($second,$minute,$hour,$dom,$mon,$year);
#   print "User => $user, Source => $source, Time => $epoch_time\n" if ($verbose);
  
  # Convert the source to IP
  my $ipaddr;
  if ($source =~ m/^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5]).([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$/) {
    $ipaddr = $source;
  }
  else {
    if (my $ipaddr_binary = gethostbyname($source)) {
      $ipaddr = inet_ntoa($ipaddr_binary);
    }
    else { # If the name did not resovle...
      $ipaddr = "0.0.0.0";
    }
  }
  
  # Skip whitelisted users
  next if ($whitelisted_users{$user});
  
  # Skip whitelisted IPs
  next if (whitelisted_source_ip($ipaddr));
  
  # If it is a new user.  Add them to the hash and create a new array for them
  unless ($user_login_sources{$user}) {
    $user_login_sources{$user} = {$source => $ipaddr};
  }
  # It is a known user.  Check if the source is already known and add it to the array if not.
  else {
    my $hash_ref = $user_login_sources{$user};
    
    # Add the source to the hash if it is new
    ${$hash_ref}{$source} = $ipaddr unless (${$hash_ref}{$source});
  }
  
}


# Find non-US sources
my $geo_ip_object = Geo::IP->new(GEOIP_MEMORY_CACHE);

for my $user (keys(%user_login_sources)) {
  my $hash_ref = $user_login_sources{$user};
  
  for my $source (keys(%$hash_ref)) {
    my $ipaddr = ${$hash_ref}{$source};
    
    # Skip IPs we couldn't find from the name and skip if we can't find the country
    my $country;
    if (
      ($ipaddr ne "0.0.0.0") and
      ($country = $geo_ip_object->country_code_by_addr($ipaddr)) and
      ($country ne "US")
    ) {
      print BOLD RED datetime(), "Found non-US source IP: User => $user, IP => $ipaddr, Source => $source\n";
      system("/usr/bin/logger -p user.err -t NOC-NETCOOL-TICKET 'Found non-US source IP: User => $user, IP => $ipaddr, Source => $source'");
    }
  
  }

}


# Check the number of non-whitelisted sources
for my $user (keys(%user_login_sources)) {
  my $hash_ref = $user_login_sources{$user};
  
  # Check how many sources the user has logged in from
  my $num_sources = scalar(keys(%$hash_ref));
  
  # If the user logged in from more than 3 non-whitelisted addresses within 7 days...
  if ($num_sources >= 3) {
    my @sources = keys(%$hash_ref);
    print BOLD RED datetime(), "Found user with logins from multiple sources: User => $user, Sources => @sources\n";
    system("/usr/bin/logger -p user.err -t NOC-NETCOOL-TICKET 'Found user with logins from multiple sources: User => $user, Sources => @sources'");
  }
}
