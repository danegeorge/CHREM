#!/usr/bin/perl
# 
#====================================================================
# Results_collate.pl
# Author:    Lukas Swan
# Date:      Apr 2010
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl collated_set_name [set_names_to_be_collated]
#
# DESCRIPTION:
# This script collates results


#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;

# use CSV; #CSV-2 (for CSV split and join, this works best)
#use Array::Compare; #Array-Compare-1.15
#use Switch;
# use XML::Simple; # to parse the XML results files
use XML::Dumper;
# use threads; #threads-1.71 (to multithread the program)
#use File::Path; #File-Path-2.04 (to create directory trees)
#use File::Copy; #(to copy files)
use Data::Dumper; # For debugging
# use Storable  qw(dclone); # To create copies of arrays so that grep can do find/replace without affecting the original data
use Hash::Merge qw(merge); # To merge the results data

# CHREM modules
use lib ('./modules');
use General; # Access to general CHREM items (input and ordering)
use Results; # Subroutines for results accumulations

# Set Data Dumper to report in an ordered fashion
$Data::Dumper::Sortkeys = \&order;

# # Set merge to add and append
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


#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------
my $collated_set_name; # store the results set name
my @set_names; # Store the set names to collate

# Determine possible set names by scanning the summary_files folder
my $possible_set_names = {map {$_, 1} grep(s/.+Results_(.+)_All.xml/$1/, <../summary_files/*>)}; # Map to hash keys so there are no repeats
my @possible_set_names_print = @{&order($possible_set_names)}; # Order the names so we can print them out if an inappropriate value was supplied

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if (@ARGV < 3) {die "A minimum THREE arguments are required: collated_set_name set_name_1 set_name_2\nPossible set_names are: @possible_set_names_print\n";};
	
	$collated_set_name = shift(@ARGV); # Shift the collated_set_name
	# Check that the collated_set_name does not exist in the summary_ files as a simulated set. NOTE that this will replace a previous collation summary though
	if (defined($possible_set_names->{$collated_set_name})) {
		die "The collated set_name \"$collated_set_name\" is not unique\nPlease choose a string different than the following: @possible_set_names_print\n";
	}
	$collated_set_name = '_' . $collated_set_name; # Add and underscore to the start to support subsequent code
	
	@set_names = @ARGV; # Determine the sets to be collated
	# Cycle over these sets and verify they exist
	foreach my $set (@set_names) {
		if (defined($possible_set_names->{$set})) { # Check to see if it is defined in the list
			$set =  '_' . $set; # Add and underscore to the start to support subsequent code
		}
		else { # An inappropriate set_name was provided so die and leave a message
			die "Set_name \"$set\" was not found\nPossible set_names are: @possible_set_names_print\n";
		};
	};
};

#--------------------------------------------------------------------
# Collate
#--------------------------------------------------------------------
COLLATE: {
	# Create a file for the xml results
	my $xml_dump = new XML::Dumper;
	
	my $results_all = {};
	
	foreach my $set (@set_names) {
		my $filename = '../summary_files/Results' . $set . '_All.xml';
		my $results = $xml_dump->xml2pl($filename);
		# Use regular merge because we have many scalars that will be written over (e.g. units)
		$results_all = merge($results_all, $results);
# 		print "Set: $set\n";
# 		print Dumper $results;
	};

	# Print out the collated version so that we can use it in comparisons
	my $filename = '../summary_files/Results' . $collated_set_name . '_All.xml';
	$xml_dump->pl2xml($results_all, $filename);
# 	print "FINAL\n";
# 	print Dumper $results_all;

	# Call the remaining results printout and pass the results_all
	&print_results_out($results_all, $collated_set_name);

};

