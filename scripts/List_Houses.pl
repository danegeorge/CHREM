#!/usr/bin/perl

# ====================================================================
# List_Houses.pl
# Author: Lukas Swan
# Date: Aug 2009
# Copyright: Dalhousie University

# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"] [list of desired CSDDRD parameters, can also use hse_type and region]

# DESCRIPTION:
# This script generates a list of the houses with parameters. If no 
# parameters are listed, then only the Filename is printed.

# ===================================================================

# --------------------------------------------------------------------
# Declare modules which are used
# --------------------------------------------------------------------

use warnings;
use strict;

use CSV;	# CSV-2 (for CSV split and join, this works best)
# use Array::Compare;	# Array-Compare-1.15
use threads;	# threads-1.71 (to multithread the program)
# use File::Path;	# File-Path-2.04 (to create directory trees)
# use File::Copy;	# (to copy the input.xml file)
# use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
use Data::Dumper;

use CHREM_modules::General ('hse_types_and_regions', 'one_data_line');
# use CHREM_modules::Cross_ref ('cross_ref_readin', 'key_XML_readin');
# use CHREM_modules::Database ('database_XML');

# --------------------------------------------------------------------
# Declare the global variables
# --------------------------------------------------------------------

my $hse_types;	# declare an hash array to store the house types to be modeled (e.g. 1 -> 1-SD)
my $regions;	# declare an hash array to store the regions to be modeled (e.g. 1 -> 1-AT)

my @desired_parameters;	# array to store the desired parameters to be printed

# --------------------------------------------------------------------
# Read the command line input arguments
# --------------------------------------------------------------------

