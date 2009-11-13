#!/usr/bin/perl

# ====================================================================
# NN_Input_Gen.pl
# Author: Lukas Swan
# Date: May 2009
# Copyright: Dalhousie University

# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all]

# DESCRIPTION:
# This script generates the NN annual consumption values for each house of the CSDDRD.
# It uses a type and region approach based on the house type (SD or DR) and 
# region (AT, QC, OT, PR, BC). Which types and regions are generated is 
# specified at the beginning of the script to allow for partial generation.

# The script reads a set of input files:
# 1) CSDDRD type and region database (csv)
# 2) NN XML databases of distributions

# The script generates arrays to match the distributions and then fills out the necessary input files for the NN
# It then calls the NN_Model.pl script which numerically evaluates the input to calculate the output.

# Finally, this script reads the results of the NN and Generates the format required by Hse_Gen.pl
# NOTE: it applies efficiency and factors to convert DHW from GJ into Litres

# ===================================================================

# --------------------------------------------------------------------
# Declare modules which are used
# --------------------------------------------------------------------

use warnings;
use strict;
use lib ('./modules');

use CSV;	# CSV-2 (for CSV split and join, this works best)
# use Array::Compare;	# Array-Compare-1.15
# use threads;	# threads-1.71 (to multithread the program)
# use File::Path;	# File-Path-2.04 (to create directory trees)
# use File::Copy;	# (to copy the input.xml file)
use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
use Data::Dumper;


use General ('hse_types_and_regions', 'one_data_line', 'check_range', 'set_issue', 'print_issues', 'distribution_array');
use Cross_reference ('cross_ref_readin', 'key_XML_readin');

# --------------------------------------------------------------------
# Declare the input variables
# --------------------------------------------------------------------

my $hse_types;	# declare an hash array to store the house types to be modeled (e.g. 1 -> 1-SD)
my $regions;	# declare an hash array to store the regions to be modeled (e.g. 1 -> 1-AT)

# The following is an artifact of the development process where the ALC and DHW could be developed seperately.
# This has now been fixed b/c both are required for the format used by Hse_Gen.pl script.
my @distributions = ('ALC', 'DHW');	# declare an array to store the NN_distributions types

# --------------------------------------------------------------------
# Read the command line input arguments
# --------------------------------------------------------------------

