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

use CSV;	# CSV-2 (for CSV split and join, this works best)
# use Array::Compare;	# Array-Compare-1.15
# use threads;	# threads-1.71 (to multithread the program)
# use File::Path;	# File-Path-2.04 (to create directory trees)
# use File::Copy;	# (to copy the input.xml file)
use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
use Data::Dumper;
use List::Util 'shuffle';

# --------------------------------------------------------------------
# Declare the input variables
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

	# The following is an artifact of the development process where the ALC and DHW could be developed seperately.
	# This has now been fixed b/c both are required for the format used by Hse_Gen.pl script.
	@distributions = ('ALC', 'DHW');

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
		
		# also push onto the types_regions so we can evaluate these later during xml readin
		push (@types_regions, "$hse_type-$region_name");
	};
};

my $NN_xml;	# declare a reference to a hash to store the xml data (use $NN_xml->{ALC or DHW}

my $NN_xml_keys;	# declare a reference to a hash to store the name keys of each type of xml data

foreach my $distribution (@distributions) {
	# Readin the ALC and DHW xml files and force certain arrays for the distribution_options
	$NN_xml->{$distribution} = XMLin("../NN/NN_model/$distribution" . '_distributions.xml', ForceArray => [@distribution_options]);	# readin the xm
	
# 	print Dumper $NN_xml->{$distribution};

	# Cycle through the nodes to list them in the header
	# AND to check the xml data for validity
	foreach my $node (@{$NN_xml->{$distribution}->{'node'}}) {
	
		# add the name to an array in nodal order such that we may iterate over this at a later point
		push (@{$NN_xml_keys->{$distribution}}, $node->{'var_name'});

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

# print Dumper $NN_xml->{'combined'}

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
		foreach my $node (@{$NN_xml->{$distribution}->{'node'}}) {
			print {$NN_input->{$distribution}} ",$node->{$tag}";	# print the node name
		};
		print {$NN_input->{$distribution}} "\n";	# newline b/c we have reached the end of the NN Input header
	};
};



# The following are global variables for storing CSDDRD information
my $CSDDRD;	# the CSDDRD info

# The following is a hash to name the fields of the CSDDRD and will be used to save only certain items (as that is all we need for NN)
my %CSDDRD_fields = ('filename', 1, 'region', 3, 'city', 4, 'postalcode', 5, 'heat_sys_fuel', 75, 'heat_sys_type', 78, 'DHW_fuel', 80, 'DHW_sys_type', 81, 'DHW_eff', 82, 'Ventilation', 83, 'FA1', 97, 'FA4', 100, 'FA5', 101, 'FA6', 102);

# The following will provide an arbitrary order for the hash. Later in the code, a hash "slice" is developed using the keys and values, but we have to make sure they are in the same order, so we have to call keys earlier, not during the operation.
my @CSDDRD_keys = keys (%CSDDRD_fields);

# A global hash reference to store the names of the houses
my $file_name;

my $data;	# declare an reference to store all of the developed data structures that hold the input data to the NN. These will include the randomized values for the houses.

# Readin the hvac xml information as it indicates furnace fan and boiler pump variables
my $hvac = XMLin("../keys/hvac_key.xml", ForceArray => 1);	# readin the HVAC cross ref
# print Dumper $hvac;

# Readin the dhw xml information to cross ref the system efficiency used for the NN
my $dhw_energy_src = XMLin("../keys/dhw_key.xml", ForceArray => 1);	# readin the DHW cross ref

# -----------------------------------------------
# Read in the CWEC weather data crosslisting
# -----------------------------------------------
# Open and read the climate crosslisting (city name to CWEC file)
open (CLIMATE, '<', "../climate/Weather_HOT2XP_to_CWEC.csv") or die ("can't open datafile: ../climate/Weather_HOT2XP_to_CWEC.csv");

my $climate_ref;	# create an climate reference crosslisting hash
my @climate_header;	# declare array to hold header data

while (<CLIMATE>) {

	if ($_ =~ s/^\*header,//) {	# header row has *header tag
		@climate_header = CSVsplit($_);	# split the header onto the array
	}
		
	elsif ($_ =~ s/^\*data,//) {	# data lines will begin with the *data tag
		@_ = CSVsplit($_);	# split the data onto the @_ array
		
		# create a hash that uses the header and data array
		@{$climate_ref->{$_[0]}}{@climate_header} = @_;
	};
};
close CLIMATE;	# close the CLIMATE file




