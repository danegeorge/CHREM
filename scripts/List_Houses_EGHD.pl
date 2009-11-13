#!/usr/bin/perl

# ====================================================================
# List_Houses_EGHD.pl
# Author: Lukas Swan
# Date: Oct 2009
# Copyright: Dalhousie University

# INPUT USE:
# filename.pl [list of desired CSDDRD parameters (including perl matching syntax), can also use hse_type and region]

# DESCRIPTION:
# This script generates a list of the houses with parameters. If no 
# parameters are listed, then only the Filename is printed.
# The parameters are matched using perl syntax where beginning and end 
# of line characters are automatically added.
# e.g. (floor_area.+ becomes ^floor_area.+$ for matching and would find
# floor_area_1)
#
# NOTE NOTE NOTE: This is an alternative version of List_Houses.pl that is specific for the EGHD (not sorted by hse_type or region)

# ===================================================================

# --------------------------------------------------------------------
# Declare modules which are used
# --------------------------------------------------------------------

use warnings;
use strict;
use lib ('./modules');

use CSV;	# CSV-2 (for CSV split and join, this works best)
# use Array::Compare;	# Array-Compare-1.15
use threads;	# threads-1.71 (to multithread the program)
# use File::Path;	# File-Path-2.04 (to create directory trees)
# use File::Copy;	# (to copy the input.xml file)
# use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
use Data::Dumper;

use General ('hse_types_and_regions', 'one_data_line', 'largest', 'smallest', 'check_range', 'set_issue', 'print_issues');
# use Cross_reference ('cross_ref_readin', 'key_XML_readin');
# use Database ('database_XML');

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

# 	if ($#ARGV < 1) {die "Minimum Two arguments are required: house_types regions; followed by desired parameters\n";};	# check for proper argument count

	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
# 	($hse_types, $regions) = hse_types_and_regions(@ARGV[0..1]);

	# check to see that desired parameters have been passed and if so store them
# 	if ($#ARGV > 1) {
		@desired_parameters = @ARGV[2..$#ARGV];
	@desired_parameters = @ARGV;
# 	};
};


# --------------------------------------------------------------------
# Initiate multi-threading to run each region simulataneously
# --------------------------------------------------------------------

