#!/usr/bin/perl

# ====================================================================
# NN_Gen.pl
# Author: Lukas Swan
# Date: May 2009
# Copyright: Dalhousie University

# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all]

# DESCRIPTION:
# This script generates the NN annual consumption values for each house of the CSDDRD.
# It uses a multithreading approach based on the house type (SD or DR) and 
# region (AT, QC, OT, PR, BC). Which types and regions are generated is 
# specified at the beginning of the script to allow for partial generation.

# The script reads a set of input files:
# 1) CSDDRD type and region database (csv)
# 2) NN XML databases of distributions

# The script generates arrays to match the distributions and then fills out the necessary input files for the NN

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
use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
use Data::Dumper;
use List::Util 'shuffle';

# --------------------------------------------------------------------
# Declare the global variables
# --------------------------------------------------------------------

my @hse_types;	# declare an array to store the desired house types
my %hse_names = (1, "1-SD", 2, "2-DR");	# declare a hash with the house type names
my %hse_names_only = (1, "SD", 2, "DR");	# declare a hash with the house type names

my @regions;	# Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");	# declare a hash with the region names
my %region_names_only = (1, "AT", 2, "QC", 3, "OT", 4, "PR", 5, "BC");	# declare a hash with the region names


# --------------------------------------------------------------------
# Read the command line input arguments
# --------------------------------------------------------------------

