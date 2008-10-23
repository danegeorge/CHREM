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
my %hse_names = (1, "SD", 2, "DR");		# declare a hash with the house type names
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

foreach my $hse_type (@hse_types) {								#Multithread for each house type
	foreach my $region (@regions) {								#Multithread for each region
		$thread->[$hse_type][$region] = threads->new(\&main, $hse_type, $region); 	#Spawn the thread
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

foreach my $hse_type (@hse_types) {	# evaluate the returned materials to construct summary table of all types and regions
	foreach my $region (@regions) {
		# construct the ALL dictionary
 		foreach my $key (keys %{$thread_return->[$hse_type][$region][0]}) {	# look through each variable of a region's dictionary
 			unless (defined $dic_hash->{$key}) {	# if the variable name is not present in the hash, do the following
 				$dic_hash->{$key} = "$thread_return->[$hse_type][$region][0]->{$key}";	# add the variable to the ALL hash
 			};
		};	


	};
};

#--------------------------------------------------------------------
# PRINT THE "ALL" DICTIONARY
#--------------------------------------------------------------------
open (RES_DIC_SUMMARY, '>', "../summary_files/res_dic_ALL_summary.csv") or die ("can't open ../summary_files/res_dic_ALL_summary.csv");	# open a dictionary writeout file
my @keys = sort {$a cmp $b} keys %{$dic_hash};	# sort the hash into ASCIIbetical order
foreach my $key (@keys) {print RES_DIC_SUMMARY "\"$key\",$dic_hash->{$key}\n"};	# print the dictionary to the file
close RES_DIC_SUMMARY;	# close the dictionary writeout file

my $end_time= localtime();	#note the end time of the file generation

print "ALL OUTPUT FILES WILL BE PLACED IN THE ../summary_files DIRECTORY \n";


#--------------------------------------------------------------------
# Main code that each thread evaluates
#--------------------------------------------------------------------
sub main () {
	my $hse_type = shift (@_);		# house type number for the thread
	my $region = shift (@_);		# region number for the thread

	my @folders;			# declare an array to store the folder names
	push (@folders, <../$hse_type-$hse_names{$hse_type}/$region_names{$region}/*>);	# read in all of the folder names for this particular thread

# 	# OPEN A RESULT LIST FILE AND DECLARE ARRAYS TO STORE MAX, MIN, AND TOTAL VALUES
# 	open (RESULT_LIST, '>', "../summary_files/results_$hse_type-$hse_names{$hse_type}/$region_names{$region}.csv") or die ("can't open ../summary_files/results_$hse_type-$hse_names{$hse_type}/$region_names{$region}.csv");
# 	my $res_min;	# ARRAY REF to store the minimum value encountered for each variable
# 	my $res_max;	# ARRAY REF to store the minimum value encountered for each variable
# 	my $res_total;	# ARRAY REF to sum each house's value with those encountered in previous houses for each variable to come to totals

	# DECLARE INDEXING HASH AND HASH TO STORE THE DICTIONARY
#	my $dic_array->[0] = ["Variable", "Description", "Units"];	# ARRAY REF to store the dictionary variable, description, and units
	my $dic_hash;	# HASH REF to store new variable which are found in the dictionaries of each house
# 	my $res_index;	# HASH REF to store of each result's index in the arrays
	#-----------------------------------------------
	# GO THROUGH EACH FOLDER AND EXTRACT THE PERTINENT INFORMATION
	#-----------------------------------------------
	RECORD: foreach my $folder (@folders) {
		$folder =~ /(..........)$/;	# determine the house name from the last 10 digits of the path, automatically stores in $1
		my $record = $1;		# declare the house name

		if (open (DICTIONARY, '<', "$folder/$record.dictionary")) {;	# open the dictionary of the house. If it does not exist move on.
			while (<DICTIONARY>) {					# read the dictionary
				my @variable = CSVsplit($_);			# split each line using comma delimit (note that this requires the Lukas_Swan branch of TReportsManager.cpp)
				unless (defined $dic_hash->{$variable[0]}) {	# if the variable name is not present in the hash, do the following
					$dic_hash->{$variable[0]} = "\"$variable[1]\",\"$variable[2]\"";	# add the variable to the hash
				};#$#{$dic_array} + 1
			};
			close DICTIONARY;	# close the dictionary
		};
	}

	open (RES_DIC_SUMMARY, '>', "../summary_files/res_dic_$hse_type-$hse_names{$hse_type}_$region_names{$region}_summary.csv") or die ("can't open ../summary_files/res_dic_$hse_type-$hse_names{$hse_type}_$region_names{$region}_summary.csv");	# open a dictionary writeout file
	my @keys = sort {$a cmp $b} keys %{$dic_hash};	# sort the hash into ASCIIbetical order
	foreach my $key (@keys) {print RES_DIC_SUMMARY "\"$key\",$dic_hash->{$key}\n"};	# print the dictionary to the file
	close RES_DIC_SUMMARY;	# close the dictionary writeout file
	return ($dic_hash) #$res_index, $res_min	# return these variables at the end of the thread
};

# 
# 	#-----------------------------------------------
# 	# Print out the dictionary
# 	#-----------------------------------------------
# 	foreach my $variable (@{$dic_array}) {				#go through each extention inclusive of the zones for this particular record
# 		open (FILE, '>', "$output_path/$CSDDRD->[1].$ext") or die ("can't open datafile: $output_path/$CSDDRD->[1].$ext");	#open a file on the hard drive in the directory tree
# 		foreach my $line (@{$hse_file->[$record_extensions->{$ext}]}) {	#loop through each element of the array (i.e. line of the final file)
# 			print FILE "$line";					#print each line out
# 		}
# 		close FILE;
# 	}
# 	copy ("../templates/input.xml", "$output_path/input.xml") or die ("can't copy file: input.xml");	#add an input.xml file to the house for XML reporting of results
# 
# 
# }	#end of main code
# 
# 
# 		# SPLIT THE DWELLING DATA, CHECK THE FILENAME, AND CREATE THE APPROPRIATE PATH ../TYPE/REGION/RECORD
# 		my $CSDDRD = [CSVsplit($_)];											#split each of the comma delimited fields for use
# 		$CSDDRD->[1] =~ s/.HDF// or  & error_msg ("Bad record name", $hse_type, $region, $CSDDRD->[1]);			#strip the ".HDF" from the record name, check for bad filename
# 		my $output_path = "../$hse_type-$hse_names{$hse_type}/$region_names{$region}/$CSDDRD->[1]";			#path to the folder for writing the house folder
# 		mkpath ("$output_path");											#make the output path directory tree
# 
# 		# DECLARE ZONE AND PROPERTY HASHES. INITIALIZE THE MAIN ZONE TO BE TRUE AND ALL OTHER ZONES TO BE FALSE
# 		my $zone_indc = {"main", 1, "bsmt", 0, "crwl", 0, "attc", 0};	#hash for holding the indication of particular zone type for use with foreach statements to quickly cycle through the zones
# 		my $record_indc;	#hash for holding the indication of dwelling properties
# 
# 		#-----------------------------------------------
# 		# DETERMINE ZONE INFORMATION (NUMBER AND TYPE) FOR USE IN THE GENERATION OF ZONE TEMPLATES
# 		#-----------------------------------------------
# 		# FOUNDATION CHECK TO DETERMINE IF A bsmt OR crwl ZONES ARE REQUIRED, ALSO SET A fndn VARIABLE TO LATER DISCERN WHAT TYPE OF FOUNDATION FOR SLAB OR EXPOSED FLOOR WHICH DON'T HAVE A ZONE
# 		# FLOOR AREAS (m^2) OF FOUNDATIONS ARE LISTED IN CSDDRD[97:99]
# 		# FOUNDATION TYPE IS LISTED IN CSDDRD[15]- 1:6 ARE BSMT, 7:9 ARE CRWL, 10 IS SLAB
# 		if (($CSDDRD->[97] >= $CSDDRD->[98]) && ($CSDDRD->[97] >= $CSDDRD->[99])) {	# compare the bsmt floor area to the crwl and slab
# 			$zone_indc->{"bsmt"} = 1;	# bsmt floor area is dominant, so there is a basement zone
# 			if ($CSDDRD->[15] <= 6) {$record_indc->{"foundation"} = $CSDDRD->[15];}	# the CSDDRD foundation type corresponds, use it in the record indicator description
# 			else {$record_indc->{"foundation"} = 1;};	# the CSDDRD foundation type doesn't correspond (but floor area was dominant), assume "full" basement
# 		}
# 
# 		elsif (($CSDDRD->[98] >= $CSDDRD->[97]) && ($CSDDRD->[98] >= $CSDDRD->[99])) {	# compare the crwl floor area to the bsmt and slab
# 			# crwl space floor area is dominant, but check the type prior to creating a zone
# 			if ($CSDDRD->[15] != 7) {	# check that the crwl space is either "ventilated" or "closed" ("open" is treated as exposed main floor)
# 				$zone_indc->{"crwl"} = 1;	# create the crwl zone
# 				if (($CSDDRD->[15] >= 8) && ($CSDDRD->[15] <= 9)) {$record_indc->{"foundation"} = $CSDDRD->[15];}	# the CSDDRD foundation type corresponds, use it in the record indicator description
# 				else {$record_indc->{"foundation"} = 8;};	# the CSDDRD foundation type doesn't correspond (but floor area was dominant), assume "ventilated" crawl space
# 			}
# 			else {$record_indc->{"foundation"} = $CSDDRD->[15];};	# the crwl is actually "open" with large ventilation, so treat it as an exposed main floor with no crwl zone
# 		}
# 
# 		elsif (($CSDDRD->[99] >= $CSDDRD->[97]) && ($CSDDRD->[99] >= $CSDDRD->[98])) { # compare the slab floor area to the bsmt and crwl
# 			$record_indc->{"foundation"} = 10;	# slab floor area is dominant, so set the foundation to 10
# 		}
# 
# 		else {& error_msg ("Bad foundation determination", $hse_type, $region, $CSDDRD->[1]);};
# 
# 
# 		# ATTIC CHECK- COMPARE THE CEILING TYPE TO DISCERN IF THERE IS AN attc ZONE
# 		# THE FLAT CEILING TYPE IS LISTED IN CSDDRD[18] AND WILL HAVE A VALUE NOT EQUAL TO 1 (N/A) OR 5 (FLAT ROOF) IF AN ATTIC IS PRESENT
# 		if (($CSDDRD->[18] != 1) && ($CSDDRD->[18] != 5))  {$zone_indc->{"attc"} = 1;}	#set attic zone indicator unless flat ceiling is type "N/A" or "flat"
# 		elsif (($CSDDRD->[18] < 1) || ($CSDDRD->[18] > 6)) {& error_msg ("Bad flat roof type", $hse_type, $region, $CSDDRD->[1]);};
# 
# 
# 	#-----------------------------------------------
# 	# CREATE APPROPRIATE FILENAME EXTENTIONS AND FILENAMES FROM THE TEMPLATES FOR USE IN GENERATING THE ESP-r INPUT FILES
# 	#-----------------------------------------------
# 		# INITIALIZE OUTPUT FILE ARRAYS FOR THE PRESENT HOUSE RECORD BASED ON THE TEMPLATES
# 		my $record_extensions = {%extensions};		# new hash reference to a new hash that will hold the file extentions for this house
# 		my $hse_file;					# new array reference to the ESP-r files for this record
# 		foreach my $ext (values %{$record_extensions}) {	#for each filename extention
# 			$hse_file->[$ext]=[@{$template[$ext]}];	# create an array for each ESP-r house file equal to templates (elements are text lines)
# 		};
# 
# 
# 		# CHECK IF MAIN ZONE HAS A TMC FILE (WINDOWS) AND SET INDICATOR AND MAKE NEW MAIN.TMC
# 		# if ($CSDDRD->[152]+$CSDDRD->[153]+$CSDDRD->[154]+$CSDDRD->[155]>0) { &hse_file_indc("main", "tmc", $record_indc, $hse_file, $record_extensions); }
# 		# else { $record_indc->{"main.tmc"} = 0; };
# 
# 
# 		# CREATE THE FILES FOR THE main ZONE (main.xxx)
# 		foreach my $insertion ("opr", "con", "geo") {&hse_file_indc("main", $insertion, $hse_file, $record_extensions);};	# files required for the main zone
# 		if ($record_indc->{"foundation"} == 10) {&hse_file_indc("main", "bsm", $hse_file, $record_extensions);};	# slab foundation so create a main.bsm file
# 
# 
# 		# CHECK FOR BASEMENT, CRAWLSPACE AND ATTIC PRESENCE AND MAKE SUITABLE FILES
# 		if ($zone_indc->{"bsmt"}) {foreach my $ext ("bsm", "opr", "con", "geo") {&hse_file_indc("bsmt", $ext, $hse_file, $record_extensions);};};
# 		if ($zone_indc->{"crwl"}) {foreach my $ext ("bsm", "opr", "con", "geo") {&hse_file_indc("crwl", $ext, $hse_file, $record_extensions);};};
# 		if ($zone_indc->{"attc"}) {foreach my $ext ("opr", "con", "geo") {&hse_file_indc("attc", $ext, $hse_file, $record_extensions);};};
# 
# 
# 		# DELETE THE REFERENCES TO THE TEMPLATE FILES WHICH HAVE BEEN TRUMPED BY INDIVIDUAL ZONE FILES XXXX.YYY (DON'T DELETE THE ACTUAL TEMPLATE THOUGH AS WE MAY USE THEM LATER)
# 		foreach my $ext ("tmc", "bsm", "opr", "con", "geo") { delete $record_extensions->{$ext};};
# 
# 		# CREATE AN ARRAY WITH THE ZONE NAMES FOR USE IN CYCLING THROUGH FOREACH COMMANDS
# 		my $zones;	#array to hold the actual zone names for the house record
# 		foreach my $zone (keys %{$zone_indc}) {if ($zone_indc->{"$zone"} == 1) {push (@{$zones}, $zone)};}; # push zones that are true onto the array
# 
# 		#-----------------------------------------------
# 		# GENERATE THE *.cfg FILE
# 		#-----------------------------------------------
# 		my $time= localtime();
# 		# subroutine simple_replace (house file to read/write, keyword to identify row, location on line (1=front, 2=inside, 3=end), rows below keyword to replace, replacement text)
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#DATE", 1, 1, "*date $time");	#Put the time of file generation at the top
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#ROOT", 1, 1, "*root $CSDDRD->[1]");	#Label with the record name (.HSE stripped)
# 		CHECK_CITY: foreach my $location (1..$#climate_ref) {	#cycle through the climate reference list to find a match
# 			if (($climate_ref[$location][0] =~ /$CSDDRD->[4]/) && ($climate_ref[$location][1] =~ /$CSDDRD->[3]/)) {	#find a matching climate name and province name
# 				& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#LAT", 1, 1, "$climate_ref[$location][6] $climate_ref[$location][3] # $CSDDRD->[4],$CSDDRD->[3] -> $climate_ref[$location][4]");	#Use the weather station's lat (for esp-r beam purposes), use the site's long (it is correct, whereas CWEC is not), also in a comment show the CSDDRD weather site and compare to CWEC weather site.	
# 				& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#CLIMATE", 1, 1, "*clm ../../../climate/$climate_ref[$location][4]");	#use the CWEC city weather name
# 				last CHECK_CITY;	#if climate city matched jump out of the loop
# 			}
# 			elsif ($location == $#climate_ref) {die ("Bad climate: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n");};	#if climate not found print an error
# 		}
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#LAT", 1, 2, "1 0.3");	#site exposure and ground reflectivity (rho)
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#AIM_CTL", 1, 1, "*aim ./$CSDDRD->[1].aim");	#aim path
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#AIM_CTL", 1, 2, "*ctl ./$CSDDRD->[1].ctl");	#ctl path
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_SETUP", 1, 2, "*sps 1 10 1 10 5 0");	# sim setup: no. data sets retained; startup days; zone_ts (step/hr); plant_ts (step/hr); ?save_lv @ each zone_ts; ?save_lv @ each zone_ts;
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_SETUP", 1, 3, "1 1 31 12  default");	#simulation start day; start mo.; end day; end mo.; preset name
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_SETUP", 1, 4, "*sblr $CSDDRD->[1].res");	#res file path
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#PROJ_LOG", 1, 2, "$CSDDRD->[1].log");	#log file path
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#BLD_NAME", 1, 2, "$CSDDRD->[1]");		#name of the building
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#ZONES", 1, 1, 1+$zone_indc->{"bsmt"}+$zone_indc->{"crwl"}+$zone_indc->{"attc"});	#number of zones
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#CONNECT", 1, 1, "*cnn ./$CSDDRD->[1].cnn");	#cnn path
# 		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#AIR", 1, 1, "0");				#air flow network path
# 
# 		#zone1 (main) paths. 
# 		& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE1", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
# 		foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /main.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE1", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "main" (note use of regex brackets and $1)
# 		& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE1", 1, 1, 0, "*zon 1");	#add the top line (#zon X) for the zone
# 
# 		#zone2 (bsmt or crwl or attc or non-existant)
# 		if ($zone_indc->{"bsmt"}) {
# 			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
# 			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /bsmt.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "bsmt" (note use of regex brackets and $1)
# 			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zon 2");	#add the top line (#zon X) for the zone
# 		}
# 		elsif ($zone_indc->{"crwl"}) {
# 			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
# 			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /crwl.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "crwl" (note use of regex brackets and $1)
# 			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zon 2");	#add the top line (#zon X) for the zone
# 		}
# 		elsif ($zone_indc->{"attc"}) {
# 			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
# 			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /attc.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "attc" (note use of regex brackets and $1)
# 			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zon 2");	#add the top line (#zon X) for the zone
# 		};
# 
# 		#zone3 (attc or non-existant)
# 		if (($zone_indc->{"bsmt"} || $zone_indc->{"crwl"}) && $zone_indc->{"attc"}) {
# 			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE3", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
# 			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /attc.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE3", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "attc" (note use of regex brackets and $1)
# 			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE3", 1, 1, 0, "*zon 3");	#add the top line (#zon X) for the zone
# 		}
# 
# 
# # 		#-----------------------------------------------
# # 		# Generate the *.aim file
# # 		#-----------------------------------------------
# 		my $Pa_ELA;
# 		if ($CSDDRD->[32] == 1) {$Pa_ELA = 10} elsif ($CSDDRD->[32] == 2) {$Pa_ELA = 4} else {die ("Bad Pa_ELA: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};	#set the ELA pressure
# 		if ($CSDDRD->[28] == 1) {	#Check air tightness type (1= blower door test)
# 			& simple_replace ($hse_file->[$record_extensions->{"aim"}], "BLOWER_DOOR", 2, 0, "1 $CSDDRD->[31] $Pa_ELA 1 $CSDDRD->[33]");	#Blower door test with ACH50 and ELA specified
# 		}
# 		else { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "BLOWER_DOOR", 2, 0, "1 $CSDDRD->[31] $Pa_ELA 0 0"); };			#Airtightness rating, use ACH50 only (as selected in HOT2XP)
# 		my $eave_height = $CSDDRD->[112] + $CSDDRD->[113] + $CSDDRD->[114] + $CSDDRD->[115];								#equal to main floor heights + wall height of basement above grade. DO NOT USE HEIGHT OF HIGHEST CEILING, it is strange
# 		if ($eave_height < 1) { & error_msg ("Eave < 1 m height", $hse_type, $region, $CSDDRD->[1])}	#minimum eave height in aim2_pretimestep.F
# 		elsif ($eave_height > 12) { & error_msg ("Eave > 12 m height", $hse_type, $region, $CSDDRD->[1])}	#maximum eave height in aim2_pretimestep.F, updated from 10 m to 12 m by LS (2008-10-06)
# 		& simple_replace ($hse_file->[$record_extensions->{"aim"}], "EAVE_HEIGHT", 2, 0, "$eave_height");			#set the eave height in meters
# #PLACEHOLDER FOR MODIFICATION OF THE FLUE SIZE LINE. PRESENTLY AIM2_PRETIMESTEP.F USES HVAC FILE INSTEAD OF THESE INPUTS
# 		if ($zone_indc->{"bsmt"}) { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "ZONE_INDICES", 2, 2, "2 1 2");}			#main and basement recieve infiltration
# 		else { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "ZONE_INDICES", 2, 2, "1 1");};						#only main recieves infiltration
# 		if ($zone_indc->{"bsmt"}) { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "ZONE_INDICES", 2, 3, "2 0 0")}				#identify the basement zone for AIM, do not identify the crwl or attc as these will be dealt with in the opr file
# 		else { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "ZONE_INDICES", 2, 3, "0 0 0")};						#no bsmt, all additional zone infiltration is dealt with in the opr file
# 
# 
# # 		#-----------------------------------------------
# # 		# Generate the *.bsm file
# # 		#---------------------------------------$sides--------
# 		#placeholder for replacing the VERSION number to invoke the Moore Model for ground temp
# 		#& simple_replace ($hse_file->[$record_extensions->{bsmt.bsm}], "#VERSION", 1, 0, "1")
# 
# 		if ( $record_indc->{"foundation"} != 7) {	#if the foundation is anything by a open crawl space (exposed floor), then basesimp is employed, so check side lengths for range
# 			my $foundation_area = $CSDDRD->[97] +$CSDDRD->[98] +$CSDDRD->[99];	#certain bld have foundation area of two types. Presently summing area and set equal to dominant type
# 			my $side_length = $foundation_area ** 0.5;			#assume a square building
# 			if ($side_length < 2) {& error_msg ("Foundation < 2 m sides", $hse_type, $region, $CSDDRD->[1])}	#minimum length set to 2 m in basesimp.F. This range was increased by LS (2008-10-09) from 5 m to 2 m to account for the smallest houses of the CSDDRD
# 			elsif ($side_length > 20) {& error_msg ("Foundation > 20 m sides", $hse_type, $region, $CSDDRD->[1])};	#maximum width set to 20 m in basesimp.F
# 	
# 			#basement
# 			if ($record_indc->{"foundation"} <= 6) {		#fill out the bsm file based on basement values
# 				#the height and depth ranges need to be addressed in the source code (esrubld/basesimp.F) to see if they can be extended. Presently we are effectively reducing the size of overly large basements.
# 				my $height = $CSDDRD->[109];
# 				if ($height < 1) { $height = 1; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# HEIGHT", 2, 0, "$height");}		#min range of bsmt height (total)
# 				elsif ($height > 2.5) { $height = 2.5; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# HEIGHT", 2, 0, "$height");}	#max range of bsmt height (total)
# 				else { & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# HEIGHT", 2, 0, "$height");};				#set bsmt height (total)
# 	
# 				my $depth = $height - $CSDDRD->[115];					#difference between total height and above grade, used below for insul placement as well
# 				if (($record_indc->{"foundation"} >= 3) && ($record_indc->{"foundation"} <= 6)) { $depth = ($CSDDRD->[109] - 0.3) / 2};		#walkout basement, attribute 0.3 m above grade and divide remaining by 2 to find equivalent area below grade
# 				if ($depth < 0.65) { $depth = 0.65; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# DEPTH", 2, 0, "0.65");}		#min range of bsmt depth (below grade), if less than 0.65 m it ESP-r will fault unless it is a slab (0.05 m )
# 				elsif ($depth > 2.4) { $depth = 2.4; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# DEPTH", 2, 0, "2.4")}	#max range of bsmt depth (below grade)
# 				else {	& simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# DEPTH", 2, 0, "$depth");			#write out the depth
# 				};
# 	
# 				foreach my $sides ("# LENGTH", "# WIDTH") { & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "$sides", 2, 0, "$side_length")};
# 	
# 	
# 				if (($CSDDRD->[41] == 4) && ($CSDDRD->[38] > 1)) {	#insulation placed on exterior below grade and on interior
# 					if ($CSDDRD->[38] == 2) { & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# OVERLAP", 2, 0, "$depth")}	#full interior so overlap is equal to depth
# 					elsif ($CSDDRD->[38] == 3) { my $overlap = $depth - 0.2; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# OVERLAP", 2, 0, "$overlap")}	#partial interior to within 0.2 m of slab
# 					elsif ($CSDDRD->[38] == 4) { & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# OVERLAP", 2, 0, "0.6")}	#partial interior to 0.6 m below grade
# 					else { die ("Bad basement insul overlap: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};
# 				};
# 	
# 				#I have assumed that we only account for the RSI of interior or exterior. Must VERIFY this in source code
# 				my $insul_RSI = $CSDDRD->[40];						#set the insul value to interior
# 				if ($CSDDRD->[42] > $CSDDRD->[40]) { $insul_RSI = $CSDDRD->[42]};	#check it exterior value is larger
# 				if ($insul_RSI > 9) { $insul_RSI = 9};					#check that value is not greater than RSI=9
# 				& simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# RSI", 2, 0, "$insul_RSI");
# 			}
# 			#crawl space
# 			elsif (($record_indc->{"foundation"} >= 8) && ($record_indc->{"foundation"} <= 9) ) {		#fill out the bsm file based on crawlspace values
# 				if ($CSDDRD->[110] < 1) { & simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# HEIGHT", 2, 0, "1");}		#min range of crwl height (total)
# 				elsif ($CSDDRD->[110] > 2.5) { & simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# HEIGHT", 2, 0, "2.5");}	#max range of crwl height (total)
# 				else { & simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# HEIGHT", 2, 0, "$CSDDRD->[110]");};				#set crwl height (total)
# 	
# 				& simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# DEPTH", 2, 0, "0.05");			#consider crwl space a slab as heat transfer through walls will be dealt with later as they are above grade
# 	
# 				foreach my $sides ("# LENGTH", "# WIDTH") { & simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "$sides", 2, 0, "$side_length")};
# 	
# 				my $insul_RSI = $CSDDRD->[56];						#set the insul value to that of the crwl space slab
# 				if ($insul_RSI > 9) { $insul_RSI = 9};					#check that value is not greater than RSI=9
# 				& simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# RSI", 2, 0, "$insul_RSI")
# 			}
# 	
# 			#slab on grade
# 			elsif ($record_indc->{"foundation"} == 10) {		#if not open crwl, bsmt, or regular crwl, then must be a slab on grade
# 				if ($CSDDRD->[112] < 1) { & simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# HEIGHT", 2, 0, "1");}		#min range of main height (total)
# 				elsif ($CSDDRD->[112] > 2.5) { & simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# HEIGHT", 2, 0, "2.5")}	#max range of main height (total)
# 				else { & simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# HEIGHT", 2, 0, "$CSDDRD->[112]");};				#set main height (total)
# 	
# 				& simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# DEPTH", 2, 0, "0.05");			#consider the slab only as heat transfer through walls will be dealt with later as they are above grade
# 	
# 				foreach my $sides ("# LENGTH", "# WIDTH") { & simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "$sides", 2, 0, "$side_length")};
# 	
# 				my $insul_RSI = $CSDDRD->[63];						#set the insul value to that of the crwl space slab
# 				if ($insul_RSI > 9) { $insul_RSI = 9};					#check that value is not greater than RSI=9
# 				& simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# RSI", 2, 0, "$insul_RSI");
# 			}
# 
# 			else {& error_msg ("bsm did not build correctly", $hse_type, $region, $CSDDRD->[1])};
# 
# 		};	# end of the bsm file generation
# 
# 
# 		#-----------------------------------------------
# 		# Control file
# 		#-----------------------------------------------
# 		my $heat_watts = $CSDDRD->[79] * 1000;	#multiply kW by 1000 for watts. this is based on HOT2XP's heating sizing protocol
# 		my $cool_watts = 0;			#initialize a cooling variable
# 		if (($CSDDRD->[88] >= 1) && ($CSDDRD->[88] <= 3)) { $cool_watts = 0.25 *$heat_watts;};	#if cooling is present size it to 25% of heating capacity
# 		& simple_replace ($hse_file->[$record_extensions->{"ctl"}], "# DATA_LINE1", 3, 0, "$heat_watts 0 $cool_watts 0 $CSDDRD->[69] $CSDDRD->[70] 0");	#insert the data line (heat_watts_on heat_watts_off, cool_watts_on cool_watts_off heating_setpoint_C cooling_setpoint_C RH_control
# 		if ($zone_indc->{"bsmt"}) { & simple_replace ($hse_file->[$record_extensions->{"ctl"}], "#ZONE_LINKS", 1, 1, "1,1,0");}	#link main and bsmt to control loop. If no attic is present the extra zero will not bomb the prj (hopefully not bomb the bps as well)
# 		else { & simple_replace ($hse_file->[$record_extensions->{"ctl"}], "#ZONE_LINKS", 1, 1, "1,0,0");}	#no bsmt and crwl spc is not conditioned so zeros other than main
# 
# 		#-----------------------------------------------
# 		# Operations files
# 		#-----------------------------------------------
# 		foreach my $zone (@{$zones}) { & simple_replace ($hse_file->[$record_extensions->{"$zone.opr"}], "#DATE", 1, 1, "*date $time")};	#set the time/date for the main.opr file
# 		#if no other zones exist then do not modify the main.opr (its only use is for ventilation with the bsmt due to the aim and fcl files
# 		if ($zone_indc->{"bsmt"}) {
# 			foreach my $days ("WEEKDAY", "SATURDAY", "SUNDAY") {								#do for each day type
# 				& simple_replace ($hse_file->[$record_extensions->{"main.opr"}], "#AIR_$days", 1, 2, "0 24 0 0.5 2 0");	#add 0.5 ACH ventilation to main from basement. Note they are different volumes so this technically creates imbalance. ESP-r does not seem to account for this (zonal model). This technique should be modified in the future when volumes are known for consistency
# 				& simple_replace ($hse_file->[$record_extensions->{"bsmt.opr"}], "#AIR_$days", 1, 2, "0 24 0 0.5 1 0");	#add same ACH ventilation to bsmt from main
# 			};
# 		}
# 		elsif ($zone_indc->{"crwl"}) {
# 			my $crwl_ach;
# 			if ($record_indc->{"foundation"} == 8) {$crwl_ach = 0.5;}		#set the crwl ACH infiltration based on tightness level. 0.5 and 0.1 ACH come from HOT2XP
# 			elsif ($record_indc->{"foundation"} == 9) {$crwl_ach = 0.1;}
# 			else {& error_msg ("wrong foundation type for crwl", $hse_type, $region, $CSDDRD->[1])};
# 			foreach my $days ("WEEKDAY", "SATURDAY", "SUNDAY") { & simple_replace ($hse_file->[$record_extensions->{"crwl.opr"}], "#AIR_$days", 1, 2, "0 24 $crwl_ach 0 0 0");};	#add it as infiltration and not ventilation. It comes from ambient.
# 		};
# 		if ($zone_indc->{"attc"}) {
# 			foreach my $days ("WEEKDAY", "SATURDAY", "SUNDAY") { & simple_replace ($hse_file->[$record_extensions->{"attc.opr"}], "#AIR_$days", 1, 2, "0 24 0.5 0 0 0");};	#fixed 0.5 ACH to attic from ambient
# 		};
# 
# 
# 		#-----------------------------------------------
# 		# Preliminary geo file generation
# 		#-----------------------------------------------
# 		#for now make square and size it based on main only, no windows.
# 		foreach my $zone (@{$zones}) { 
# 			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#ZONE_NAME", 1, 1, "GEN $zone This file describes the $zone");	#set the time at the top of each zone geo file
# 
# 			my $side_length = $CSDDRD->[100] ** 0.5;	#assume a square house and use the main level to dictate size of other zones. CHANGE THIS LATER
# 			my $height;					#initialize height and vertical offset. Offset is not required for ESP-r but allows for visualization using prj
# 			my $vert_offset;
# 			if ($zone eq "main") { $height = $CSDDRD->[112] + $CSDDRD->[113] + $CSDDRD->[114]; $vert_offset = 0;}	#the main zone is height of three potential stories and originates at 0,0,0
# 			elsif ($zone eq "bsmt") { $height = $CSDDRD->[109]; $vert_offset = -$height;}	#basement or crwl space is offset by its height so that origin is below 0,0,0
# 			elsif ($zone eq "crwl") { $height = $CSDDRD->[110]; $vert_offset = -$height;}
# 			elsif ($zone eq "attc") { $height = $side_length * 5 / 12;  $vert_offset = $CSDDRD->[112] + $CSDDRD->[113] + $CSDDRD->[114];};	#attic is assumed to be 5/12 roofline and mounted to top corner of main above 0,0,0
# 			$height = $height + $vert_offset;	#include the offet in the height to place vertices>1 at the appropriate location
# 			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 1, "0 0 $vert_offset");	#origin
# 			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 2, "$side_length 0 $vert_offset");	#procced in CCW (looking down) and rise in levels
# 			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 3, "$side_length $side_length $vert_offset");
# 			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 4, "0 $side_length $vert_offset");
# 
# 			if ($zone ne "attc") {	#box shape for bsmt, crwl, and main
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 5, "0 0 $height");
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 6, "$side_length 0 $height");
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 7, "$side_length $side_length $height");
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 8, "0 $side_length $height");
# 			}
# 			else {	#5/12 attic shape
# 				my $side_length_minus = $side_length / 2 - 0.1; #not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
# 				my $side_length_plus = $side_length / 2 + 0.1;
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 5, "0 $side_length_minus $height");
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 6, "$side_length $side_length_minus $height");
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 7, "$side_length $side_length_plus $height");
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 8, "0 $side_length_plus $height");
# 			}
# 			
# 			#adjust the surface descriptions to represent conditions such as facing another zone and basesimp, RECOGNIZE the spacing as it is required by prj (maybe not bps)
# 			if (($zone eq "main") && ($zone_indc->{"bsmt"} || $zone_indc->{"crwl"})) { & simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 6, "  6, Base-6        OPAQ  FLOR  CNST-1       ANOTHER        ");}	#if bsmt or crwl then set the main zone floor into another zone
# 			elsif (($zone eq "main") && $CSDDRD->[15] == 10) { & simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 6, "  6, Base-6        OPAQ  FLOR  CNST-1       BASESIMP       ");};	#if no bsmt or crwl, then if slab set the main floor to basesimp
# 			if (($zone eq "bsmt") || ($zone eq "crwl")) {	#for bsmt or crwl mate the ceiling to main and the floor to basesimp
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 5, "  5, Top-5         OPAQ  CEIL  CNST-1       ANOTHER        ");
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 6, "  6, Base-6        OPAQ  FLOR  CNST-1       BASESIMP       ");
# 			};
# 			if ($zone eq "bsmt") { foreach my $side (1..4) {	#if bsmt then match all walls to basesimp
# 				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, $side, "  $side, Wall-$side        OPAQ  VERT  CNST-1       BASESIMP       ");};	
# 			};
# 			if (($zone eq "main") && $zone_indc->{"attc"}) { & simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 5, "  5, Top-5         OPAQ  CEIL  CNST-1       ANOTHER        ");};	#map roof of main to attc
# 			if ($zone eq "attc") {& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 6, "  6, Base-6        OPAQ  FLOR  CNST-1       ANOTHER        ");};	#map floor of attc to main
# 			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#BASE", 1, 1, "6 0 0 0 0 0 $CSDDRD->[100] 0");	#last line in GEO file which uses surface count and floor area
# 		}
# 
# 
# 		#-----------------------------------------------
# 		# Connections file
# 		#-----------------------------------------------
# 		& simple_replace ($hse_file->[$record_extensions->{"cnn"}], "#DATE", 1, 1, "*date $time");	#add the date stamp
# 		my $cnn_count = 0;	#declare a variable for number of connections
# 		foreach my $zone (@{$zones}) { $cnn_count = $cnn_count + 6;};	#total the number of connections, THIS IS SIMPLIFIED (no windows)
# 		& simple_replace ($hse_file->[$record_extensions->{"cnn"}], "#CONN_NUM", 1, 1, "$cnn_count");
# 		if ($zone_indc->{"attc"} && ($zone_indc->{"bsmt"} || $zone_indc->{"crwl"})) {	#make attic the third zone
# 			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "3 6 3 1 5");	#attach floor of attic to main ceiling
# 			foreach my $side (5, 4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "3 $side 0 0 0");};	#all remaining attc to ambient
# 		}
# 		elsif ($zone_indc->{"attc"}) {	#there is no bsmt or crwl so attc is zone #2
# 			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 6 3 1 5");
# 			foreach my $side (5, 4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 $side 0 0 0");};
# 		};
# 		if ($zone_indc->{"bsmt"}) {	#bsmt exists
# 			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 6 6 1 20");	#attach slab to basesimp, assume inside wall insul, 20% heat loss
# 			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 5 3 1 6");	#attach bsmt ceiling to main floor
# 			foreach my $side (4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 $side 6 1 20");};	#remaining sides of bsmt to basesimp, same assumptions
# 		}
# 		elsif ($zone_indc->{"crwl"}) {	#bsmt exists
# 			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 6 6 28 100");	#attach slab to basesimp, assume ino slab insul, 100% heat loss
# 			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 5 3 1 6");	#attach crwl ceiling to main floor
# 			foreach my $side (4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 $side 0 0 0");};	#remaining sides of crwl to ambient
# 		}
# 		if ($zone_indc->{"bsmt"} || $zone_indc->{"crwl"}) {
# 			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 6 3 2 5");	#check if main is attached to a bsmt or crwl
# 			if ($zone_indc->{"attc"}) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 5 3 3 6");};	#if attc exist then it is zone 3
# 		}
# 		elsif ($record_indc->{"foundation"} == 10) {
# 			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 6 6 28 100");	#main slab so use basesimp
# 			if ($zone_indc->{"attc"}) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 5 3 2 6");};	#if attc exists then it is zone 2
# 		}
# 		else {
# 			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 6 0 0 0");	#main has exposed floor
# 			if ($zone_indc->{"attc"}) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 5 3 2 6");};	#if attc exists then it is zone 2
# 		}
# 		if (!$zone_indc->{"attc"}) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 5 0 0 0");};	#attc was not filled out so expose main ceiling to ambient
# 		foreach my $side (4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 $side 0 0 0");};	#expose main walls to ambient
# 
# 
# 		#-----------------------------------------------
# 		# Constructions file
# 		#-----------------------------------------------
# 		foreach my $zone (@{$zones}) {	#for each zone of the hosue
# 			my $surface_count = 6;		#assume eight vertices and six side TEMPORARY
# 			foreach (1..$surface_count) {& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#LAYERS_GAPS", 1, 1, 0, "1 0");};	#number of layers for each surface, number of air gaps for each surface
# 			foreach (1..$surface_count) {& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#PROPERTIES", 1, 1, 0, "0.03 500 2000 0.040 0 0 0 0");};	#add the surface layer information ONLY 1 LAYER AT THIS POINT
# 			
# 			my $emm_inside = "";	#initialize text strings for the long-wave emissivity and short wave absorbtivity on the appropriate construction side
# 			my $emm_outside = "";
# 			my $slr_abs_inside = "";
# 			my $slr_abs_outside = "";
# 	
# 			foreach (1..$surface_count) {		#add an emm/abs for each surface of a zone
# 				$emm_inside = "0.75 $emm_inside";
# 				$emm_outside = "0.75 $emm_outside";
# 				$slr_abs_inside = "0.5 $slr_abs_inside";
# 				$slr_abs_outside = "0.5 $slr_abs_outside";
# 			}
# 			& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#EMM_INSIDE", 1, 1, 0, "$emm_inside");	#write out the emm/abs of the surfaces for each zone
# 			& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#EMM_OUTSIDE", 1, 1, 0, "$emm_outside");
# 			& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#SLR_ABS_INSIDE", 1, 1, 0, "$slr_abs_inside");
# 			& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#SLR_ABS_OUTSIDE", 1, 1, 0, "$slr_abs_outside");
# 		}
# 
# 
# 		#-----------------------------------------------
# 		# Print out each esp-r house file for the house record
# 		#-----------------------------------------------
# 		foreach my $ext (keys %{$record_extensions}) {				#go through each extention inclusive of the zones for this particular record
# 			open (FILE, '>', "$output_path/$CSDDRD->[1].$ext") or die ("can't open datafile: $output_path/$CSDDRD->[1].$ext");	#open a file on the hard drive in the directory tree
# 			foreach my $line (@{$hse_file->[$record_extensions->{$ext}]}) {	#loop through each element of the array (i.e. line of the final file)
# 				print FILE "$line";					#print each line out
# 			}
# 			close FILE;
# 		}
# 		copy ("../templates/input.xml", "$output_path/input.xml") or die ("can't copy file: input.xml");	#add an input.xml file to the house for XML reporting of results
# 
# 
# 	}	#end of the while loop through the CSDDRD->
# }	#end of main code
# 
# 
# #-----------------------------------------------
# # Subroutines
# #-----------------------------------------------
# sub hse_file_indc() {				#subroutine to add and appropriately name another copy of a template file to support multiple zones (i.e. main.geo, bsmt.geo) and then notes it in the cross reference hash
# 	my $zone = shift (@_);			#the zone title
# 	my $ext = shift (@_);			#the extension title
# 	my $hse_file = shift (@_);		#array of house esp-r files to add too
# 	my $record_extensions = shift (@_);	#array of house extentions to add too for the zone and extension
# 	push (@{$hse_file},[@{$hse_file->[$record_extensions->{$ext}]}]);	#copy the template file to the new location
# 	$record_extensions->{"$zone.$ext"} = $#{$hse_file};			#use the hash to record the zone's file and extension and cross reference its location in the array
# }
# 
# 
# sub simple_replace () {			#subroutine to perform a simple element replace (house file to read/write, keyword to identify row, rows below keyword to replace, replacement text)
# 	my $hse_file = shift (@_);	#the house file to read/write
# 	my $find = shift (@_);		#the word to identify
# 	my $location = shift (@_);	#where to identify the word: 1=start of line, 2=anywhere within the line, 3=end of line
# 	my $beyond = shift (@_);	#rows below the identified word to operate on
# 	my $replace = shift (@_);	#replacement text for the operated element
# 	CHECK_LINES: foreach my $line (0..$#{$hse_file}) {		#pass through the array holding each line of the house file
# 		if ((($location == 1) && ($hse_file->[$line] =~ /^$find/)) || (($location == 2) && ($hse_file->[$line] =~ /$find/)) || (($location == 3) && ($hse_file->[$line] =~ /$find$/))) {	#search for the identification word at the appropriate position in the line
# 			$hse_file->[$line+$beyond] = "$replace\n";	#replace the element that is $beyond that where the identification word was found
# 			last CHECK_LINES;				#If matched, then jump out to save time and additional matching
# 		}
# 	}
# }
# 
# sub simple_insert () {			#subroutine to perform a simple element insert after (specified) the identified element (house file to read/write, keyword to identify row, number of elements after to do insert, replacement text)
# 	my $hse_file = shift (@_);	#the house file to read/write
# 	my $find = shift (@_);		#the word to identify
# 	my $location = shift (@_);	#1=start of line, 2=anywhere within the line, 3=end of line
# 	my $beyond = shift (@_);	#rows below the identified word to remove from and insert too
# 	my $remove = shift (@_);	#rows to remove
# 	my $replace = shift (@_);	#replacement text for the operated element
# 	CHECK_LINES: foreach my $line (0..$#{$hse_file}) {		#pass through the array holding each line of the house file
# 		if ((($location == 1) && ($hse_file->[$line] =~ /^$find/)) || (($location == 2) && ($hse_file->[$line] =~ /$find/)) || (($location == 3) && ($hse_file->[$line] =~ /$find$/))) {	#search for the identification word at the appropriate position in the line
# 			splice (@{$hse_file}, $line+$beyond, $remove, "$replace\n");	#replace the element that is $beyond that where the identification word was found
# 			last CHECK_LINES;				#If matched, then jump out to save time and additional matching
# 		}
# 	}
# }
# 
# sub error_msg () {			#subroutine to perform a simple element insert after (specified) the identified element (house file to read/write, keyword to identify row, number of elements after to do insert, replacement text)
# 	my $msg = shift (@_);		#the error message to print
# 	my $hse_type = shift (@_);	#the house type
# 	my $region = shift (@_);	#the region
# 	my $record = shift (@_);	#the house record
# 	print GEN_SUMMARY "$msg: hse_type=$hse_type; region=$region; record=$record\n";
# 	next RECORD;
# }