# GO THROUGH THE HOUSE TYPES AND REGIONS SO AS TO BUILD ARRAYS WITH THE RANDOMIZED VALUES FOR APPLICATION TO THE HOUSES

foreach my $hse_type (@hse_types) {	# go through each house type
	foreach my $region (@regions) {	# go through each region type
	
		# open the CSDDRD files
		my $input_path = "../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_$hse_names{$hse_type}_subset_$region_names{$region}.csv";
		open (CSDDRD, '<', $input_path) or die ("can't open datafile: $input_path");
		
		$_ = <CSDDRD>;	# strip the header info
		
		while (<CSDDRD>) {
			@_ = CSVsplit($_);	# split each of the comma delimited fields of the house record
			# Store the CSDDRD information that is required for subsequent logic. Use the desired fields from above. NOTE: this is hash slice that uses the hash as a guide to identify and label data from the CSDDRD
			@{$CSDDRD->{$hse_type}->{$region}->{$_[1]}}{@CSDDRD_keys} = @_[@CSDDRD_fields{@CSDDRD_keys}];
			
			# shorten the name to the house while within the loop
			my $house = $CSDDRD->{$hse_type}->{$region}->{$_[1]};
# 			print Dumper $house;
			# PERFORM SUBSEQUENT PROCESSING TO DETERMINE VARIABLES REQUIRED FOR THE NN FROM THE CSDDRD INFORMATION
			
			# check for presence of a furnace fan or boiler pump by cross referencing to the hvac.xml
			foreach my $fan_pump ('Furnace_Fan', 'Boiler_Pump') {
				$house->{$fan_pump} = $hvac->{'energy_type'}->[$house->{'heat_sys_fuel'}]->{'system_type'}->[$house->{'heat_sys_type'}]->{$fan_pump};
				&check_min_max ($house, $fan_pump);
			};
# 			print "fan_pump check- fan: $house->{'Furnace_Fan'}; pump: $house->{'Boiler_Pump'}\n";

			# calculate the heated floor area
			$house->{'Area'} = 0;	# intialize to zero
			foreach my $level (1, 4, 5, 6) {$house->{'Area'} = $house->{'Area'} + $house->{"FA$level"}};	# add up basement, first, second, and third floors
			&check_min_max ($house, 'Area');

			# check the ventilation system for bathroom exhaust fans
			if ($house->{'Ventilation'} >= 4 && $house->{'Ventilation'} <= 5) {
			
				# fans are true, but set to 2 or 1 depending on the heated floor area (1 up to 175 m^2, and 2 for larger size)
				if ($house->{'Area'} > 175) {$house->{'Bath_Exhaust_Fan'} = 2;}
				else {$house->{'Bath_Exhaust_Fan'} = 1;};
			}
			# no bathroom fans
			else {$house->{'Bath_Exhaust_Fan'} = 0;};
			&check_min_max ($house, 'Bath_Exhaust_Fan');
			
			# check CVS
			if ($house->{'Ventilation'} == 3) {$house->{'Central_Air_Exchanger'} = 1;}
			else {$house->{'Central_Air_Exchanger'} = 0;};
			&check_min_max ($house, 'Central_Air_Exchanger');
			
			# check HRV
			if ($house->{'Ventilation'} == 2 || $house->{'Ventilation'} == 5) {$house->{'HRV'} = 1;}
			else {$house->{'HRV'} = 0;};
			&check_min_max ($house, 'HRV');
			
			# check HDD
			$house->{'HDD'} = $climate_ref->{$house->{'city'}}->{'CWEC_EC_HDD_18C'};
			&check_min_max ($house, 'HDD');

			# check CDD
			$house->{'CDD'} = $climate_ref->{$house->{'city'}}->{'CWEC_EC_CDD_24C'};
			&check_min_max ($house, 'CDD');
			
			# determine the DHW system efficiency: NOTE: use the NN values of Merih Aydinalp
			$house->{'NN_DHW_System_Efficiency'} = $dhw_energy_src->{'energy_type'}->[$house->{'DHW_fuel'}]->{'NN_DHW_System_Efficiency'};
			&check_min_max ($house, 'NN_DHW_System_Efficiency');
			
			# determine the ground temperature (annual average, at 3 m depth?)
			$house->{'Ground_Temp'} = $climate_ref->{$house->{'city'}}->{'BASECALC_GND_TEMP_AVG_C'};
			&check_min_max ($house, 'Ground_Temp');
			
		};
		
		# fill out the filename in a particular order so we can use this as a key in the future, allowing us to get back to the particular location.
		$file_name->{$hse_type}->{$region} = [keys (%{$CSDDRD->{$hse_type}->{$region}})];
		my $count = @{$file_name->{$hse_type}->{$region}};	# count the number of houses
		print "House Type: $hse_type; Region: $region; Count: $count\n";
		
		# discern the names of the type and region using the hashes, these will be used to access data from the xml
		my $type_name = $hse_names_only{$hse_type};
		my $region_name = $region_names_only{$region};


		# go through each xml distribution node
		# NOTE:we are using the combined distribution here to fill out the input data so there is no overlap in the distribution types (ALC or DHW)
		# This process is un-ordered for now as it will be placed into a data hash
		foreach my $key (keys %{$NN_xml->{'combined'}}) {

			$data->{$hse_type}->{$region}->{$key} = [];	# add an array reference to the data hash reference to keep the data
			
			
			
			# go through each element of the header, remember this is the value to be provided to the house file
			foreach my $element (0..$#{$NN_xml->{'combined'}->{$key}->{'header'}}) {
				
				# determine the size that the array should be with the particular header value (multiply the distribution by the house count)
				# NOTE I am using sprintf to cast the resultant float as an integer. Float is still used as this will perform rounding (0.5 = 1 and 0.49 = 0). If I had cast as an integer it simply truncates the decimal places (i.e. always rounding down)
				my $index_size = sprintf("%.f", $NN_xml->{'combined'}->{$key}->{"$type_name-$region_name"}->[$element] * $count);
				
				# only fill out the array if the size is greater than zero (this eliminates pushing the value 1 time when no instances are present)
				if ($index_size > 0) {
					# use the index size to fill out the array with the appropriate header value. Note that we start with 1 because 0 to value is actually value + 1 instances
					# go through the array spacing and set the each spaced array element equal to the header value. This will generate a large array with ordered values corresponding to the distribution and the header. NOTE each element value will be used to represent the data for one house of the variable
					foreach my $index (1..$index_size) {
						# push the header value onto the data array. NOTE: we will check for rounding errors (length) and shuffle the array later
						push (@{$data->{$hse_type}->{$region}->{$key}}, $NN_xml->{'combined'}->{$key}->{'header'}->[$element]);
					
					};
					
				};
			};

			
			# SHUFFLE the array to get randomness b/c we do not know this information for a particular house.
			@{$data->{$hse_type}->{$region}->{$key}} = shuffle (@{$data->{$hse_type}->{$region}->{$key}});
			
			# CHECK for rounding errors that will cause the array to be 1 or more elements shorter or longer than the number of houses.
			# e.g. three equal distributions results in 10 houses * [0.33 0.33 0.33] results in [3 3 3] which is only 9 elements!
			# if this is true: the push or pop on the array. NOTE: I am using the first array element and this is legitimate because we previously shuffled, so it is random.
			while (@{$data->{$hse_type}->{$region}->{$key}} < $count) {	# to few elements
				push (@{$data->{$hse_type}->{$region}->{$key}}, $data->{$hse_type}->{$region}->{$key}->[0]);
				# in case we do this more than once, I am shuffling it again so that the first element is again random.
				@{$data->{$hse_type}->{$region}->{$key}} = shuffle (@{$data->{$hse_type}->{$region}->{$key}});
			};
			while (@{$data->{$hse_type}->{$region}->{$key}} > $count) {	# to many elements
				shift (@{$data->{$hse_type}->{$region}->{$key}});
			};
			

# 			print "@{$data->{$hse_type}->{$region}->{$key}}\n";

			# NOTE this completes the random distribution organization of the variables for the CSDDRD NN.
		};
		

		# Go through the houses and develop the files required by the NN_Model.pl script
		foreach my $house (0..$#{$file_name->{$hse_type}->{$region}}) {	# do this by element number so we can call certain locations in the array. We are not popping from the array as we need to cross reference certain items later in the code to redevelop files for Hse_Gen and to go from DHW GJ to Litres

			foreach my $distribution (@distributions) {
			
				printf {$NN_input->{$distribution}} ("%s,%s", '*data', $file_name->{$hse_type}->{$region}->[$house]);	# info

				foreach my $field (@{$NN_xml_keys->{$distribution}}) {	# cycle over the required values for the particular NN (either ALC or DHW)
				
					# The following checks to see if data for that field is accessible from the CSDDRD, if not it reverts to the distributions
					
					# Check if data is defined for that field in the CSDDRD
					if (defined ($CSDDRD->{$hse_type}->{$region}->{$file_name->{$hse_type}->{$region}->[$house]}->{$field})) {
						# it is, so print out the CSDDRD data
						print {$NN_input->{$distribution}} ",$CSDDRD->{$hse_type}->{$region}->{$file_name->{$hse_type}->{$region}->[$house]}->{$field}";
# 						print "FOUND: $field\n";
					}
					
					# The data is not present, so use the distribution
					else {
						print {$NN_input->{$distribution}} ",$data->{$hse_type}->{$region}->{$field}->[$house]";	# get that particular array element and write it out
# 						print "NOT FOUND: $field\n"
					};
				};
				print {$NN_input->{$distribution}} "\n";	# newline as we have reached the end of that house.
			};
		};

	};
	
};

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
	system "./NN_Model.pl $distribution";
};


