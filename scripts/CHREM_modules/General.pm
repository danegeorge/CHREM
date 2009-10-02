# ====================================================================
# CHREM_modules::Cross_ref.pl
# Author: Lukas Swan
# Date: July 2009
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# hse_types_and_regions: a subroutine that reads in user input and stores returns the house type and region information
# header_line: a subroutine that reads a file and returns the header as an array within a hash reference 'header'
# one_data_line: a subroutine that reads a file and returns a line of data in the form of a hash ref with header field keys
# largest and smallest: simple subroutine to determine and return the largest or smallest value of a passed list
# check_range: checks value against min/max and corrects if require with a notice
# set_issue: simply pushes the issue into the issues hash reference in a formatted method
# print_issues: subroutine prints out the issues encountered by the script during execution
# distribution_array: returns an array of values distributed in accordance with a hash to a defined number of elements
# ====================================================================

# Declare the package name of this perl module
package CHREM_modules::General;

# Declare packages used by this perl module
use strict;
use CSV;	# CSV-2 (for CSV split and join, this works best)
use Data::Dumper;
use List::Util ('shuffle');

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('hse_types_and_regions', 'header_line', 'one_data_line', 'largest', 'smallest', 'check_range', 'set_issue', 'print_issues', 'distribution_array');


# ====================================================================
# hse_types_and_regions
# This subroutine recieves the user specified house type and region that
# is seperated by forward slashes. It interprets the appropriate House Types
# (e.g. 1 => 1-SD) and Regions (e.g. 2 => 2-QC) and outputs these back to
# the calling script. 
# It will also issue warnings if the input is malformed.
# ====================================================================

