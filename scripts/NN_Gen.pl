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


my @distribution_options = ('header');	# declare an array to hold all of the hse_type and region varieties (e.g. SD, AT, SD-AT


# Cycle through each of the types to generate a list
foreach my $hse_type (values (%hse_names_only)) {
	push (@distribution_options, $hse_type);	
	foreach my $region_name (values (%region_names_only)) {
		push (@distribution_options, $region_name, "$hse_type-$region_name");
	};
};

print "@distribution_options\n";

# Readin the ALC and DHW xml files and force arrays for the distribution_options
my $ALC_xml = XMLin("../NN/NN_model/ALC_distributions.xml", ForceArray => [@distribution_options]);	# readin the ALC xml
# my $DHW_xml = XMLin("../NN/NN_model/DHW_distributions.xml", ForceArray => [@distribution_options]);	# readin the DHW xml

print Dumper $ALC_xml;

# -----------------------------------------------
# Read in the DHW and AL annual energy consumption CSDDRD listing
# -----------------------------------------------	
# Open the DHW and AL file
open (DHW_AL, '<', "../CSDDRD/CSDDRD_DHW_AL_annual.csv") or die ("can't open datafile: ../CSDDRD/CSDDRD_DHW_AL_annual.csv");
open (ALC, '>', "../NN/NN_model/ALC-Inputs-V2.csv") or die ("can't open datafile: ../NN/NN_model/ALC-Inputs-V2.csv");
# open (DHW, '>', "../NN/NN_model/DHW-Inputs-V2.csv") or die ("can't open datafile: ../NN/NN_model/DHW-Inputs-V2.csv");

print ALC "Number,File_name";

foreach my $node (@{$ALC_xml->{'node'}}) {
	print ALC ",$node->{'var_name'}";
};

print ALC "\n";

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

# foreach
# 
# foreach my $hse_type (@{$dhw_al}) {
# 	foreach my $type_region (@{$hse_type}) {
# 		my $count = @{$type_region};
# 		