my $NN_output;	# Create a hash reference to store the results of the NN calculation so that we can reformulate them as required for Hse_Gen.pl

foreach my $distribution (@distributions) {
	#open the correct file
	open (NN_OUTPUT , '<', "../NN/NN_model/$distribution-Results.csv") or die ("can't open datafile: ../NN/NN_model/$distribution-Results.csv");
	
	while (<NN_OUTPUT>) {
		if (/^\*data/) {	# only if a data line is encountered do we do something
			@_ = CSVsplit($_);
			$NN_output->{$_[1]}->{$distribution} = $_[2];	# store the GJ of either ALC or DHW
		};
	};
	close NN_OUTPUT;
};

# print Dumper $NN_output;

# Open a file to store the reformulated results. This will be used by Hse_Gen
open (DHW_AL , '>', "../CSDDRD/CSDDRD_DHW_AL_annual.csv") or die ("can't open datafile: ../CHREM/CSDDRD_DHW_AL_annual.csv");

# print the header info
print DHW_AL "*header,File_Name,Attachment,Region,DHW_LpY,AL_GJ\n";

# iterate through the types and regions
foreach my $hse_type (@hse_types) {
	foreach my $region (@regions) {
		
		# iterate through each house
		foreach my $house (0..$#{$file_name->{$hse_type}->{$region}}) {
			# determine the name of the house and print it
			my $record = $file_name->{$hse_type}->{$region}->[$house];
			print DHW_AL "*data,$record,$hse_type,$region,";
			
			# Convert energy consumption (GJ) to DHW draw (L)
			# GJ * efficiency * kJ/GJ / density / Cp / deltaT * L/m^3
			# Assume: 1000 kg/m^3, 4.18 kJ/kgK, deltaT of 50 C
			printf DHW_AL ("%u", $NN_output->{$file_name->{$hse_type}->{$region}->[$house]}->{'DHW'} * $CSDDRD->{$hse_type}->{$region}->{$file_name->{$hse_type}->{$region}->[$house]}->{'NN_DHW_System_Efficiency'} * 1E6 / 1000 / 4.18 / 50 * 1000);
			
			# print the ALC annual energy consumption (GJ)
			print DHW_AL ",$NN_output->{$file_name->{$hse_type}->{$region}->[$house]}->{'ALC'}\n";
		};
	};
};

close DHW_AL;


sub check_min_max () {
	my $house = shift (@_);	# house
	my $check = shift (@_);	# key to check for values
	
	my $min = $NN_xml->{'combined'}->{$check}->{'min'};
	my $max = $NN_xml->{'combined'}->{$check}->{'max'};
	
	if ($house->{$check} < $min) {
		print "WARNING in $house->{'filename'}: $check of $house->{$check} is less than minimum of $min, SETTING TO THE MIN VAL!\n";
		$house->{$check} = $min;
	}
	elsif ($house->{$check} > $max) {
		print "WARNING in $house->{'filename'}: $check of $house->{$check} is greater than maximum of $max, SETTING TO THE MAX VAL!\n";
		$house->{$check} = $max;
	};

};