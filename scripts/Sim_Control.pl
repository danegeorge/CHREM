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
use Data::Dumper;

use lib ('./modules');
use General;

#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------
my $hse_types;	# declare an hash array to store the house types to be modeled (e.g. 1 -> 1-SD)
my $regions;	# declare an hash array to store the regions to be modeled (e.g. 1 -> 1-AT)
my $cores;
#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if ($#ARGV != 2) {die "Three arguments are required: house_types regions core_information\n";};
	
	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
	($hse_types, $regions) = hse_types_and_regions(@ARGV[0..1]);

	# Check the cores arguement which should be three numeric values seperated by a forward-slash
	unless ($ARGV[2] =~ /^(\d+)\/(\d+)\/(\d+)$/) {
		die ("CORE argument requires three Positive numeric values seperated by a \"/\": #_of_cores/low_core_#/high_core_#\n");
	};
	
	# set the core information
	# 'num' is total number of cores (if only using a single QC (quad-core) then 8, if using two QCs then 16
	# 'low' is starting core, if using two QCs then the first QC has a 1 and the second QC has a 9
	# 'high' is ending core, value is 8 or 16 depending on machine
	@{$cores}{'num', 'low', 'high'} = ($1, $2, $3);
	
	# check the core infomration for validity
	unless (
		$cores->{'num'} >= 1 &&
		($cores->{'high'} - $cores->{'low'}) >= 0 &&
		($cores->{'high'} - $cores->{'low'}) <= $cores->{'num'} &&
		$cores->{'low'} >= 1 &&
		$cores->{'high'} <= $cores->{'num'}
		) {
		die ("CORE argument numeric values are inappropriate (e.g. high_core > #_of_cores)\n");
	};
	
};

#--------------------------------------------------------------------
# Identify the house folders for simulation
#--------------------------------------------------------------------
my @folders;	#declare an array to store the path to each hse which will be simulated

foreach my $hse_type (sort {$a cmp $b} values (%{$hse_types})) {		#each house type
	foreach my $region (sort {$a cmp $b} values (%{$regions})) {		#each region
	push (@folders, <../$hse_type/$region/*>);	#read all hse directories and store them in the array
	};
};

# print Dumper @folders;

#--------------------------------------------------------------------
# Determine how many houses go to each core for core usage balancing
#--------------------------------------------------------------------
my $interval = int(@folders/$cores->{'num'}) + 1;	#round up to the nearest integer


#--------------------------------------------------------------------
# Generate and print lists of directory paths for each core to simulate
#--------------------------------------------------------------------
SIMULATION_LIST: {
	foreach my $core (1..$cores->{'num'}) {
		my $low_element = ($core - 1) * $interval;	#hse to start this particular core at
		my $high_element = $core * $interval - 1;	#hse to end this particular core at
		if ($core == $cores->{'num'}) { $high_element = $#folders};	#if the final core then adjust to end of array to account for rounding process
		open (HSE_LIST, '>', "../summary_files/House_List_for_Core_$core.csv") or die ("can't open ../summary_files/House_List_for_Core_$core.csv");	#open the file to print the list for the core
		foreach my $element ($low_element..$high_element) {
			print HSE_LIST "$folders[$element]\n";	#print the hse path to the list
		}
		close HSE_LIST;		#close the particular core list
	};
};



#--------------------------------------------------------------------
# Call the simulations.
#--------------------------------------------------------------------
SIMULATION: {
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

	foreach my $core ($cores->{'low'}..$cores->{'high'}) {	#simulate the appropriate list (i.e. QC2 goes from 9 to 16)
		system ("nohup ./Core_Sim.pl $core > ../summary_files/Core_Sim_Output_for_Core_$core.txt &");	#call nohup of simulation program script and pass the argument $core so the program knows which set to simulate
	} 
	print "THE HOUSE LISTINGS FOR EACH CORE TO SIMULATE ARE LOCATED IN ../summary_files/House_List_for_Core_X.csv\n";
	print "THE HOUSE SIMULATION OUTPUT FROM EACH CORE IS LOCATED IN ../summary_files/Core_Sim_Output_for_Core_X.txt\n";
};