COMMAND_LINE: {

	if ($#ARGV < 1) {die "Minimum Two arguments are required: house_types regions; followed by desired parameters\n";};	# check for proper argument count

	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
	($hse_types, $regions) = hse_types_and_regions(@ARGV[0..1]);

	# check to see that desired parameters have been passed and if so store them
	if ($#ARGV > 1) {
		@desired_parameters = @ARGV[2..$#ARGV];
	};
};


# --------------------------------------------------------------------
# Initiate multi-threading to run each region simulataneously
# --------------------------------------------------------------------

MULTI_THREAD: {

	# The dictionary of available parameters must only be written once, even though we are multi-threading. So to do a check for its existance, we must first unlink it so that a new copy is generated for each run
	my $unlink_path = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_COMBINED_subset_COMBINED_Dictionary.csv';
	unlink ($unlink_path);


	print "Multi-threading for each House Type and Region : please be patient\n";
	
	my $thread;	# Declare threads for each type and region
	my $house_info_compiled; # storage hash reference to store all of the house information from all the hse_types and regions
	
	foreach my $hse_type (values (%{$hse_types})) {	# Multithread for each house type
		foreach my $region (values (%{$regions})) {	# Multithread for each region
			# Add the particular hse_type and region to the pass hash ref
			my $pass = {'hse_type' => $hse_type, 'region' => $region};
			$thread->{$hse_type}->{$region} = threads->new(\&main, $pass);	# Spawn the threads and send to main subroutine
		};
	};
	
	foreach my $hse_type (values (%{$hse_types})) {	# return for each house type
		foreach my $region (values (%{$regions})) {	# return for each region type
			
			# retrieve the threads information and temporarily store it at house_info
			my $house_info = $thread->{$hse_type}->{$region}->join();
# 			print Dumper $house_info;
			
			# go through each house and store the information into the compiled hash for later use
			foreach my $house (keys %{$house_info}) {
				# generate the hash key here, as no parameters may be specified, but we still want to print the house name
				$house_info_compiled->{$house} = {};
				foreach my $parameter (keys %{$house_info->{$house}}) {
					$house_info_compiled->{$house}->{$parameter} = $house_info->{$house}->{$parameter};
				};
			};
		};
	};
	
# 	print Dumper $house_info_compiled;

	# open a file to print out the compiled list
	my $path = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_COMBINED_subset_COMBINED_Data.csv';
	open (my $CSDDRD_FILE, '>', $path) or die ("can't open datafile: $path");
	
	# print a header onto the file (note use of concatenation)
	print $CSDDRD_FILE CSVjoin ('Filename', @desired_parameters) . "\n";

	# print the desired parameters and house name for each house (sorted)
	foreach my $house (sort {$a cmp $b} keys (%{$house_info_compiled})) {
		print $CSDDRD_FILE CSVjoin ($house, @{$house_info_compiled->{$house}}{@desired_parameters}) . "\n";
	};
	
	close $CSDDRD_FILE;

	print "PLEASE CHECK $path FOR THE HOUSE NAME LISTING\n";	# tell user to go look
};

# --------------------------------------------------------------------
# Main code that each thread evaluates
# --------------------------------------------------------------------

MAIN: {
	sub main () {
		my $pass = shift;	# the hash reference that contains all of the information

		my $hse_type = $pass->{'hse_type'};	# house type number for the thread
		my $region = $pass->{'region'};	# region number for the thread


		# -----------------------------------------------
		# Open the CSDDRD source
		# -----------------------------------------------
		# Open the data source files from the CSDDRD - path to the correct CSDDRD type and region file
		my $input_path = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_type . '_subset_' . $region;
		open (my $CSDDRD_FILE, '<', "$input_path.csv") or die ("can't open datafile: $input_path.csv");	# open the correct CSDDRD file to use as the data source

		my $CSDDRD; # declare a hash reference to store the CSDDRD data. This will only store one house at a time and the header data

		my $house_info; # declare a hash reference to store the desired information of all of the houses
		
		# -----------------------------------------------
		# GO THROUGH EACH LINE OF THE CSDDRD SOURCE DATAFILE AND STORE INFO
		# -----------------------------------------------
		
		# this is a temporary storage variable for the house data prior to storing it at $CSDDRD. This was required because we are printing a dictionary using the last valid CSDDRD house. But because of the way the while loop is written below, it was cycling until the 'one_data_line' returned false and if this was directly stored in the CSDDRD there would be no dictionary data remaining
		my $house;
		
		while ($house = one_data_line($CSDDRD_FILE, $CSDDRD)) {	# go through each line (house) of the file
			
			$CSDDRD = $house;	# migrate the data to CSDDRD
			
			# the CSDDRD does not list hse_type and region in the same format as we use, so this creates such a data structure for use with @desired_parameters
			$CSDDRD->{'hse_type'} = $hse_type;
			$CSDDRD->{'region'} = $region;

			# initialize the file so that the filename exists even if there are no other desired parameters
			$house_info->{$CSDDRD->{'file_name'}} = {};

			# cycle through the desired parameters and store the data for the house in the cumulative storage variable
			foreach my $parameter (@desired_parameters) {
				if (defined ($CSDDRD->{$parameter})) {
					$house_info->{$CSDDRD->{'file_name'}}->{$parameter} = $CSDDRD->{$parameter};
				}
				
				# perhaps there was a spelling mistake by the user input, so throw an error message
				else {
					die "The parameter $parameter is not found in the CSDDRD\n";
				};
			};

		};

		close $CSDDRD_FILE;
		
		# create a dictionary path
		my $path = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_COMBINED_subset_COMBINED_Dictionary.csv';
		

		# check to see if another thread has already created a dictionary, and if so, do not do it. If none has been created then use the last valid CSDDRD data keys to construct a dictionary.
		unless (-e $path) {
			open (my $CSDDRD_FILE, '>', $path) or die ("can't open datafile: $path");	# open the correct CSDDRD file to use as the data source
		
			foreach my $available_parameter (sort {$a cmp $b} keys (%{$CSDDRD})) {
				print $CSDDRD_FILE "$available_parameter\n";
			};
			
			close $CSDDRD_FILE;
		};
		
		
		
		print "Thread for File Name of $hse_type $region - Complete\n";
# 		print Dumper $house_info;

		return ($house_info);
	
	};	# end of main code
};

