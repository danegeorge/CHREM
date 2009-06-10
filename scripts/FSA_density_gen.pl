#!/usr/bin/perl

# ====================================================================
# FSA_density_gen.pl
# Author: Lukas Swan
# Date: June 2009
# Copyright: Dalhousie University

# INPUT USE:
# filename.pl

# DESCRIPTION:
# This script reads two files (land_area and population) that area a
# function of FSA (forward sortation area; postal code) and then divides
# the population by the land_area to determine a density value. This
# density value is output to a final key file for use in determining
# the population density for the NN.

# Note two things:
# 1) land_area has multiple values for many FSAs (likely due to the GIS
#    methodology used to create them). These were summed into a single
#    value for the FSA
# 2) There are a number of checks as certain FSAs do not exist in one
#    file or the other. These are printed out for user knowledge.

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
use Data::Dumper;
# use List::Util 'shuffle';

# --------------------------------------------------------------------
# Declare the input variables
# --------------------------------------------------------------------

#open the land_area file
open (LAND_AREA, '<', '../NN/StatCan_items/FSA_1996_land_area_km2.csv') or die ("can\'t open: ../NN/StatCan_items/FSA_1996_land_area_km2.csv\n");

# declare a hash reference to store data
my $land_area;

# iterate over the file
while (<LAND_AREA>) {
	# look for a data tag
	if (/^\*data/) {
		# split the line, note that element 1 is FSA and element 2 is land_area in km^2
		@_ = CSVsplit ($_);
		
		# check to see if we have already encountered this FSA, if so add to the value
		if (defined ($land_area->{$_[1]})) {$land_area->{$_[1]} = $land_area->{$_[1]} + $_[2];}
		
		# it is a new FSA so simple set the value
		else {$land_area->{$_[1]} = $_[2];};
	};
};

close LAND_AREA;

# open the population file
open (POPULATION, '<', '../NN/StatCan_items/FSA_2006_population.csv') or die ("can\'t open: ../NN/StatCan_items/FSA_2006_population.csv\n");

# declare a hash reference to store data
my $population;

# iterate over the file
while (<POPULATION>) {
	# look for a data tag
	if (/^\*data/) {
		# split the line, note that element 1 is FSA and element 3 is population
		@_ = CSVsplit ($_);
		# set the value directly as we know they only appear once
		$population->{$_[1]} = $_[3];
	};
};

close POPULATION;

# print Dumper $land_area;
# print Dumper $population;

# open a file to writeout the key
open (DENSITY, '>', '../keys/FSA_population_density.csv') or die ("can\'t open: ../keys/FSA_population_density.csv\n");

# print the header, unit and note information
print DENSITY "*header,FSA,population_density\n";
print DENSITY "*unit,-,people/km^2\n";
print DENSITY "*note,\"This file is the result of dividing the FSA (forward sortation area; i.e. postal code) population by land area. It may be used as an indicator or rural/urban.\"\n";
print DENSITY "*note,\"MAKE SURE TO CHECK THE LIST OF MISSING FSAs AT THE END OF THIS FILE. THEY WERE PRESENT IN EITHER THE LAND_AREA OR POPULATION FILE, BUT NOT THE OTHER\"\n";

# declare a hash reference to store all FSAs from both input files so we can compare
my $FSAs;

# iterate over the keys of both files and add them to a hash so we can have a total list
foreach my $FSA (keys (%{$land_area}), keys (%{$population})) {
	$FSAs->{$FSA} = 1;
};

# declare an array to store missing FSAs
my @missing_FSA;

# order the list of FSAs and cycle through it
foreach my $FSA (sort {$a cmp $b} keys (%{$FSAs})) {

	# check to see that the FSA exists in both the land_area and population and print a warning if it does not, but do not error
	if (! defined ($land_area->{$FSA})) {print "land_area is missing FSA: $FSA\n"; push (@missing_FSA, $FSA);}
	elsif (! defined ($population->{$FSA})) {print "population is missing FSA: $FSA\n"; push (@missing_FSA, $FSA);}
	
	# the FSA exist in both files, so perform division and print the population density file
	else {printf DENSITY ("%s,%s,%.2f\n", '*data', $FSA, $population->{$FSA} / $land_area->{$FSA});};
};

# if there are missing FSA then print them out
if (@missing_FSA > 0) {

	# cycle through the missing list
	foreach my $FSA (@missing_FSA) {
		print DENSITY "*missing_FSA,$FSA\n";	# print the item
	};
};

close DENSITY;

my $count_land_area = keys (%{$land_area});
my $count_population = keys (%{$population});

print "land_area has $count_land_area FSAs\n";
print "population has $count_population FSAs\n";





