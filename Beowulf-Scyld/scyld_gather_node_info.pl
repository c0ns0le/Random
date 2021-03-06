#!/opt/sam/perl/5.16.0/gcc41/bin/perl
#!/usr/bin/env perl
use strict;
use warnings;
# Description: Gather info (CPU cores, RAM amount, etc.) of compute nodes
# Written by: Jeff White of the University of Pittsburgh (jaw171@pitt.edu)
# Version: 1.2
# Last change: Fixed a bug in finding the number of CPU cores, added more RAM amount mappings, added
# mappings for /scratch size

# License
# This script is released under version three of the GNU General Public License (GPL) of the 
# Free Software Foundation (FSF), the text of which is available at http://www.fsf.org/licensing/licenses/gpl-3.0.html.
# Use or modification of this script implies your acceptance of this license and its terms.
# This is a free script, you are free to change and redistribute it with the terms of the GNU GPL.
# There is NO WARRANTY, not even for FITNESS FOR A PARTICULAR USE to the extent permitted by law.

# The output for each node is: Node,MAC #1,MAC #2,CPU Type,CPU Cores,GPU?,IB?,Scratch Disk (GB),RAM (GB),Ethernet IP,Serial

use Getopt::Long;
Getopt::Long::Configure("bundling");

# Don't change these
$| = 0;

GetOptions('h|help' => \my $helpopt,
           's|sum' => \my $sum,
          ) || die "Invalid usage, use -h for help.\n";

if ($helpopt) {
  print "Gather info (CPU cores, RAM amount, etc.) of compute nodes.\n";
  print "Run this script via beorun to get the node details via STDOUT.\n";
  print "License: GNU General Public License (GPL) v3.\n\n";
  print "Usage: $0 [options]\n"; 
  print "-h | --help : Show this help\n";
  print "-s | --sum : Display sums (total CPU count, etc.) of a CSV generated by this script via STDIN\n\n";
  print "Example:\n";
  print "beorun --all-nodes --nolocal $0 | $0 -s\n";
  print "  RAM (GB): 4224\n";
  print "  CPU core count: 2624\n";
  print "  Scratch disk (GB): 85194.64\n";
  exit;
}

#
# Print the sum if we were asked to
#
if ($sum) {
  
  my %totals;
  $totals{"CPU core count"} = 0;
  $totals{"Scratch disk"} = 0;
  $totals{"RAM"} = 0;
  
  # Get the totals from the input
  for my $line (<>) {
    my ($cpu_cores, $scratch, $ram) = (split(m/,/, $line))[4,7,8];
    
    $cpu_cores =~ s/ CPU cores$//;
    $scratch =~ s/G \/scratch$//;
    $ram =~ s/G RAM$//;
    
    $totals{"CPU core count"} = $totals{"CPU core count"} + $cpu_cores;
    $totals{"RAM"} = $totals{"RAM"} + $ram;
    $totals{"Scratch disk"} = $totals{"Scratch disk"} + $scratch;
  }

  # Print the totals we gathered
  print "CPU Cores: $totals{'CPU core count'}\n";
  print "RAM: ", sprintf("%.2f", $totals{'RAM'} / 1024), " TB\n";
  print "Scratch Disk: ", sprintf("%.2f", $totals{'Scratch disk'} / 1024), " TB\n";
  
  exit;
}


#
# Node number
#
my $hostname = `hostname`;
chomp $hostname;

# Are we on a compute node?
die "Not running on a compute node..." unless ($hostname =~ m/^n\d/);

print "$hostname,";


#
# MAC of eth0
#
open(my $ETH0_MAC_FILE, "<", "/sys/class/net/eth0/address");
my $eth0_mac = <$ETH0_MAC_FILE>;
close $ETH0_MAC_FILE;

chomp $eth0_mac;
print "$eth0_mac,";


#
# MAC of eth1
#
open(my $ETH1_MAC_FILE, "<", "/sys/class/net/eth1/address");
my $eth1_mac = <$ETH1_MAC_FILE>;
close $ETH1_MAC_FILE;

chomp $eth1_mac;
print "$eth1_mac,";


#
# Type of CPU
#
open(my $CPU_INFO_FILE, "<", "/proc/cpuinfo");
my @cpu_info = <$CPU_INFO_FILE>;
close $CPU_INFO_FILE;

for my $line (@cpu_info) {
  chomp $line;
  
  # Skip everything except the model name
  next unless ($line =~ m/^model name/);
  
  my $cpu_model = $line;
  $cpu_model =~ s/^model name\s+:\s+//;
  $cpu_model =~ s/\s\s+/ /g;
  
  print "$cpu_model,";
  
  last;
}


#
# Number of CPU cores
#
my %physical_ids = map{
  my $phys_id = (split(m/\s+/))[3];
  $phys_id => 1;
} grep(m/^physical id/, @cpu_info);

my $num_physical_cpus = scalar(keys(%physical_ids));

