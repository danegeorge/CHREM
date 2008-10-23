#!/usr/bin/perl
# 
#====================================================================
# Sim_Control.pl
# Author:    Lukas Swan
# Date:      Aug 2008
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all] [cores/start_core/end_core]
# Use start and end cores to evenly divide the houses between two machines (e.g. QC2 would be [16/9/16])
#
# DESCRIPTION:
# This script divides the desired house simulations up to match the CPU cores 
# and then intiates the simulations. The script reads the directories based on 
# the house type (SD or DR) and # region (AT, QC, OT, PR, BC). Which types and 
# regions are generated is specified at the beginning of the script to allow for 
# partial generation.
# 
# The script adds the list of houses to an array and then divides the array by the
# total number of CPU cores used for simulation. It then writes text files with 
# the paths for each house that the simulator will follow and then simulate.
# 
# The script then calls another simulating script using the nohup command to account
# for chdir() and background simulation requirements as detailed below. This script 
# quickly ends, leaving the appropriate simulating scripts running.


#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;
#use CSV;		#CSV-2 (for CSV split and join, this works best)
#use Array::Compare;	#Array-Compare-1.15
#use Switch;
#use threads;		#threads-1.71 (to multithread the program)
#use File::Path;	#File-Path-2.04 (to create directory trees)
#use File::Copy;	#(to copy the input.xml file)


#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
if ($#ARGV != 2) {die "Three arguments are required: house_types regions core_information\n";};

my @hse_types;					# declare an array to store the desired house types
my %hse_names = (1, "SD", 2, "DR");		# declare a hash with the house type names
if ($ARGV[0] eq "0") {@hse_types = (1, 2);}	# check if both house types are desired
else {
	@hse_types = split (/\//,$ARGV[0]);	#House types to generate
	foreach my $type (@hse_types) {
		unless (defined ($hse_names{$type})) {
			my @keys = sort {$a cmp $b} keys (%hse_names);
			die "House type argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
		};
	};
};

my @regions;									#Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");
if ($ARGV[1] eq "0") {@regions = (1, 2, 3, 4, 5);}
else {
	@regions = split (/\//,$ARGV[1]);	#House types to generate
	foreach my $region (@regions) {
		unless (defined ($region_names{$region})) {
			my @keys = sort {$a cmp $b} keys (%region_names);
			die "Region argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
		};
	};
};

my @core_input = split (/\//,$ARGV[2]);
if ($#core_input != 2) {die "CORE argument requires three numeric values seperated by a \"/\": #_of_cores/low_core_#/high_core_#\n"};
foreach my $core_value (@core_input) {
	unless ($core_value >= 1) {
		die "CORE argument requires three numeric values seperated by a \"/\": #_of_cores/low_core_#/high_core_#\n";
	};
};
my $cores = $core_input[0]; 	#total number of cores (if only using a single QC (quad-core) then 8, if using two QCs then 16
my $low_core = $core_input[1];	#starting core, if using two QCs then the first QC has a 1 and the second QC has a 9
my $high_core = $core_input[2];	#ending core, value is 8 or 16 depending on machine


#--------------------------------------------------------------------
# Identify the house folders for simulation
#--------------------------------------------------------------------
my @folders;	#declare an array to store the path to each hse which will be simulated

foreach my $hse_type (@hse_types) {		#each house type
	foreach my $region (@regions) {		#each region
	push (@folders, <../$hse_type-$hse_names{$hse_type}/$region_names{$region}/*>);	#read all hse directories and store them in the array
	}
}


#--------------------------------------------------------------------
# Determine how many houses go to each core for core usage balancing
#--------------------------------------------------------------------
my $interval = int(@folders/$cores) + 1;	#round up to the nearest integer


#--------------------------------------------------------------------
# Generate and print lists of directory paths for each core to simulate
#--------------------------------------------------------------------
foreach my $core (1..$cores) {
	my $low_element = ($core - 1) * $interval;	#hse to start this particular core at
	my $high_element = $core * $interval - 1;	#hse to end this particular core at
	if ($core == $cores) { $high_element = $#folders};	#if the final core then adjust to end of array to account for rounding process
	open (HSE_LIST, '>', "../summary_files/hse_list_core_$core.csv") or die ("can't open ../summary_files/hse_list_core_$core.csv");	#open the file to print the list for the core
	foreach my $element ($low_element..$high_element) {
		print HSE_LIST "\"$folders[$element]\"\n";	#print the hse path to the list
	}
	close HSE_LIST;		#close the particular core list
};


#--------------------------------------------------------------------
# Call the simulations.
# This is done using the nohup command for two reasons:
# 1) chdir() cannot be used with multi-threading as they all have the same 
# current working directory. "bps" must be run in the directory to eliminate issues
# with the res file looking in the wrong director and the xml files being generated 
# in the top level directory
# 2) nohup allows for the shutdown of the remote terminal and the continuation of the
# simulation. This is very important as the simulation may take a long time. It also 
# records all the screen output of the simulations. Note - as the simulations have 
# been released as their own, to kill them requires that each (# of cores) perl script 
# (Sim_Core_V1.pl) is killed and then either let the bps finish that house or kill it 
# as well
#--------------------------------------------------------------------
print "THE HOUSE LISTINGS FOR EACH CORE TO SIMULATE ARE LOCATED IN ../summary_files/hse_list_core_X.csv\n";
print "THE HOUSE SIMULATION OUTPUT FROM EACH CORE IS LOCATED IN ../summary_files/sim_output_core_X.txt\n";
foreach my $core ($low_core..$high_core) {	#simulate the appropriate list (i.e. QC2 goes from 9 to 16)
	system ("nohup ./Core_Sim.pl $core > ../summary_files/sim_output_core_$core.txt &");	#call nohup of simulation program script and pass the argument $core so the program knows which set to simulate
} 
print "THE HOUSE LISTINGS FOR EACH CORE TO SIMULATE ARE LOCATED IN ../summary_files/hse_list_core_X.csv\n";
print "THE HOUSE SIMULATION OUTPUT FROM EACH CORE IS LOCATED IN ../summary_files/sim_output_core_X.txt\n";
