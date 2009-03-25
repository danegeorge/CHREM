#!/usr/bin/perl
# 
#====================================================================
# Core_Sim.pl
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
open (HSE_LIST, '<', "../summary_files/hse_list_core_$core.csv") or die ("can't open ../summary_files/hse_list_core_$core.csv");	#open the file


#--------------------------------------------------------------------
# Perform a simulation of each house in the directory list
#--------------------------------------------------------------------
SIMULATION: {
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

		open (CFG, '<', "./$folder_name.cfg") or die ("can't open ./$folder_name.cfg");	#open the cfg file to check for isi
		my @month;
		SEARCH: while (<CFG>) {
			if ($_ =~ /^#SIM_PRESET_LINE2/) {	# find the simulation months line
				@month = split (/\s/, <CFG>);	# split and store the start day/month and end day/month
				print "month begin: $month[1]; month end: $month[3]\n";
			}
			elsif ($_ =~ /^\*isi/) {
				system ("ish -mode text -file ./$folder_name.cfg -zone main -month_begin $month[1] -month_end $month[3] -act update_silent");	# call the ish shading and insolation analyzer
				last SEARCH;
			};
		};
		close CFG;

		system ("bps -mode text -file ./$folder_name.cfg -p sim_presets silent");	#call the bps simulator with arguements to automate it
		# rename the xml output files with the house name
		rename ("out.csv", "$folder_name.csv");			
		rename ("out.dictionary", "$folder_name.dictionary");
		rename ("out.summary", "$folder_name.summary");
		rename ("out.xml", "$folder_name.xml");

		open (SUMMARY, '<', "./$folder_name.summary") or die ("can't open ./$folder_name.summary");     #open the summary file to reorder it
		my $results;
		while (<SUMMARY>) {
		# Lukas/zone_01/active_cool::Total_Average -311.102339 (W)
		# Lukas/MCOM::Minimum 28.000000 (#)
		#       if ($_ =~ /(.*)::(\w*)\s*(\w*\.\w*)\s*(\(.*\))/) {
			my @split = split (/::|\s/, $_);
			$results->{$split[0]}->{$split[1]} = [$split[2], $split[3]];
		# 	};
		};
		close SUMMARY;
# 		print Dumper ($results);

		open (DICTIONARY, '<', "./$folder_name.dictionary") or die ("can't open ./$folder_name.dictionary");     #open the dictionary file to cross reference
		my $parameter;
		while (<DICTIONARY>) {
		# "Lukas/zone_01/active_cool","active cooling required by zone","(W)"
			$_ =~ /"(.*)","(.*)","(.*)"/;
			$parameter->{$1}->{'description'} = $2;
			$parameter->{$1}->{'units'} = $3;
		};
		# print Dumper ($parameter);
		close DICTIONARY;

		open (RESULTS, '>', "./$folder_name.results") or die ("can't open ./$folder_name.results");     #open the a results file to write out the organized summary results
		printf RESULTS ("%10s %10s %10s %10s %10s %10s %10s %-50s %-s\n", 'Integrated', 'Int units', 'Total Avg', 'Active avg', 'Min', 'Max', 'Units', 'Name', 'Description');

		my @keys = sort {$a cmp $b} keys (%{$results});  # sort results
		my @values = ('AnnualTotal', 'Total_Average', 'Active_Average', 'Minimum', 'Maximum');
		foreach my $key (@keys) {
			foreach (@values) {unless (defined ($results->{$key}->{$_})) {$results->{$key}->{$_} = ['0', '-']};};
			printf RESULTS ("%10.2f %10s %10.2f %10.2f %10.2f %10.2f %10s %-50s %-s\n",
				$results->{$key}->{$values[0]}->[0],
				$results->{$key}->{$values[0]}->[1],
				$results->{$key}->{$values[1]}->[0],
				$results->{$key}->{$values[2]}->[0],
				$results->{$key}->{$values[3]}->[0],
				$results->{$key}->{$values[4]}->[0],
				$results->{$key}->{$values[4]}->[1],
				$key,
				$parameter->{$key}->{'description'});
		};
		close RESULTS;
            
		chdir ("../../../scripts");	#return to the original working directory
		$simulations++;			#increment the simulations counter
	}	#end of the while loop through the simulations
};

#--------------------------------------------------------------------
# Do a final print of the times and simulations (discover using "tail" command on ../summary_files/sim_output_core_X.txt)
#--------------------------------------------------------------------
my $end_time= localtime();
print "start time $start_time; end time $end_time; $simulations simulations\n";