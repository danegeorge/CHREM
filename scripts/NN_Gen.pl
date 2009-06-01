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

my @distributions;	# declare an array to store the NN_distributions types

# --------------------------------------------------------------------
# Read the command line input arguments
# --------------------------------------------------------------------

COMMAND_LINE: {

	if ($#ARGV != 2) {die "Three arguments are required: house_types regions NN_distributions\n";};	# check for proper argument count

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

	@distributions = split (/\//,$ARGV[2]);	# regions to generate
	foreach my $distribution (@distributions) {
		unless ($distribution eq 'ALC' || $distribution eq 'DHW') {	# check that the distribution is either ALC or DHW
			die "Distribution argument must be either ALC or DHW or both seperated by a /\n";
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

my $NN_xml;	# declare a reference to a hash to store the xml data (use $NN_xml->{ALC or DHW}

foreach my $distribution (@distributions) {
	# Readin the ALC and DHW xml files and force certain arrays for the distribution_options
	$NN_xml->{$distribution} = XMLin("../NN/NN_model/$distribution" . '_distributions.xml', ForceArray => [@distribution_options]);	# readin the xml

# 	print Dumper $NN_xml->{$distribution};

	# Cycle through the nodes to list them in the header
	# AND to check the xml data for validity
	foreach my $node (@{$NN_xml->{$distribution}->{'node'}}) {

		# Check the xml data for validity
		foreach my $value (@{$node->{'header'}}) {	# check each value of the header (which is the value information)
			# compare it to the min and max values and die if out of range
			if ($value < $node->{'min'} || $value > $node->{'max'}) {
				die ("XML Source Issue in $distribution at Node: $node->{'var_name'}. Value = $value; min = $node->{'min'}; max = $node->{'max'}\n");
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
		
		# Declare a combined hash with all of the information from each of the distribution types
		# this is used because some of the variables are the same and we have to make sure we use the same values for the same variables for a house.
		# So now instead of cycling through all of the elements of the certain distribution, we will cycle through all of the keys of the 'combined'
		$NN_xml->{'combined'}->{$node->{'var_name'}} = {%{$node}};
	};
	
};

print Dumper $NN_xml->{'combined'};
# print "\ncombined\n";
# my @keys = keys(%{$NN_xml->{'combined'}});
# my $elements = @keys;
# printf "elements $elements\n";

# ----------------------------------------------------------------------------------------------------------------------
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ----------------------------------------------------------------------------------------------------------------------
# AT THIS POINT, THE XML DATA HAS BEEN READ IN AND THE DISTRIBUTIONS HAVE BEEN OPERATED ON IN SUCH A FASHION AS TO ACCOUNT FOR THE DISTRIBUTION AND PRESENCE.

# THE DATA IS ENTIRELY CONTAINED IN A HASH REFERENCE WHERE THE KEY IS AN ARRAY FOUND AT THE REFERENCE:
# $NN_xml->{$distribution}->{'node'}->[array of nodes]->{'header'}

# AND THE ACTUAL DATA IS (for each type-region; e.g. SD-AT):
# $NN_xml->{$distribution}->{'node'}->[array of nodes]->{'SD-AT'}->[array of distribution data totalling a value of 1.]
# ----------------------------------------------------------------------------------------------------------------------
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ----------------------------------------------------------------------------------------------------------------------


foreach my $distribution (@distributions) {

	open (NN_INPUT, '>', "../NN/NN_model/$distribution-Inputs-V2.csv") or die ("can't open datafile: ../NN/NN_model/$distribution-Inputs-V2.csv");

	# print the first two fields of the NN Input information
	print NN_INPUT "*header,File_name";

	foreach my $node (@{$NN_xml->{$distribution}->{'node'}}) {
		print NN_INPUT ",$node->{'var_name'}";	# print the node name
	};
	print NN_INPUT "\n";	# newline b/c we have reached the end of the NN Input header

	# print additional information
	foreach my $tag ('unit', 'min', 'max') {
		print NN_INPUT "*$tag,-";
		foreach my $node (@{$NN_xml->{$distribution}->{'node'}}) {
			print NN_INPUT ",$node->{$tag}";	# print the node name
		};
		print NN_INPUT "\n";	# newline b/c we have reached the end of the NN Input header
	};



	my $CSDDRD;
	my %CSDDRD_fields = ('region', 3, 'city', 4, 'postalcode', 5, 'heat_sys_fuel', 75, 'heat_sys_type', 78, 'DHW_fuel', 80, 'DHW_sys_type', 81, 'DHW_eff', 82, 'Ventilation', 83, 'FA1', 97, 'FA4', 100, 'FA5', 101, 'FA6', 102);
	my @CSDDRD_keys = keys (%CSDDRD_fields);

	# GO THROUGH THE HOUSE TYPES AND REGIONS SO AS TO BUILD ARRAYS WITH THE RANDOMIZED VALUES FOR APPLICATION TO THE HOUSES
	# go through each house type
	foreach my $hse_type (@hse_types) {
		foreach my $region (@regions) {
			my $input_path = "../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_$hse_names{$hse_type}_subset_$region_names{$region}.csv";
			open (CSDDRD, '<', $input_path) or die ("can't open datafile: $input_path"); 
			$_ = <CSDDRD>;	# strip the header info
			while (<CSDDRD>) {
				@_ = CSVsplit($_);	# split each of the comma delimited fields of the house record
				# Store the CSDDRD information that is required for subsequent logic. Use the desired fields from above.
				@{$CSDDRD->{$hse_type}->{$region}->{$_[1]}}{@CSDDRD_keys} = @_[@CSDDRD_fields{@CSDDRD_keys}];
			};
			
			# count the number of houses
			my $count = keys (%{$CSDDRD->{$hse_type}->{$region}});
			print "House Type: $hse_type; Region: $region; Count: $count\n";
			
			# discern the names of the type and region using the hashes
			my $type_name = $hse_names_only{$hse_type};
			my $region_name = $region_names_only{$region};
			
			my $data;	# declare an array reference to store all of the developed data structures that hold the input data to the NN
			
			# go through each distribution node
			foreach my $node (@{$NN_xml->{$distribution}->{'node'}}) {

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
# 				print "@{$data->[$#{$data}]}\n";
			};

###############################
# IN THE BELOW YOU NEED TO CONSIDER THE FOLLOWING
# 1) HOW DO I MANAGE IDENTICAL VALUES BETWEEN THE ALC AND THE DHW (e.g. INCOME OR ADULTS)
# 2) HOW DO I INSERT THE DATA FROM THE CSDDRD. REMEMBER THAT THERE NEEDS TO BE CALLS TO THE CLIMATE ETC AND DECODING OF THE HEATING EQUIPMENT

# 			foreach my $house (0..$#{$dhw_al->[$type_num]->[$region_num]}) {
# 				printf NN_INPUT ("%s,%s", '*data', $dhw_al->[$type_num]->[$region_num]->[$house]);
# 	# 			printf NN_INPUT ("%u,%s", $house + 1, $dhw_al->[$type_num]->[$region_num]->[$house]);
# 				foreach my $field (@{$data}) {
# 					print NN_INPUT ",$field->[$house]";
# 				};
# 				print NN_INPUT "\n";
# 			};
		};
	};
	
};

