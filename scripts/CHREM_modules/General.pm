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
use Data::Dumper;

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('hse_types_and_regions');


# ====================================================================
# key_XML_readin
# This subroutine recieves the path to an XML file and a reference to 
# an array of labels that should be forced into an array. It then prints
# some user info and reads in all of the XML info with attention paid to
# the ForceArray
# ====================================================================

sub hse_types_and_regions {
	# house type and region
	my @variables = ('House_Type', 'Region');

	# common house type and region names
	my $define_names->{$variables[0]} = {1, '1-SD', 2, '2-DR'};	# house type names
	$define_names->{$variables[1]} = {1, '1-AT', 2, '2-QC', 3, '3-OT', 4, '4-PR', 5, '5-BC'};	# region names

	unless (@_ == 2) {die "ERROR hse_types_and_regions subroutine requires two user inputs to be passed\n";};
	
	# shift the user input of houses and regions, this is a hash slice
	my $user_input;
	@{$user_input}{@variables} = @_;

	# storage of the utilized house types and regions based on user input
	my $utilized;

	foreach my $variable (@variables) {
		# Check to see if the user wants all the names for that variable
		if ($user_input->{$variable} == 0) {
			$utilized->{$variable} = $define_names->{$variable};
		}
		
		else {
			my @values = split (/\//, $user_input->{$variable});	# regions to generate
			foreach my $value (@values) {
				if (defined ($define_names->{$variable}->{$value})) {	# check that region exists
					$utilized->{$variable}->{$value} = $define_names->{$variable}->{$value};
				}
				else {
					my @keys = sort {$a cmp $b} keys (%{$define_names->{$variable}});	# sort regions for following error printout
					die "$variable argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
				};
			};
		};
	};
	
	# Return the hash reference that includes all of the header and data
	return (@{$utilized}{@variables});
};


# Final return value of one to indicate that the perl module is successful
1;