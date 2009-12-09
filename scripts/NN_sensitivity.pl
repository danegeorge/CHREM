#!/usr/bin/perl

# ====================================================================
# NN_sensitivity.pl
# Author: Lukas Swan
# Date: Dec 2009
# Copyright: Dalhousie University

# INPUT USE:
# filename.pl

# DESCRIPTION:
# This script conducts a sensitivity analysis of the NN models.
# It reads in a base house case for comparitive purposes.
# The input file also includes the min/max values for each field
# as well as a *var (variance) value. The script then generates
# a new house for each field variant and leaving all remaining fields as the base
# The variants start with the min value, and then progressive variants have *var added
# to them. Finally, a max variant is also completed as it is likely the *var does not
# divide max into a whole number

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
# use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
use Data::Dumper;	# to dump info to the terminal for debugging purposes
# use Switch;
# use Storable  qw(dclone);
# use Hash::Merge qw(merge);

use lib qw(./modules);
use General;
# use Cross_reference;
# use Database;
# use Constructions;

$Data::Dumper::Sortkeys = \&order;

# Hash::Merge::specify_behavior(
# 	{
# 		'SCALAR' => {
# 			'SCALAR' => sub {$_[0] + $_[1]},
# 			'ARRAY'  => sub {[$_[0], @{$_[1]}]},
# 			'HASH'   => sub {$_[1]->{$_[0]} = undef},
# 		},
# 		'ARRAY' => {
# 			'SCALAR' => sub {[@{$_[0]}, $_[1]]},
# 			'ARRAY'  => sub {[@{$_[0]}, @{$_[1]}]},
# 			'HASH'   => sub {[@{$_[0]}, $_[1]]},
# 		},
# 		'HASH' => {
# 			'SCALAR' => sub {$_[0]->{$_[1]} = undef},
# 			'ARRAY'  => sub {[@{$_[1]}, $_[0]]},
# 			'HASH'   => sub {Hash::Merge::_merge_hashes($_[0], $_[1])},
# 		},
# 	}, 
# 	'Merge where scalars are added, and items are (pre)|(ap)pended to arrays', 
# );

# --------------------------------------------------------------------
# MAIN CODE
# --------------------------------------------------------------------

