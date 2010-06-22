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
my $set; # Store the set names to collate

# Determine possible set names by scanning the summary_files folder
my $possible_set_names = {map {$_, 1} grep(s/.+Results_(.+).xml/$1/, <../summary_files/*>)}; # Map to hash keys so there are no repeats
my @possible_set_names_print = @{&order($possible_set_names)}; # Order the names so we can print them out if an inappropriate value was supplied

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if (@ARGV != 1) {die "Please provide a set name\nPossible set_names are: @possible_set_names_print\n";};
	
	$set = shift(@ARGV); # Determine the sets to be collated
	# Cycle over these sets and verify they exist
	if (defined($possible_set_names->{$set})) { # Check to see if it is defined in the list
		$set =  '_' . $set; # Add and underscore to the start to support subsequent code
	}
	else { # An inappropriate set_name was provided so die and leave a message
		die "Set_name \"$set\" was not found\nPossible set_names are: @possible_set_names_print\n";
	};
};

#--------------------------------------------------------------------
# Collate
#--------------------------------------------------------------------
REPRINT: {
	# Create a file for the xml results
	my $xml_dump = new XML::Dumper;
	
	my $filename = '../summary_files/Results' . $set . '.xml';
	my $results = $xml_dump->xml2pl($filename);

	# Call the remaining results printout and pass the results_all
	&print_results_out_alt($results, $set);

};