COMMAND_LINE: {

	if ($#ARGV != 1) {die "Two arguments are required: house_types regions\n";};	# check for proper argument count
	
	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
	($hse_types, $regions) = hse_types_and_regions(@ARGV[0..1]);

};

# declare an array reference to hold all of the hse_type and region varieties (e.g. SD, AT, SD-AT) as well as the presence, header, and ALL
# this will be used in the ForceArray command so that the logic works even if there is only one element (that would otherwise default to a hash)
my $distribution_options = ['node', 'header', 'ALL'];

# declare an array to hold the type_regions so as to fill out for each combination (e.g. SD-AT)
my @types_regions;

# Cycle through each of the house type and region varieties to generate the list
foreach my $hse_type ('SD', 'DR') {	# house types; NOTE: I had to list these manually because the hse_types_and_regions() only returns those in use
	push (@{$distribution_options}, $hse_type);	# remember the house type by itself

	foreach my $region ('AT', 'QC', 'OT', 'PR', 'BC') {	# regions; NOTE: I had to list these manually because the hse_types_and_regions() only returns those in use
		# remember the region name and the combination of the house type and region name
		push (@{$distribution_options}, $region, "$hse_type-$region");
		
		# also push onto the types_regions so we can evaluate these later during xml readin
		push (@types_regions, "$hse_type-$region");
	};
};

my $NN_xml;	# declare a reference to a hash to store the xml data (use $NN_xml->{ALC or DHW}

my $NN_xml_keys;	# declare a reference to a hash to store the name keys of each type of xml data

# Cycle over the two distributions, but also add COMMON as it holds data that both types use
foreach my $distribution (@distributions, 'COMMON') {
	# Readin the ALC and DHW xml files and force certain arrays for the distribution_options
	$NN_xml->{$distribution} = key_XML_readin("../NN/NN_model/$distribution" . '_distributions.xml', $distribution_options);	# readin the xml

	# Cycle through the nodes to list them in the header
	# AND to check the xml data for validity
	foreach my $node (@{$NN_xml->{$distribution}->{'node'}}) {
	
		# add the name to an array in nodal order such that we may iterate over this at a later point
		push (@{$NN_xml_keys->{$distribution}}, $node->{'var_name'});

		# Check to see if there is a common indicator attribute in the node. If there is, we skip because it will be found in the COMMON_distributions.xml
		if (! exists $node->{'common'}) {

			# Check the xml data for validity (min, max)
			foreach my $value (@{$node->{'header'}}) {	# check each value of the header (which is the value information)
				# compare it to the min and max values and die if out of range
				if ($value < $node->{'min'} || $value > $node->{'max'}) {
					die ("XML Source Issue in $distribution at Node: $node->{'var_name'}. Value = $value; min = $node->{'min'}; max = $node->{'max'}\n");
				};
			};
			
			# normalize each data element by the sum of the row and then make an allowance for the presence factor
			# this is required because the data was entered as values of houses in the CHS as predicted by SHEU.
			# The presence accounts for the potential that not all houses own something, but the distribution may actually be use of that item.
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
			
			# go through each type_region and check for definition of it in the xml data (i.e. fine resolution data at the type-region level. If it is not defined, then create it with the most suitable next up resolution level of data (e.g. if a value is provided for AT, then attribute it to each house type of AT, SD-AT and DR-AT)
			foreach my $type_region (@types_regions) {
				# split up the name and store the hse_type and region for later use
				$type_region =~ /^(..)-(..)$/ or die ("\nMalformed type_region array: $type_region\n");
				my $hse_type = $1;
				my $region = $2;
				
				my $res;	# resolution level. This will be filled with the most relevant data type name (e.g. in preferred order: SD-AT, SD, AT, ALL)
				
				# check for existance in ordered resolution
				if (defined ($node->{$type_region})) {$res = $type_region;}	# Fine resolution and nothing is required
				elsif (defined ($node->{$hse_type})) {$res = $hse_type;}	# house type resolution is best we have
				elsif (defined ($node->{$region})) {$res = $region;}	# regional resolution is the best we have
				elsif (defined ($node->{'ALL'})) {$res = 'ALL';}	# national resolution is all we have
				
				# The following checks to see if SD exists for the region and then this will be used.
				# This provides a fallback, where if no data exists for DR-region and we are not comfortable with the national DR or Regional values, it will default back to the SD-region distributions.
				# It is felt this is OK because SD better represents DR then regional (a combination of SD, DR, Apartments, and mobile homes) or the national value.
				elsif (defined ($node->{"SD-$region"})) {$res = "SD-$region";}	# use the SD-region version for the DR-region version
				
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
	
};

# print Dumper $NN_xml->{'combined'};

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

my $NN_input;	# Create a hash reference to store the NN input files (DHW and AL) so I can call them independently in loops

foreach my $distribution (@distributions) {

	# The following lines describe a reference to a file for output. This is used for subsequent iteration.
	local *NN_INPUT;
	open (NN_INPUT , '>', "../NN/NN_model/$distribution-Inputs-V2.csv") or die ("can't open datafile: ../NN/NN_model/$distribution-Inputs-V2.csv");
	$NN_input->{$distribution} = *NN_INPUT;	# remember the file

	# print the first two fields of the NN Input information
	print {$NN_input->{$distribution}} "*header,File_name";

	# NOTE:we are using each distribution independently here to fill out the input data
	foreach my $node (@{$NN_xml_keys->{$distribution}}) {
		print {$NN_input->{$distribution}} ",$node";	# print the node name
	};
	print {$NN_input->{$distribution}} "\n";	# newline b/c we have reached the end of the NN Input header

	# print additional information
	foreach my $tag ('unit', 'min', 'max') {
		print {$NN_input->{$distribution}} "*$tag,-";
		foreach my $node (@{$NN_xml_keys->{$distribution}}) {
# 			print "node $node; tag $tag; value $NN_xml->{'combined'}->{$node}->{$tag}\n";
			print {$NN_input->{$distribution}} ",$NN_xml->{'combined'}->{$node}->{$tag}";	# print the node information
		};
		print {$NN_input->{$distribution}} "\n";	# newline b/c we have reached the end of the NN Input header
	};
};


# The following are global variables for storing CSDDRD information
my $CSDDRD;	# the CSDDRD info

# The following will provides a list of CSDDRD fields that we would like to store. We are storing these for each house, so it will fill up memory, so there cannot be to many.
my @CSDDRD_keys = ('file_name', 'HOT2XP_PROVINCE_NAME', 'HOT2XP_CITY', 'postal_code', 'heating_energy_src', 'heating_equip_type', 'DHW_energy_src', 'DHW_equip_type', 'DHW_eff', 'vent_equip_type', 'bsmt_floor_area', 'main_floor_area_1', 'main_floor_area_2', 'main_floor_area_3', 'stove_fuel_use', 'dryer_fuel_used');

# A global hash reference to store the names of the houses
my $file_name;

# my $data;	# declare an reference to store all of the developed data structures that hold the input data to the NN. These will include the randomized values for the houses.

# Readin the hvac xml information as it indicates furnace fan and boiler pump variables
my $hvac = key_XML_readin('../keys/hvac_key.xml', [1]);	# readin the HVAC cross ref

# Readin the dhw xml information to cross ref the system efficiency used for the NN
my $dhw_energy_src = key_XML_readin('../keys/dhw_key.xml', [1]);	# readin the DHW cross ref

# -----------------------------------------------
# Read in the CWEC weather data crosslisting
# -----------------------------------------------

my $climate_ref = cross_ref_readin('../climate/Weather_HOT2XP_to_CWEC.csv');	# create an climate crosslisting hash reference

my $PostalCode = cross_ref_readin('../keys/Census_PCCF_Postal-Code_Urban-Rural-Type.csv');	# create an postal code crosslisting hash reference

# create a hash ref to store all of the issues encountered for a later printing
my $issues;

# GO THROUGH THE HOUSE TYPES AND REGIONS SO AS TO BUILD ARRAYS WITH THE RANDOMIZED VALUES FOR APPLICATION TO THE HOUSES
foreach my $hse_type (sort {$a cmp $b} values (%{$hse_types})) {	# for each house type
	foreach my $region (sort {$a cmp $b} values (%{$regions})) {	# for each region
	
	system ("printf \"Generating the NN Input files for House Type: $hse_type and Region: $region\"");
	
		# open the CSDDRD files
		my $input_path = "../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_$hse_type" . "_subset_$region.csv";
		open (my $CSDDRD_FILE, '<', $input_path) or die ("can't open datafile: $input_path");
		
		my $CSDDRD_data_line;
		
		while ($CSDDRD_data_line = one_data_line($CSDDRD_FILE, $CSDDRD_data_line)) {	# go through each line (house) of the file
		
			my $filename = $CSDDRD_data_line->{'file_name'};
		
			# Store the CSDDRD information that is required for subsequent logic. Use the desired fields from above. NOTE: this is hash slice that uses the hash as a guide to identify and label data from the CSDDRD
			@{$CSDDRD->{$hse_type}->{$region}->{$filename}}{@CSDDRD_keys} = @{$CSDDRD_data_line}{@CSDDRD_keys};
			$CSDDRD->{$hse_type}->{$region}->{$filename}->{'hse_type'} = $hse_types->{$hse_type};
			$CSDDRD->{$hse_type}->{$region}->{$filename}->{'region'} = $regions->{$region};
			
			my $coordinates = {'hse_type' => $hse_type, 'region' => $region, 'file_name' => $filename};
			
			# shorten the name to the house while within the loop
			my $house = $CSDDRD->{$hse_type}->{$region}->{$filename};
# 			print Dumper $house;
			# PERFORM SUBSEQUENT PROCESSING TO DETERMINE VARIABLES REQUIRED FOR THE NN FROM THE CSDDRD INFORMATION
			
			Furnace_Boiler: {
				# check for presence of a furnace fan or boiler pump by cross referencing to the hvac.xml
				foreach my $var ('Furnace_Fan', 'Boiler_Pump') {
					$house->{$var} = $hvac->{'energy_type'}->[$house->{'heating_energy_src'}]->{'system_type'}->[$house->{'heating_equip_type'}]->{$var};
					($house->{$var}, $issues) = check_range("%u", $house->{$var}, $NN_xml->{'combined'}->{$var}->{'min'}, $NN_xml->{'combined'}->{$var}->{'max'}, $var, $coordinates, $issues);
				};
			};

			Floor_Area: {
				# calculate the heated floor area
				my $var = 'Area';
				$house->{$var} = 0;	# intialize to zero
				# add up basement, first, second, and third floors
				foreach my $level ('bsmt_floor_area', 'main_floor_area_1', 'main_floor_area_2', 'main_floor_area_3') {
					$house->{$var} = $house->{$var} + $house->{$level};
				};
				($house->{$var}, $issues) = check_range("%.1f", $house->{$var}, $NN_xml->{'combined'}->{$var}->{'min'}, $NN_xml->{'combined'}->{$var}->{'max'}, $var, $coordinates, $issues);
			};

			Bathroom_Exhaust_Fan: {
				# check the ventilation system for bathroom exhaust fans
				my $var = 'Bath_Exhaust_Fan';
				if ($house->{'vent_equip_type'} >= 4 && $house->{'vent_equip_type'} <= 5) {
				
					# fans are true, but set to 2 or 1 depending on the heated floor area (1 up to 175 m^2, and 2 for larger size)
					if ($house->{'Area'} > 175) {$house->{$var} = 2;}
					else {$house->{$var} = 1;};
				}
				# no bathroom fans
				else {$house->{$var} = 0;};
				($house->{$var}, $issues) = check_range("%u", $house->{$var}, $NN_xml->{'combined'}->{$var}->{'min'}, $NN_xml->{'combined'}->{$var}->{'max'}, $var, $coordinates, $issues);
			};
			
			CVS: {
				# check CVS
				my $var = 'Central_Air_Exchanger';
				if ($house->{'vent_equip_type'} == 3) {$house->{$var} = 1;}
				else {$house->{$var} = 0;};
				($house->{$var}, $issues) = check_range("%u", $house->{$var}, $NN_xml->{'combined'}->{$var}->{'min'}, $NN_xml->{'combined'}->{$var}->{'max'}, $var, $coordinates, $issues);;
			};
				
			HRV: {
				# check HRV
				my $var = 'HRV';
				if ($house->{'vent_equip_type'} == 2 || $house->{'vent_equip_type'} == 5) {$house->{$var} = 1;}
				else {$house->{$var} = 0;};
				($house->{$var}, $issues) = check_range("%u", $house->{$var}, $NN_xml->{'combined'}->{$var}->{'min'}, $NN_xml->{'combined'}->{$var}->{'max'}, $var, $coordinates, $issues);
			};
				
			HDD: {
				# check HDD
				my $var = 'HDD';
				$house->{$var} = $climate_ref->{'data'}->{$house->{'HOT2XP_CITY'}}->{'CWEC_EC_HDD_18C'};
				($house->{$var}, $issues) = check_range("%.0f", $house->{$var}, $NN_xml->{'combined'}->{$var}->{'min'}, $NN_xml->{'combined'}->{$var}->{'max'}, $var, $coordinates, $issues);;
			};

			CDD: {
				# check CDD
				my $var = 'CDD';
				$house->{$var} = $climate_ref->{'data'}->{$house->{'HOT2XP_CITY'}}->{'CWEC_EC_CDD_18C'};
				($house->{$var}, $issues) = check_range("%.0f", $house->{$var}, $NN_xml->{'combined'}->{$var}->{'min'}, $NN_xml->{'combined'}->{$var}->{'max'}, $var, $coordinates, $issues);
			};
			
			DHW_System_Efficiency: {
				# determine the DHW system efficiency: NOTE: use the NN values of Merih Aydinalp
				my $var = 'NN_DHW_System_Efficiency';
				$house->{$var} = $dhw_energy_src->{'energy_type'}->[$house->{'DHW_energy_src'}]->{$var};
				($house->{$var}, $issues) = check_range("%.3f", $house->{$var}, $NN_xml->{'combined'}->{$var}->{'min'}, $NN_xml->{'combined'}->{$var}->{'max'}, $var, $coordinates, $issues);;
			};
			
			Ground_Temp: {
				# determine the ground temperature (annual average, at 1.5 m depth)
				my $var = 'Ground_Temp';
				$house->{$var} = $climate_ref->{'data'}->{$house->{'HOT2XP_CITY'}}->{'EC_GND_TEMP_AVG_C'};
				($house->{$var}, $issues) = check_range("%.1f", $house->{$var}, $NN_xml->{'combined'}->{$var}->{'min'}, $NN_xml->{'combined'}->{$var}->{'max'}, $var, $coordinates, $issues);
			};
			
			Postal_Code: {
				my $var = 'Postal Code';

				if ($house->{'postal_code'} =~ /^([A-Z][0-9][A-Z]\s[0-9][A-Z][0-9])$/) {
					my $POSTCODE = $1;	# remember the postal code
					$POSTCODE =~ /^.(.)/;	# examine the first two digits of the postal code and store the second digit
					my $POSTCODE_2nd_dig = $1;
				
					# check to see if the postal code is in the cross reference
					if (defined ($PostalCode->{'data'}->{$POSTCODE})) {
	# 					print Dumper $PostalCode->{'data'}->{$POSTCODE};
						my $pop_density = $PostalCode->{'data'}->{$POSTCODE}->{'RURAL_URBAN_CORE'};
	# 					print "rural urban core $pop_density\n";

						# check the population density for range
						if ($pop_density >= 1 && $pop_density <= 3) {$house->{'Rural_Suburb_Urban'} = $pop_density;}
						
						# not in range, so check the second digit and make an assumption
						elsif ($POSTCODE_2nd_dig == 0) {
							$issues = set_issue("%s", $issues, $var, 'Bad_pop_density_2nd_dig_OK - assuming rural (1)', $POSTCODE, $coordinates);
							$house->{'Rural_Suburb_Urban'} = 1; # assume rural
						}
						else {
							$issues = set_issue("%s", $issues, $var, 'Bad_pop_density - assuming urban (2)', $POSTCODE, $coordinates);
							$house->{'Rural_Suburb_Urban'} = 2; # assume urban
						};
					}
					
					# not in the postal code cross reference, so check the second digit and make an assumption
					elsif ($POSTCODE_2nd_dig == 0) {
						$issues = set_issue("%s", $issues, $var, 'No_pop_density_2nd_dig_OK - assuming rural (1)', $POSTCODE, $coordinates);
						$house->{'Rural_Suburb_Urban'} = 1; # assume rural
					}
					else {
						$issues = set_issue("%s", $issues, $var, 'No_pop_density - assuming urban (2)', $POSTCODE, $coordinates);
						$house->{'Rural_Suburb_Urban'} = 2; # assume urban
					};
					
				}
				
				# issue reading the postal code, so use the distribution by SHEU
				else {
					$issues = set_issue("%s", $issues, $var, 'Bad_postal_code - let urban/rural be decided by SHEU distribution (1 or 2)', $house->{'postalcode'}, $coordinates);
					# Let the population be decided by the distribution
				};
			};
			
		};
# 		print Dumper $CSDDRD;
		


		my $count = keys (%{$CSDDRD->{$hse_type}->{$region}}); 	# count the number of houses for this house type and region
# 		print "House Type: $hse_type; Region: $region; Count: $count\n";
		
		# discern the names of the type and region without the numerical values (i.e. 1-SD -> SD)
		# this is because XML does not support parameter names that begin with numerical values
		(my $type_name) = ($hse_type =~ /^\d+-(.+)$/);
		(my $region_name) = ($region =~ /^\d+-(.+)$/);
		
		# Storage for a hash reference of arrays. The arrays store the values for each house of the shuffled and inflated distributions
		my $data;

		# go through each xml distribution node
		# NOTE:we are using the combined distribution here to fill out the input data so there is no overlap in the distribution types (ALC or DHW)
		# This process is un-ordered for now as it will be placed into a data hash
		foreach my $key (keys %{$NN_xml->{'combined'}}) {

			# call a subroutine to examine the distribution and develop a shuffled array for the variable (one element for each house)
			# provide it the variable name, the number of houses to fill out the array to, and the house type region names
			# The subroutine returns the array of data, so store it in an array reference at the data hash by key name
			my $dist_hash;# temp storage for hash of header keys and distribution ratio values
			@{$dist_hash}{@{$NN_xml->{'combined'}->{$key}->{'header'}}} = @{$NN_xml->{'combined'}->{$key}->{"$type_name-$region_name"}};
			$data->{$key} = [&distribution_array ($dist_hash, $count)];
			
		};	# NOTE this completes the random distribution organization of the variables for the CSDDRD NN.
		
# 		print Dumper $data;
		

		# a storage variable to count the frequency of a certain number of adults - this will be used to properly distribute employment ratio
		my $adult_count;

		# The following completes a run through the array that holds the household information (XX) where the first digit is num of adults, and second digit is number of children.
		# This function replaces the values in the array for adults and children, preserving the family structure for each region.
		# In essence, the correct number of 1 Adult, 2 Adults, and 1 to 3 children distributions will be attributed appropriately.
		# This is required b/c the adults and children nodes are seperate.
		foreach my $element (0..$#{$data->{'Household'}}) {	# cycle over each element
			# split the two digits and record them
			$data->{'Household'}->[$element] =~ /^(\d)(\d)$/ or die ("Bad household value: $data->{'Household'}->[$element]; at house type $hse_type; region $region; element $element\n");
			# store the adults and then the children in proper order at the proper array element.
			$data->{'Num_of_Adults'}->[$element] = $1;
			$data->{'Num_of_Children'}->[$element] = $2;
			
			# check to see if this adults present (e.g. 1, 2, 3, or 4) exists. If not then this is now a value of one because fo the first house
			unless (exists ($adult_count->{$1})) {
				$adult_count->{$1} = 1;
			}
			# Otherwise simply increment the value because this house has that many adults
			else {$adult_count->{$1}++;};
		};
		
		# The following performs a distribution analysis of employment ratio for the different numbers of adults that may be present in a household.
		# This is primarily because there are only certain acceptable values of employment ratio for certain adult presence: 
		# ADULTS  POSSIBLE EMPLOYMENT_RATIOS
		#   1     0.00 1.00
		#   2     0.00 0.50 1.00
		#   3     0.00 0.33 0.66 1.00
		#   4     0.00 0.25 0.50 0.75 1.00
		
		# temporary array storage of the employment data. An distributed array with appropriate employment_ratios corresponding in length to the number of households with that many adults present
		my $employment_data;
		
		# Go thorugh the different types of adult presence
		foreach my $key (keys %{$adult_count}) {
			# Call the subroutine again to create an array of data from the distribution, but this time use the number of households with X many adults instead of the total number of households
			my $dist_hash; # temp storage for hash of header keys and distribution ratio values
			@{$dist_hash}{@{$NN_xml->{'combined'}->{'Employment_Ratio_' . $key . '_Adults'}->{'header'}}} = @{$NN_xml->{'combined'}->{'Employment_Ratio_' . $key . '_Adults'}->{"$type_name-$region_name"}};
			$employment_data->{$key} = [&distribution_array ($dist_hash, $adult_count->{$key})];
			
		};
		
		# Now cycle back through each element of 'Household', determine the number of adults and then shift off an employment_ratio from the correct array of distributed values
		# This process will end up with two ordered arrays - Household (which has adults count) and Employment_Ratio which is a function of the number of adults count.
		# This loop replaces the existing value that was prelimnarily developed from the ALC_distributions.
		foreach my $element (0..$#{$data->{'Household'}}) {	# cycle over each element
			# split the two digits and record them
			$data->{'Household'}->[$element] =~ /^(\d)(\d)$/ or die ("Bad household value: $data->{'Household'}->[$element]; at house type $hse_type; region $region; element $element\n");
			
			# Reset the employment ratio at the same element (household) corresponding to the number of adults at that household.
			$data->{'Employment_Ratio'}->[$element] = shift (@{$employment_data->{$1}});
			
# 			print "Household $data->{'Household'}->[$element]; Adults $1; Emp_ratio $data->{'Employment_Ratio'}->[$element]\n";
		};
		

# print Dumper $data;


		# Go through the houses and develop the files required by the NN_Model.pl script
		foreach my $house (sort {$a cmp $b} keys (%{$CSDDRD->{$hse_type}->{$region}})) {	# do this for each house in order

			my $house_data;	# a temporary storage variable that is used to hold the NN data for the house

			# loop through all the fields of the combined NN inputs (data). If the field is present in the CSDDRD, use it and pop the distribution version off data. Otherwise pop the distribution version off data and use that instead. Note this does all the fields and that only the appropriate fields are used to fulfill each input file later on
			foreach my $field (keys (%{$data})){
				if (defined ($CSDDRD->{$hse_type}->{$region}->{$house}->{$field})) {
					# it is defined in CSDDRD, so use this value and trash the distribution value
					$house_data->{$field} = $CSDDRD->{$hse_type}->{$region}->{$house}->{$field};
					shift (@{$data->{$field}});
				}
				else {
					# use the distribution value
					$house_data->{$field} = shift (@{$data->{$field}});
				};
			};
			
			# store these fields of interest that came from data into the actual CSDDRD for later use
			foreach my $field ('Rural_Suburb_Urban', 'Num_of_Adults', 'Num_of_Children', 'Employment_Ratio') {
				$CSDDRD->{$hse_type}->{$region}->{$house}->{$field} = $house_data->{$field};
			};

			# cycle through the distributions to fill out their input files. Note this is complicated b/c of gas appliances
			# The primary routine below simply writes out a line of data to the NN input file corresponding to the ordered field.
			# The more complicated version turns on/off the dryer/stove and then creates a second house with the same name and an added indicator.
			# e.g. xxxxxxx.HDF and xxxxxxxx.HDF.Stove
			foreach my $distribution (@distributions) {

				# print the base house - this is the way the house is for electricity including electric stove and dryer
				print {$NN_input->{$distribution}} CSVjoin('*data', $house, @{$house_data}{@{$NN_xml_keys->{$distribution}}}) . "\n";
				
				# Store the clothes dryer value in the CSDDRD so it may be printed out later
				$CSDDRD->{$hse_type}->{$region}->{$house}->{'Clothes_Dryer'} = $house_data->{'Clothes_Dryer'};
				
				# remember the clothes dryer data and then turn it off
				my $Clothes_Dryer = $house_data->{'Clothes_Dryer'};
				$house_data->{'Clothes_Dryer'} = 0;
				
				# create another house (xxxxxxxx.HDF.No-Dryer) where the dryer is turned off. This is to estimate the electricity consumption of the dryer so that it may be exhausted outside the conditioned zone
				print {$NN_input->{$distribution}} CSVjoin('*data', $house . '.No-Dryer', @{$house_data}{@{$NN_xml_keys->{$distribution}}}) . "\n";
				
				# copy the base house to a house termed *.Not-Dryer
				$CSDDRD->{$hse_type}->{$region}->{$house . '.No-Dryer'} = {%{$CSDDRD->{$hse_type}->{$region}->{$house}}};
				# Store the clothes dryer value in the CSDDRD so it may be printed out later
				$CSDDRD->{$hse_type}->{$region}->{$house . '.No-Dryer'}->{'Clothes_Dryer'} = $house_data->{'Clothes_Dryer'};
				
				# reinstate the original clothes_dryer data for use on the next cycle
				$house_data->{'Clothes_Dryer'} = $Clothes_Dryer;

			};
		};
	print " - Complete\n";
	};
	
};

# print out the issues encountered during this script
print_issues('../summary_files/NN_Input_Gen.txt', $issues);

# ----------------------------------------------------------------------------------------------------------------------
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ----------------------------------------------------------------------------------------------------------------------
# AT THIS POINT, THE INPUT TO THE NN HAS BEEN COMPLETELY DEVELOPED.
# SUBSEQUENT TASKS INCLUDE RUNNING THE NN AND REFORMULATING THE RESULTS
# ----------------------------------------------------------------------------------------------------------------------
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# ----------------------------------------------------------------------------------------------------------------------

# Call the NN_Model.pl to calculate the annual energy consumption of the ALC and DHW
foreach my $distribution (@distributions) {
	print "Performing NN model calculations (MA Thesis) for $distribution";
	system "./NN_Model.pl $distribution";
	print " - Complete\n";
};


my $NN_output;	# Create a hash reference to store the results of the NN calculation so that we can reformulate them as required for Hse_Gen.pl

print "Reading the NN Results files";
foreach my $distribution (@distributions) {
	#open the correct file
	open (my $NN_OUTPUT_FILE , '<', "../NN/NN_model/$distribution-Results.csv") or die ("can't open datafile: ../NN/NN_model/$distribution-Results.csv");
	
	my $data_line;
	while ($data_line = one_data_line($NN_OUTPUT_FILE, $data_line)) {
		$NN_output->{$data_line->{'Filename'}}->{$distribution} = $data_line->{'GJ'};	# store the GJ of either ALC or DHW
	};
	close $NN_OUTPUT_FILE;
};
print " - Complete\n";

# print Dumper $NN_output;

print "Printing the organized CSDDRD DHW and AL csv file";

# Open a file to store the reformulated results. This will be used by Hse_Gen
open (DHW_AL , '>', "../CSDDRD/CSDDRD_DHW_AL_annual.csv") or die ("can't open datafile: ../CHREM/CSDDRD_DHW_AL_annual.csv");

# declare the parameters that we want to print out with the DHW and AL consumption for statistical purposes
my @parameters = ('AL-Dryer_GJpY', 'AL-Stove-Other_GJpY', 'stove_fuel_use', 'dryer_fuel_used', 'Clothes_Dryer', 'Rural_Suburb_Urban', 'Num_of_Adults', 'Num_of_Children', 'Employment_Ratio', 'HDD', 'Ground_Temp');
			
# print the header info
print DHW_AL CSVjoin ('*header', 'File_Name', 'Attachment', 'Region', 'DHW_LpY', 'DHW_GJpY', 'DHW_energy_src', 'NN_DHW_System_Efficiency', 'AL_GJpY', @parameters) . "\n";

# iterate through the types and regions
foreach my $hse_type (sort {$a cmp $b} values (%{$hse_types})) {	# for each house type
	foreach my $region (sort {$a cmp $b} values (%{$regions})) {	# for each region
		
		# iterate through each house
		foreach my $house (sort {$a cmp $b} keys (%{$CSDDRD->{$hse_type}->{$region}})) {
			# check that the house is a regular house, not a 'No-Dryer' house
			unless ($house =~ /No-Dryer/) {
				# declare an array to store the line items. These will be CSVjoin later and printed
				my @line = ('*data', $house, $hse_type, $region);
				
				# Convert energy consumption (GJ) to DHW draw (L)
				# GJ * efficiency * kJ/GJ / density / Cp / deltaT * L/m^3
				# Assume: 1000 kg/m^3, 4.18 kJ/kgK, deltaT is 55 C - annual 1.5 m depth ground temperature
				# Note temp setpoints for DHW range from 55 to 60 C (prevention of legionairres bacteria while not scalding). It appears ESP-r works with 55 (the DHW_module.F).
				my $LpY = sprintf ("%u", $NN_output->{$house}->{'DHW'} * $CSDDRD->{$hse_type}->{$region}->{$house}->{'NN_DHW_System_Efficiency'} * 1E6 / 1000 / 4.18 / (55 - $CSDDRD->{$hse_type}->{$region}->{$house}->{'Ground_Temp'}) * 1000);
				
				# store the DHW annual draw consumption (L) and ALC annual energy consumption (GJ) on the line
				push (@line, $LpY, $NN_output->{$house}->{'DHW'}, $CSDDRD->{$hse_type}->{$region}->{$house}->{'DHW_energy_src'}, $CSDDRD->{$hse_type}->{$region}->{$house}->{'NN_DHW_System_Efficiency'}, $NN_output->{$house}->{'ALC'});
				

				# calculate the AL-Dryer by taking the difference between the real house and the house with no dryer
				$CSDDRD->{$hse_type}->{$region}->{$house}->{'AL-Dryer_GJpY'} = sprintf ("%.2f", $NN_output->{$house}->{'ALC'} - $NN_output->{$house . '.No-Dryer'}->{'ALC'});
				
				# in certain houses, removing the dryer increases energy consumption. This is not possible, so set to zero if that is true and then attribute all of the AL loads to the AL-Stove-Other
				if ($CSDDRD->{$hse_type}->{$region}->{$house}->{'AL-Dryer_GJpY'} < 0) {
					$CSDDRD->{$hse_type}->{$region}->{$house}->{'AL-Dryer_GJpY'} = 0;
					$CSDDRD->{$hse_type}->{$region}->{$house}->{'AL-Stove-Other_GJpY'} = $NN_output->{$house}->{'ALC'};
				}
				
				# otherwise the dryer requires energy, so then the Stove-Other will be the remaining as determined by the No-Dryer scenario
				else {
					$CSDDRD->{$hse_type}->{$region}->{$house}->{'AL-Stove-Other_GJpY'} = $NN_output->{$house . '.No-Dryer'}->{'ALC'};
				};

				
				# print some indicator values

				print DHW_AL CSVjoin(@line, @{$CSDDRD->{$hse_type}->{$region}->{$house}}{@parameters}) . "\n";
			};

		};
	};
};

close DHW_AL;
print " - Complete\n";

