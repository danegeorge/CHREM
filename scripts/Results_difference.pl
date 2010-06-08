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
# This script determines results differences between two runs, including GHG emisssions for electricity based on monthly margin EIF


#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;

# use CSV; #CSV-2 (for CSV split and join, this works best)
#use Array::Compare; #Array-Compare-1.15
#use Switch;
use XML::Simple; # to parse the XML results files
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
my $difference_set_name; # Initialize a variable to store the difference results set name
my $orig_set_name; # Initialize a variable to store the orig set name
my $upgraded_set_name; # Initialize a variable to store the upgraded set name

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
	
	# Declare storage of the results
	my $results_all = {};
	
	# Readin the original set and store it at 'orig'
	my $filename = '../summary_files/Results' . $orig_set_name . '_All.xml';
	$results_all->{'orig'} = $xml_dump->xml2pl($filename);
	print "Finished reading in $orig_set_name\n";
	# Readin the upgraded set and store it at 'upgraded'
	$filename = '../summary_files/Results' . $upgraded_set_name . '_All.xml';
	$results_all->{'upgraded'} = $xml_dump->xml2pl($filename);
	print "Finished reading in $upgraded_set_name\n";

	# Read in the GHG multipliers file
	my $ghg_file;
	# Check for existance as this script could be called from two different directories
	if (-e '../../../keys/GHG_key.xml') {$ghg_file = '../../../keys/GHG_key.xml'}
	elsif (-e '../keys/GHG_key.xml') {$ghg_file = '../keys/GHG_key.xml'}
	# Read in the file
	my $GHG = XMLin($ghg_file);

	# Remove the 'en_src' field from the GHG information as that is all we need
	my $en_srcs = $GHG->{'en_src'};

	# Cycle over the UPGRADED file and compare the differences with original file
	foreach my $region (keys(%{$results_all->{'upgraded'}->{'house_names'}})) { # By region
		foreach my $province (keys(%{$results_all->{'upgraded'}->{'house_names'}->{$region}})) { # By province
			foreach my $hse_type (keys(%{$results_all->{'upgraded'}->{'house_names'}->{$region}->{$province}})) { # By house type
				foreach my $house (@{$results_all->{'upgraded'}->{'house_names'}->{$region}->{$province}->{$hse_type}}) { # Cycle over each listed house
					# Declare an indicator that is used to show that the original house also exists and has valid data
					my $indicator = 0;
					
					# Cycle over the results for this house and do the comparison
					foreach my $key (keys(%{$results_all->{'upgraded'}->{'house_results'}->{$house}})) {
						# For energy and quantity, just calculate the difference
						if ($key =~ /(energy|quantity)\/integrated$/) {
							# Verify that the original house also has this data
							if (defined($results_all->{'orig'}->{'house_results'}->{$house}->{$key})) {
								# Subtract the original from the upgraded to get the difference (negative means lowered consumption or emissions)
								$results_all->{'difference'}->{'house_results'}->{$house}->{$key} = $results_all->{'upgraded'}->{'house_results'}->{$house}->{$key} - $results_all->{'orig'}->{'house_results'}->{$house}->{$key};
								# Store the parameter units and set the indicator
								$results_all->{'difference'}->{'parameter'}->{$key} = $results_all->{'upgraded'}->{'parameter'}->{$key};
								$indicator = 1;
							};
						};
						if ($key =~ /electricity\/quantity\/integrated$/) {
							foreach my $period (@{&order($results_all->{'upgraded'}->{'house_results_electricity'}->{$house}->{$key})}) {
								$results_all->{'difference'}->{'house_results_electricity'}->{$house}->{$key}->{$period} = $results_all->{'upgraded'}->{'house_results_electricity'}->{$house}->{$key}->{$period} - $results_all->{'orig'}->{'house_results_electricity'}->{$house}->{$key}->{$period};
							};
						};
					};
					
					# The indicator was set, so store the sim_period and push the name of the house onto the list for the difference group
					if ($indicator) {
						$results_all->{'difference'}->{'house_results'}->{$house}->{'sim_period'} = dclone($results_all->{'upgraded'}->{'house_results'}->{$house}->{'sim_period'});
						push(@{$results_all->{'difference'}->{'house_names'}->{$region}->{$province}->{$hse_type}}, $house);
					};
				};
			};
		};
	};
	print "Completed the difference calculations on energy and quantity\n";
	&GHG_conversion_difference($results_all);

	print "Completed the GHG calculations\n";
	# Call the remaining results printout and pass the results_all
	&print_results_out_difference($results_all, $difference_set_name);

	print Dumper $results_all;
};

