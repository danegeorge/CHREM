#!/usr/bin/perl
# 
#====================================================================
# CSDDRD_CSV_assemble.pl
# Author:    Lukas Swan
# Date:      Dec 2008
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all] [cores/start_core/end_core]
#
# DESCRIPTION:
# This script simply assembles the specified type and regions files of the
# CSDDRD into a larger CSV file for use with a spreadsheet program for
# filtering and range check purposes.


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
# Declare the global variables
#--------------------------------------------------------------------
my @hse_types;					# declare an array to store the desired house types
my %hse_names = (1, "1-SD", 2, "2-DR");		# declare a hash with the house type names

my @regions;									#Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if ($#ARGV != 1) {die "Two arguments are required: house_types regions\n";};
	
	if ($ARGV[0] eq "0") {@hse_types = (1, 2);}	# check if both house types are desired
	else {
		@hse_types = split (/\//,$ARGV[0]);	# House types to generate
		foreach my $type (@hse_types) {
			unless (defined ($hse_names{$type})) {
				my @keys = sort {$a cmp $b} keys (%hse_names);
				die "House type argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
			};
		};
	};
	
	if ($ARGV[1] eq "0") {@regions = (1, 2, 3, 4, 5);}
	else {
		@regions = split (/\//,$ARGV[1]);	# House regions to generate
		foreach my $region (@regions) {
			unless (defined ($region_names{$region})) {
				my @keys = sort {$a cmp $b} keys (%region_names);
				die "Region argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
			};
		};
	};
};

open (HSE_LIST, '>', "../CSDDRD/CSDDRD_CSV_assemble_window.csv") or die ("can't open ../CSDDRD/CSDDRD_CSV_assemble_window.csv");	#open the file to print the list
my $indicator = 0;

foreach my $hse_type (@hse_types) {
	foreach my $region (@regions) {
		open (DATA, '<', "../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_$hse_names{$hse_type}_subset_$region_names{$region}.window.csv") or die ("can't open ../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_$hse_names{$hse_type}_subset_$region_names{$region}.window.csv");	# open the type/region data file
		$_ = <DATA>;	# strip the first line
		if ($indicator == 0) {print HSE_LIST "$_"; $indicator++;}; # if indicator is zero print the header row, then alter the indicator
		while (<DATA>) { print HSE_LIST "$_";};	# print each line of the data file
		close DATA;		# close the type/region data file
	};
};

close HSE_LIST;