# If it looks like a multi-core CPU...
if (grep(m/^siblings/, @cpu_info)) {

  for my $line (@cpu_info) {
    chomp $line;
    
    # Skip everything except the "cpu cores" line
    next unless ($line =~ m/^cpu cores/);
    
    my $num_cores = (split(m/\s+/, $line))[3];
    
    # This assumes all CPUs have the same number of cores
    # This should also not count any "extra" hyper-threading cores
    print $num_physical_cpus * $num_cores, ",";
    
    last;
  }

}
else {
  print "$num_physical_cpus,";
}


#
# GPU found?
#
if (grep(m/^nvidia/, `lsmod`)) {
  print "Yes,";
}
else {
  print "No,";
}


#
# Infiniband found?
#
if (-d "/sys/class/net/ib0") {
  print "Yes,";
}
else {
  print "No,";
}


#
# Amount of scratch disk
#
my @df_out = `df -kP /scratch`;
if ($df_out[1]) {
  my $scratch_size = (split(m/\s+/, $df_out[1]))[1];
  $scratch_size = sprintf("%.2f", $scratch_size / 1024 / 1024);
  
#   # Ugly but it works
#   if (($scratch_size == 905.89) or ($scratch_size == 905.63) or ($scratch_size == 872.38)) {
#     $scratch_size = 1000;
#   }
#   elsif (($scratch_size == 1822.77) or ($scratch_size == 1830.02)) {
#     $scratch_size = 2000;
#   }
#   elsif (($scratch_size == 228.20) or ($scratch_size == 230.08) or (206.69)) {
#     $scratch_size = 250;
#   }
#   elsif ($scratch_size == 684.77) {
#     $scratch_size = 750;
#   }
#   elsif (($scratch_size == 144.79) or (144.82)) {
#     $scratch_size = 160;
#   }
#   elsif ($scratch_size == 2640.68) {
#     $scratch_size = 2880;
#   }
#   elsif ($scratch_size == 2738.20) {
#     $scratch_size = 2995;
#   }
  
  print "${scratch_size}G /scratch,";  
}
else {
  print "0G /scratch,";
}


#
# Amount of RAM
#
open(my $MEMINFO_FILE, "<", "/proc/meminfo");
for my $line (<$MEMINFO_FILE>) {
  chomp $line;

  # Skip everything except the memtotal
  next unless ($line =~ m/^MemTotal:\s+(\d+)/);
  
  # Convert to GB and slice off all but two decimal points
  my $memtotal = sprintf("%.2f", $1 / 1024 / 1024);
  
#   # Ugly but it works...
#   if (($memtotal == 125.36) or ($memtotal == 125.98) or ($memtotal == 126.14) or
#   ($memtotal == 126.16) or ($memtotal == 125.55) or ($memtotal == 126.15)) {
#     $memtotal = 128;
#   }
#   elsif (($memtotal == 109.58) or ($memtotal == 109.77)) {
#     $memtotal = 112;
#   }
#   elsif (($memtotal == 118.09) or ($memtotal == 118.27)) {
#     $memtotal = 120;
#   }
#   elsif (($memtotal == 5.87) or ($memtotal == 5.82)) {
#     $memtotal = 6
#   }
#   elsif ($memtotal == 4.84) {
#     $memtotal = 5;
#   }
#   elsif (($memtotal == 47.16) or ($memtotal == 47.14) or ($memtotal == 47.26)) {
#     $memtotal = 48;
#   }
#   elsif (($memtotal == 252.04) or ($memtotal == 252.41)) {
#     $memtotal = 256;
#   }
#   elsif (($memtotal == 62.95) or ($memtotal == 63.02) or ($memtotal == 63.04)) {
#     $memtotal = 64;
#   }
#   elsif (($memtotal == 11.72) or ($memtotal == 11.75)) {
#     $memtotal = 12;
#   }
#   elsif (($memtotal == 23.53) or ($memtotal == 23.59) or ($memtotal == 23.58) or 
#   ($memtotal == 23.59)) {
#     $memtotal = 24;
#   }
#   elsif (($memtotal == 19.59) or ($memtotal == 19.64)) {
#     $memtotal = 20;
#   }
#   elsif ($memtotal == 7.80) {
#     $memtotal = 8;
#   }
#   elsif ($memtotal == 15.67) {
#     $memtotal = 16;
#   }
#   elsif ($memtotal == 13.70) {
#     $memtotal = 14;
#   }
#   elsif ($memtotal == 31.46) {
#     $memtotal = 32;
#   }
#   elsif ($memtotal == 9.78) {
#     $memtotal = 10;
#   }
#   elsif ($memtotal == 27.52) {
#     $memtotal = 28;
#   }
  
  print "${memtotal}G RAM,";
}


#
# Ethernet IP
#
for my $line (`ip addr list dev eth0`){
  chomp $line;
  
  # Skip everything except the IP address
  next unless ($line =~ m/^\s+inet /);
  
  my $ip_address = (split(m/\s+/, $line))[2];
  
  # Remove the netmask
  $ip_address =~ s|/\d+||;
  
  print "$ip_address,";
}


#
# Serial
#
my $serial = `dmidecode -s system-serial-number`;

if ($serial) {
  print "$serial\n";
}
else {
  print "Unknown\n";
}