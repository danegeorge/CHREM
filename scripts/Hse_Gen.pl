#!/usr/bin/perl

# ====================================================================
# Hse_Gen.pl
# Author: Lukas Swan
# Date: Apl 2009
# Copyright: Dalhousie University


# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all]


# DESCRIPTION:
# This script generates the esp-r house files for each house of the CSDDRD.
# It uses a multithreading approach based on the house type (SD or DR) and 
# region (AT, QC, OT, PR, BC). Which types and regions are generated is 
# specified at the beginning of the script to allow for partial generation.

# The script builds a directory structure for the houses which begins with 
# the house type as top level directories, regions as second level directories 
# and the house name (10 digit w/o ".HDF") for each house directory. It places 
# all house files within that directory (all house files in the same directory). 

# The script reads a set of input files:
# 1) CSDDRD type and region database (csv)
# 2) esp-r file templates (template.xxx)
# 3) weather station cross reference list

# The script copies the template files for each house of the CSDDRD and replaces
# and inserts within the templates based on the values of the CSDDRD house. Each 
# template file is explicitly dealt with in the main code (actually a sub) and 
# utilizes insert and replace subroutines to administer the specific house 
# information.

# The script is easily extendable to addtional CSDDRD files and template files.
# Care must be taken that the appropriate lines of the template file are defined 
# and that any required changes in other template files are completed.


# ===================================================================

# --------------------------------------------------------------------
# Declare modules which are used
# --------------------------------------------------------------------
use warnings;
use strict;
use CSV;	# CSV-2 (for CSV split and join, this works best)
# use Array::Compare;	# Array-Compare-1.15
use threads;	# threads-1.71 (to multithread the program)
use File::Path;	# File-Path-2.04 (to create directory trees)
use File::Copy;	# (to copy the input.xml file)
use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
use Data::Dumper;

# --------------------------------------------------------------------
# Declare the global variables
# --------------------------------------------------------------------
my @hse_types;	# declare an array to store the desired house types
my %hse_names = (1, "1-SD", 2, "2-DR");	# declare a hash with the house type names

my @regions;	# Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");	# declare a hash with the region names


my $mat_name;	# declare an array ref to store (at index = material number) a reference to that material in the mat_db.xml
my $con_name;	# declare a hash ref to store (at key = construction name) a reference to that construction in the con_db.xml
my $optic_data;	# declare a hash ref to store the optical data from optic_db.xml


