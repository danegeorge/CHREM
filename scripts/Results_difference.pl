#!/usr/bin/perl
# 
#====================================================================
# Results_difference.pl
# Author:    Lukas Swan
# Date:      Jun 2010
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl difference_set_name orig_set_name upgraded_set_name
#
# DESCRIPTION:
# This script determines results differences including GHG emisssions


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
use Storable  qw(dclone); # To create copies of arrays so that grep can do find/replace without affecting the original data
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
my $difference_set_name; # store the results set name
my $orig_set_name; # Store the orig set name
my $upgraded_set_name; # Store the orig set name

# Determine possible set names by scanning the summary_files folder
my $possible_set_names = {map {$_, 1} grep(s/.+Results_(.+)_All.xml/$1/, <../summary_files/*>)}; # Map to hash keys so there are no repeats
my @possible_set_names_print = @{&order($possible_set_names)}; # Order the names so we can print them out if an inappropriate value was supplied

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if (@ARGV != 3) {die "THREE arguments are required: difference_set_name orig_set_name upgraded_set_name\nPossible set_names are: @possible_set_names_print\n";};
	
	($difference_set_name, $orig_set_name, $upgraded_set_name) = @ARGV; # Shift the names
	# Check that the collated_set_name does not exist in the summary_ files as a simulated set. NOTE that this will replace a previous collation summary though
	if (defined($possible_set_names->{$difference_set_name})) {
		die "The collated set_name \"$difference_set_name\" is not unique\nPlease choose a string different than the following: @possible_set_names_print\n";
	}
	$difference_set_name = '_' . $difference_set_name; # Add and underscore to the start to support subsequent code
	
	# Cycle over these sets and verify they exist
	foreach my $set ($orig_set_name, $upgraded_set_name) {
		if (defined($possible_set_names->{$set})) { # Check to see if it is defined in the list
			$set =  '_' . $set; # Add and underscore to the start to support subsequent code
		}
		else { # An inappropriate set_name was provided so die and leave a message
			die "Set_name \"$set\" was not found\nPossible set_names are: @possible_set_names_print\n";
		};
	};
};

#--------------------------------------------------------------------
# Difference
#--------------------------------------------------------------------
DIFFERENCE: {
	# Create a file for the xml results
	my $xml_dump = new XML::Dumper;
	
	my $results_all = {};
	
	my $filename = '../summary_files/Results' . $orig_set_name . '_All.xml';
	$results_all->{'orig'} = $xml_dump->xml2pl($filename);
	$filename = '../summary_files/Results' . $upgraded_set_name . '_All.xml';
	$results_all->{'upgraded'} = $xml_dump->xml2pl($filename);
	
	foreach my $region (keys(%{$results_all->{'upgraded'}->{'house_names'}})) {
		foreach my $province (keys(%{$results_all->{'upgraded'}->{'house_names'}->{$region}})) {
			foreach my $hse_type (keys(%{$results_all->{'upgraded'}->{'house_names'}->{$region}->{$province}})) {
				foreach my $house (@{$results_all->{'upgraded'}->{'house_names'}->{$region}->{$province}->{$hse_type}}) {
					my $indicator = 0;
					foreach my $key (keys(%{$results_all->{'upgraded'}->{'house_results'}->{$house}})) {
						
						if ($key =~ /(energy|quantity|GHG)\/integrated/) {
							if (defined($results_all->{'orig'}->{'house_results'}->{$house}->{$key})) {
								$results_all->{'difference'}->{'house_results'}->{$house}->{$key} = $results_all->{'upgraded'}->{'house_results'}->{$house}->{$key} - $results_all->{'orig'}->{'house_results'}->{$house}->{$key};
								
								$results_all->{'difference'}->{'parameter'}->{$key} = $results_all->{'upgraded'}->{'parameter'}->{$key};
								
								$indicator = 1;
							};
						}
					};
					if ($indicator) {
						$results_all->{'difference'}->{'house_results'}->{$house}->{'sim_period'} = dclone($results_all->{'upgraded'}->{'house_results'}->{$house}->{'sim_period'});
						push(@{$results_all->{'difference'}->{'house_names'}->{$region}->{$province}->{$hse_type}}, $house);
					};
				};
			};
		};
	};

# 	print Dumper $results_all->{'difference'};

	# Call the remaining results printout and pass the results_all
	&print_results_out_difference($results_all, $difference_set_name);

};