# Cycle through the ALC and DHW networks
foreach my $NN qw(ALC DHW) {
	# Declare a path and open the sensitivity input file which contains the min/max/var and base case house
	my $path = '../NN/NN_model/';
	my $file = $NN . '-Inputs-Sensitivity';
	my $ext = '.csv';
	my $FILE;

	open ($FILE, '<', $path . $file . $ext) or die ("Can't open datafile: $path$file$ext");	# open readable file

	# declare a storage variable to store the base case house
	my $base = {};

	# go through the lines of the and store everything
	# Note that this stores each different tagged item and returns the first data item (base case house)
	$base = &one_data_line_keyed($FILE, $base);

	close $FILE;

# 	print Dumper $input;

	# Now open a writeable file to overwrite the existing NN inputs with all of the house variants
	$file = $NN . '-Inputs-V2';
	open ($FILE, '>', $path . $file . $ext) or die ("Can't open datafile: $path$file$ext");	# open writeable file

	# Because of the way data is stored, only certain items are arrays (e.g. header, comments) and other items such as min/max/var/data are hashs that lookup values based on the header array
	# Thus, printout this information appropriately by checking the ref type
	# Also - note that there is an 'order' provided so that the file tag lines appear in the same order they were read from the original file
	foreach my $tag (@{$base->{'order'}}) {
		# Hash type so use the header array as keys
		if (ref($base->{$tag}) eq 'HASH') {
			print $FILE CSVjoin('*' .$tag, @{$base->{$tag}}{@{$base->{'header'}}}) . "\n";
		}
		# Array type so simply print in order
		elsif (ref($base->{$tag}) eq 'ARRAY') {
			print $FILE CSVjoin('*' .$tag, @{$base->{$tag}}) . "\n";
		}
		# Unexpected
		else {
			die "The tag \"$tag\" is not a HASH or ARRAY reference\n";
		};
	};
	
	# The following is to make the base case house us the same naming structure as the other houses
	# Stove the filename
	my $File_name = $base->{'data'}->{'File_name'};
	# Rename the filename using the correct format
	$base->{'data'}->{'File_name'} = 'base_base_0';
	# Output the base case house to the NN_Input
	print $FILE CSVjoin('*data', @{$base->{'data'}}{@{$base->{'header'}}}) . "\n";
	# Revert the base case filename
	$base->{'data'}->{'File_name'} = $File_name;
	
	# VARIATIONS - THIS SECTION CREATES ALL OF THE HOUSING VARIATIONS
	
	# Cycle through all of the fields with the exception of the filename (as we don't vary this)
	foreach my $field (@{$base->{'header'}}[1..$#{$base->{'header'}}]) {
		
		# Begin the variations for this field at the minimum value
		my $variation = $base->{'min'}->{$field};
		
		# Continue to make variations as long as they are less <= the maximum value for the field
		VARIATIONS: while ($variation <= $base->{'max'}->{$field}) {
		
			# Declare a storage hash for this particular house variant
			my $data;
			# Copy the base case house data hash for this house so that we do not have to revert it later (it falls out of scope)
			%{$data} = %{$base->{'data'}};
			
			# Set the field of the house variant equal to the new variation
			$data->{$field} = $variation;
			# Redefine the filename using the specified format to indicate it is a variant and what the field value is
			$data->{'File_name'} = $data->{'File_name'} . '_' . $field . '_' . $variation;
			
			# Print this house variant out to the NN_Input file
			print $FILE CSVjoin('*data', @{$data}{@{$base->{'header'}}}) . "\n";
			
			# The following will kick us out if we are equal to the max field value, so that we cycle onto the next field
			if ($variation == $base->{'max'}->{$field}) {
				last VARIATIONS;
			};
			
			# The next variation has a field value equal to the preceding value + the *var
			$variation = $variation + $base->{'var'}->{$field};
			
			# Check to see if this pushed us over the max value and if so, set it to the max value so that we have both a min and max house variant
			if ($variation > $base->{'max'}->{$field}) {
				$variation = $base->{'max'}->{$field};
			};
			
		};
	};

	close $FILE;
	
	# RUN THE NN MODEL FOR THIS TYPE
	system "./NN_Model.pl $NN";
	
	# Open the NN_Model results file so that we can reorganize the findings
	$file = $NN . '-Results';
	open ($FILE, '<', $path . $file . $ext) or die ("Can't open datafile: $path$file$ext");	# open readable file
	
	# declare a storage variable for the results for reorganization
	my $results = {};

	# This is used to keep the order of the variants as specified as the NN field input order
	# It begins with 'base' because we do not want to consider the base as a variant
	my $prev = 'base';
	
	# Declare a variable to store the *data info
	my $input = {};
	
	# go through the lines and store everything
	while ($input = &one_data_line_keyed($FILE, $input)) {
	
		# Split the filename to determine the house variant field and value
		$input->{'data'}->{'Filename'} =~ /^base_(\w+)_(\d+$|\d+\.\d+$)/;
		# Store the variant in the reorganized hash
		$results->{'data'}->{$1}->{$2} = sprintf("%u", $input->{'data'}->{'GJ'});
		
		# If this field is different then previous, store it at the order array ref so the printout is the same
		if ($1 ne $prev) {
			push(@{$results->{'order'}},$1);
			$prev = $1;
		};
	};
	
# 	print Dumper $results;
	
	close $FILE;
	
	# Open a file to store the organized sensitivity information
	$file = $NN . '-Results_Sensitivity';
	open ($FILE, '>', $path . $file . $ext) or die ("Can't open datafile: $path$file$ext");	# open writeable file
	
	# Add commenting
	print $FILE CSVjoin('*comment', "The following lines show the sensitivity of the $NN NN to the input variables") . "\n";
	print $FILE CSVjoin('*comment', "A Base case house was generated and then the variations were applied to see the change") . "\n";
	print $FILE CSVjoin('*comment', "The first row is the altered variable's input values; the second row contains the whole GJ consumption for these input values") . "\n";
	print $FILE CSVjoin('*comment', "The base case values are shown as the first column of data for reference") . "\n";
	print $FILE CSVjoin('*header', 'variable', 'type', 'base', 'variations') . "\n";
	
	# Cycle through the variant fields (note that base is not included here)
	foreach my $field (@{$results->{'order'}}) {
		# Find the variants and store them in order
		my @keys = &array_order(keys %{$results->{'data'}->{$field}});
		
		# Print the variant input data. Note that the base is the first column, then followed by variants
		print $FILE CSVjoin('*data', $field, 'Input', $base->{'data'}->{$field}, @keys) . "\n";
		# Print the variant results. Note that the base is the first column, then followed by variants
		print $FILE CSVjoin('*data', $field, 'GJ', $results->{'data'}->{'base'}->{0}, @{$results->{'data'}->{$field}}{@keys}) . "\n";
	};
	
	close $FILE;
	
};
	
	
