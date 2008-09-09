#!/usr/bin/perl
# 
#====================================================================
# V1.pl
# Author:    Lukas Swan
# Date:      June 2008
# Copyright: Dalhousie University
#
# Requirements
#
# DEPENDENCIES:
# ???
#--------------------------------------------------------------------

#--------------------------------------------------------------------

#===================================================================

use warnings;
use strict;
use CSV;		#CSV-2 (for CSV split and join, this works best)
use Array::Compare;	#Array-Compare-1.15
use Switch;
use threads;		#threads-1.71 (to multithread the program)
use File::Path;		#File-Path-2.04 (to create directory trees)

#--------------------------------------------------------------------
# Prototypes
#--------------------------------------------------------------------
#sub xxx();

#--------------------------------------------------------------------
# Declare importnat variables and defaults
#--------------------------------------------------------------------
my @hse_types = (2);							#House types to generate
my %hse_names = (1, "SD", 2, "DR");

my @regions = (1);							#Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");
#--------------------------------------------------------------------
# Done
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# Intiate by multi-threading to run each region simulataneously
#--------------------------------------------------------------------
my @thread;		#Declare threads
my @thread_return;	#Declare a return array for collation of returning thread data

foreach my $hse_type (@hse_types) {								#Multithread for each house type
	foreach my $region (@regions) {								#Multithread for each region
		$thread[$hse_type][$region] = threads->new(\&main, $hse_type, $region); 	#Spawn the thread
	}
}
foreach my $hse_type (@hse_types) {
	foreach my $region (@regions) {
		$thread_return[$hse_type][$region] = [$thread[$hse_type][$region]->join()];	#Return the threads together for info collation
	}
}

#--------------------------------------------------------------------
# Main code that each thread evaluates
#--------------------------------------------------------------------

sub main () {
	my $hse_type = $_[0];		#house type number for the thread
	my $region = $_[1];		#region number for the thread
	print "hse_type = $hse_type; region = $region\n";
	#Examine the data source files from the CSDDRD
	my $input_path = "../$hse_type-$hse_names{$hse_type}/$region_names{$region}";	#path to the correct CSDDRD type and region folder
	print "$input_path\n";
	my @folders = <$input_path/*>;
	print "@folders\n";

	#-----------------------------------------------
	# Go through each folder and conduct a simulation
	#-----------------------------------------------
	foreach my $folder (@folders) {
		my $folder_name = $folder;
		$folder_name =~ s/$input_path\///;
		chdir ($folder);
		system ("bps -mode text -file $folder_name.cfg -p default silent");
		rename ("out.csv", "$folder_name.csv");
		rename ("out.dictionary", "$folder_name.dictionary");
		rename ("out.xml", "$folder_name.xml");
		chdir ("../../../scripts");
	}	#end of the while loop through the simulations
}	#end of main code

