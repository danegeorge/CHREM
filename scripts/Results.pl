#!/usr/bin/perl
#  
#====================================================================
# Results.pl
# Author:    Lukas Swan
# Date:      Oct 2008
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all]
#
#
# DESCRIPTION:
# This script collects and collates the results (record_number.summary)
# of a simulation and places it in a file that is grouped by type and region. 
# Additionally it makes note of any house records that are missing results and 
# constructs a summary file with the min, max, avg, and total results
# of each house type and region.
# The script also reviews the dictionary file (record_number.dictionary)
# and outputs a summary file which includes all variables encountered in the
# simulation.
#
#
#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;
use CSV;		#CSV-2 (for CSV split and join, this works best)
#use Array::Compare;	#Array-Compare-1.15
#use Switch;
use threads;		#threads-1.71 (to multithread the program)
#use File::Path;		#File-Path-2.04 (to create directory trees)
#use File::Copy;		#(to copy the input.xml file)


#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
if ($#ARGV != 1) {die "Two arguments are required: house_types regions\n";};

my @hse_types;					# declare an array to store the desired house types
my %hse_names = (1, "1-SD", 2, "2-DR");		# declare a hash with the house type names
#print "$hse_names{1}\n";
my %hse_names_rev = reverse (%hse_names);
#print "$hse_names_rev{\"1-SD\"}\n";
if ($ARGV[0] eq "0") {@hse_types = (1, 2);}	# check if both house types are desired
else {
	@hse_types = split (/\//,$ARGV[0]);	#House types to generate
	foreach my $type (@hse_types) {
		unless (defined ($hse_names{$type})) {
			my @keys = sort {$a cmp $b} keys (%hse_names);
			die "House type argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
		};
	};
};

my @regions;									#Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");
my %region_names_rev = reverse (%region_names);
if ($ARGV[1] eq "0") {@regions = (1, 2, 3, 4, 5);}
else {
	@regions = split (/\//,$ARGV[1]);	#House types to generate
	foreach my $region (@regions) {
		unless (defined ($region_names{$region})) {
			my @keys = sort {$a cmp $b} keys (%region_names);
			die "Region argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
		};
	};
};

#--------------------------------------------------------------------
# Initiate multi-threading to run each region simulataneously
#--------------------------------------------------------------------
print "ALL OUTPUT FILES WILL BE PLACED IN THE ../summary_files DIRECTORY \n";

my $start_time= localtime();	#note the end time of the file generation

my $thread;		#Declare threads
my $thread_return;	#Declare a return array for collation of returning thread data

my @characteristics = ("minimum", "maximum",  "average", "count", "total"); # characteristics to store in the summary data files. NOTE order is important for the subroutine

foreach my $hse_type (@hse_types) {								#Multithread for each house type
	foreach my $region (@regions) {								#Multithread for each region
		($thread->[$hse_type][$region]) = threads->create(\&main, $hse_type, $region); 	#Spawn the thread: NOTE: parenthesis around the variable create the thread in list context for join
	};
};
foreach my $hse_type (@hse_types) {
	foreach my $region (@regions) {
		$thread_return->[$hse_type][$region] = [$thread->[$hse_type][$region]->join()];	#Return the threads together for info collation
	};
};

#--------------------------------------------------------------------
# COMPILE THE TYPE/REGION OUTPUTS FOR A TOTAL OUTPUT (BOTH DICTIONARIES AND RESULTS)
#--------------------------------------------------------------------
my $dic_hash;	# declare a ALL dictionary hash
my $sum_hash = {"1_House_Type", 1, "2_Region", 1};	# declare an array ref for ALL summary variables hash, and initialize the house type and region keys
my $representation;	# declare an array reference to store the house representation corresponding to type/region
$representation->[1] = [(0, 521.113, 525.155, 504.152, 510.995, 514.153)];	# house count representation of SD types for the 5 regions (there is no region 0)
$representation->[2] = [(0, 687.224, 587.962, 574.961, 559.745, 645.868)];	# house count representation of DR types for the 5 regions

foreach my $hse_type (@hse_types) {	# evaluate the returned materials to construct summary table of all types and regions
	foreach my $region (@regions) {
		# construct the ALL dictionary
 		foreach my $key (keys %{$thread_return->[$hse_type][$region][0]}) {	# look through each variable of a region's dictionary
 			unless (defined $dic_hash->{$key}) {	# if the variable name is not present in the hash, do the following
 				$dic_hash->{$key} = "$thread_return->[$hse_type][$region][0]->{$key}";	# add the variable to the ALL hash
 			};
		};	
 		foreach my $key (keys %{$thread_return->[$hse_type][$region][1]}) {	# look through each variable of a region's summary
 			unless (defined $sum_hash->{$key}) {	# if the variable name is not present in the hash, do the following
 				$sum_hash->{$key} = 1;	# add the variable to the ALL hash
 			};
		};
	};
};

my $sum_array;	# declare an array ref to store the results of each type/region
my @keys_sum = sort {$a cmp $b} keys %{$sum_hash};	# sort the hash into ASCIbetical order
foreach my $key (0..$#keys_sum) {$sum_hash->{$keys_sum[$key]} = $key;};	# make the value of the hash equal to the variable placement in the array
$sum_array->[0] = [@keys_sum];	# store the first line of variables
foreach my $hse_type (@hse_types) {
	foreach my $region (@regions) {
		foreach my $element (1..$#{$thread_return->[$hse_type][$region][2]}) {
			unless (($element == 1) && ($#{$sum_array} != 0)) {
				push (@{$sum_array}, [("$hse_names{$hse_type}", "$region_names{$region}")]);	# create a new array row (push) and set the first two columns equal to the type/region
				foreach my $key (keys %{$thread_return->[$hse_type][$region][1]}) {	# foreach of the variables for the particular region
					$sum_array->[$#{$sum_array}][$sum_hash->{$key}] = $thread_return->[$hse_type][$region][2][$element][$thread_return->[$hse_type][$region][1]->{$key}];	# add the value of the variable for the region to the appropriate column for the totals. This involves mapping from one set of variables to the total set of variables.
				};
			};
		};
	};
};

#--------------------------------------------------------------------
# REORGANIZE THE SUMMARY TABLE BASED ON CHARACTERISTIC (MIN, MAX, TOTAL) FOR EASY PROCESSING
#--------------------------------------------------------------------
$sum_array->[0][2] = "Characteristic";	# relabel the third column
foreach my $element (0..2) {$sum_array->[1][$element] = "value";};	# remove the units information for first three columns. Must place something there or the join process goes awry

my $res_sorted;	# array reference to store the sorted results of the sum_array
foreach my $type (@hse_types) {push (@{$res_sorted->[$type]}, ([@{$sum_array->[0]}], [@{$sum_array->[1]}]));};	# set the header lines for the house type results array


foreach my $characteristic (@characteristics) {	# loop over the characteristics (e.g. min, max, total)
	foreach my $element (2..$#{$sum_array}) {	# do not loop over the two header rows
		if ((defined ($hse_names_rev{$sum_array->[$element][0]})) && ($sum_array->[$element][2] eq $characteristic)) {	# check that the type is defined and continue if the characteristics match
			push (@{$res_sorted->[$hse_names_rev{$sum_array->[$element][0]}]}, [@{$sum_array->[$element]}]);	# put the sorted line at the end of the sorted array (this is a logical sort process that count on the regions being properly aligned
		};
	};
};

#--------------------------------------------------------------------
# EVALUATE THE SORTED SUMMARY TABLE FOR TOTALS AND SCALE THESE TO REGIONAL AND ALL REGIONS TOTALS BASED ON REPRESENTATION
#--------------------------------------------------------------------
foreach my $type (@hse_types) {
	my $all_regions_total = [($hse_names{$type}, "Canada", "all_regions_total")];	# declare a national array to sum each region; give it titles
	foreach my $element (3..$#{$res_sorted->[$type][0]}) {$all_regions_total->[$element] = 0;};	# writeout zeros to the appropriate length for use in the summation (must be initialized)
	foreach my $element (2..$#{$res_sorted->[$type]}) {	 # loop over the sorted result, skipping the header rows
		if ($res_sorted->[$type][$element][2] eq "total") {	# if "total" appears, then continue
			push (@{$res_sorted->[$type]}, [($res_sorted->[$type][$element][0], $res_sorted->[$type][$element][1], "regional total")]);	# fill first three columns with type/region and descriptor "regional total"
			foreach my $element_2 (3..$#{$res_sorted->[$type][$element]}) {	# go through each element of the row to do multiplication
				$res_sorted->[$type][$#{$res_sorted->[$type]}][$element_2] = $res_sorted->[$type][$element][$element_2] * $representation->[$hse_names_rev{$res_sorted->[$type][$element][0]}][$region_names_rev{$res_sorted->[$type][$element][1]}];	# set the same element on the latest last row to be equal to the multiplication of that region's value by its representation value
				$all_regions_total->[$element_2] = $all_regions_total->[$element_2] + $res_sorted->[$type][$#{$res_sorted->[$type]}][$element_2];	# add the regional total values to the all_regions total.
			};
		};
	};
	push (@{$res_sorted->[$type]}, [@{$all_regions_total}]);	# push the all_regions total onto the last row of the sorted results
};

#--------------------------------------------------------------------
# PRINT THE "ALL" DICTIONARY
#--------------------------------------------------------------------
open (RES_DIC, '>', "../summary_files/res_dictionary_ALL.csv") or die ("can't open ../summary_files/res_dictionary_ALL.csv");	# open a dictionary writeout file
my @keys_dic = sort {$a cmp $b} keys %{$dic_hash};	# sort the hash into ASCIIbetical order
foreach my $key (@keys_dic) {print RES_DIC "\"$key\",$dic_hash->{$key}\n"};	# print the dictionary to the file
close RES_DIC;	# close the dictionary writeout file

#-----------------------------------------------
# PRINT THE TYPE/REGION RESULTS SUMMARY FILE (RESULT FOR EACH HOUSE)
#-----------------------------------------------

open (RES_SUM, '>', "../summary_files/res_summary_ALL.csv") or die ("can't open ../summary_files/res_summary_ALL.csv");	# open a summary writeout file
foreach my $element (0..$#{$sum_array}) {	# iterate over each element of the array (i.e. variable,units,min,max,total,count,avg, then each house)
	my $string = CSVjoin(@{$sum_array->[$element]});	# join the row into a string for printing
	print RES_SUM "$string\n";	# print the type/region summary string to the file
};
close RES_SUM;	# close the summary writeout file


#-----------------------------------------------
# PRINT THE SORTED TYPE/REGION RESULTS SUMMARY FILES (RESULT FOR EACH REGION AND ALL_REGIONS)
#-----------------------------------------------
foreach my $type (@hse_types) {
	open (RES_SORT, '>', "../summary_files/res_sum_sort_$hse_names{$type}.csv") or die ("can't open ../summary_files/res_sum_sort_$hse_names{$type}.csv");	# open a sorted summary writeout file for each type
	foreach my $element (0..$#{$res_sorted->[$type]}) {	# iterate over each element of the array (i.e. variable,units,min,max,total,count,avg, then each house)
		my $string = CSVjoin(@{$res_sorted->[$type][$element]});	# join the row into a string for printing
		print RES_SORT "$string\n";	# print the type/region summary string to the file
	};
	close RES_SORT;	# close the summary writeout file
}

my $end_time= localtime();	#note the end time of the file generation

print "ALL OUTPUT FILES WILL BE PLACED IN THE ../summary_files DIRECTORY \n";


#--------------------------------------------------------------------
# Main code that each thread evaluates
#--------------------------------------------------------------------
sub main () {
	my $hse_type = shift (@_);		# house type number for the thread
	my $region = shift (@_);		# region number for the thread

	my @folders;			# declare an array to store the folder names
	push (@folders, <../$hse_names{$hse_type}/$region_names{$region}/*>);	# read in all of the folder names for this particular thread

# 	# OPEN A RESULT LIST FILE AND DECLARE ARRAYS TO STORE MAX, MIN, AND TOTAL VALUES
# 	open (RESULT_LIST, '>', "../summary_files/results_$hse_names{$hse_type}/$region_names{$region}.csv") or die ("can't open ../summary_files/results_$hse_names{$hse_type}/$region_names{$region}.csv");
# 	my $res_min;	# ARRAY REF to store the minimum value encountered for each variable
# 	my $res_max;	# ARRAY REF to store the minimum value encountered for each variable
# 	my $res_total;	# ARRAY REF to sum each house's value with those encountered in previous houses for each variable to come to totals

	# DECLARE INDEXING HASH AND HASH TO STORE THE DICTIONARY
#	my $dic_array->[0] = ["Variable", "Description", "Units"];	# ARRAY REF to store the dictionary variable, description, and units
	my $dic_hash;	# HASH REF to store new variable which are found in the dictionaries of each house
	my $sum_hash;
# 	my $res_index;	# HASH REF to store of each result's index in the arrays
	#-----------------------------------------------
	# GO THROUGH EACH FOLDER AND EXTRACT THE PERTINENT INFORMATION FOR THE HASHES (DIC AND SUM)
	#-----------------------------------------------
	my $counts;			# declare a hash reference to count houses that have files or do not

	RECORD: foreach my $folder (@folders) {
		$folder =~ /(..........)$/;	# determine the house name from the last 10 digits of the path, automatically stores in $1
		my $record = $1;		# declare the house name

		if (open (DICTIONARY, '<', "$folder/$record.dictionary")) {;	# open the dictionary of the house. If it does not exist move on.
			$counts->{"dic_true"}++;				# increment the dictionary true counter
			while (<DICTIONARY>) {					# read the dictionary
				my @variable = CSVsplit($_);			# split each line using comma delimit (note that this requires the Lukas_Swan branch of TReportsManager.cpp)
				unless (defined $dic_hash->{$variable[0]}) {	# if the variable name is not present in the hash, do the following
					$dic_hash->{$variable[0]} = "\"$variable[1]\",\"$variable[2]\"";	# add the variable to the hash
				};
			};
			close DICTIONARY;	# close the dictionary
		}
		else {$counts->{"dic_false"}++;};				# increment the dictionary false counter

		$sum_hash->{"3_Filename"} = "Filename (unitless)";	# field for the house filename. Include the A to make it first
#		$sum_hash->{z_LAST_FIELD} = "End field (unitless)";	# last field (use "z") so that each house has same final array element for use in CSVjoin
		if (open (SUMMARY, '<', "$folder/$record.summary")) {;		# open the summary of the house. If it does not exist move on.
			$counts->{"sum_true"}++;				# increment the summary true counter
			while (<SUMMARY>) {					# read the summary file
				my @variable = split(/\s/);		# split each line using "::" or whitespace
				unless (defined $sum_hash->{$variable[0]}) {	# if the variable name is not present in the hash, do the following
					$sum_hash->{$variable[0]} = "$variable[2]";	# add the variable to the hash
				};
			};
			close SUMMARY;	# close the dictionary
		}
		else {$counts->{"sum_false"}++;};				# increment the summary false counter
	}

	#-----------------------------------------------
	# INITIALIZE AN ARRAY TO STORE THE RESULTS OF EACH HOUSE AND MIN/MAX/TOTAL/COUNT/AVG VALUES OF TYPE/REGION
	#-----------------------------------------------
	my @keys_sum = sort {$a cmp $b} keys %{$sum_hash};	# sort the hash into ASCIIbetical order
	my $sum_array;	# declare an array reference to hold the summary results of each house
	push (@{$sum_array}, [@keys_sum]);	# push the ordered field titles onto the array
	foreach my $key (0..$#keys_sum) {	# iterate over the number of elements in @keys_sum (note this is not the value of the array as we need to index the array)
		push (@{$sum_array->[1]}, $sum_hash->{$keys_sum[$key]});	# push the value of the hash (given the key using the array and element index) which is the description and units of the variable, onto the second row of the array
		$sum_hash->{$keys_sum[$key]} = $key;	# reassociate the summary hash value from the description/units to the array element index. This will be used for index location in the subsequent RECORD2 where the values for each house are stored.
	};
	foreach my $row (@characteristics) {push (@{$sum_array}, [($row)]);};	# add these rows to the array for statistical purposes
	foreach my $element (1..$#keys_sum) {	# iterate over each element number
		$sum_array->[2][$element] = 99999999;	# intialize the minimum sum_array values to a very high number for future comparison
		$sum_array->[3][$element] = -99999999;	# intialize the maximum sum_array values to a very low number for future comparison
		$sum_array->[4][$element] = 0;	# intialize the average
		$sum_array->[5][$element] = 0;	# intialize the count
		$sum_array->[6][$element] = 0;	# intialize the integrator for the total so that it can add to itself
	};

	#-----------------------------------------------
	# GO THROUGH EACH FOLDER AND ADD THE RESULTS DATA TO THE ARRAY. CHECK THE MIN/MAX/TOTAL/COUNT/AVG 
	#-----------------------------------------------
	RECORD2: foreach my $folder (@folders) {
		$folder =~ /(..........)$/;	# determine the house name from the last 10 digits of the path, automatically stores in $1
		my $record = $1;		# declare the house name

		if (open (SUMMARY, '<', "$folder/$record.summary")) {	# open the summary of the house. If it does not exist move on.
			my $row = $#{$sum_array} + 1;	# increment from the last array element to start a new row
			$sum_array->[$row][0] = $record;	# title the row with the house name
			while (<SUMMARY>) {					# read the summary file
				my @variable = split(/\s/);		# split each line using "::" or whitespace
				$sum_array->[$row][$sum_hash->{$variable[0]}] = $variable[1];	# add the variable to the to the array at the appropriate row (house) and element (from the hash)
				if ($variable[1] < $sum_array->[2][$sum_hash->{$variable[0]}]) {$sum_array->[2][$sum_hash->{$variable[0]}] = $variable[1];};	# check for minimum
				if ($variable[1] > $sum_array->[3][$sum_hash->{$variable[0]}]) {$sum_array->[3][$sum_hash->{$variable[0]}] = $variable[1];};	# check for maximum
				$sum_array->[6][$sum_hash->{$variable[0]}] = $sum_array->[6][$sum_hash->{$variable[0]}] + $variable[1];	# integrate the total
				$sum_array->[5][$sum_hash->{$variable[0]}]++;	# increment the counter
			};
			close SUMMARY;	# close the dictionary
#			$sum_array->[$row][$sum_hash->{z_LAST_FIELD}] = 1;	# define the final column so that CSVjoin works correctly
		}
	}

	#-----------------------------------------------
	# PRINT THE TYPE/REGION DICTIONARY 
	#-----------------------------------------------
	open (RES_DIC, '>', "../summary_files/res_dictionary_$hse_names{$hse_type}_$region_names{$region}.csv") or die ("can't open ../summary_files/res_dictionary_$hse_names{$hse_type}_$region_names{$region}.csv");	# open a dictionary writeout file
	my @keys_dic = sort {$a cmp $b} keys %{$dic_hash};	# sort the hash into ASCIIbetical order
	foreach my $key (@keys_dic) {print RES_DIC "\"$key\",$dic_hash->{$key}\n"};	# print the dictionary to the file
	close RES_DIC;	# close the dictionary writeout file

	#-----------------------------------------------
	# PRINT THE TYPE/REGION RESULTS SUMMARY FILE (RESULT FOR EACH HOUSE)
	#-----------------------------------------------

	open (RES_SUM, '>', "../summary_files/res_summary_$hse_names{$hse_type}_$region_names{$region}.csv") or die ("can't open ../summary_files/res_summary_$hse_names{$hse_type}_$region_names{$region}.csv");	# open a dictionary writeout file
	foreach my $element (0..$#{$sum_array}) {	# iterate over each element of the array (i.e. variable,units,min,max,total,count,avg, then each house)
		if ($element == 4) {	# check if at the average row
			foreach my $avg_element (1..$#{$sum_array->[0]}) {	# go through each variable (skip first column)
				$sum_array->[$element][$avg_element] = $sum_array->[6][$avg_element] / $sum_array->[5][$avg_element];	# calc the average from total/count
			};
		};
		my $string = CSVjoin(@{$sum_array->[$element]});	# join the row into a string for printing
		print RES_SUM "$string\n";	# print the type/region summary string to the file
	};
	close RES_SUM;	# close the summary writeout file

	my $sum_array_return;	# declare an array to store references to the first few lines of sum_array, so that the individual house data is forgotten when the thread goes out of scope
	foreach my $element (1..6) {$sum_array_return->[$element] = $sum_array->[$element];};	# store the references to the first 7 rows of the summary data
	return ($dic_hash, $sum_hash, $sum_array_return); #$res_index, $res_min	# return these variables at the end of the thread
};

