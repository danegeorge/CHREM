#!/usr/bin/perl
# 
#====================================================================
# Climate_site_name_update.pl
# Author:    Lukas Swan
# Date:      Apr 2009
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl
#
# DESCRIPTION:
# This script updates ascii CWEC files located in folder
# ../climate/clm-dat_Canada


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

open (CLM_INFO, '<', "../climate/CWEC_info_organized.csv") or die ("can't open ../climate/CWEC_info_organized.csv");	#open the file with organized CWEC info

my $info;

while (<CLM_INFO>) {
	@_ = CSVsplit($_);
	$info->{$_[0]} = [@_[1..$#_]];
};

close CLM_INFO;


foreach my $climate (@climates) {
	my $i = 1;	
	open (CLM, '<', $climate) or die ("can't open $climate");	#open the climate data file
	open (CLM2, '>', "$climate.2") or die ("can't open $climate.2");	#open the climate data file
	my $climate_name = $climate;
	$climate_name =~ s/^.+(can_\w*\.cwec).a/$1/;

	print "$climate\n";

	while (<CLM>) {

		if ($i == 10) { printf CLM2 ("%-32s%s\n", "$info->{$climate_name}->[0], $info->{$climate_name}->[1]", '# site name');}
		else { print CLM2 "$_";};
		$i++;
	};
	
	close CLM;
	close CLM2;
};

foreach my $climate (@climates) {
	system ("mv $climate.2 $climate");
};