# --------------------------------------------------------------------
# Read the command line input arguments
# --------------------------------------------------------------------
COMMAND_LINE: {
	if ($ARGV[0] eq "db") {&database_XML(); exit;};	# construct the databases and leave the information loaded in the variables for use in house generation

	if ($#ARGV != 1) {die "Two arguments are required: house_types regions; or \"db\" for database generation\n";};	# check for proper argument count

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


&database_XML();	# construct the databases and leave the information loaded in the variables for use in house generation

my $dhw_energy_src;
my $hvac;
&keys_XML();	# bring in the key information to cross reference between CSDDRD and ESP-r

# --------------------------------------------------------------------
# Initiate multi-threading to run each region simulataneously
# --------------------------------------------------------------------
MULTI_THREAD: {
	mkpath ("../summary_files");	# make a path to place files that summarize the script results
	print "PLEASE CHECK THE gen_summary.txt FILE IN THE ../summary_files DIRECTORY FOR ERROR LISTING\n";	# tell user to go look
	open (GEN_SUMMARY, '>', "../summary_files/gen_summary.txt") or die ("can't open ../summary_files/gen_summary.txt");	# open a error and summary writeout file
	my $start_time= localtime();	# note the start time of the file generation

	my $thread;	# Declare threads for each type and region
	my $thread_return;	# Declare a return array for collation of returning thread data

	foreach my $hse_type (@hse_types) {	# Multithread for each house type
		foreach my $region (@regions) {	# Multithread for each region
			$thread->[$hse_type][$region] = threads->new(\&main, $hse_type, $region, $mat_name, $con_name, $dhw_energy_src, $hvac);	# Spawn the threads and send to main subroutine
		};
	};
	foreach my $hse_type (@hse_types) {	# return for each house type
		foreach my $region (@regions) {	# return for each region type
			$thread_return->[$hse_type][$region] = $thread->[$hse_type][$region]->join();	# Return the threads together for info collation
		};
	};

	my $attempt_total = 0;
	my $success_total = 0;
	foreach my $hse_type (@hse_types) {	# for each house type
		foreach my $region (@regions) {	# for each region
			my $attempt = $thread_return->[$hse_type][$region][0];
			$attempt_total = $attempt_total + $attempt;
			my $success = $thread_return->[$hse_type][$region][1];
			$success_total = $success_total + $success;
			my $failed = $thread_return->[$hse_type][$region][0] - $thread_return->[$hse_type][$region][1];
			my $success_ratio = $success / $attempt * 100;
			printf GEN_SUMMARY ("%s %4.1f\n", "$hse_names{$hse_type} $region_names{$region}: Attempted $attempt; Successful $success; Failed $failed; Success Ratio (%)", $success_ratio);
		};
	};
	my $failed = $attempt_total - $success_total;
	my $success_ratio = $success_total / $attempt_total * 100;
	printf GEN_SUMMARY ("%s %4.1f\n", "Total: Attempted $attempt_total; Successful $success_total; Failed $failed; Success Ratio (%)", $success_ratio);

	my $end_time= localtime();	# note the end time of the file generation
	print GEN_SUMMARY "start time $start_time; end time $end_time\n";	# print generation characteristics
	close GEN_SUMMARY;	# close the summary file
	print "PLEASE CHECK THE gen_summary.txt FILE IN THE ../summary_files DIRECTORY FOR ERROR LISTING\n";	# tell user to go look
};

# --------------------------------------------------------------------
# Main code that each thread evaluates
# --------------------------------------------------------------------
MAIN: {
	sub main () {
		my $hse_type = shift (@_);	# house type number for the thread
		my $region = shift (@_);	# region number for the thread
		my $mat_name = shift (@_);	# material database reference list
		my $con_data = shift (@_);	# constructions database
		my $dhw_energy_src = shift (@_);	# keys to cross ref dhw of CSDDRD to ESP-r
		my $hvac = shift (@_);	# keys to cross ref hvac of CSDDRD to ESP-r

		my $models_attempted;	# incrementer of each encountered CSDDRD record
		my $models_OK;	# incrementer of records that are OK

		# -----------------------------------------------
		# Declare important variables for file generation
		# -----------------------------------------------
		# The template extentions that will be used in file generation (alphabetical order)
		my %extensions = ('aim', 1, 'bsm', 2, 'cfg', 3, 'cnn', 4, 'con', 5, 'ctl', 6, 'geo', 7, 'log', 8, 'opr', 9, 'tmc', 10, 'mvnt', 11, 'obs', 12, 'dhw', 13, 'hvac', 14, 'elec', 15);


		# -----------------------------------------------
		# Read in the templates
		# -----------------------------------------------
		my @template;	# declare an array to hold the original templates for use with the generation house files for each record

		# Open and read the template files
		foreach my $ext (keys %extensions) {	# do for each filename extention
			open (TEMPLATE, '<', "../templates/template.$ext") or die ("can't open tempate: $ext");	# open the template
			$template[$extensions{$ext}]=[<TEMPLATE>];	# Slurp the entire file with one line per array element
			close TEMPLATE;	# close the template file and loop to the next one
		}


		# -----------------------------------------------
		# Read in the CWEC weather data crosslisting
		# -----------------------------------------------	
		# Open and read the climate crosslisting (city name to CWEC file)
		open (CWEC, '<', "../climate/city_to_CWEC.csv") or die ("can't open datafile: ../climate/city_to_CWEC.csv");
		my @climate_ref;	# create an climate referece crosslisting array
		while (<CWEC>) {push (@climate_ref, [CSVsplit($_)]);};	# append the next line of data to the climate_ref array
		close CWEC;	# close the CWEC file


		# -----------------------------------------------
		# Open the CSDDRD source
		# -----------------------------------------------
		# Open the data source files from the CSDDRD - path to the correct CSDDRD type and region file
		my $input_path = "../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_$hse_names{$hse_type}_subset_$region_names{$region}.csv";
		open (CSDDRD_DATA, '<', "$input_path") or die ("can't open datafile: $input_path");	# open the correct CSDDRD file to use as the data source
		$_ = <CSDDRD_DATA>;	# strip the first header row from the CSDDRD file


		# -----------------------------------------------
		# GO THROUGH EACH REMAINING LINE OF THE CSDDRD SOURCE DATAFILE
		# -----------------------------------------------
		RECORD: while (<CSDDRD_DATA>) {	# go through each line (house) of the file
			$models_attempted++;
			my $time= localtime();	# note the present time

			# SPLIT THE DWELLING DATA, CHECK THE FILENAME, AND CREATE THE APPROPRIATE PATH ../TYPE/REGION/RECORD
			my $CSDDRD = [CSVsplit($_)];	# split each of the comma delimited fields for use
			my $coordinates = "hse_type=$hse_type; region=$region; record=$CSDDRD->[1]";
			$CSDDRD->[1] =~ s/.HDF// or  &error_msg ("Bad record name", $coordinates);	# strip the ".HDF" from the record name, check for bad filename
			my $output_path = "../$hse_names{$hse_type}/$region_names{$region}/$CSDDRD->[1]";	# path to the folder for writing the house folder
			mkpath ("$output_path");	# make the output path directory tree to store the house files

			# DECLARE ZONE AND PROPERTY HASHES. INITIALIZE THE MAIN ZONE TO BE TRUE AND ALL OTHER ZONES TO BE FALSE
			my $zone_indc = {"main", 1};	# hash for holding the indication of particular zone presence and its number for use with determine zones and where they are located
			my $record_indc;	# hash for holding the indication of dwelling properties

			# -----------------------------------------------
			# DETERMINE ZONE INFORMATION (NUMBER AND TYPE) FOR USE IN THE GENERATION OF ZONE TEMPLATES
			# -----------------------------------------------
			ZONE_PRESENCE: {
				# FOUNDATION CHECK TO DETERMINE IF A BSMT OR CRWL ZONES ARE REQUIRED, IF SO SET TO ZONE #2
				# ALSO SET A FOUNDATION INDICATOR EQUAL TO THE APPROPRIATE TYPE
				# FLOOR AREAS (m^2) OF FOUNDATIONS ARE LISTED IN CSDDRD[97:99]
				# FOUNDATION TYPE IS LISTED IN CSDDRD[15]- 1:6 ARE BSMT, 7:9 ARE CRWL, 10 IS SLAB (NOTE THEY DONT' ALWAYS ALIGN WITH SIZES, THEREFORE USE FLOOR AREA AS FOUNDATION TYPE DECISION
				# BSMT CHECK
				if (($CSDDRD->[97] >= $CSDDRD->[98]) && ($CSDDRD->[97] >= $CSDDRD->[99])) {	# compare the bsmt floor area to the crwl and slab
					$zone_indc->{"bsmt"} = 2;	# bsmt floor area is dominant, so there is a basement zone
					if ($CSDDRD->[15] <= 6) {$record_indc->{"foundation"} = $CSDDRD->[15];}	# the CSDDRD foundation type corresponds, use it in the record indicator description
					else {$record_indc->{"foundation"} = 1;};	# the CSDDRD foundation type doesn't correspond (but floor area was dominant), assume "full" basement
				}
				# CRWL CHECK
				elsif (($CSDDRD->[98] >= $CSDDRD->[97]) && ($CSDDRD->[98] >= $CSDDRD->[99])) {	# compare the crwl floor area to the bsmt and slab
					# crwl space floor area is dominant, but check the type prior to creating a zone
					if ($CSDDRD->[15] != 7) {	# check that the crwl space is either "ventilated" or "closed" ("open" is treated as exposed main floor)
						$zone_indc->{"crwl"} = 2;	# create the crwl zone
						if (($CSDDRD->[15] >= 8) && ($CSDDRD->[15] <= 9)) {$record_indc->{"foundation"} = $CSDDRD->[15];}	# the CSDDRD foundation type corresponds, use it in the record indicator description
						else {$record_indc->{"foundation"} = 8;};	# the CSDDRD foundation type doesn't correspond (but floor area was dominant), assume "ventilated" crawl space
					}
					else {$record_indc->{"foundation"} = 7;};	# the crwl is actually "open" with large ventilation, so treat it as an exposed main floor with no crwl zone
				}
				# SLAB CHECK
				elsif (($CSDDRD->[99] >= $CSDDRD->[97]) && ($CSDDRD->[99] >= $CSDDRD->[98])) { # compare the slab floor area to the bsmt and crwl
					$record_indc->{"foundation"} = 10;	# slab floor area is dominant, so set the foundation to 10
				}
				# FOUNDATION ERROR
				else {&error_msg ("Bad foundation determination", $coordinates);};

				# ATTIC CHECK- COMPARE THE CEILING TYPE TO DISCERN IF THERE IS AN ATTC ZONE
				# THE FLAT CEILING TYPE IS LISTED IN CSDDRD[18] AND WILL HAVE A VALUE NOT EQUAL TO 1 (N/A) OR 5 (FLAT ROOF) IF AN ATTIC IS PRESENT
				if (($CSDDRD->[18] != 1) && ($CSDDRD->[18] != 5)) {	# set attic zone indicator unless flat ceiling is type "N/A" or "flat"
					if (defined($zone_indc->{"bsmt"}) || defined($zone_indc->{"crwl"})) {$zone_indc->{"attc"} = 3;}
					else {$zone_indc->{"attc"} = 2;};
				}
				# CEILING TYPE ERROR
				elsif (($CSDDRD->[18] < 1) || ($CSDDRD->[18] > 6)) {&error_msg ("Bad flat roof type", $coordinates);};
			};

			# -----------------------------------------------
			# CREATE APPROPRIATE FILENAME EXTENTIONS AND FILENAMES FROM THE TEMPLATES FOR USE IN GENERATING THE ESP-r INPUT FILES
			# -----------------------------------------------

			# INITIALIZE OUTPUT FILE ARRAYS FOR THE PRESENT HOUSE RECORD BASED ON THE TEMPLATES
			my $record_extensions = {%extensions};	# new hash reference to a new hash that will hold the file extentions for this house. Initialize for use
			my $hse_file;	# new array reference to the ESP-r files for this record

			INITIALIZE_HOUSE_FILES: {
				# COPY THE TEMPLATES FOR USE WITH THIS HOUSE (SINGLE USE FILES WILL REMAIN, BUT ZONE FILES (e.g. geo) WILL BE AGAIN COPIED FOR EACH ZONE	
				foreach my $ext (values (%{$record_extensions})) {$hse_file->[$ext]=[@{$template[$ext]}];};
				# CREATE THE BASIC FILES FOR EACH ZONE 
				foreach my $zone (keys (%{$zone_indc})) {
					foreach my $file_type ("opr", "con", "geo") {&zone_file_create($zone, $file_type, $hse_file, $record_extensions);};	# files required for the main zone
					if (($zone eq "bsmt") || ($zone eq "crwl") || ($record_indc->{"foundation"} == 10)) {&zone_file_create($zone, "bsm", $hse_file, $record_extensions);};
				};
				
				&zone_file_create("main", "obs", $hse_file, $record_extensions);

				# CHECK MAIN WINDOW AREA (m^2) AND CREATE A TMC FILE ([156..159] is Front, Right, Back, Left)
				if ($CSDDRD->[156] + $CSDDRD->[157] + $CSDDRD->[158] + $CSDDRD->[159] > 0) {&zone_file_create("main", "tmc", $hse_file, $record_extensions);};	# windows so generate a TMC file
				# DELETE THE REFERENCES TO THE FILES WHICH HAVE BEEN TRUMPED BY INDIVIDUAL ZONE FILES XXXX.YYY
				foreach my $ext ("tmc", "bsm", "opr", "con", "geo", "obs") { delete $record_extensions->{$ext};};
			};

			# -----------------------------------------------
			# GENERATE THE *.cfg FILE
			# -----------------------------------------------
			CFG: {
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#DATE", 1, 1, "%s\n", "*date $time");	# Put the time of file generation at the top
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#ROOT", 1, 1, "%s\n", "*root $CSDDRD->[1]");	# Label with the record name (.HSE stripped)
				CHECK_CITY: foreach my $location (1..$#climate_ref) {	# cycle through the climate reference list to find a match
					if (($climate_ref[$location][0] =~ /$CSDDRD->[4]/) && ($climate_ref[$location][1] =~ /$CSDDRD->[3]/)) {	# find a matching climate name and province name
						&replace ($hse_file->[$record_extensions->{"cfg"}], "#LAT_LONG", 1, 1, "%s\n", "$climate_ref[$location][6] $climate_ref[$location][3] # $CSDDRD->[4],$CSDDRD->[3] -> $climate_ref[$location][4]");	# Use the weather station's lat (for esp-r beam purposes), use the site's long (it is correct, whereas CWEC is not), also in a comment show the CSDDRD weather site and compare to CWEC weather site.	
						&replace ($hse_file->[$record_extensions->{"cfg"}], "#CLIMATE", 1, 1, "%s\n", "*clm ../../../climate/$climate_ref[$location][4]");	# use the CWEC city weather name
						last CHECK_CITY;	# if climate city matched jump out of the loop
					}
					elsif ($location == $#climate_ref) {&error_message ("Bad climate comparison", $hse_type, $region, $CSDDRD->[1]);};	# if climate not found print an error
				};
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#SITE_RHO", 1, 1, "%s\n", "1 0.3");	# site exposure and ground reflectivity (rho)
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#AIM", 1, 1, "%s\n", "*aim ./$CSDDRD->[1].aim");	# aim path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#CTL", 1, 1, "%s\n", "*ctl ./$CSDDRD->[1].ctl");	# control path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#MVNT", 1, 1, "%s\n", "*mvnt ./$CSDDRD->[1].mvnt");	# central ventilation system path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#DHW", 1, 1, "%s\n", "*dhw ./$CSDDRD->[1].dhw");	# dhw path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#HVAC", 1, 1, "%s\n", "*hvac ./$CSDDRD->[1].hvac");	# hvac path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#PNT", 1, 1, "%s\n", "*pnt ./$CSDDRD->[1].elec");	# electrical network path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#BCD", 1, 1, "%s\n", "*bcd ../../../fcl/DHW_200_LpD_3600_s.bcd");	# boundary condition path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_PRESET_LINE1", 1, 1, "%s\n", "*sps 1 2 1 10 4 0");	# sim setup: no. data sets retained; startup days; zone_ts (step/hr); plant_ts (step/hr); ?save_lv @ each zone_ts; ?save_lv @ each zone_ts;
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_PRESET_LINE2", 1, 1, "%s\n", "1 1 10 1 sim_presets");	# simulation start day; start mo.; end day; end mo.; preset name
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_PRESET_LINE3", 1, 1, "%s\n", "*sblr $CSDDRD->[1].res");	# res file path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_PRESET_LINE4", 1, 1, "%s\n", "*selr $CSDDRD->[1].elr");	# electrical load results file path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#PROJ_LOG", 1, 2, "%s\n", "$CSDDRD->[1].log");	# log file path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#BLD_NAME", 1, 2, "%s\n", "$CSDDRD->[1]");	# name of the building
				my $zone_count = keys (%{$zone_indc});	# scalar of keys, equal to the number of zones
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#ZONE_COUNT", 1, 1, "%s\n", "$zone_count");	# number of zones
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#CONNECT", 1, 1, "%s\n", "*cnn ./$CSDDRD->[1].cnn");	# cnn path
				&replace ($hse_file->[$record_extensions->{"cfg"}], "#AIR", 1, 1, "%s\n", "0");	# air flow network path

				# SET THE ZONE PATHS 
				foreach my $zone (keys (%{$zone_indc})) {	# cycle through the zones
					&insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE$zone_indc->{$zone}", 1, 1, 0, "%s\n", "*zon $zone_indc->{$zone}");	# add the top line (*zon X) for the zone
					foreach my $ext (keys (%{$record_extensions})) {
						if ($ext =~ /$zone.(...)/) {
							&insert ($hse_file->[$record_extensions->{"cfg"}], "#END_ZONE$zone_indc->{$zone}", 1, 0, 0, "%s\n", "*$1 ./$CSDDRD->[1].$ext");
						};	# insert a path for each valid zone file with the proper name (note use of regex brackets and $1)
					};
					if ($zone eq "main") {&insert ($hse_file->[$record_extensions->{"cfg"}], "#END_ZONE$zone_indc->{$zone}", 1, 0, 0, "%s\n", "*isi ./$CSDDRD->[1].isi");};
					&insert ($hse_file->[$record_extensions->{"cfg"}], "#END_ZONE$zone_indc->{$zone}", 1, 0, 0, "%s\n", "*zend");	# provide the *zend at the end
				};
			};

			# -----------------------------------------------
			# Generate the *.aim file
			# -----------------------------------------------
			AIM: {
				my $Pa_ELA;
				if ($CSDDRD->[32] == 1) {$Pa_ELA = 10} elsif ($CSDDRD->[32] == 2) {$Pa_ELA = 4} else {die ("Bad Pa_ELA: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};	# set the ELA pressure
				if ($CSDDRD->[28] == 1) {	# Check air tightness type (1= blower door test)
					&replace ($hse_file->[$record_extensions->{"aim"}], "#BLOWER_DOOR", 1, 1, "%s\n", "1 $CSDDRD->[31] $Pa_ELA 1 $CSDDRD->[33]");	# Blower door test with ACH50 and ELA specified
				}
				else { &replace ($hse_file->[$record_extensions->{"aim"}], "#BLOWER_DOOR", 1, 1, "%s\n", "1 $CSDDRD->[31] $Pa_ELA 0 0");};	# Airtightness rating, use ACH50 only (as selected in HOT2XP)
				my $eave_height = $CSDDRD->[112] + $CSDDRD->[113] + $CSDDRD->[114] + $CSDDRD->[115];	# equal to main floor heights + wall height of basement above grade. DO NOT USE HEIGHT OF HIGHEST CEILING, it is strange
				if ($eave_height < 1) { &error_msg ("Eave < 1 m height", $coordinates)}	# minimum eave height in aim2_pretimestep.F
				elsif ($eave_height > 12) { &error_msg ("Eave > 12 m height", $coordinates)}	# maximum eave height in aim2_pretimestep.F, updated from 10 m to 12 m by LS (2008-10-06)
				&replace ($hse_file->[$record_extensions->{"aim"}], "#EAVE_HEIGHT", 1, 1, "%s\n", "$eave_height");	# set the eave height in meters

# PLACEHOLDER FOR MODIFICATION OF THE FLUE SIZE LINE. PRESENTLY AIM2_PRETIMESTEP.F USES HVAC FILE TO MODIFY FURNACE FLUE INPUTS FOR ON/OFF

				unless (defined ($zone_indc->{"bsmt"})) {
					&replace ($hse_file->[$record_extensions->{"aim"}], "#ZONE_INDICES", 1, 2, "%s\n", "1 1");	# only main recieves AIM calculated infiltration
				}
				else {
					&replace ($hse_file->[$record_extensions->{"aim"}], "#ZONE_INDICES", 1, 2, "%s\n", "2 1 2");	# main and basement recieve AIM calculated infiltration
				};

				my @zone_indc_and_crwl_ACH;	# declare array to store zone indicators and crawl space AC/h for AIM
				foreach my $zone ("bsmt", "crwl", "attc") {	# for each major zone
					if (defined ($zone_indc->{$zone})) { push (@zone_indc_and_crwl_ACH, $zone_indc->{$zone});}	# if the zone exist, push its number
					else { push (@zone_indc_and_crwl_ACH, 0);};	# if zone does not exist set equal to zero
				};
				if (defined ($zone_indc->{"crwl"})) {	# crawl requires specification of AC/h
					my $crwl_ach = 0;	# initialize scalar
					if ($record_indc->{"foundation"} == 8) {$crwl_ach = 0.5;}	# ventilated crawl
					elsif ($record_indc->{"foundation"} == 9) {$crwl_ach = 0.1;};	# closed crawl
					push (@zone_indc_and_crwl_ACH, $crwl_ach);	# push onto the array
				}
				else { push (@zone_indc_and_crwl_ACH, 0.0);};	# no crawl space
				&replace ($hse_file->[$record_extensions->{"aim"}], "#ZONE_INDICES", 1, 3, "%s %s %s %s\n", @zone_indc_and_crwl_ACH);	# print the zone indicators and crawl space AC/h for AIM 
			};


			# -----------------------------------------------
			# Generate the *.mvnt file
			# -----------------------------------------------
			MVNT: {
				if ($CSDDRD->[83] == 2 || $CSDDRD->[83] == 5) {	# HRV is present
					&replace ($hse_file->[$record_extensions->{"mvnt"}], "#CVS_SYSTEM", 1, 1, "%s\n", 2);	# list CSV as HRV
					&insert ($hse_file->[$record_extensions->{"mvnt"}], "#HRV_DATA", 1, 1, 0, "%s\n%s\n", "0 $CSDDRD->[86] 75", "-25 $CSDDRD->[87] 125");	# list efficiency and fan power (W) at cool (0C) and cold (-25C) temperatures
					&insert ($hse_file->[$record_extensions->{"mvnt"}], "#HRV_FLOW_RATE", 1, 1, 0, "%s\n", $CSDDRD->[84]);	# supply flow rate
					&insert ($hse_file->[$record_extensions->{"mvnt"}], "#HRV_COOL_DATA", 1, 1, 0, "%s\n", 25);	# cool efficiency
					&insert ($hse_file->[$record_extensions->{"mvnt"}], "#HRV_PRE_HEAT", 1, 1, 0, "%s\n", 0);	# preheat watts
					&insert ($hse_file->[$record_extensions->{"mvnt"}], "#HRV_TEMP_CTL", 1, 1, 0, "%s\n", "7 0 0");	# this is presently not used (7) but can make for controlled HRV by temp
					&insert ($hse_file->[$record_extensions->{"mvnt"}], "#HRV_DUCT", 1, 1, 0, "%s\n%s\n", "1 1 2 2 152 0.1", "1 1 2 2 152 0.1");	# use the typical duct values
				}
				elsif ($CSDDRD->[83] == 3) {	# fan only ventilation
					&replace ($hse_file->[$record_extensions->{"mvnt"}], "#CVS_SYSTEM", 1, 1, "%s\n", 3);	# list CSV as fan ventilation
					&insert ($hse_file->[$record_extensions->{"mvnt"}], "#VENT_FLOW_RATE", 1, 1, 0, "%s\n", "$CSDDRD->[84] $CSDDRD->[85] 75");	# supply and exhaust flow rate (L/s) and fan power (W)
					&insert ($hse_file->[$record_extensions->{"mvnt"}], "#VENT_TEMP_CTL", 1, 1, 0, "%s\n", "7 0 0");	# no temp control
				};
				if ($CSDDRD->[83] == 4 || $CSDDRD->[83] == 5) {	# exhaust fans exist
					&replace ($hse_file->[$record_extensions->{"mvnt"}], "#EXHAUST_TYPE", 1, 1,  "%s\n", 2);	# exhaust fans exist
					if ($CSDDRD->[83] == 5) {	# HRV + exhaust fans
						&insert ($hse_file->[$record_extensions->{"mvnt"}], "#EXHAUST_DATA", 1, 1, 0, "%s %s %.1f\n", 0, $CSDDRD->[85] - $CSDDRD->[84], 27.7 / 12 * ($CSDDRD->[85] - $CSDDRD->[84]));	# flowrate supply (L/s) = 0, flowrate exhaust = exhaust - supply due to HRV, total fan power (W)
					}
					else {	# exhaust fans only
						&insert ($hse_file->[$record_extensions->{"mvnt"}], "#EXHAUST_DATA", 1, 1, 0, "%s %s %.1f\n", 0, $CSDDRD->[85], 27.7 / 12 * $CSDDRD->[85]);	# flowrate supply (L/s) = 0, flowrate exhaust = exhaust , total fan power (W)
					};
				};
			};


			# -----------------------------------------------
			# Control file
			# -----------------------------------------------
			CTL: {
				my $heat_watts = $CSDDRD->[79] * 1000;	# multiply kW by 1000 for watts. this is based on HOT2XP's heating sizing protocol
				my $cool_watts = 0;	# initialize a cooling variable
				if (($CSDDRD->[88] >= 1) && ($CSDDRD->[88] <= 3)) { $cool_watts = 0.25 *$heat_watts;};	# if cooling is present size it to 25% of heating capacity
				&insert ($hse_file->[$record_extensions->{"ctl"}], "#NUM_FUNCTIONS", 1, 1, 0, "%s\n", 1);	# one control function
				&insert ($hse_file->[$record_extensions->{"ctl"}], "#SENSOR_DATA", 1, 1, 0, "%s\n", "0 0 0 0");	# sensor at air point of zone 1
				&insert ($hse_file->[$record_extensions->{"ctl"}], "#ACTUATOR_DATA", 1, 1, 0, "%s\n", "0 0 0");	# at zone air point
				&insert ($hse_file->[$record_extensions->{"ctl"}], "#NUM_YEAR_PERIODS", 1, 1, 0, "%s\n", 1);	# one period in year
				&insert ($hse_file->[$record_extensions->{"ctl"}], "#VALID_DAYS", 1, 1, 0, "%s\n", "1 365");	# Jan 1 through Dec 31, no leap year
				&insert ($hse_file->[$record_extensions->{"ctl"}], "#NUM_DAY_PERIODS", 1, 1, 0, "%s\n", 1);	# one day period
				&insert ($hse_file->[$record_extensions->{"ctl"}], "#CTL_TYPE", 1, 1, 0, "%s\n", "0 1 0");	# fixed heat/cool values upon setpoint
				&insert ($hse_file->[$record_extensions->{"ctl"}], "#NUM_DATA_ITEMS", 1, 1, 0, "%s\n", 7);	# four items
				&insert ($hse_file->[$record_extensions->{"ctl"}], "#DATA_LINE1", 1, 1, 0, "%s\n", "$heat_watts 0 $cool_watts 0 $CSDDRD->[69] $CSDDRD->[70] 0");	# heat_watts cool_watts heating_setpoint_C cooling_setpoint_C

				if (defined ($zone_indc->{"bsmt"})) { &insert ($hse_file->[$record_extensions->{"ctl"}], "#ZONE_LINKS", 1, 1, 0, "%s\n", "1,1,0");}	# link main and bsmt to control loop and attic has no control. Even if attc is not present the extra zero is not a problem.
				else { &insert ($hse_file->[$record_extensions->{"ctl"}], "#ZONE_LINKS", 1, 1, 0, "%s\n", "1,0,0");};	# no bsmt and crwl spc is not conditioned so zeros other than main
			};


			# -----------------------------------------------
			# Obstruction, Shading and Insolation file
			# -----------------------------------------------
			OBS_ISI: {
				my $obs = 0;	# replace this with logic to decide if obstruction is present
				unless ($obs) {	# there is no obstruction desired so uncomment it in the cfg file
					foreach my $line (@{$hse_file->[$record_extensions->{"cfg"}]}) {	# check each line of the cfg file
						if (($line =~ /^(\*obs.*)/) || ($line =~ /^(\*isi.*)/)) {	# if *obs or *isi tag is present then
							$line = "#$1\n";	# comment out the *obs or *isi tag
							# do not put a 'last' statement here b/c we have to comment both the obs and the isi
						};
					};
				};
			};


			# -----------------------------------------------
			# Appliance and Lighting file for Electrical Load Network
			# -----------------------------------------------
			AL: {
				&replace ($hse_file->[$record_extensions->{'elec'}], "#CFG_FILE", 1, 1, "  %s\n", "./$CSDDRD->[1].cfg");
				&replace ($hse_file->[$record_extensions->{'elec'}], "#MULTIPLIER", 1, 1, "  %s\n", "10");
				&replace ($hse_file->[$record_extensions->{'elec'}], "#FCL_FILE", 1, 1, "  %s\n", "../../../fcl/can_gen_med_y1.fcl");
			};


			# -----------------------------------------------
			# DHW file
			# -----------------------------------------------
			DHW: {
				if ($CSDDRD->[80] == 9) {	# DHW is not available, so comment the *dhw line in the cfg file
					foreach my $line (@{$hse_file->[$record_extensions->{"cfg"}]}) {	# read each line of cfg
						if ($line =~ /^(\*dhw.*)/) {	# if the *dhw tag is found then
							$line = "#$1\n";	# comment the *dhw tag
							last DHW;	# when found jump out of loop and DHW all together
						};
					};
				}
				else {	# DHW file exists and is used
					&replace ($hse_file->[$record_extensions->{"dhw"}], "#ANNUAL_LITRES", 1, 1, "%s\n", 65000.);	# annual litres of DHW
					if ($zone_indc->{"bsmt"}) {&replace ($hse_file->[$record_extensions->{"dhw"}], "#ZONE_WITH_TANK", 1, 1, "%s\n", 2);}	# tank is in bsmt zone
					else {&replace ($hse_file->[$record_extensions->{"dhw"}], "#ZONE_WITH_TANK", 1, 1, "%s\n", 2);};	# tank is in main zone

					my $energy_src = $dhw_energy_src->{'energy_type'}->[$CSDDRD->[80]];	# make ref to shorten the name
					&replace ($hse_file->[$record_extensions->{"dhw"}], "#ENERGY_SRC", 1, 1, "%s %s %s\n", $energy_src->{'ESP-r_dhw_num'}, "#", $energy_src->{'description'});	# cross ref the energy src type

					my $tank_type = $energy_src->{'tank_type'}->[$CSDDRD->[81]];	# make ref to shorten the tank type name
					&replace ($hse_file->[$record_extensions->{"dhw"}], "#TANK_TYPE", 1, 1, "%s %s %s\n", $tank_type->{'ESP-r_tank_num'}, "#", $tank_type->{'description'});	# cross ref the tank type

					&replace ($hse_file->[$record_extensions->{"dhw"}], "#TANK_EFF", 1, 1, "%s\n", $CSDDRD->[82]);	# tank efficiency

					&replace ($hse_file->[$record_extensions->{"dhw"}], "#ELEMENT_WATTS", 1, 1, "%s\n", $tank_type->{'Element_watts'});	# cross ref the element watts

					&replace ($hse_file->[$record_extensions->{"dhw"}], "#PILOT_WATTS", 1, 1, "%s\n", $tank_type->{'Pilot_watts'});	# cross ref the pilot watts
				};
			};


			# -----------------------------------------------
			# HVAC file
			# -----------------------------------------------
			HVAC: {
				my $energy_src = $hvac->{'energy_type'}->[$CSDDRD->[75]];	# make ref to shorten the name
				my $system = $energy_src->{'system_type'}->[$CSDDRD->[78]]->{'ESP-r_system_num'};
				my $equip = $energy_src->{'system_type'}->[$CSDDRD->[78]]->{'ESP-r_equip_num'};

				my $sys_count = 1;	# declare a scalar to count the hvac system types
				if ($system >= 7) {$sys_count++;};	# these are heat pump systems and have a backup (i.e. 2 heating systems)
				if ($CSDDRD->[88] < 4) {$sys_count++;};	# there is a cooling system installed
				
				&replace ($hse_file->[$record_extensions->{"hvac"}], "##HVAC_NUM_ALT", 1, 1, "%s\n", "$sys_count 0");	# number of systems and altitude (m)
				my @served_zones = (1, "1 1");
				if ($zone_indc->{"bsmt"}) {@served_zones = (2, "1 0.75 2 0.25");};

				# Fill out the primariy heating system type
				&replace ($hse_file->[$record_extensions->{"hvac"}], "#TYPE_PRIORITY_ZONES_1", 1, 1, "%s %s\n", "$system 1", $served_zones[0]);	# system #, priority, num of served zones

				if ($system <= 2) {
					my $draft_fan_W = 0;
					if ($equip == 8 || $equip == 10) {$draft_fan_W = 75;};
					my $pilot_W = 0;
					PILOT: foreach (7, 11, 14) {if ($equip == $_) {$pilot_W = 10; last PILOT;};};
					&insert ($hse_file->[$record_extensions->{"hvac"}], "#END_DATA_1", 1, 0, 0, "%s %s %s %s\n", "$equip $energy_src->{'ESP-r_energy_num'} $served_zones[1]", $CSDDRD->[79] * 1000, $CSDDRD->[77] / 100, "1 -1 $draft_fan_W $pilot_W 1")
				}
				elsif ($system == 3) {
					&insert ($hse_file->[$record_extensions->{"hvac"}], "#END_DATA_1", 1, 0, 0, "%s %s %s %s\n", "$served_zones[1]", $CSDDRD->[79] * 1000, $CSDDRD->[77] / 100, "0 0 0")
				};	
			};


			# -----------------------------------------------
			# Preliminary geo file generation
			# -----------------------------------------------
			# Window area per side ([156..159] is Window Area Front, Right, Back, Left)
			# Door1 ([137..141] Count, Type, Width (m), Height(m), RSI)
			# Door2 [142..146]
			# Basement door [147..151]
			my $window_area = [$CSDDRD->[156], $CSDDRD->[157], $CSDDRD->[158], $CSDDRD->[159]];	# declare an array equal to the total window area for each side
			my $door_width = [0, 0, 0, 0, 0, 0, 0];	# declare and intialize an array reference to hold the door WIDTHS for each side

			my $door_locate;	# declare hash reference to hold CSDDRD index location of doors
			%{$door_locate} = (137, 0, 142, 2, 147, 4);	# provide CSDDRD location and side location of doors. NOTE: bsmt doors are at elements [4,5]
			foreach my $index (keys(%{$door_locate})) {
				if ($CSDDRD->[$index] != 0) {
					if (($CSDDRD->[$index + 2] > 1.5) && ($CSDDRD->[$index + 3] < 1.5)) {	# check that door width/height entry wasn't reversed
						my $temp = $CSDDRD->[$index + 2];	# store door width
						$CSDDRD->[$index + 2] = $CSDDRD->[$index + 3];	# set door width equal to original door height
						$CSDDRD->[$index + 3] = $temp;	# set door height equal to original door width
						print GEN_SUMMARY "\tDoor\@[$index] width/height reversed: $coordinates\n";
					};
					$CSDDRD->[$index + 2] = &range ($CSDDRD->[$index + 2], 0.5, 2.5, "Door\@[$index] width", $coordinates);	# check door width range (m)
					$CSDDRD->[$index + 3] = &range ($CSDDRD->[$index + 3], 1.5, 3, "Door\@[$index] height", $coordinates);	# check door height range (m)
				};
				if ($CSDDRD->[$index] <= 2) {foreach my $door (1..$CSDDRD->[$index]) {$door_width->[$door_locate->{$index} + $door - 1] = $CSDDRD->[$index + 2];};}	# apply the door widths ($index+1) directly to consecutive sides
				else {foreach my $door (1..2) {$door_width->[$door_locate->{$index} + $door - 1] = sprintf("%.2f", $CSDDRD->[$index + 2] * $CSDDRD->[$index] / 2);};};	# increase the width of the doors to account for more than 2 doors
			};

			my $connections;	# array reference to hold all zones surface connections listing (5 items on each line)

			# DETERMINE WIDTH AND DEPTH OF ZONE (with limitations)
			my $w_d_ratio = 1; # declare and intialize a width to depth ratio (width is front of house) 
			if ($CSDDRD->[7] == 0) {$w_d_ratio = &range($CSDDRD->[8] / $CSDDRD->[9], 0.75, 1.33, "w_d_ratio", $coordinates);};	# If auditor input width/depth then check range NOTE: these values were chosen to meet the basesimp range and in an effort to promote enough size for windows and doors

			GEO: {
				foreach my $zone (sort { $zone_indc->{$a} <=> $zone_indc->{$b} } keys(%{$zone_indc})) {	# sort the keys by their value so main comes first
					my $vertex_index = 1;	# index counter
					my $surface_index = 1;	# index counter
					&replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#ZONE_NAME", 1, 1, "%s\n", "GEN $zone This file describes the $zone");	# set the time at the top of each zone geo file

					# DETERMINE EXTREMITY RECTANGULAR GEOMETRY (does not include windows/doors)
					my $x; my $y; my $z;	# declare the zone side lengths
					my $x1 = 0; my $y1 = 0, my $z1 = 0;	# declare and initialize the zone origin
					my $x2; my $y2; my $z2;	# declare the zone extremity

					# DETERMINE WIDTH AND DEPTH OF ZONE (with limitations)
					$x = sprintf("%.2f", ($CSDDRD->[100] ** 0.5) * $w_d_ratio);	# determine width of zone based upon main floor area
					$y = sprintf("%.2f", ($CSDDRD->[100] ** 0.5) / $w_d_ratio);	# determine depth of zone
					$x2 = $x1 + $x;	# set the extremity points
					$y2 = $y1 + $y;	# set the extremity points

					# DETERMINE HEIGHT OF ZONE
					if ($zone eq "main") { $z = $CSDDRD->[112] + $CSDDRD->[113] + $CSDDRD->[114]; $z1 = 0;}	# the main zone is height of three potential stories and originates at 0,0,0
					elsif ($zone eq "bsmt") { $z = $CSDDRD->[109]; $z1 = -$z;}	# basement or crwl space is offset by its height so that origin is below 0,0,0
					elsif ($zone eq "crwl") { $z = $CSDDRD->[110]; $z1 = -$z;}
					elsif ($zone eq "attc") { $z = &smallest($x, $y) / 2 * 5 / 12;  $z1 = $CSDDRD->[112] + $CSDDRD->[113] + $CSDDRD->[114];};	# attic is assumed to be 5/12 roofline with peak in parallel with long side of house. Attc is mounted to top corner of main above 0,0,0
					$z = sprintf("%.2f", $z);	# sig digits
					$z1 = sprintf("%.2f", $z1);	# sig digits
					$z2 = $z1 + $z;	# include the offet in the height to place vertices>1 at the appropriate location

					# ZONE VOLUME
					$record_indc->{"vol_$zone"} = sprintf("%.2f", $x * $y * $z);

					# DETERMINE EXTREMITY VERTICES (does not include windows/doors)
					my $vertices;	# declare an array reference for the vertices
					my @attc_slop_vert;
					push (@{$vertices},	# base vertices in CCW (looking down)
						"$x1 $y1 $z1 # v1", "$x2 $y1 $z1 # v2", "$x2 $y2 $z1 # v3", "$x1 $y2 $z1 # v4");	
					if ($zone ne "attc") {push (@{$vertices},	# second level of vertices for rectangular NOTE: Rework for main sloped ceiling
						"$x1 $y1 $z2 #v 5", "$x2 $y1 $z2 # v6", "$x2 $y2 $z2 # v7", "$x1 $y2 $z2 # v8");}	
					elsif (($CSDDRD->[18] == 2) || ($CSDDRD->[16] == 3)) {	# 5/12 attic shape OR Middle DR type house (hip not possible) with NOTE: slope facing the long side of house and gable ends facing the short side
						if (($w_d_ratio >= 1) || ($CSDDRD->[16] > 1)) {	# the front is the long side OR we have a DR type house, so peak in parallel with x
							my $peak_minus = $y1 + $y / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
							my $peak_plus = $y1 + $y / 2 + 0.05;
							push (@{$vertices},	# second level attc vertices
								"$x1 $peak_minus $z2 # v5", "$x2 $peak_minus $z2 # v6", "$x2 $peak_plus $z2 # v7", "$x1 $peak_plus $z2 # v8");
							@attc_slop_vert = ("SLOP", "VERT", "SLOP", "VERT");
						}
						else {	# otherwise the sides of the building are the long sides and thus the peak runs parallel to y
							my $peak_minus = $x1 + $x / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
							my $peak_plus = $x1 + $x / 2 + 0.05;
							push (@{$vertices},	# second level attc vertices
								"$peak_minus $y1 $z2 # v5", "$peak_plus $y1 $z2 # v6", "$peak_plus $y2 $z2 # v7", "$peak_minus $y2 $z2 # v8");
							@attc_slop_vert = ("VERT", "SLOP", "VERT", "SLOP");
						}
					}
					elsif ($CSDDRD->[18] == 3) {	# Hip roof
						my $peak_y_minus;
						my $peak_y_plus;
						my $peak_x_minus;
						my $peak_x_plus;
						if ($CSDDRD->[16] == 1) {	# SD type house, so place hips but leave a ridge in the middle (i.e. 4 sloped roof sides)
							if ($w_d_ratio >= 1) {	# ridge runs from side to side
								$peak_y_minus = $y1 + $y / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_y_plus = $y1 + $y / 2 + 0.05;
								$peak_x_minus = $x1 + $x / 3; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_x_plus = $x1 + $x * 2 / 3;
							}
							else {	# the depth is larger then the width
								$peak_y_minus = $y1 + $y / 3; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_y_plus = $y1 + $y * 2 / 3;
								$peak_x_minus = $x1 + $x / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_x_plus = $x1 + $x / 2 + 0.05;
							};
							@attc_slop_vert = ("SLOP", "SLOP", "SLOP", "SLOP");
						}
						else {	# DR type house
							if ($CSDDRD->[16] == 2) {	# left end house type
								$peak_y_minus = $y1 + $y / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_y_plus = $y1 + $y / 2 + 0.05;
								$peak_x_minus = $x1 + $x / 3; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_x_plus = $x2;
								@attc_slop_vert = ("SLOP", "VERT", "SLOP", "SLOP");
							}
							elsif ($CSDDRD->[16] == 4) {	# right end house
								$peak_y_minus = $y1 + $y / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_y_plus = $y1 + $y / 2 + 0.05;
								$peak_x_minus = $x1; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_x_plus = $x1 + $x * 2 / 3;
								@attc_slop_vert = ("SLOP", "SLOP", "SLOP", "VERT");
							};
						};
						push (@{$vertices},	# second level attc vertices
							"$peak_x_minus $peak_y_minus $z2 # v5", "$peak_x_plus $peak_y_minus $z2 # v6", "$peak_x_plus $peak_y_plus $z2 # v7", "$peak_x_minus $peak_y_plus $z2 # v8");
					};

					# CREATE THE EXTREMITY SURFACES (does not include windows/doors)
					my $surfaces;	# array reference to hold surface vertex listings
					push (@{$surfaces},	# create the floor and ceiling surfaces for all zone types (CCW from outside view)
						"4 1 4 3 2 # surf1 - floor", "4 5 6 7 8 # surf2 - ceiling");

					# DECLARE CONNECTIONS AND SURFACE ATTRIBUTES ARRAY REFERENCES FOR EXTREMITY SURFACES (does not include windows/doors)
					my $surf_attributes;	# for individual zones
					my $constructions;	# for individual zones

					# DETERMINE THE SURFACES, CONNECTIONS, AND SURFACE ATTRIBUTES FOR EACH ZONE (does not include windows/doors)
					if ($zone eq "attc") {	# build the floor, ceiling, and sides surfaces and attributes for the attc
						# FLOOR AND CEILING
						my $con = "R_MAIN_ceil";
						push (@{$constructions}, [$con, $CSDDRD->[20], $CSDDRD->[19]]);	# floor type
						push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "ANOTHER"]); # floor faces the main
						push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 1 2 # $zone floor");	# floor face (3) zone main (1) surface (2)
						$surface_index++;
						$con = "ATTC_slop";
						push (@{$constructions}, [$con, 1, 1]);	# ceiling type NOTE: somewhat arbitrarily set RSI = 1 and type = 1
						push (@{$surf_attributes}, [$surface_index, "Ceiling", $con_name->{$con}{'type'}, "CEIL", $con, "EXTERIOR"]); # ceiling faces exterior
						push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone ceiling");	# ceiling faces exterior (0)
						$surface_index++;
						# SIDES
						push (@{$surfaces},	# create surfaces for the sides from the vertex numbers
							"4 1 2 6 5 # surf3 - front side", "4 2 3 7 6 # surf4 - right side", "4 3 4 8 7 # surf5 - back side", "4 4 1 5 8 # surf6 - left side");
						# assign surface attributes for attc : note sloped sides (SLOP) versus gable ends (VERT)
						foreach my $side (@attc_slop_vert) {
							if ($side =~ /SLOP/) {$con = "ATTC_slop";}
							elsif ($side =~ /VERT/) {$con = "ATTC_gbl";};
							push (@{$constructions}, [$con, 1, 1]);	# side type NOTE: somewhat arbitrarily set RSI = 1 and type = 1
							push (@{$surf_attributes}, [$surface_index, "Side", $con_name->{$con}{'type'}, $side, $con, "EXTERIOR"]); # sides face exterior
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $side");	# add to cnn file
							$surface_index++;
						};
					}
					elsif ($zone eq "bsmt") {	# build the floor, ceiling, and sides surfaces and attributes for the bsmt
						# FLOOR AND CEILING
						my $con = "BSMT_flor";
						push (@{$constructions}, [$con, &largest($CSDDRD->[40], $CSDDRD->[42]), $CSDDRD->[39]]);	# floor type
						push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "BASESIMP"]); # floor faces the ground
						push (@{$connections}, "$zone_indc->{$zone} $surface_index 6 1 20 # $zone floor");	# floor is basesimp (6) NOTE insul type (1) loss distribution % (20)
						$surface_index++;
						$con = "MAIN_BSMT";
						push (@{$constructions}, [$con, 1, 1]);	# ceiling type NOTE: somewhat arbitrarily set RSI = 1 and type = 1
						push (@{$surf_attributes}, [$surface_index, "Ceiling", $con_name->{$con}{'type'}, "CEIL", $con, "ANOTHER"]); # ceiling faces main
						push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 1 1 # $zone ceiling");	# ceiling faces main (1)
						$surface_index++;
						# SIDES
						push (@{$surfaces},	# create surfaces for the sides from the vertex numbers
							"4 1 2 6 5 # surf3 - front side", "4 2 3 7 6 # surf4 - right side", "4 3 4 8 7 # surf5 - back side", "4 4 1 5 8 # surf6 - left side");
						foreach my $side ("front", "right", "back", "left") {
							$con = "BSMT_wall";
							push (@{$constructions}, [$con, &largest($CSDDRD->[40], $CSDDRD->[42]), $CSDDRD->[39]]);	# side type
							push (@{$surf_attributes}, [$surface_index, "Side-$side", $con_name->{$con}{'type'}, "VERT", $con, "BASESIMP"]); # sides face ground
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 6 1 20 # $zone $side side");	# add to cnn file
							$surface_index++;
						};

						# BASESIMP
						my $height_basesimp = &range($z, 1, 2.5, "height_basesimp", $coordinates);	# check crwl height for range
						&replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#HEIGHT", 1, 1, "%s\n", "$height_basesimp");	# set height (total)
						my $depth = &range($z - $CSDDRD->[115], 0.65, 2.4, "basesimp grade depth", $coordinates);	# difference between total height and above grade, used below for insul placement as well
						if ($record_indc->{"foundation"} >= 3) {$depth = &range(($z - 0.3) / 2, 0.65, 2.4, "basesimp walkout depth", $coordinates)};	# walkout basement, attribute 0.3 m above grade and divide remaining by 2 to find equivalent height below grade
						&replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#DEPTH", 1, 1, "%s\n", "$depth");

						foreach my $sides (&largest ($y, $x), &smallest ($y, $x)) {&insert ($hse_file->[$record_extensions->{"$zone.bsm"}], "#END_LENGTH_WIDTH", 1, 0, 0, "%s\n", "$sides");};

						if (($CSDDRD->[41] == 4) && ($CSDDRD->[38] > 1)) {	# insulation placed on exterior below grade and on interior
							if ($CSDDRD->[38] == 2) { &replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#OVERLAP", 1, 1, "%s\n", "$depth")}	# full interior so overlap is equal to depth
							elsif ($CSDDRD->[38] == 3) { my $overlap = $depth - 0.2; &replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#OVERLAP", 1, 1, "%s\n", "$overlap")}	# partial interior to within 0.2 m of slab
							elsif ($CSDDRD->[38] == 4) { &replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#OVERLAP", 1, 1, "%s\n", "0.6")}	# partial interior to 0.6 m below grade
							else { die ("Bad basement insul overlap: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};
						};

						my $insul_RSI = &range(&largest($CSDDRD->[40], $CSDDRD->[42]), 0, 9, "basesimp insul_RSI", $coordinates);	# set the insul value to the larger of interior/exterior insulation of basement
						&replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#RSI", 1, 1, "%s\n", "$insul_RSI")

					}
					elsif ($zone eq "crwl") {	# build the floor, ceiling, and sides surfaces and attributes for the crwl
						# FLOOR AND CEILING
						my $con = "CRWL_flor";
						push (@{$constructions}, [$con, $CSDDRD->[56], $CSDDRD->[55]]);	# floor type
						push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "BASESIMP"]); # floor faces the ground
						push (@{$connections}, "$zone_indc->{$zone} $surface_index 6 28 100 # $zone floor");	# floor is basesimp (6) NOTE insul type (28) loss distribution % (100)
						$surface_index++;
						$con = "R_MAIN_CRWL";
						push (@{$constructions}, [$con, $CSDDRD->[58], $CSDDRD->[57]]);	# ceiling type
						push (@{$surf_attributes}, [$surface_index, "Ceiling", $con_name->{$con}{'type'}, "CEIL", $con, "ANOTHER"]); # ceiling faces main
						push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 1 1 # $zone ceiling");	# ceiling faces main (1)
						$surface_index++;
						# SIDES
						push (@{$surfaces},	# create surfaces for the sides from the vertex numbers
							"4 1 2 6 5 #surf3 - front side", "4 2 3 7 6 # surf4 - right side", "4 3 4 8 7 # surf5 - back side", "4 4 1 5 8 # surf6 - left side");
						foreach my $side ("front", "right", "back", "left") {
							$con = "CRWL_wall";
							push (@{$constructions}, [$con, $CSDDRD->[51], $CSDDRD->[50]]);	# side type
							push (@{$surf_attributes}, [$surface_index, "Side-$side", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $side side");	# add to cnn file
							$surface_index++;
						};	
						# BASESIMP
						my $height_basesimp = &range($z, 1, 2.5, "height_basesimp", $coordinates);	# check crwl height for range
						&replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#HEIGHT", 1, 1, "%s\n", "$height_basesimp");	# set height (total)
						&replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#DEPTH", 1, 1, "%s\n", "0.05");	# consider a slab as heat transfer through walls will be dealt with later as they are above grade

						foreach my $sides (&largest ($y, $x), &smallest ($y, $x)) {&insert ($hse_file->[$record_extensions->{"$zone.bsm"}], "#END_LENGTH_WIDTH", 1, 0, 0, "%s\n", "$sides");};

						my $insul_RSI = &range($CSDDRD->[56], 0, 9, "basesimp insul_RSI", $coordinates);	# set the insul value to that of the crwl space slab
						&replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#RSI", 1, 1, "%s\n", "$insul_RSI")
					}
					elsif ($zone eq "main") {	# build the floor, ceiling, and sides surfaces and attributes for the main
						my $con;
						# FLOOR AND CEILING
						if (defined ($zone_indc->{"bsmt"}) || defined ($zone_indc->{"crwl"})) {	# foundation zone exists
							if (defined ($zone_indc->{"bsmt"})) {$con = "MAIN_BSMT"; push (@{$constructions}, [$con, 1, 1]);}	# floor type NOTE: somewhat arbitrarily set RSI = 1 and type = 1
							else {$con = "MAIN_CRWL"; push (@{$constructions}, [$con, $CSDDRD->[58], $CSDDRD->[57]]);};
							push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "ANOTHER"]); # floor faces the foundation ceiling
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 2 2 # $zone floor");	# floor faces (3) foundation zone (2) ceiling (2)
							$surface_index++;
						}
						elsif ($record_indc->{"foundation"} == 10) {	# slab on grade
							$con = "BSMT_flor";
							push (@{$constructions}, [$con, $CSDDRD->[63], $CSDDRD->[62]]);	# floor type
							push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "BASESIMP"]); # floor faces the ground
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 6 28 100 # $zone floor");	# floor is basesimp (6) NOTE insul type (28) loss distribution % (100)
							$surface_index++;
						}
						else {	# exposed floor
							$con = "MAIN_CRWL";
							push (@{$constructions}, [$con, $CSDDRD->[63], $CSDDRD->[62]]);	# floor type
							push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "EXTERIOR"]); # floor faces the ambient
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone floor");	# floor is exposed to ambient
							$surface_index++;
						};
						if (defined ($zone_indc->{"attc"})) {	# attc exists
							$con = "MAIN_ceil";
							push (@{$constructions}, [$con, $CSDDRD->[20], $CSDDRD->[19]]);	# ceiling type
							push (@{$surf_attributes}, [$surface_index, "Ceiling", $con_name->{$con}{'type'}, "CEIL", $con, "ANOTHER"]); # ceiling faces attc
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 $zone_indc->{'attc'} 1 # $zone ceiling");	# ceiling faces attc (1)
							$surface_index++;
						}
						else {	# attc does not exist
							$con = "MAIN_roof";
							push (@{$constructions}, [$con, $CSDDRD->[20], $CSDDRD->[19]]);	# ceiling type NOTE: Flat ceiling only. Rework when implementing main sloped ceiling
							push (@{$surf_attributes}, [$surface_index, "Ceiling", $con_name->{$con}{'type'}, "CEIL", $con, "EXTERIOR"]); # ceiling faces exterior
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone ceiling");	# ceiling faces exterior
							$surface_index++;
						};
						# SIDES
						my @side_names = ("front", "right", "back", "left");	# names of the sides
						my $side_surface_vertices = [[4, 1, 2, 6, 5], [4, 2, 3, 7, 6], [4, 3, 4, 8, 7], [4, 4, 1, 5, 8]];	# surface vertex numbers in absence of windows and doors
						my @side_width = ($x, $y, $x, $y);	# a temporary variable to compare side lengths with window and door width
						my @window_side_start = (162, 233, 304, 375);	# the element indices of the CSDDRD data of the first windows data per side. This will be used in logic to determine the most prevalent window type per side.
						foreach my $side (0..3) {	# loop over each side of the house
							if ($window_area->[$side] || $door_width->[$side]) {	# a window or door exists
								my $window_height = sprintf("%.2f", $window_area->[$side] ** 0.5);	# assume a square window
								my $window_width = $window_height;	# assume a square window
								if ($window_height >= ($z - 0.4)) {	# compare window height to zone height. Offset is 0.2 m at top and bottom (total 0.4 m)
									$window_height = $z - 0.4;	# readjust  window height to fit
									$window_width = sprintf("%.2f", $window_area->[$side] / $window_height);	# recalculate window width
								};
								my $window_center = $side_width[$side] / 2;	# assume window is centrally placed along wall length
								if (($window_width / 2 + $door_width->[$side] + 0.4) > ($side_width[$side] / 2)) {	# check to see that the window and a door will fit on the side. Note that the door is placed to the right side of window with 0.2 m gap between and 0.2 m gap to wall end
									if (($window_width + $door_width->[$side] + 0.6) > ($side_width[$side])) {	# window cannot be placed centrally, but see if they will fit at all, with 0.2 m gap from window to wall beginning
										&error_msg ("Window + Door width too great on $side_names[$side]", $coordinates);	# window and door will not fit
									}
									else {	# window cannot be central but will fit with door
										$window_center = sprintf("%.2f",($side_width[$side] - $door_width->[$side] - 0.4) / 2);	# readjust window location to facilitate the door and correct gap spacing between window/door/wall end
									};
								};

								if ($window_area->[$side]) {	# window is true for the side so insert it into the wall (vetices, surfaces, surf attb)
									my $window_vertices;	# declare array ref to hold window vertices
									# windows for each side have different vertices (x, y, z) and no simple algorithm exists, so have explicity geometry statement for each side. Vertices are in CCW position, starting from lower left.
									if ($side == 0) {	# front
										# back and forth across window center, all at y = 0, and centered on zone height
										push (@{$window_vertices}, [$x1 + $window_center - $window_width / 2, $y1, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x1 + $window_center + $window_width / 2, $y1, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x1 + $window_center + $window_width / 2, $y1, $z1 + $z / 2 + $window_height / 2]);
										push (@{$window_vertices}, [$x1 + $window_center - $window_width / 2, $y1, $z1 + $z / 2 + $window_height / 2]);
									}
									elsif ($side == 1) {
										push (@{$window_vertices}, [$x2, $y1 + $window_center - $window_width / 2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x2, $y1 + $window_center + $window_width / 2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x2, $y1 + $window_center + $window_width / 2, $z1 + $z / 2 + $window_height / 2]);
										push (@{$window_vertices}, [$x2, $y1 + $window_center - $window_width / 2, $z1 + $z / 2 + $window_height / 2]);
									}
									elsif ($side == 2) {
										push (@{$window_vertices}, [$x2 - $window_center + $window_width / 2, $y2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x2 - $window_center - $window_width / 2, $y2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x2 - $window_center - $window_width / 2, $y2, $z1 + $z / 2 + $window_height / 2]);
										push (@{$window_vertices}, [$x2 - $window_center + $window_width / 2, $y2, $z1 + $z / 2 + $window_height / 2]);
									}
									elsif ($side == 3) {
										push (@{$window_vertices}, [$x1, $y2 - $window_center + $window_width / 2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x1, $y2 - $window_center - $window_width / 2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x1, $y2 - $window_center - $window_width / 2, $z1 + $z / 2 + $window_height / 2]);
										push (@{$window_vertices}, [$x1, $y2 - $window_center + $window_width / 2, $z1 + $z / 2 + $window_height / 2]);
									};
									foreach my $vertex (0..$#{$window_vertices}) {	# push the vertex information onto the actual array with a side and window comment
										push (@{$vertices}, "@{$window_vertices->[$vertex]} # $side_names[$side] window v$vertex");
									};
									push (@{$side_surface_vertices->[$side]}, $side_surface_vertices->[$side][1], $#{$vertices} - 2);	# push the return vertex of the wall onto its array, then add the first corner vertex of the window
									my @window_surface_vertices = (4);	# declare an array to hold the vertex numbers of the window, initialize with "4" as there will be four vertices to follow in the description
									foreach my $vertex (0..3) {
										push (@{$side_surface_vertices->[$side]}, $#{$vertices} + 1 - $vertex);	# push the window vertices onto the wall surface vertex list in CW order to create an enclosed surface. Return to the first window vertex and stop (final side vertex is implied)
										push (@window_surface_vertices, $#{$vertices} -2 + $vertex);	# push the window vertices onto the window surface vertex list in CCW order
									};
									push (@{$surfaces},"@window_surface_vertices # $side_names[$side] window");	# push the window surface array onto the actual surface array

									# store then number of windows of each type for the side. this will be used to select the most apropriate window code for each side of the house. Note that we do not have the correct areas of individual windows, so the assessment of window code will be based on the largest number of windows of the type
									my $win_code_count;	# hash array to store the number of windows of each code type (key = code, value = count)
									foreach my $win_index (0..9) {	# iterate through the 10 windows specified for each side
										if ($CSDDRD->[$window_side_start[$side] + $win_index * 7 + 1] > 0) {	# check that window duplicates (e.g. 1) exist for that window index
											unless (defined ($win_code_count->{$CSDDRD->[$window_side_start[$side] + $win_index * 7 + 6]})) {	# if this type has not been encountered then initialize the hash key at the window code equal to zerro
												$win_code_count->{$CSDDRD->[$window_side_start[$side] + $win_index * 7 + 6]} = 0;
											};
											# add then number of window duplicates to the the present number for that window type
											$win_code_count->{$CSDDRD->[$window_side_start[$side] + $win_index * 7 + 6]} = $win_code_count->{$CSDDRD->[$window_side_start[$side] + $win_index * 7 + 6]} + $CSDDRD->[$window_side_start[$side] + $win_index * 7 + 1];
										};
									};

									# determine the window code that is most frequent for the side
									my @win_code_side = (0, 0);	# initialize an array (window code, number of windows)
									foreach my $code (keys (%{$win_code_count})) {	# iterate through the different window codes
										if ($win_code_count->{$code} > $win_code_side[1]) {	# if more windows of a certain code are present then set this as the 'favourite' window code for that particular side
											$win_code_side[0] = $code;
											$win_code_side[1] = $win_code_count->{$code};
										};
									};

									my @win_dig = split (//, $win_code_side[0]);	# split the favourite side window code by digits
									$con = "WNDW_$win_dig[0]$win_dig[1]$win_dig[2]"; # use the first three digits to construct the window construction name in ESP-r
									push (@{$constructions}, [$con, 1.5, $CSDDRD->[160]]);	# side type, RSI, code
									push (@{$surf_attributes}, [$surface_index, "$side_names[$side]-Wndw", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior 
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $side_names[$side] window");	# add to cnn file
									$surface_index++;
								};

								if ($door_width->[$side]) {	# door is true for the side so insert it into the wall (vetices, surfaces, surf attb)
									# this logic follows similar to the windows above and is therefore not commented so much
									my $door_vertices;
									if ($side == 0) {
										# door is 0.2 m from the side end and starts 0.2 m above the zone floor. Door is 2 m tall.
										push (@{$door_vertices}, [$x2 - 0.2 - $door_width->[$side], $y1, 0.2]);
										push (@{$door_vertices}, [$x2 - 0.2, $y1, 0.2]);
										push (@{$door_vertices}, [$x2 - 0.2, $y1, 0.2 + 2]);
										push (@{$door_vertices}, [$x2 - 0.2 - $door_width->[$side], $y1, 0.2 + 2]);
									}
									elsif ($side == 1) {
										push (@{$door_vertices}, [$x2, $y2 - 0.2 - $door_width->[$side], 0.2]);
										push (@{$door_vertices}, [$x2, $y2 - 0.2, 0.2]);
										push (@{$door_vertices}, [$x2, $y2 - 0.2, 0.2 + 2]);
										push (@{$door_vertices}, [$x2, $y2 - 0.2 - $door_width->[$side], 0.2 + 2]);
									}
									elsif ($side == 2) {
										push (@{$door_vertices}, [$x1 + 0.2 + $door_width->[$side], $y2, 0.2]);
										push (@{$door_vertices}, [$x1 + 0.2, $y2, 0.2]);
										push (@{$door_vertices}, [$x1 + 0.2, $y2, 0.2 + 2]);
										push (@{$door_vertices}, [$x1 + 0.2 + $door_width->[$side], $y2, 0.2 + 2]);
									}
									elsif ($side == 3) {
										push (@{$door_vertices}, [$x1, $y1 + 0.2 + $door_width->[$side], 0.2]);
										push (@{$door_vertices}, [$x1, $y1 + 0.2, 0.2]);
										push (@{$door_vertices}, [$x1, $y1 + 0.2, 0.2 + 2]);
										push (@{$door_vertices}, [$x1, $y1 + 0.2 + $door_width->[$side], 0.2 + 2]);
									};
									foreach my $vertex (0..$#{$door_vertices}) {
										push (@{$vertices}, "@{$door_vertices->[$vertex]} # $side_names[$side] door v$vertex");
									};
									push (@{$side_surface_vertices->[$side]}, $side_surface_vertices->[$side][1], $#{$vertices} - 2);
									my @door_surface_vertices = (4);
									foreach my $vertex (0..3) {
										push (@{$side_surface_vertices->[$side]}, $#{$vertices} + 1 - $vertex);
										push (@door_surface_vertices, $#{$vertices} -2 + $vertex);
									};
									push (@{$surfaces},"@door_surface_vertices # $side_names[$side] door");
									# check the side number to apply the appropriate type, RSI, etc. as there are two types of doors (main zone) listed in the CSDDRD
									if ($side == 0 || $side == 1) {
										$con = "DOOR_wood";
										push (@{$constructions}, [$con, $CSDDRD->[141], $CSDDRD->[138]]);	# side type, RSI, code
									}
									elsif ($side == 2 || $side == 3) {
										$con = "DOOR_wood";
										push (@{$constructions}, [$con, $CSDDRD->[146], $CSDDRD->[143]]);	# side type, RSI, code
									};
									push (@{$surf_attributes}, [$surface_index, "$side_names[$side]-Door", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior 
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $side_names[$side] door");	# add to cnn file
									$surface_index++;
								};

								$side_surface_vertices->[$side][0] = $#{$side_surface_vertices->[$side]};	# reset the count of vertices in the side surface to be representative of any additions due to windows and doors (an addition of 6 for each item)
								push (@{$surfaces},"@{$side_surface_vertices->[$side]} # $side_names[$side] side");	# push the side surface onto the actual surfaces array
								$con = "MAIN_wall";
								push (@{$constructions}, [$con, $CSDDRD->[25], $CSDDRD->[24]]);	# side type
								push (@{$surf_attributes}, [$surface_index, "$side_names[$side]-Side", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior 
								push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $side_names[$side] side");	# add to cnn file
								$surface_index++;

							}
							else {	# no windows or doors on this side so simply push out the appropriate information for the side
								push (@{$surfaces}, "@{$side_surface_vertices->[$side]} # $side_names[$side] side");
								$con = "MAIN_wall";
								push (@{$constructions}, [$con, $CSDDRD->[25], $CSDDRD->[24]]);	# side type
								push (@{$surf_attributes}, [$surface_index, "$side_names[$side]-Side", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior 
								push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $side_names[$side] side");	# add to cnn file
								$surface_index++;
							};
						};

							# BASESIMP FOR A SLAB
							if ($record_indc->{"foundation"} == 10) {
							my $height_basesimp = &range($z, 1, 2.5, "height_basesimp", $coordinates);	# check crwl height for range
							&replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#HEIGHT", 1, 1, "%s\n", "$height_basesimp");	# set height (total)
							&replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#DEPTH", 1, 1, "%s\n", "0.05");	# consider a slab as heat transfer through walls will be dealt with later as they are above grade

							foreach my $sides (&largest ($y, $x), &smallest ($y, $x)) {&insert ($hse_file->[$record_extensions->{"$zone.bsm"}], "#END_LENGTH_WIDTH", 1, 0, 0, "%s\n", "$sides");};

							my $insul_RSI = &range($CSDDRD->[63], 0, 9, "basesimp insul_RSI", $coordinates);	# set the insul value to that of the crwl space slab
							&replace ($hse_file->[$record_extensions->{"$zone.bsm"}], "#RSI", 1, 1, "%s\n", "$insul_RSI")
						};
					};

					&replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#BASE", 1, 1, "%s\n", "1 0 0 0 0 0 $CSDDRD->[100]");	# last line in GEO file which lists FLOR surfaces (total elements must equal 6) and floor area (m^2)
					my $rotation = ($CSDDRD->[17] - 1) * 45;	# degrees rotation (CCW looking down) from south
					my @vert_surf = ($#{$vertices} + 1, $#{$surfaces} + 1);
					&replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VER_SUR_ROT", 1, 1, "%s\n", "@vert_surf $rotation");
					$vertex_index--;	# decrement count as it is indexed one ahead of total number
					$surface_index--;
					my @zero_array;
					foreach my $zero (1..$surface_index) {push (@zero_array, 0)};
					&replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#UNUSED_INDEX", 1, 1, "%s\n", "@zero_array");
					&replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_INDENTATION", 1, 1, "%s\n", "@zero_array");

					foreach my $vertex (@{$vertices}) {&insert ($hse_file->[$record_extensions->{"$zone.geo"}], "#END_VERTICES", 1, 0, 0, "%s\n", "$vertex");};
					foreach my $surface (@{$surfaces}) {&insert ($hse_file->[$record_extensions->{"$zone.geo"}], "#END_SURFACES", 1, 0, 0, "%s\n", "$surface");};
					foreach my $surf_attribute (@{$surf_attributes}) {&insert ($hse_file->[$record_extensions->{"$zone.geo"}], "#END_SURFACE_ATTRIBUTES", 1, 0, 0, "%3s, %-13s %-5s %-5s %-12s %-15s\n", @{$surf_attribute});};

					my @tmc_type;	# initialize arrays to hold data for a string to print on one line
					my $tmc_flag = 0;
					my @em_inside;
					my @em_outside;
					my @slr_abs_inside;
					my @slr_abs_outside;
					foreach my $construction (@{$constructions}) {
						my $con = $construction->[0];
						my $gaps = 0;	# holds a count of the number of gaps
						my @pos_rsi;	# holds the position of the gaps and RSI
						foreach my $layer_num (0..$#{$con_name->{$con}{'layer'}}) {
							my $layer = $con_name->{$con}{'layer'}->[$layer_num];
							my $mat = $layer->{'mat_name'};
							if ($mat eq 'Gap') {
								$gaps++;
								push (@pos_rsi, $layer_num + 1, $layer->{'gap_RSI'}->[0]->{'vert'});	# FIX THIS LATER SO THE RSI IS LINKED TO THE POSITION (VERT, HORIZ, SLOPE)
								&insert ($hse_file->[$record_extensions->{"$zone.con"}], "#END_PROPERTIES", 1, 0, 0, "%s %s %s\n", "0 0 0", $layer->{'thickness_mm'} / 1000, "0 0 0 0");	# add the surface layer information
							}
							elsif ($mat eq 'Fbrglas_Batt') {	# modify the thickness if we know it is insulation batt NOTE this precuses using the real construction development
								my $thickness_m = $construction->[1] * $mat_name->{$mat}->{'conductivity_W_mK'};	# thickness equal to RSI * k
								&insert ($hse_file->[$record_extensions->{"$zone.con"}], "#END_PROPERTIES", 1, 0, 0, "%s %5.3f %s \t%s\n", "$mat_name->{$mat}->{'conductivity_W_mK'} $mat_name->{$mat}->{'density_kg_m3'} $mat_name->{$mat}->{'spec_heat_J_kgK'}", $thickness_m, "0 0 0 0", "#\t$layer->{'thickness_mm'}");	# add the surface layer information
							}
							else { &insert ($hse_file->[$record_extensions->{"$zone.con"}], "#END_PROPERTIES", 1, 0, 0, "%s %s %s\n", "$mat_name->{$mat}->{'conductivity_W_mK'} $mat_name->{$mat}->{'density_kg_m3'} $mat_name->{$mat}->{'spec_heat_J_kgK'}", $layer->{'thickness_mm'} / 1000, "0 0 0 0");};	# add the surface layer information
						};

						my $layer_count = @{$con_name->{$con}{'layer'}};
						&insert ($hse_file->[$record_extensions->{"$zone.con"}], "#END_LAYERS_GAPS", 1, 0, 0, "%s\n", "$layer_count $gaps # $con");

						if ($con_name->{$con}{'type'} eq "OPAQ") { push (@tmc_type, 0);}
						elsif ($con_name->{$con}{'type'} eq "TRAN") {
							push (@tmc_type, $con_name->{$con}{'optic_name'});
							$tmc_flag = 1;
						};
						if (@pos_rsi) {
							&insert ($hse_file->[$record_extensions->{"$zone.con"}], "#END_GAP_POS_AND_RSI", 1, 0, 0, "%s\n", "@pos_rsi");
						};

						push (@em_inside, $mat_name->{$con_name->{$con}{'layer'}->[$#{$con_name->{$con}{'layer'}}]->{'mat_name'}}->{'emissivity_in'});
						push (@em_outside, $mat_name->{$con_name->{$con}{'layer'}->[0]->{'mat_name'}}->{'emissivity_out'});
						push (@slr_abs_inside, $mat_name->{$con_name->{$con}{'layer'}->[$#{$con_name->{$con}{'layer'}}]->{'mat_name'}}->{'absorptivity_in'});
						push (@slr_abs_outside, $mat_name->{$con_name->{$con}{'layer'}->[0]->{'mat_name'}}->{'absorptivity_out'});
					};

					&insert ($hse_file->[$record_extensions->{"$zone.con"}], "#EM_INSIDE", 1, 1, 0, "%s\n", "@em_inside");	# write out the emm/abs of the surfaces for each zone
					&insert ($hse_file->[$record_extensions->{"$zone.con"}], "#EM_OUTSIDE", 1, 1, 0, "%s\n", "@em_outside");
					&insert ($hse_file->[$record_extensions->{"$zone.con"}], "#SLR_ABS_INSIDE", 1, 1, 0, "%s\n", "@slr_abs_inside");
					&insert ($hse_file->[$record_extensions->{"$zone.con"}], "#SLR_ABS_OUTSIDE", 1, 1, 0, "%s\n", "@slr_abs_outside");

					if ($tmc_flag) {
						&replace ($hse_file->[$record_extensions->{"$zone.tmc"}], "#SURFACE_COUNT", 1, 1, "%s", $#tmc_type + 1);
						my %optic_lib = (0, 0);
						foreach my $element (0..$#tmc_type) {
							my $optic = $tmc_type[$element];
							unless (defined ($optic_lib{$optic})) {
								$optic_lib{$optic} = keys (%optic_lib);
								my $layers = @{$optic_data->{$optic}->[0]->{'layer'}};
								&insert ($hse_file->[$record_extensions->{"$zone.tmc"}], "#END_TMC_DATA", 1, 0, 0, "%s\n", "$layers $optic");
								&insert ($hse_file->[$record_extensions->{"$zone.tmc"}], "#END_TMC_DATA", 1, 0, 0, "%s\n", "$optic_data->{$optic}->[0]->{'optic_con_props'}->[0]->{'trans_solar'} $optic_data->{$optic}->[0]->{'optic_con_props'}->[0]->{'trans_vis'}");
								foreach my $layer (0..$#{$optic_data->{$optic}->[0]->{'layer'}}) {
									&insert ($hse_file->[$record_extensions->{"$zone.tmc"}], "#END_TMC_DATA", 1, 0, 0, "%s\n", "$optic_data->{$optic}->[0]->{'layer'}->[$layer]->{'absorption'}");
								};
								&insert ($hse_file->[$record_extensions->{"$zone.tmc"}], "#END_TMC_DATA", 1, 0, 0, "%s\n", "0");	# optical control flag
							};
							$tmc_type[$element] = $optic_lib{$optic};	# change from optics name to the appearance number in the tmc file
						};
						&replace ($hse_file->[$record_extensions->{"$zone.tmc"}], "#TMC_INDEX", 1, 1, "%s\n", "@tmc_type");	# print the key that links each surface to an optic (by number)
					};
				};
			};	

			my $cnn_count = $#{$connections} + 1;
			&replace ($hse_file->[$record_extensions->{"cnn"}], "#CNN_COUNT", 1, 1, "%s\n", "$cnn_count");
			foreach my $connection (@{$connections}) {&insert ($hse_file->[$record_extensions->{"cnn"}], "#END_CONNECTIONS", 1, 0, 0, "%s\n", "$connection");};


			# -----------------------------------------------
			# Operations files
			# -----------------------------------------------
			OPR: {
				foreach my $zone (keys (%{$zone_indc})) { 
					&replace ($hse_file->[$record_extensions->{"$zone.opr"}], "#DATE", 1, 1, "%s\n", "*date $time");	# set the time/date for the main.opr file
					# if no other zones exist then do not modify the main.opr (its only use is for ventilation with the bsmt due to the aim and fcl files
					if ($zone eq "bsmt") {
						foreach my $days ("WEEKDAY", "SATURDAY", "SUNDAY") {	# do for each day type
							&replace ($hse_file->[$record_extensions->{"bsmt.opr"}], "#END_AIR_$days", 1, -1, "%s\n", "0 24 0 0.5 1 0");	# add 0.5 ACH ventilation to basement from main. Note they are different volumes so this is based on the basement zone.
							&replace ($hse_file->[$record_extensions->{"main.opr"}], "#END_AIR_$days", 1, -1, "%s %.2f %s\n", "0 24 0", 0.5 * $record_indc->{"vol_bsmt"} / $record_indc->{"vol_main"}, "2 0");	# add ACH ventilation to main from basement. In this line the differences in volume are accounted for
						};
					};
				};
			};


			# -----------------------------------------------
			# Print out each esp-r house file for the house record
			# -----------------------------------------------
			FILE_PRINTOUT: {
				foreach my $ext (keys %{$record_extensions}) {	# go through each extention inclusive of the zones for this particular record
					open (FILE, '>', "$output_path/$CSDDRD->[1].$ext") or die ("can't open datafile: $output_path/$CSDDRD->[1].$ext");	# open a file on the hard drive in the directory tree
					foreach my $line (@{$hse_file->[$record_extensions->{$ext}]}) {print FILE "$line";};	# loop through each element of the array (i.e. line of the final file) and print each line out
					close FILE;
				};
				copy ("../templates/input.xml", "$output_path/input.xml") or die ("can't copy file: input.xml");	# add an input.xml file to the house for XML reporting of results
			};

			$models_OK++;
		};	# end of the while loop through the CSDDRD->
	return ([$models_attempted, $models_OK]);
	};	# end of main code
};

# -----------------------------------------------
# Subroutines
# -----------------------------------------------
SUBROUTINES: {
	sub zone_file_create() {	# subroutine to add and appropriately name another copy of a template file to support multiple zones (i.e. main.geo, bsmt.geo) and then notes it in the cross reference hash
		my $zone = shift (@_);	# the zone title
		my $ext = shift (@_);	# the extension title
		my $hse_file = shift (@_);	# array of house esp-r files to add too
		my $record_extensions = shift (@_);	# array of house extentions to add too for the zone and extension
		push (@{$hse_file},[@{$hse_file->[$record_extensions->{$ext}]}]);	# copy the template file to the new location
		$record_extensions->{"$zone.$ext"} = $#{$hse_file};	# use the hash to record the zone's file and extension and cross reference its location in the array
	};


	sub replace () {	# subroutine to perform a simple element replace (house file to read/write, keyword to identify row, rows below keyword to replace, replacement text)
		my $hse_file = shift (@_);	# the house file to read/write
		my $find = shift (@_);	# the word to identify
		my $location = shift (@_);	# where to identify the word: 1=start of line, 2=anywhere within the line, 3=end of line
		my $beyond = shift (@_);	# rows below the identified word to operate on
		my $format = shift (@_);	# format of the replacement text for the operated element
		CHECK_LINES: foreach my $line (0..$#{$hse_file}) {	# pass through the array holding each line of the house file
			if ((($location == 1) && ($hse_file->[$line] =~ /^$find/)) || (($location == 2) && ($hse_file->[$line] =~ /$find/)) || (($location == 3) && ($hse_file->[$line] =~ /$find$/))) {	# search for the identification word at the appropriate position in the line
				$hse_file->[$line+$beyond] = sprintf ($format, @_);	# replace the element that is $beyond that where the identification word was found
				last CHECK_LINES;	# If matched, then jump out to save time and additional matching
			};
		};
	};

	sub insert () {	# subroutine to perform a simple element insert after (specified) the identified element (house file to read/write, keyword to identify row, number of elements after to do insert, replacement text)
		my $hse_file = shift (@_);	# the house file to read/write
		my $find = shift (@_);	# the word to identify
		my $location = shift (@_);	# 1=start of line, 2=anywhere within the line, 3=end of line
		my $beyond = shift (@_);	# rows below the identified word to remove from and insert too
		my $remove = shift (@_);	# rows to remove
		my $format = shift (@_);	# format of the replacement text for the operated element
		CHECK_LINES: foreach my $line (0..$#{$hse_file}) {	# pass through the array holding each line of the house file
			if ((($location == 1) && ($hse_file->[$line] =~ /^$find/)) || (($location == 2) && ($hse_file->[$line] =~ /$find/)) || (($location == 3) && ($hse_file->[$line] =~ /$find$/))) {	# search for the identification word at the appropriate position in the line
				splice (@{$hse_file}, $line + $beyond, $remove, sprintf ($format, @_));	# replace the element that is $beyond that where the identification word was found
				last CHECK_LINES;	# If matched, then jump out to save time and additional matching
			};
		};
	};

	sub error_msg () {	# subroutine to perform a simple element insert after (specified) the identified element (house file to read/write, keyword to identify row, number of elements after to do insert, replacement text)
		my $msg = shift (@_);	# the error message to print
		my $coordinates = shift (@_);	# the house type, region, record number
		print GEN_SUMMARY "MODEL ERROR $msg: $coordinates\n";
		next RECORD;
	};

	sub range () {	# subroutine to perform a range check and modify as required to fit the range
		my $value = shift (@_);	# the original value
		my $min = shift (@_);	# the range minimum
		my $max = shift (@_);	# the range maximum
		my $msg = shift (@_);	# the error message to print
		my $coordinates = shift (@_);	# the house type, region, record number
		if ($value < $min) {
			$value = $min;
			print GEN_SUMMARY "\tRange MIN: $msg: $coordinates\n";
		}
		elsif ($value > $max) {
			$value = $max;
			print GEN_SUMMARY "\tRange MAX: $msg: $coordinates\n";
		};
		return ($value)
	};

	sub largest () {	# subroutine to find the largest value of the provided list
		my $value = $_[0];	# placeholder for the value
		foreach my $test (@_) {if ($test > $value) {$value = $test;};};
		return ($value)
	};

	sub smallest () {	# subroutine to find the smallest value of the provided list
		my $value = $_[0];	# placeholder for the value
		foreach my $test (@_) {if ($test < $value) {$value = $test;};};
		return ($value)
	};

	sub database_XML() {
		# DESCRIPTION:
		# This subroutine generates the esp-r database files to facilitate opening 
		# CSDDRD houses within prj. This script reads the material and 
		# composite construction XML databases and generates the appropriate 
		# ASCII columnar delimited format files required by ESP-r.

		my $mat_data;	# declare repository for mat_db.xml readin
		my $con_data;	# declare repository for con_db.xml readin
# 		my $optic_data;	# declare repository for optic_db.xml readin

		MATERIALS: {
			$mat_data = XMLin("../databases/mat_db.xml", ForceArray => 1);	# readin the XML data, note that any hash with properties will recieve an array index even if there is only one of that hash
			open (MAT_DB_XML, '>', "../databases/mat_db_regen.xml") or die ("can't open  ../databases/mat_db_regen.xml");	# open a writeout file
			print MAT_DB_XML XMLout($mat_data);	# printout the XML data
			close MAT_DB_XML;

			NEW_FORMAT: {	# the tagged format version 1.1
				open (MAT_DB, '>', "../databases/mat_db_xml_1.1.a") or die ("can't open  ../databases/mat_db_xml_1.1.a");	# open a writeout file
				open (MAT_LIST, '>', "../databases/mat_db_xml_list") or die ("can't open  ../databases/mat_db_xml_list");	# open a list file that will simply list the materials for use as a reference when making composite constructions

				print MAT_DB "*Materials 1.1\n";	# print the head tag line
 				my $time = localtime();	# determine the time
				printf MAT_DB ("%s,%s\n", "*date", $time);	# print the time
				print MAT_DB "*doc,Materials database (tagged format) constructed from mat_db.xml by DB_Gen.pl\n#\n";	# print the documentation tag line

				printf MAT_DB ("%d%s", $#{$mat_data->{'class'}}," # total number of classes\n#\n");	# print the number of classes

				# specification of file format
				printf MAT_DB ("%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n",
					"# Material classes are listed as follows:",
					"#	*class, 'class number'(2 digits),'number of materials in class','class name'",
					"#	'class description",
					"#",
					"# Materials within each class are listed as follows:",
					"#	*item,'material name','material number'(20 * 'class number' + 'material position within class'; 3 digits),'class number'(2 digits),'material description'",
					"# The material tag is followed by the following material attributes:",
					"#	conductivity (W/(m-K), density (kg/m**3), specific heat (J/(kg-K),",
					"#	emissivity out (-), emissivity in (-), absorptivity out, (-) absorptivity in (-),",
					"#	diffusion resistance (?), default thickness (mm),",
					"#	flag [-] legacy [o] opaque [t] transparent [g] gas data+T cor [h] gas data at 4T",
					"#",
					"#	transparent material include additional attributes:",
					"#		longwave tran (-), solar direct tran (-), solar reflec out (-), solar refled in (-),",
					"#		visable tran (-), visable reflec out (-), visable reflec in (-), colour rendering (-)"
				);

				print MAT_LIST "Materials database constructed from material_db.xml by DB_Gen.pl\n\n";

				foreach my $class_num (0..$#{$mat_data->{'class'}}) {	# iterate over each class
					my $class = $mat_data->{'class'}->[$class_num];	# simplify the class reference to a simple scalar for use

					if ($class->{'class_name'} eq 'gap') {$class->{'class_name'} = 'Gap';};
					print MAT_LIST "\n$class->{'class_name'} : $class->{'description'}\n";	# print the class name and description to the list

					unless ($class->{'class_name'} eq 'Gap') {	# do not print out for Gap
						print MAT_DB "#\n#\n# CLASS\n";	# print a common identifier

						printf MAT_DB ("%s,%2d,%2d,%s\n",	# print the class information
							"*class",	# class tag
							$class_num,	# class number
							$#{$class->{'material'}} + 1,	# number of materials in the class
							"$class->{'class_name'}"	# class name
						);
						print MAT_DB "$class->{'description'}\n";	# print the class description
	
						print MAT_DB "#\n# MATERIALS\n";	# print a common identifier
					};

					foreach my $mat_num (0..$#{$class->{'material'}}) {	# iterate over each material within the class
						my $mat = $class->{'material'}->[$mat_num];
						$mat_name->{$mat->{'mat_name'}} = $mat;	# set mat_name equal to a reference to the material
						if ($class->{'class_name'} eq 'Gap') {$mat->{'mat_num'} = 0;}	# material is Gap so set equal to mat_num 0
						else {$mat->{'mat_num'} = ($class_num - 1) * 20 + $mat_num + 1;};	# add a key in the material equal to the ESP-r material number

						print MAT_LIST "\t$mat->{'mat_name'} : $mat->{'description'}\n";	# material name and description

						unless ($class->{'class_name'} eq 'Gap') {	# do not print out for Gap
							printf MAT_DB ("%s,%s,%3d,%2d,%s",	# print the material title line
								"*item",	# material tag
								"$mat->{'mat_name'}",	# material name
								$mat->{'mat_num'},	# material number (groups of 20)
								$class_num,
								"$mat->{'description'}\n"	# material description
							);

							# print the first part of the material data line
							foreach my $property ('conductivity_W_mK', 'density_kg_m3', 'spec_heat_J_kgK', 'emissivity_out', 'emissivity_in', 'absorptivity_out', 'absorptivity_in', 'vapor_resist') {
								printf MAT_DB ("%.3f,", $mat->{$property});
							};
							printf MAT_DB ("%.1f", $mat->{'default_thickness_mm'});	# this property has a different format but is on the same line
	
							if ($mat->{'type'} eq "OPAQ") {print MAT_DB ",o\n";} # opaque material so print last digit of line
							elsif ($mat->{'type'} eq "TRAN") {	# translucent material so print t and additional data
								print MAT_DB ",t,";	# print TRAN identifier
								# print the translucent properties
								foreach my $property ('trans_long', 'trans_solar', 'trans_vis', 'refl_solar_out', 'refl_solar_in', 'refl_vis_out', 'refl_vis_in') {
									printf MAT_DB ("%.3f,", $mat->{'optic_mat_props'}->[0]->{$property});
								};
								printf MAT_DB ("%.3f\n", $mat->{'optic_mat_props'}->[0]->{'clr_render'});	# print the last part of translucent properties line
							};
						};
					};
				};
				print MAT_DB "*end\n";	# print the end tag
				close MAT_DB;
				close MAT_LIST;
			};
		};


		OPTICS: {
			$optic_data = XMLin("../databases/optic_db.xml", ForceArray => 1);	# readin the XML data, note that any hash with properties will recieve an array index even if there is only one of that hash
			open (OPTIC_DB_XML, '>', "../databases/optics_db_regen.xml") or die ("can't open  ../databases/optics_db_regen.xml");	# open a writeout file
			print OPTIC_DB_XML XMLout($optic_data);	# printout the XML data
			close OPTIC_DB_XML;

			open (OPTIC_DB, '>', "../databases/optic_db_xml.a") or die ("can't open  ../databases/optic_db_xml.a");	# open a writeout file for the optics database
			open (OPTIC_LIST, '>', "../databases/optic_db_xml_list") or die ("can't open  ../databases/optic_db_xml_list");	# open a list file that will simply list the optic name and description 

			# provide the header lines and instructions to the optics database
			print OPTIC_DB "# optics database (columnar format) constructed from con_db.xml by DB_Gen.pl based on mat_db.xml\n#\n";

			# print the file format
			foreach my $statement (
				"# optical properties db for default windows and most of the information",
				"# required to automatically build transparent constructions & tmc files.",
				"#",
				"# 1st line of each item is column sensitive and holds:",
				"# an identifier (12 char) followed by a description",
				"# 2nd line holds:",
				"# a) the number of default (always 1?) and tmc layers (equal to construction)",
				"# b) visable trans ",
				"# c) solar reflectance (outside)",
				"# d) overall solar absorbed",
				"# e) U value (for reporting purposes only)",
				"# 3rd line holds:",
				"# a) direct solar tran at 0deg 40deg 55deg 70deg 80deg from normal",
				"# b) total heat gain at the same angles (for reporting purposes only)",
				"# then for each layer there is a line containing",
				"# a) refractive index",
				"# b) solar absorption at 0deg 40deg 55deg 70deg 80deg from normal",
				"#",
				"#"
				) {printf OPTIC_DB ("%s\n", $statement);
				};

			my @optics = sort {$a cmp $b} keys (%{$optic_data});	# sort optic types to order the printout


			foreach my $optic (@optics) {

				my $opt = $optic_data->{$optic}->[0];	# shorten the name for subsequent use

				# fill out the optics database (TMC)
				printf OPTIC_DB ("%-14s%s\n",
					$optic,	# print the optics name
					": $opt->{'description'}"	# print the optics description
				);

				printf OPTIC_LIST ("%-14s%s\n",
					$optic,	# print the optics name
					": $opt->{'description'}"	# print the optics description
				);

				print OPTIC_DB "# $opt->{'optic_con_props'}->[0]->{'optical_description'}\n";	# print additional optical description

				# print the one time optical information
				printf OPTIC_DB ("%s%4d%7.3f%7.3f%7.3f%7.3f\n",
					"  1",
					$#{$opt->{'layer'}} + 1,
					$opt->{'optic_con_props'}->[0]->{'trans_vis'},
					$opt->{'optic_con_props'}->[0]->{'refl_solar_doc_only'},
					$opt->{'optic_con_props'}->[0]->{'abs_solar_doc_only'},
					$opt->{'optic_con_props'}->[0]->{'U_val_W_m2K_doc_only'}
				);

				# print the transmission and heat gain values at different angles for the construction type
				printf OPTIC_DB ("  %s %s\n",
					$opt->{'optic_con_props'}->[0]->{'trans_solar'},
					$opt->{'optic_con_props'}->[0]->{'heat_gain_doc_only'}
				);

				print OPTIC_DB "# layers\n";	# print a common identifier
				# print the refractive index and abs values at different angles for each layer of the transluscent construction type
				foreach my $layer (@{$opt->{'layer'}}) {	# iterate over construction layers
					printf OPTIC_DB ("  %4.3f %s\n",
						$layer->{'refr_index'},
						$layer->{'absorption'}
					);
				};
			};

			close OPTIC_DB;
			close OPTIC_LIST;
		};

		CONSTRUCTIONS: {
			$con_data = XMLin("../databases/con_db.xml", ForceArray => 1);	# readin the XML data, note that any hash with properties will recieve an array index even if there is only one of that hash
			open (CON_DB_XML, '>', "../databases/con_db_regen.xml") or die ("can't open  ../databases/con_db_regen.xml");	# open a writeout file
			print CON_DB_XML XMLout($con_data);	# printout the XML data
			close CON_DB_XML;

			open (CON_DB, '>', "../databases/con_db_xml.a") or die ("can't open  ../databases/con_db_xml.a");	# open a writeout file for the constructions
			open (CON_LIST, '>', "../databases/con_db_xml_list") or die ("can't open  ../databases/con_db_xml_list");	# open a list file that will simply list the materials 

			print CON_DB "# composite constructions database (columnar format) constructed from con_db.xml by DB_Gen.pl based on mat_db.xml\n#\n";	# heading intro line
			print CON_LIST "# composite constructions database (columnar format) constructed from con_db.xml by DB_Gen.pl based on mat_db.xml\n#\n";	# heading intro line

			printf CON_DB ("%5d%s\n", $#{$con_data->{'construction'}} + 1," # total number of constructions\n#");	# print the number of constructions

			printf CON_DB ("%s\n%s\n%s\n",	# format instructions for the construction database
				"# for each construction list the: # of layers, construction name, type (OPAQ or TRAN), Optics name (or OPAQUE), symmetry.",
				"#\t followed by for each material of the construction:",
				"#\t\t material number, thickness (m), material name, and if 'Gap' then RSI at vert horiz and sloped"
			);

			foreach my $con (@{$con_data->{'construction'}}) {	# iterate over each construction
				print CON_DB "#\n#\n# CONSTRUCTION\n";	# print a common identifier

				print CON_LIST "\n$con->{'con_name'} : $con->{'type'} : $con->{'symmetry'} : $con->{'description'}\n";	# print the construction name and description to the list

				printf CON_DB ("%5d    %-14s%-6s", 	# print the construction information
					$#{$con->{'layer'}} + 1,	# number of layers in the construction
					$con->{'con_name'},	# construction name
					$con->{'type'}	# type of construction (OPAQ or TRAN)
				);
				$con_name->{$con->{'con_name'}} = $con;

				if ($con->{'type'} eq "OPAQ") {printf CON_DB ("%-14s", "OPAQUE");}	# opaque so no line to optics database
				elsif ($con->{'type'} eq "TRAN") {printf CON_DB ("%-14s", $con->{'optic_name'});};	# transluscent construction so link to the optics database


				printf CON_DB ("%-14s\n", $con->{'symmetry'});	# print symetrical or not

				print CON_DB "# $con->{'description'}\n";	# print the construction description
				print CON_DB "#\n# MATERIALS\n";	# print a common identifier

				foreach my $layer (@{$con->{'layer'}}) {	# iterate over construction layers
					# check if the material is Gap
					if ($layer->{'mat_name'} eq 'gap') {	# check spelling of Gap and fix if necessary
						$layer->{'mat_name'} = "Gap";
					};

					printf CON_DB ("%5d%10.4f",	# print the layers number and name
						$mat_name->{$layer->{'mat_name'}}->{'mat_num'},	# material number
						$layer->{'thickness_mm'} / 1000	# material thickness in (m)
					);

					if ($layer->{'mat_name'} eq 'Gap') {	# it is Gap based on material number zero
						# print the RSI properties of Gap for the three positions that the construction may be placed in
						printf CON_DB ("%s%4.3f %4.3f %4.3f\n",
							"  Gap  ",
							$layer->{'gap_RSI'}->[0]->{'vert'},
							$layer->{'gap_RSI'}->[0]->{'horiz'},
							$layer->{'gap_RSI'}->[0]->{'slope'}
						);
					}
					else {	# not Gap so simply report the name and descriptions
						print CON_DB "  $layer->{'mat_name'} : $mat_name->{$layer->{'mat_name'}}->{'description'}\n";	# material name and description from the list
					};

					print CON_LIST "\t$layer->{'mat_name'} : $layer->{'thickness_mm'} (mm) : $mat_name->{$layer->{'mat_name'}}->{'description'}\n";	# material name and description
				};
			};
			close CON_DB;
			close CON_LIST;
		};

	};

	sub keys_XML() {
		# DESCRIPTION:
		# This subroutine reads in cross referencing key information for CSDDRD to ESP-r

		# readin the XML data, note that any hash with properties will recieve an array index even if there is only one of that hash
		$dhw_energy_src = XMLin("../keys/dhw_key.xml", ForceArray => 1);	# readin the DHW cross ref
		$hvac = XMLin("../keys/hvac_key.xml", ForceArray => 1);	# readin the HVAC cross ref

	};
};