COMMAND_LINE: {

	if ($#ARGV != 1) {die "Two arguments are required: house_types regions\n";};	# check for proper argument count

	if ($ARGV[0] eq "0") {@hse_types = (1, 2);}	# check if both house types are desired
	else {	# determine desired house types
		@hse_types = split (/\//,$ARGV[0]);	# House types to generate
		foreach my $type (@hse_types) {
			unless (defined ($hse_names{$type})) {	# check that type exists
				my @keys = sort {$a cmp $b} keys (%hse_names);	# sort house types for following error printout
				die "House type argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
			};
		};
	};


	if ($ARGV[1] eq "0") {@regions = (1, 2, 3, 4, 5);}	# check if all regions are desired
	else {
		@regions = split (/\//,$ARGV[1]);	# regions to generate
		foreach my $region (@regions) {
			unless (defined ($region_names{$region})) {	# check that region exists
				my @keys = sort {$a cmp $b} keys (%region_names);	# sort regions for following error printout
				die "Region argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
			};
		};
	};
	
};

# declare an array to hold all of the hse_type and region varieties (e.g. SD, AT, SD-AT) as well as the presence, header, and ALL
# this will be used in the ForceArray command so that the logic works even if there is only one element (that would otherwise default to a hash)
my @distribution_options = ('node', 'header', 'ALL');
# declare an array to hold the type_regions so as to fill out for each combination (e.g. SD-AT)
my @types_regions;

# Cycle through each of the house type and region varieties to generate the list
foreach my $hse_type (values (%hse_names_only)) {	# house types
	push (@distribution_options, $hse_type);	# remember the house type by itself
	
	foreach my $region_name (values (%region_names_only)) {	# regions
		# remember the region name and the combination of the house type and region name
		push (@distribution_options, $region_name, "$hse_type-$region_name");
		push (@types_regions, "$hse_type-$region_name");
	};
};

# print "@distribution_options\n";

# Readin the ALC and DHW xml files and force certain arrays for the distribution_options
my $ALC_xml = XMLin("../NN/NN_model/ALC_distributions.xml", ForceArray => [@distribution_options]);	# readin the ALC xml
# my $DHW_xml = XMLin("../NN/NN_model/DHW_distributions.xml", ForceArray => [@distribution_options]);	# readin the DHW xml

# print Dumper $ALC_xml;

# Cycle through the nodes to list them in the header
# AND to check the xml data for validity

foreach my $node (@{$ALC_xml->{'node'}}) {

	# Check the xml data for validity
	foreach my $value (@{$node->{'header'}}) {	# check each value of the header (which is the value information)
		# compare it to the min and max values and die if out of range
		if ($value < $node->{'min'} || $value > $node->{'max'}) {
			die ("XML Source Issue @ Node: $node->{'var_name'}. Value = $value; min = $node->{'min'}; max = $node->{'max'}\n");
		};
	};
	
	# normalize each data element by the sum of the row and then make an allowance for the presence factor
	foreach my $data_type (keys (%{$node->{'presence'}})) {	# use the presence as the key to finding data rows
		my $sum = 0;	# initialize a summation
		foreach my $element (@{$node->{$data_type}}) {$sum = $sum + $element};	# sum the elements and store
		# normalize the elements by the sum and then multiply by the presence factor
		foreach my $element (@{$node->{$data_type}}) {$element = $element / $sum * $node->{'presence'}->{$data_type}};
		
		# Check to see if the presence factor is less than one which would indicate we need to supply a minimum term 
		if ($node->{'presence'}->{$data_type} < 1) {
		
			# this checks to see if the minimum value already exists. If it does, then it is added to. If it does not, then a location is created.
			CHECK_FOR_ZERO: {
				# go through the header as that is where the minimum value would be
				foreach my $element (0..$#{$node->{'header'}}) {
				
					# check to see that the header includes the minimum value. If it does then add to the correct value of the data array. Not the use of the && which is because we need to cycle through this loop for each data type. If the array sizes are different, it means that the header DID NOT initially include the value, it was simply set by a previous data loop.
					if ($node->{'header'}->[$element] == $node->{'min'} && @{$node->{$data_type}} == @{$node->{'header'}}) {
						# then increase it by the difference between 1 and the presence
						
						$node->{$data_type}->[$element] = $node->{$data_type}->[$element] + (1 - $node->{'presence'}->{$data_type});
						last CHECK_FOR_ZERO;	# jump out of loop because the correct location was found
					};
				};
				
				# we did not find the minimum value in the header, so create this location and populate it with the difference between 1 and the presence
				push (@{$node->{$data_type}}, 1 - $node->{'presence'}->{$data_type});
				# only push the minimum value onto the header if the arrays are different sizes. This is again to deal with the multiple loop passes over all of the data types.
				if (@{$node->{$data_type}} != @{$node->{'header'}}) {
					push (@{$node->{'header'}}, $node->{'min'});
				};
			};
		};
	};
	
	# go through each type_region and check for definition. If it is not defined, then creat it with the most suitable next up resolution level of data
	foreach my $type_region (@types_regions) {
		# split up the name and store the hse_type and region for later use
		$type_region =~ /^(..)-(..)$/ or die ("\nMalformed type_region array: $type_region\n");
		my $hse_type = $1;
		my $region = $2;
		
		my $res;	# resolution level. This will be filled with the most relevant data type name (e.g. in preferred order: SD-AT, SD, AT, ALL)
		
		if (defined ($node->{$type_region})) {$res = $type_region;}	# Fine resolution and nothing is required
		elsif (defined ($node->{$hse_type})) {$res = $hse_type;}	# house type resolution is best we have
		elsif (defined ($node->{$region})) {$res = $region;}	# regional resolution is the best we have
		elsif (defined ($node->{'ALL'})) {$res = 'ALL';}	# national resolution is all we have
		else {die ("\nCannot find distribution information for node $node->{'var_name'}; checked $type_region, $hse_type, $region, and 'ALL'\n");};
		
		# if the resolution is not equal to the type and region then we have to use a higher resolution distribution and set that for the type_region
		unless ($res eq $type_region) {
			# cycle through all of the data for the closest resolution level
			foreach my $element (@{$node->{$res}}) {
				# set the type_region element equal to that of the closest resolution element
				push (@{$node->{$type_region}}, $element);
			};
		};
	};
};

print Dumper $ALC_xml;

# ----------------------------------------------------------------------------------------------------------------------
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ----------------------------------------------------------------------------------------------------------------------
# AT THIS POINT, THE XML DATA HAS BEEN READ IN AND THE DISTRIBUTIONS HAVE BEEN OPERATED ON IN SUCH A FASHION AS TO ACCOUNT FOR THE DISTRIBUTION AND PRESENCE.

# THE DATA IS ENTIRELY CONTAINED IN A HASH REFERENCE WHERE THE KEY IS AN ARRAY FOUND AT THE REFERENCE:
# $ALC_xml->{'node'}->[array of nodes]->{'header'}

# AND THE ACTUAL DATA IS (for each type-region; e.g. SD-AT):
# $ALC_xml->{'node'}->[array of nodes]->{'SD-AT'}->[array of distribution data totalling a value of 1.]
# ----------------------------------------------------------------------------------------------------------------------
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ----------------------------------------------------------------------------------------------------------------------


# -----------------------------------------------
# Read in the DHW and AL annual energy consumption CSDDRD listing
# -----------------------------------------------	
# Open the DHW and AL file
open (DHW_AL, '<', "../CSDDRD/CSDDRD_DHW_AL_annual.csv") or die ("can't open datafile: ../CSDDRD/CSDDRD_DHW_AL_annual.csv");
open (ALC, '>', "../NN/NN_model/ALC-Inputs-V2.csv") or die ("can't open datafile: ../NN/NN_model/ALC-Inputs-V2.csv");
# open (DHW, '>', "../NN/NN_model/DHW-Inputs-V2.csv") or die ("can't open datafile: ../NN/NN_model/DHW-Inputs-V2.csv");

# print the first two fields of the NN Input information
# print ALC "*header,File_name,House_type,Region";
print ALC "Number,File_name";
# print DHW "Number,File_name";
foreach my $node (@{$ALC_xml->{'node'}}) {
	print ALC ",$node->{'var_name'}";	# print the node name
};
print ALC "\n";	# newline b/c we have reached the end of the NN Input header

# # print additional information
# foreach my $tag ('units', 'min', 'max')
# 	print ALC "*$tag,-,-,-";
# 	foreach my $node (@{$ALC_xml->{'node'}}) {
# 		print ALC ",$node->{$tag}";	# print the node name
# 	};
# 	print ALC "\n";	# newline b/c we have reached the end of the NN Input header
# };

my $dhw_al;	# declare a 2D array that is a hash ref (first array is hse_type, second is region, then hash ref at hse file name)
my @dhw_al_header;	# store the header info

while (<DHW_AL>) {	# cycle through the remainder of the file
	@_ = CSVsplit($_);
	if ($_[0] =~ /^\*header/) {@dhw_al_header = @_}	# split the csv header into an array
	elsif ($_[0] =~ /^\*data/) {
# 		$_[1] =~ s/.HDF$//;	# strip the .HDF from the filename (this matches use below in code)
		push (@{$dhw_al->[$_[2]]->[$_[3]]}, $_[1]);
	};
};
close DHW_AL;


# GO THROUGH THE HOUSE TYPES AND REGIONS SO AS TO BUILD ARRAYS WITH THE RANDOMIZED VALUES FOR APPLICATION TO THE HOUSES
# go through each house type
foreach my $type_num (1..$#{$dhw_al}) {
	# go through each region
	foreach my $region_num (1..$#{$dhw_al->[$type_num]}) {
	
		# count the number of houses
		my $count = @{$dhw_al->[$type_num]->[$region_num]};
		print "Type: $type_num; Region: $region_num; Count: $count\n";
		
		# discern the names of the type and region using the hashes
		my $type_name = $hse_names_only{$type_num};
		my $region_name = $region_names_only{$region_num};
		
		my $data;	# declare an array reference to store all of the developed data structures that hold the input data to the NN
		
		# go through each distribution node
		foreach my $node (@{$ALC_xml->{'node'}}) {

			push (@{$data}, []);	# add an array reference to the data array reference

			# go through each element of the header, remember this is the value to be provided to the house file
			foreach my $element (0..$#{$node->{'header'}}) {

				# determine how long to make the array from the value in the data line that corresponds to the header value
				my $array_space = sprintf("%.f", $node->{"$type_name-$region_name"}->[$element] * $count) + @{$data->[$#{$data}]};
				
				# go through the spacing and set the array equal to the header value. This will generate a large array with ordered values corresponding to the distribution and the header
				foreach my $position (@{$data->[$#{$data}]}..$array_space) {
					$data->[$#{$data}]->[$position] = $node->{'header'}->[$element];
				};
			};
			
			# shuffle the array to get randomness
			@{$data->[$#{$data}]} = shuffle (@{$data->[$#{$data}]});
			print "@{$data->[$#{$data}]}\n";
		};
		
		foreach my $house (0..$#{$dhw_al->[$type_num]->[$region_num]}) {
# 			printf ALC ("%u,%s,%u,%u", $house + 1, $dhw_al->[$type_num]->[$region_num]->[$house], $type_num, $region_num);
			printf ALC ("%u,%s", $house + 1, $dhw_al->[$type_num]->[$region_num]->[$house]);
			foreach my $field (@{$data}) {
				print ALC ",$field->[$house]";
			};
			print ALC "\n";
		};
	};
};

