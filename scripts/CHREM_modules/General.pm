# ====================================================================
# CHREM_modules::Cross_ref.pl
# Author: Lukas Swan
# Date: July 2009
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# cross_ref_readin: a subroutine that reads in information from a tagged file and stores it in a hash reference
# key_XML_readin: a subroutine that reads in XML information with specific ForceArray information
# ====================================================================

# Declare the package name of this perl module
package CHREM_modules::General;

# Declare packages used by this perl module
use strict;
use CSV;	# CSV-2 (for CSV split and join, this works best)
use Data::Dumper;

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('hse_types_and_regions', 'one_data_line');


# ====================================================================
# hse_types_and_regions
# This subroutine recieves the user specified house type and region that
# is seperated by forward slashes. It interprets the appropriate House Types
# (e.g. 1 => 1-SD) and Regions (e.g. 2 => 2-QC) and outputs these back to
# the calling script. 
# It will also issue warnings if the input is malformed.
# ====================================================================

sub hse_types_and_regions {
	# house type and region in an ordered array
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
		if ($user_input->{$variable} == 0) {
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
	my $FILE = shift();
	# shift the existing data which may include the array of header info at $existing_data->{'header'}
	my $existing_data = shift();

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


# Final return value of one to indicate that the perl module is successful
1;