MULTI_THREAD: {

	# The dictionary of available parameters must only be written once, even though we are multi-threading. So to do a check for its existance, we must first unlink it so that a new copy is generated for each run
	my $unlink_path = '../EGHD/2007-10-31_EGHD-HOT2XP_dupl-chk_tagged_Dictionary.csv';
	unlink ($unlink_path);


# 	print "Multi-threading for each House Type and Region : please be patient\n";
	
	my $thread;	# Declare threads for each type and region
	my $house_info_compiled; # storage hash reference to store all of the house information from all the hse_types and regions
	
# 	foreach my $hse_type (values (%{$hse_types})) {	# Multithread for each house type
# 		foreach my $region (values (%{$regions})) {	# Multithread for each region
	foreach my $hse_type (1) {	# Multithread for each house type
		foreach my $region (1) {	# Multithread for each region
			# Add the particular hse_type and region to the pass hash ref
			my $pass = {'hse_type' => $hse_type, 'region' => $region};
			$thread->{$hse_type}->{$region} = threads->new(\&main, $pass);	# Spawn the threads and send to main subroutine
		};
	};
	
	# declare an array to store the actual parameters because these may differ from those supplied by the user due to wildcard matching
	my @actual_parameters;
	
# 	foreach my $hse_type (values (%{$hse_types})) {	# return for each house type
# 		foreach my $region (values (%{$regions})) {	# return for each region type
	foreach my $hse_type (1) {	# return for each house type
		foreach my $region (1) {	# return for each region type

			# retrieve the threads information and temporarily store it at house_info
			my $house_info = $thread->{$hse_type}->{$region}->join();
			
			# overwrite the actual parameters array with this thread and then remove it from the hash
			@actual_parameters = @{$house_info->{'actual_parameters'}};
			delete ($house_info->{'actual_parameters'});
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
	my $path = '../EGHD/2007-10-31_EGHD-HOT2XP_dupl-chk_tagged_A-files_Data.csv';
	open (my $CSDDRD_FILE, '>', $path) or die ("can't open datafile: $path");
	
	# print a header onto the file (note use of concatenation)
	print $CSDDRD_FILE CSVjoin ('Filename', @actual_parameters) . "\n";

	# print the desired parameters and house name for each house (sorted)
	foreach my $house (sort {uc ($a) cmp uc ($b)} keys (%{$house_info_compiled})) {
		print $CSDDRD_FILE CSVjoin ($house, @{$house_info_compiled->{$house}}{@actual_parameters}) . "\n";
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
		my $input_path = '../EGHD/2007-10-31_EGHD-HOT2XP_dupl-chk_tagged';
		open (my $CSDDRD_FILE, '<', "$input_path.csv") or die ("can't open datafile: $input_path.csv");	# open the correct CSDDRD file to use as the data source

		my $CSDDRD; # declare a hash reference to store the CSDDRD data. This will only store one house at a time and the header data

		my $house_info; # declare a hash reference to store the desired information of all of the houses
		
		# -----------------------------------------------
		# GO THROUGH EACH LINE OF THE CSDDRD SOURCE DATAFILE AND STORE INFO
		# -----------------------------------------------
		
		# read the header line of the file so we can distinguish the wildcard matching and do it only once per thread
		my $header = header_line($CSDDRD_FILE);
		# sort the header keys and store them. Also add on hse_type and region as these may be used
		my @header_keys = sort {uc ($a) cmp uc ($b)} (@{$header->{'header'}}, 'hse_type', 'region', 'hse_type_num', 'region_num');
		
		# declare an array to store the actual parameters including all matches
		my @actual_parameters;
		
		# cycle through the desired parameters and store the data for the house in the cumulative storage variable
		foreach my $parameter (@desired_parameters) {
			
			# provide an indicator so we die if there is no match
			my $indicator = 0;
			
			# cycle through the keys to find matches, note the use of the begging/end of line character and how the indicator is changed if successful.
			# all matches will be found as there is no next/last command
			foreach my $key (@header_keys) {
				if ($key =~ /^$parameter$/) {
					push (@actual_parameters, $key);
					$indicator = 1;
				};
			};
			
			# did not find a match, so die
			unless ($indicator) {
				die "The parameter $parameter is not found in the CSDDRD\n";
			};
		};
		
		# store the actual parameter array so that it may be passed back when this thread ends
		$house_info->{'actual_parameters'} = [@actual_parameters];
		
		my $hse_type_key = {1 => '1-SD', 2 => '2-DR', 3 => '2-DR', 4 => '2-DR'};
		my $region_key = {'NEW BRUNSWICK' => '1-AT', 'PRINCE EDWARD ISLAND' => '1-AT', 'NOVA SCOTIA' => '1-AT', 'NEWFOUNDLAND' => '1-AT', 
			'QUEBEC' => '2-QC',
			'ONTARIO' => '3-OT',
			'ALBERTA' => '4-PR', 'SASKATCHEWAN' => '4-PR', 'MANITOBA' => '4-PR',
			'BRITISH COLUMBIA' => '5-BC'
		};
		
		while ($CSDDRD = one_data_line($CSDDRD_FILE, $header)) {	# go through each line (house) of the file
			
			if ($CSDDRD->{'file_name'} =~ /\w\w\w\wA\w\w\w\w\w\.HDF/ &&
				defined ($hse_type_key->{$CSDDRD->{'attachment_type'}}) &&
				defined ($region_key->{$CSDDRD->{'HOT2XP_PROVINCE_NAME'}})
				) {
			
				# the CSDDRD does not list hse_type and region in the same format as we use, so this creates such a data structure for use with @desired_parameters
				$CSDDRD->{'hse_type'} = $hse_type_key->{$CSDDRD->{'attachment_type'}};
				($CSDDRD->{'hse_type_num'}) = $CSDDRD->{'hse_type'} =~ /(\d)-\w\w/;

				$CSDDRD->{'region'} = $region_key->{$CSDDRD->{'HOT2XP_PROVINCE_NAME'}};
				($CSDDRD->{'region_num'}) = $CSDDRD->{'region'} =~ /(\d)-\w\w/;

				# initialize the file so that the filename exists even if there are no other desired parameters
				$house_info->{$CSDDRD->{'file_name'}} = {};

				# cycle throught the actual parameters (developed above) and store the information
				foreach my $parameter (@actual_parameters) {
					$house_info->{$CSDDRD->{'file_name'}}->{$parameter} = $CSDDRD->{$parameter};
				};
			};
		};

		close $CSDDRD_FILE;
		
		
		# create a dictionary path
		my $path = '../EGHD/2007-10-31_EGHD-HOT2XP_dupl-chk_tagged_Dictionary.csv';

		# check to see if another thread has already created a dictionary, and if so, do not do it. If none has been created then use the last valid CSDDRD data keys to construct a dictionary.
		unless (-e $path) {
			open (my $CSDDRD_FILE, '>', $path) or die ("can't open datafile: $path");	# open the correct CSDDRD file to use as the data source
		
			# use the header keys to store an sorted dictionary of keys
			foreach my $available_parameter (@header_keys) {
				print $CSDDRD_FILE "$available_parameter\n";
			};
			
			close $CSDDRD_FILE;
		};
		
		
		
		print "Thread for File Name of $hse_type $region - Complete\n";
# 		print Dumper $house_info;

		return ($house_info);
	
	};	# end of main code
};

