#!/usr/bin/perl
# 
#====================================================================
# Sim_Core_V1.pl
# Author:    Lukas Swan
# Date:      Aug 2008
# Copyright: Dalhousie University
#
# DESCRIPTION:
# This script is called from the simulation control script (Sim_Control_xx.pl).
# It reads the supplied core number arguement and opens the appropriate file 
# that lists the house directories to be simulated by that core.
# 
# The script determined the house name, changes directories to the appropriate 
# folder (to get RES and XML files right) and then simulates using bps and the 
# automation arguements.

#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;
use CSV;		#CSV-2 (for CSV split and join, this works best)
#use Array::Compare;	#Array-Compare-1.15
#use Switch;
#use threads;		#threads-1.71 (to multithread the program)
#use File::Path;	#File-Path-2.04 (to create directory trees)
use Cwd;		#(to determine current working directory)


#--------------------------------------------------------------------
# Read the input arguments to determine which set of houses to simulate
#--------------------------------------------------------------------
my $core = $ARGV[0];		#store the core input arguments
print "the ARGV says core $core\n";


#--------------------------------------------------------------------
# Declare time and simulation count variables and open the appropriate file with the hse directories to be simulated
#--------------------------------------------------------------------
my $start_time= localtime();	#note the start time of the file generation
my $simulations = 0;		#set a variable to count the simulations
open (HSE_LIST, '<', "../summary_files/hse_list_core_$core.csv") or die ("can't open ../summary_files/hse_list_core_$core");	#open the file


#--------------------------------------------------------------------
# Perform a simulation of each house in the directory list
#--------------------------------------------------------------------
while (<HSE_LIST>) {			#do until the house list is exhausted
	my @folder = CSVsplit($_);	#This split command is required to remove the EOL character so the chdir() works correctly
	$folder[0] =~ /(..........)$/;	#determine the house name (10 digits w/o .HDF), stores in $1
	my $folder_name = $1;		#declare the house name
# 	my $dir = getcwd;
# 	print "$dir\n";
	chdir ($folder[0]);		#change to the appropriate directory for simulation. Need to be in directory for xml output
# 	print "dir $folder[0]; folder $folder_name\n";
# 	my $dir = getcwd;
# 	print "$dir\n";
	system ("bps -mode text -file ./$folder_name.cfg -p default silent");	#call the bps simulator with arguements to automate it
	# rename the xml output files with the house name
	rename ("out.csv", "$folder_name.csv");			
	rename ("out.dictionary", "$folder_name.dictionary");
	rename ("out.summary", "$folder_name.summary");
	rename ("out.xml", "$folder_name.xml");
	chdir ("../../../scripts");	#return to the original working directory
	$simulations++;			#increment the simulations counter
}	#end of the while loop through the simulations


#--------------------------------------------------------------------
# Do a final print of the times and simulations (discover using "tail" command)
#--------------------------------------------------------------------
my $end_time= localtime();
print "start time $start_time; end time $end_time; $simulations simulations\n";