sub hse_types_and_regions {
	my @variables = ('House_Type', 'Region');

	# common house type and region names, note that they are specified using the ordered array from above
	my $define_names->{$variables[0]} = {1, '1-SD', 2, '2-DR'};	# house type names
	$define_names->{$variables[1]} = {1, '1-AT', 2, '2-QC', 3, '3-OT', 4, '4-PR', 5, '5-BC'};	# region names

	# check that two arguements were passed
	unless (@_ == 2) {die "ERROR hse_types_and_regions subroutine requires two user inputs to be passed\n";};
	
	# shift the user input of houses and regions, this is a hash slice
	my $user_input;
	@{$user_input}{@variables} = @_;


	# declare a storage hash ref of the utilized house types and regions based on user input
	my $utilized;

	# cycle through the two variable types (house types and regions)
	foreach my $variable (@variables) {
		# Check to see if the user wants all the names for that variable
		if ($user_input->{$variable} eq '0') {
			$utilized->{$variable} = $define_names->{$variable};	# set the utilized equal to the entire definition hash for this variable
		}
		
		# the user should have specified the exact types and regions they want, seperated by a forward slash
		else {
			my @values = split (/\//, $user_input->{$variable});	# split the input based on a forward slash

			# cycle through the resulting elements
			foreach my $value (@values) {
				# verify that the requested house type or region exists and then set it on the utilized array for this variable
				if (defined ($define_names->{$variable}->{$value})) {	# check that region exists
					$utilized->{$variable}->{$value} = $define_names->{$variable}->{$value}; # it does so add it to the utilized
				}
				
				# the user input does not match the definitions, so organize the definitions and return an error message to the user
				else {
					my @keys = sort {$a cmp $b} keys (%{$define_names->{$variable}});	# sort for following error printout
					die "$variable argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";	# error printout
				};
			};
		};
	};
	
	# Return the ordered hash slice so that the house type hash is first, followed by the region hash
	return (@{$utilized}{@variables});
};


# ====================================================================
# header_line
# This subroutine is similar to a one_data_line, but
# instead only reads in the header.

# The header is stored as an ordered array at the location header (i.e. 
# $CSDDRD->{'header'}->[header array is here]

# This subroutine returns either header or
# returns a 0 for False so that the calling while loop terminates.
# ====================================================================

sub header_line {
	# shift the passed file path
	my $FILE = shift;

	my $new_data;	# create an crosslisting hash reference

	# Cycle through the File until suitable data is encountered
	while (<$FILE>) {

		$_ =~ s/\r\n$|\n$|\r$//g;	# chomp the end of line characters off (dos, unix, or mac)
		$_ =~ s/^\s+|\s+$//g;	# remove leading and trailing whitespace
		
		# Check to see if header has not yet been encountered. This will fill out $new_data once
		if ($_ =~ s/^\*header,//) {	# header row has *header tag, so remove this portion, leaving ALL remaining CSV information
			$new_data->{'header'} = [CSVsplit($_)];	# split the header into an array
			# We have successfully identified the header, so return this to the calling program
			return ($new_data);
		}
	
	# No header was found on that iteration, so continue to read through the file to find data, until the end of the file is encountered
	};
	

	# The end of the file was reached, so return a 0 (false) so that the calling routine moves onward
	return (0);
};




# ====================================================================
# one_data_line
# This subroutine is similar to a complete tagged file readin, but
# instead only reads in one data line at a time. This is to be used
# with very large files that require processing one line at a time.
# The CSDDRD is such a file.

# Both the filehandle and existing data hash reference are passed to 
# the subroutine. The existing data hash is examined to see if header 
# information is present and if so this is used. This is because this
# subroutine will forget the header information as soon as it returns.

# The file read is similar to an entire read, but stores all items, and
# does not use the second element as an identifier, because there is only
# one data hash.

# NOTE:Because this is intended for the CSDDRD and it is nice to keep the
# name short, all of the data is stored at the base hash reference (i.e.
# at $CSDDRD->{HERE}, not at $CSDDRD->{'data'}->{HERE}). Therefore, the 
# header is stored as an ordered array at the location header (i.e. 
# $CSDDRD->{'header'}->[header array is here]

# This subroutine returns either data (to be used in a while loop) or
# returns a 0 for False so that the calling while loop terminates.
# ====================================================================

sub one_data_line {
	# shift the passed file path
	my $FILE = shift;
	# shift the existing data which may include the array of header info at $existing_data->{'header'}
	my $existing_data = shift;

	my $new_data;	# create an crosslisting hash reference

	if (defined ($existing_data->{'header'})) {
		$new_data->{'header'} = $existing_data->{'header'};
	}

	# Cycle through the File until suitable data is encountered
	while (<$FILE>) {

		$_ =~ s/\r\n$|\n$|\r$//g;	# chomp the end of line characters off (dos, unix, or mac)
		$_ =~ s/^\s+|\s+$//g;	# remove leading and trailing whitespace
		
		# Check to see if header has not yet been encountered. This will fill out $new_data once and in subsequent calls to this subroutine with the same file the header will be set above.
		if ($_ =~ s/^\*header,//) {	# header row has *header tag, so remove this portion, leaving ALL remaining CSV information
			$new_data->{'header'} = [CSVsplit($_)];	# split the header into an array
		}
		
		# Check for the existance of the data tag, and if so store the data and return to the calling program.
		elsif ($_ =~ s/^\*data,//) {	# data lines will begin with the *data tag, so remove this portion, leaving the CSV information
			
			# create a hash slice that uses the header and data
			# although this is a complex structure it simply creates a hash with an array of keys and array of values
			# @{$hash_ref}{@keys} = @values
			@{$new_data}{@{$new_data->{'header'}}} = CSVsplit($_);

			# We have successfully identified a line of data, so return this to the calling program, complete with the header information to be passed back to this routine
			return ($new_data);
		};
	
	# No data was found on that iteration, so continue to read through the file to find data, until the end of the file is encountered
	};
	
	
	# The end of the file was reached, so return a 0 (false) so that the calling routine moves onward
	return (0);
};


# ====================================================================
# largest and smallest
# The following two subroutines simply examine the passed list and return
# either the largest or smallest value in that list
# ====================================================================

sub largest {	# subroutine to find the largest value of the provided list
	my $value = shift;	# set equal to the first value
	foreach my $test_value (@_) {
		if ($test_value > $value) {
			$value = $test_value;
		};
	};
	return ($value);
};

sub smallest {	# subroutine to find the smallest value of the provided list
	my $value = shift;	# set equal to the first value
	foreach my $test_value (@_) {
		if ($test_value < $value) {
			$value = $test_value;
		};
	};
	return ($value);
};


# ====================================================================
# check_range
# This subroutine checks a value against a min/max range and sets the
# value to either if required. It will note this in the $issues hash ref
# ====================================================================

sub check_range {
	my $value = shift;	# key to check for values
	my $min = shift;
	my $max = shift;
	my $area = shift;
	my $coordinates = shift;
	my $issues = shift;
	
	# check the minimum and add it to the hash ref if so
	if ($value < $min) {
		if ($area =~ /^Door (\w+) (\d)$/) {
			$issues = set_issue($issues, 'Door', "$1 less than minimum $min, setting to the minimum value (Door_# house_value house_name)", "$2 $value", $coordinates);
		}
		
		else {
			$issues = set_issue($issues, $area, "Less than minimum $min, setting to the minimum value", $value, $coordinates);
		};
	
		return ($min, $issues);
	}
	# check the max and add it to the hash ref if so
	elsif ($value > $max) {
		if ($area =~ /^Window width on Side/) {
			$issues = set_issue($issues, $area, 'Greater than maximum, setting to the maximum value (house_value maximum house_name)', "$value $max", $coordinates);
		}
		elsif ($area =~ /^Door (\w+) (\d)$/) {
			$issues = set_issue($issues, 'Door', "$1 greater than maximum $max, setting to the maximum value (Door_# house_value house_name)", "$2 $value", $coordinates);
		}
		else {
			$issues = set_issue($issues, $area, "Greater than maximum $max, setting to the maximum value", $value, $coordinates);
		};
		
		return ($max, $issues);
	};
	return ($value, $issues);
};


# ====================================================================
# set_issue
# This subroutine simply puts the issue information into the issues variable
# It is simply to save a little line space in the script
# ====================================================================

sub set_issue {
	my $issues = shift;
	my $area = shift;
	my $problem = shift;
	my $value = shift;
	my $coordinates = shift;
	
	#set_issue($issues, $issue_area, $problem, $value, $coordinates);
	
	$issues->{$area}->{$problem}->{$coordinates->{'hse_type'}}->{$coordinates->{'region'}}->{$coordinates->{'file_name'}} = $value;
	
	return ($issues);
};


# ====================================================================
# print_issues
# This subroutine prints out the issues encountered by the script during
# execution. The format is set below which is easy to look at in a text
# editor. In the future additional output files may be set to output in 
# different formats (e.g. csv, xml)
# ====================================================================

sub print_issues {

	my $file = shift;
	my $issues = shift;
	
	print "Printing the ISSUES to $file";
	
	open (my $ISSUES_TXT, '>', $file) or die ("can't open datafile: $file");
	print $ISSUES_TXT "THIS FILE HOLDS THE HSE_GEN ISSUES - the total number of instances is at the bottom of this file"; 

	# The following $instances will count the number of times an error is encountered for reporting purposes.
	my $instances->{'total'} = 0;
	
	# NOTE NOTE The below is a HUGE issue. For some reason I could not do a 3D Hash as $instances->{'unique'}->{$instance} = 1 to count the unique instances. It seems to overwrite the value with a random number and then fails because it cannot access the correct thing. I do not see any issue in the code. It works to half way through and even though $instance is a house name it ends up with a value like '1234562435' instead of '1234567890.HDF' and dies.
	# The below unique is to get around the problem, but I MUST FIND A SOLUTION
	my $unique;
	

	foreach my $issue (sort {$a cmp $b} keys (%{$issues})) {	# cycle through the issues
		$instances->{'issue'} = 0; # this sums up the number of instances of the issue (all problems) for each type and region
		# The ISSUE refers to a field: e.g. HDD or PostalCode
		print $ISSUES_TXT "\n\nISSUE - $issue\n";
		
		foreach my $problem (sort {$a cmp $b} keys (%{$issues->{$issue}})) {	# cycle thorugh problems
			$instances->{'problem'} = 0;	# this sums up the number of instances of the problem for each type and region
			# The PROBLEM is where the problem lies for the ISSUE: e.g. min or max or malformed PostalCode
			print $ISSUES_TXT "\n\tPROBLEM - $problem\n";
			
			# go through the house types and region
			foreach my $hse_type (sort {$a cmp $b} keys (%{$issues->{$issue}->{$problem}})) {
				foreach my $region (sort {$a cmp $b} keys (%{$issues->{$issue}->{$problem}->{$hse_type}})) {
					
					# count the instances for this type/region
					my $type_region_instances = keys (%{$issues->{$issue}->{$problem}->{$hse_type}->{$region}});
					# keep track of the total
					foreach my $type (keys %{$instances}) {
						$instances->{$type} = $instances->{$type} + $type_region_instances;
					};

					print $ISSUES_TXT "\t\tHouse Type: $hse_type; Region $region; instances $type_region_instances\n";
					
					print $ISSUES_TXT "\t\t";
					my $counter = 1;	# set the counter, we will use this so we can put multiple houses on a line withour running over
					# print $ISSUES_TXT each instance with information to a new line so it may be examined
					foreach my $instance (sort {$a cmp $b} keys (%{$issues->{$issue}->{$problem}->{$hse_type}->{$region}})) {	# cycle through each house with this problem
					
					
						# NOTE NOTE see below here, the commented $instances will cause this program to bomb.
# 						print Dumper $instance;
# 						$instances->{'unique'}->{$instance} = 1;
						$unique->{$instance} = 1;
						
					
					
						# if enough have been printed, then simply go to next line and reset counter
						if ($counter >= 4) {
							print $ISSUES_TXT "\n\t\t\t$issues->{$issue}->{$problem}->{$hse_type}->{$region}->{$instance} $instance";
							$counter = 1;
						}
						# there is still room to print so add a tab and then the value/house
						else {
							print $ISSUES_TXT "    $issues->{$issue}->{$problem}->{$hse_type}->{$region}->{$instance} $instance";
						};
						$counter++;	# increment counter
						


					};
					print $ISSUES_TXT "\n";
					
# 					print Dumper $instances;
# 					print Dumper $unique;
				};
			};
			# final count for that problem
			print $ISSUES_TXT "\tInstances of Problem $problem: $instances->{'problem'}\n";
		};
		print $ISSUES_TXT "\nInstances of Issue $issue: $instances->{'issue'}\n";
	};
	print $ISSUES_TXT "\nTotal instances ALL: $instances->{'total'}\n";
	
	my $unique_keys = keys (%{$unique});
	print $ISSUES_TXT "Total instances UNIQUE HOUSES: $unique_keys\n";
	
	print " - Complete\n";
	return (1);
};


# ====================================================================
# distribution_array
# This subroutine develops a shuffled array of values based on a distribution
# defined at $hash = {value1 => distribution_ratio2, value1 => distribution_ratio2...}
# where the number of array elements desired is provided.
# The array is returned from the subroutine.
# For example: 
# Passed: $hash = {'RED' => 0.25, 'BLUE' => 0.75}; $count = 4
# Return: ['BLUE', 'BLUE', 'RED', 'BLUE']
# ====================================================================

sub distribution_array {

	my $distribution = shift(); # hash reference containing {header1 => dist_data1, header2 => dist_data2...}
	my $count = shift(); # the number of elements desired (typically number of houses)

	my @data; # the array to store the values that will be returned
	
	# go through each element of the header, remember this is the value to be provided to the house file
# 	foreach my $element (0..$#{$NN_xml->{'combined'}->{$key}->{'header'}}) {
	foreach my $key (keys (%{$distribution})) {
		
		# determine the size that the array should be with the particular header value (multiply the distribution by the house count)
		# NOTE I am using sprintf to cast the resultant float as an integer. Float is still used as this will perform rounding (0.5 = 1 and 0.49 = 0). If I had cast as an integer it simply truncates the decimal places (i.e. always rounding down)
		my $index_size = sprintf('%.f', $distribution->{$key} * $count);
		
		# only fill out the array if the size is greater than zero (this eliminates pushing the value 1 time when no instances are present)
		if ($index_size > 0) {
			# use the index size to fill out the array with the appropriate header value. Note that we start with 1 because 0 to value is actually value + 1 instances
			# go through the array spacing and set the each spaced array element equal to the header value. This will generate a large array with ordered values corresponding to the distribution and the header. NOTE each element value will be used to represent the data for one house of the variable
				
			
			foreach my $index (1..$index_size) {
				# push the header value onto the data array. NOTE: we will check for rounding errors (length) and shuffle the array later
				push (@data, $key);
			};
			
			
		};
	};

	
	# SHUFFLE the array to get randomness b/c we do not know this information for a particular house.
	@data = shuffle (@data);
	
	# CHECK for rounding errors that will cause the array to be 1 or more elements shorter or longer than the number of houses.
	# e.g. three equal distributions results in 10 houses * [0.33 0.33 0.33] results in [3 3 3] which is only 9 elements!
	# if this is true: the push or pop on the array. NOTE: I am using the first array element and this is legitimate because we previously shuffled, so it is random.
	while (@data < $count) {	# to few elements
		push (@data, $data[0]);
		# in case we do this more than once, I am shuffling it again so that the first element is again random.
		@data = shuffle (@data);
	};
	while (@data > $count) {	# to many elements
		shift (@data);
	};
	
	return (@data);
};



# Final return value of one to indicate that the perl module is successful
1;
