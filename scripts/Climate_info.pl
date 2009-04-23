#!/usr/bin/perl
# 
#====================================================================
# Climate_info.pl
# Author:    Lukas Swan
# Date:      Apr 2009
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl
#
# DESCRIPTION:
# This script gathers info from the ascii CWEC files located in folder
# ../climate/clm-dat_Canada


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
# Identify the house folders for simulation
#--------------------------------------------------------------------
my @climates;	#declare an array to store the path to each climate

push (@climates, <../climate/clm-dat_Canada/*>);	# read all climate directories and store them in the array

print "@climates\n";

#--------------------------------------------------------------------
# Find and print climate info
#--------------------------------------------------------------------

open (CLM_INFO, '>', "../climate/CWEC_info.csv") or die ("can't open ../climate/CWEC_info.csv");	#open the file to print the info
print CLM_INFO "CWEC_FILE,CWEC_CITY,CWEC_PROVINCE,CWEC_YEAR,CWEC_LATITUDE,CWEC_LONGITUDE_DIFF,CWEC_RAD_FLAG\n";

foreach my $climate (@climates) {
	open (CLM, '<', $climate) or die ("can't open $climate");	#open the climate data file
	($climate) = ($climate =~ /(can_\w*\.cwec)/);

	foreach (1..9) {$_ = <CLM>;};	# strip lines until we reach desired info

	$_ = <CLM>;
	$_ =~ s/#.*$//;
	@_ = split;
	print CLM_INFO "$climate,\"";	# print the climate file
	
	if ($#_ > 0) {
		foreach my $element (0..$#_-1) {print CLM_INFO "$_[$element] ";};	# print the city
		print CLM_INFO "\",$_[$#_],";	# print the province
	}
	else {print CLM_INFO "$_[0]\",-,";};	# print the province

	$_ = <CLM>;
	@_ = split;
	print CLM_INFO "$_[0],$_[1],$_[2],$_[3]\n";	#print the year, lat, long diff, rad flag

	close CLM;		#close the climate
};

close CLM_INFO;	# close the info list
