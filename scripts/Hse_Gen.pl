#!/usr/bin/perl

# ====================================================================
# Hse_Gen.pl
# Author: Lukas Swan
# Date: Apl 2009
# Copyright: Dalhousie University

# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all] [simulation timestep in minutes]

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

use CHREM_modules::General ('hse_types_and_regions', 'one_data_line', 'largest', 'smallest', 'check_range', 'set_issue', 'print_issues');
use CHREM_modules::Cross_ref ('cross_ref_readin', 'key_XML_readin');
use CHREM_modules::Database ('database_XML');

# --------------------------------------------------------------------
# Declare the global variables
# --------------------------------------------------------------------

my $hse_types;	# declare an hash array to store the house types to be modeled (e.g. 1 -> 1-SD)
my $regions;	# declare an hash array to store the regions to be modeled (e.g. 1 -> 1-AT)

my $time_step;	# declare a scalar to hold the timestep in minutes


# --------------------------------------------------------------------
# Read the command line input arguments
# --------------------------------------------------------------------

COMMAND_LINE: {
	if ($ARGV[0] eq "db") {database_XML(); exit;};	# construct the databases and leave the information loaded in the variables for use in house generation

	if ($#ARGV != 2) {die "Three arguments are required: house_types regions simulation_time-step_(minutes); or \"db\" for database generation\n";};	# check for proper argument count

	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
	($hse_types, $regions) = hse_types_and_regions(@ARGV[0..1]);
	
	if ($ARGV[2] < 1 || $ARGV[2] > 60) {die "Simulation time-step must be equal to or between 1 and 60 minutes\n";}
	else {$time_step = $ARGV[2];};
};

# -----------------------------------------------
# Develop the ESP-r databases and cross reference keys
# -----------------------------------------------
(my $mat_name, my $con_name, my $optic_data) = database_XML();
# &database_XML();	# construct the databases and leave the information loaded in the variables for use in house generation

# -----------------------------------------------
# Develop the HVAC and DHW cross reference keys
# -----------------------------------------------
# Readin the hvac xml information as it indicates furnace fan and boiler pump variables
my $hvac = key_XML_readin('../keys/hvac_key.xml', [1]);	# readin the HVAC cross ref

# Readin the dhw xml information to cross ref the system efficiency used for the NN
my $dhw_energy_src = key_XML_readin('../keys/dhw_key.xml', [1]);	# readin the DHW cross ref



# -----------------------------------------------
# Read in the CWEC weather data crosslisting
# -----------------------------------------------
my $climate_ref = cross_ref_readin('../climate/Weather_HOT2XP_to_CWEC.csv');	# create an climate reference crosslisting hash


# -----------------------------------------------
# Read in the DHW and AL annual energy consumption CSDDRD listing
# -----------------------------------------------	
my $dhw_al = cross_ref_readin('../CSDDRD/CSDDRD_DHW_AL_annual.csv');	# create an DHW and AL reference crosslisting hash


# -----------------------------------------------
# Read in the annual consumption information of the DHW and AL annual energy consumption profile from the BCD files
# -----------------------------------------------	
my @BCD_dhw_al_ann_files = <../bcd/ANNUAL_$ARGV[2]*>;	# only find cross referencing files that have the correct time-step in minutes

# check that there are not two different cross references for the same timestep (i.e. they came from different source timesteps though)
if ($#BCD_dhw_al_ann_files > 0) {
	# two solutions exist, so report and die
	die "bcd data can come from multiple time-step sources (minutes): delete one 'ANNUAL' from the ../bcd folder"; 
}

my $BCD_dhw_al_ann = cross_ref_readin($BCD_dhw_al_ann_files[0]);	# create an DHW and AL annual consumption reference crosslisting hash


# -----------------------------------------------
# Declare important variables for file generation
# -----------------------------------------------
# The template extentions that will be used in file generation (alphabetical order)
my $bld_extensions = ['aim', 'cfg', 'cnn', 'ctl', 'dhw', 'elec', 'hvac', 'log', 'mvnt'];	# extentions that are building based (not per zone)
my $zone_extensions = ['bsm', 'con', 'geo', 'obs', 'opr', 'tmc'];	# extentions that are used for individual zones

# -----------------------------------------------
# Read in the templates
# -----------------------------------------------
my $template;	# declare a hash reference to hold the original templates for use with the generation house files for each record

# Open and read the template files
foreach my $ext (@{$bld_extensions}, @{$zone_extensions}) {	# do for each filename extention
	my $file = "../templates/template.$ext";
	# note that the file handle below is a variable so that it simply goes out of scope
	open (my $TEMPLATE, '<', $file) or die ("can't open template: $file");	# open the template
	$template->{$ext} = [<$TEMPLATE>];	# Slurp the entire file with one line per array element
}



my $issues;

# --------------------------------------------------------------------
# Initiate multi-threading to run each region simulataneously
# --------------------------------------------------------------------

MULTI_THREAD: {
	print "Multi-threading for each House Type and Region : please be patient\n";
	
	my $thread;	# Declare threads for each type and region
	my $thread_return;	# Declare a return array for collation of returning thread data
	
	foreach my $hse_type (values (%{$hse_types})) {	# Multithread for each house type
		foreach my $region (values (%{$regions})) {	# Multithread for each region
			# Add the particular hse_type and region to the pass hash ref
			my $pass = {'hse_type' => $hse_type, 'region' => $region};
			$thread->{$hse_type}->{$region} = threads->new(\&main, $pass);	# Spawn the threads and send to main subroutine
		};
	};
	my $input_path = '../CSDDRD/CSDDRD_DHW_AL_BCD_MULT';
	open (BCD_FILE_MULT, '>', "$input_path.csv") or die ("can't open datafile: $input_path.csv");
	print BCD_FILE_MULT CSVjoin ('House', 'hse_type', 'region', 'DHW filename', 'DHW multiplier', 'Dryer filename', 'Dryer multiplier', 'Stove-Other filename', 'Stove-Other multiplier') . "\n";
	
	foreach my $hse_type (sort {$a cmp $b} values (%{$hse_types})) {	# return for each house type
		foreach my $region (sort {$a cmp $b} values (%{$regions})) {	# return for each region type
			$thread_return->{$hse_type}->{$region} = $thread->{$hse_type}->{$region}->join();	# Return the threads together for info collation
			
# 			print Dumper $thread_return;
			foreach my $issue_key (keys (%{$thread_return->{$hse_type}->{$region}->{'issues'}})) {
				my $issue = $thread_return->{$hse_type}->{$region}->{'issues'}->{$issue_key};
				foreach my $problem (keys (%{$issue})) {
					$issues->{$issue_key}->{$problem}->{$hse_type}->{$region} = $issue->{$problem}->{$hse_type}->{$region};
				};
			};
			
			foreach my $house_key (sort {$a cmp $b} keys (%{$thread_return->{$hse_type}->{$region}->{'BCD_characteristics'}})) {
				my $house = $thread_return->{$hse_type}->{$region}->{'BCD_characteristics'}->{$house_key};
				my @line = ($house_key, @{$house}{'hse_type', 'region'});
				foreach my $field ('DHW_LpY', 'AL-Dryer_GJpY', 'AL-Stove-Other_GJpY') {
					push (@line, $house->{$field}->{'filename'}, $house->{$field}->{'multiplier'});
				};
				print BCD_FILE_MULT CSVjoin (@line) . "\n";
			};
# 			print Dumper $thread_return->{$hse_type}->{$region}->{'BCD_characteristics'};
		};
	};

	close BCD_FILE_MULT;

# 	my $attempt_total = 0;
# 	my $success_total = 0;
# 	
# 	foreach my $hse_type (sort {$a cmp $b} values (%{$hse_types})) {	# for each house type
# 		foreach my $region (sort {$a cmp $b} values (%{$regions})) {	# for each region
# 			my $attempt = $thread_return->{$hse_type}->{$region}[0];
# 			$attempt_total = $attempt_total + $attempt;
# 			my $success = $thread_return->{$hse_type}->{$region}[1];
# 			$success_total = $success_total + $success;
# 			my $failed = $thread_return->{$hse_type}->{$region}[0] - $thread_return->{$hse_type}->{$region}[1];
# 			my $success_ratio = $success / $attempt * 100;
# # 			printf GEN_SUMMARY ("%s %4.1f\n", "$hse_types->{$hse_type} $regions->{$region}: Attempted $attempt; Successful $success; Failed $failed; Success Ratio (%)", $success_ratio);
# 		};
# 	};
# 	
# 	my $failed = $attempt_total - $success_total;
# 	my $success_ratio = $success_total / $attempt_total * 100;
# # 	printf GEN_SUMMARY ("%s %4.1f\n", "Total: Attempted $attempt_total; Successful $success_total; Failed $failed; Success Ratio (%)", $success_ratio);

	mkpath ("../summary_files");	# make a path to place files that summarize the script results

	# print out the issues encountered during this script
	print_issues('../summary_files/Hse_Gen.txt', $issues);

	print "PLEASE CHECK THE Hse_Gen.txt FILE IN THE ../summary_files DIRECTORY FOR ERROR LISTING\n";	# tell user to go look
};

# --------------------------------------------------------------------
# Main code that each thread evaluates
# --------------------------------------------------------------------

MAIN: {
	sub main () {
		my $pass = shift;	# the hash reference that contains all of the information

		my $hse_type = $pass->{'hse_type'};	# house type number for the thread
		my $region = $pass->{'region'};	# region number for the thread

		my $models_attempted;	# incrementer of each encountered CSDDRD record
		my $models_OK;	# incrementer of records that are OK


		# -----------------------------------------------
		# Open the CSDDRD source
		# -----------------------------------------------
		# Open the data source files from the CSDDRD - path to the correct CSDDRD type and region file
		my $input_path = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_type . '_subset_' . $region;
		open (my $CSDDRD_FILE, '<', "$input_path.csv") or die ("can't open datafile: $input_path.csv");	# open the correct CSDDRD file to use as the data source

		my $CSDDRD; # declare a hash reference to store the CSDDRD data. This will only store one house at a time and the header data
		my $BCD_characteristics;
		
		open (WINDOW, '>', "$input_path.window.csv") or die ("can't open datafile: $input_path.window.csv");	# open the correct WINDOW file to output the data
		
		print WINDOW "House type,Region,Vintage,Filename,Front of house (1=S then CCW to 8),Front window,Right window,Back window,Left window,S window,E window,N window,W window,S area,E area,N area,W area,-,Windows not in the con_db.xml database\n";


		# -----------------------------------------------
		# GO THROUGH EACH LINE OF THE CSDDRD SOURCE DATAFILE AND BUILD THE HOUSE MODELS
		# -----------------------------------------------
		
		RECORD: while ($CSDDRD = one_data_line($CSDDRD_FILE, $CSDDRD)) {	# go through each line (house) of the file

			$models_attempted++;	# count the models attempted
			
			my @window_print;	# declare an array to store the window codes
			my @window_bad = ('-');	# declare an array to store bad window codes

			my $time= localtime();	# note the present time
			
			# house file coordinates to print when an error is encountered
# 			my $coordinates = "$hse_type, $region, $CSDDRD->{'file_name'}";
			my $coordinates = {'hse_type' => $hse_type, 'region' => $region, 'file_name' => $CSDDRD->{'file_name'}};
			
			# remove the trailing HDF from the house name and check for bad filename
			$CSDDRD->{'file_name'} =~ s/.HDF// or  &die_msg ('RECORD: Bad record name (no *.HDF)', $CSDDRD->{'file_name'}, $coordinates);

			my @window_area_print = ($CSDDRD->{'wndw_area_front'}, $CSDDRD->{'wndw_area_right'}, $CSDDRD->{'wndw_area_back'}, $CSDDRD->{'wndw_area_left'});

			# DECLARE ZONE AND PROPERTY HASHES. INITIALIZE THE MAIN ZONE TO BE TRUE AND ALL OTHER ZONES TO BE FALSE
			my $zone_indc = {'main', 1};	# hash for holding the indication of particular zone presence and its number for use with determine zones and where they are located
			my $record_indc;	# hash for holding the indication of dwelling properties
			
			# Determine the climate for this house from the Climate Cross Reference
			my $climate = $climate_ref->{'data'}->{$CSDDRD->{'HOT2XP_CITY'}};	# shorten the name for use this house

			# -----------------------------------------------
			# DETERMINE ZONE INFORMATION (NUMBER AND TYPE) FOR USE IN THE GENERATION OF ZONE TEMPLATES
			# -----------------------------------------------
			ZONE_PRESENCE: {
				# FOUNDATION CHECK TO DETERMINE IF A BSMT OR CRWL ZONES ARE REQUIRED, IF SO SET TO ZONE #2
				# ALSO SET A FOUNDATION INDICATOR EQUAL TO THE APPROPRIATE TYPE
				# FLOOR AREAS (m^2) OF FOUNDATIONS ARE LISTED IN CSDDRD[97:99]
				# FOUNDATION TYPE IS LISTED IN CSDDRD[15]- 1:6 ARE BSMT, 7:9 ARE CRWL, 10 IS SLAB (NOTE THEY DONT' ALWAYS ALIGN WITH SIZES, THEREFORE USE FLOOR AREA AS FOUNDATION TYPE DECISION
				
				# BSMT CHECK
				if (($CSDDRD->{'bsmt_floor_area'} >= $CSDDRD->{'crawl_floor_area'}) && ($CSDDRD->{'bsmt_floor_area'} >= $CSDDRD->{'slab_on_grade_floor_area'})) {	# compare the bsmt floor area to the crwl and slab
					$zone_indc->{'bsmt'} = 2;	# bsmt floor area is dominant, so there is a basement zone
					if ($CSDDRD->{'foundation_type'} <= 6) {$record_indc->{'foundation'} = $CSDDRD->{'foundation_type'};}	# the CSDDRD foundation type corresponds, use it in the record indicator description
					else {$record_indc->{'foundation'} = 1;};	# the CSDDRD foundation type doesn't correspond (but floor area was dominant), assume "full" basement
				}
				
				# CRWL CHECK
				elsif (($CSDDRD->{'crawl_floor_area'} >= $CSDDRD->{'bsmt_floor_area'}) && ($CSDDRD->{'crawl_floor_area'} >= $CSDDRD->{'slab_on_grade_floor_area'})) {	# compare the crwl floor area to the bsmt and slab
					# crwl space floor area is dominant, but check the type prior to creating a zone
					if ($CSDDRD->{'foundation_type'} != 7) {	# check that the crwl space is either "ventilated" or "closed" ("open" is treated as exposed main floor)
						$zone_indc->{'crwl'} = 2;	# create the crwl zone
						if (($CSDDRD->{'foundation_type'} >= 8) && ($CSDDRD->{'foundation_type'} <= 9)) {$record_indc->{'foundation'} = $CSDDRD->{'foundation_type'};}	# the CSDDRD foundation type corresponds, use it in the record indicator description
						else {$record_indc->{'foundation'} = 8;};	# the CSDDRD foundation type doesn't correspond (but floor area was dominant), assume "ventilated" crawl space
					}
					else {$record_indc->{'foundation'} = 7;};	# the crwl is actually "open" with large ventilation, so treat it as an exposed main floor with no crwl zone
				}
				
				# SLAB CHECK
				elsif (($CSDDRD->{'slab_on_grade_floor_area'} >= $CSDDRD->{'bsmt_floor_area'}) && ($CSDDRD->{'slab_on_grade_floor_area'} >= $CSDDRD->{'crawl_floor_area'})) { # compare the slab floor area to the bsmt and crwl
					$record_indc->{'foundation'} = 10;	# slab floor area is dominant, so set the foundation to 10
				}
				
				# FOUNDATION ERROR
# 				else {&error_msg ('Bad foundation determination', $coordinates);};
				else {&die_msg ('ZONE PRESENCE: Bad foundation determination', 'foundation areas cannot be used to determine largest',$coordinates);};

				# ATTIC CHECK- COMPARE THE CEILING TYPE TO DISCERN IF THERE IS AN ATTC ZONE
				
				# THE FLAT CEILING TYPE IS LISTED IN CSDDRD AND WILL HAVE A VALUE NOT EQUAL TO 1 (N/A) OR 5 (FLAT ROOF) IF AN ATTIC IS PRESENT
				if (($CSDDRD->{'flat_ceiling_type'} != 1) && ($CSDDRD->{'flat_ceiling_type'} != 5)) {	# set attic zone indicator unless flat ceiling is type "N/A" or "flat"
					if (defined($zone_indc->{'bsmt'}) || defined($zone_indc->{'crwl'})) {$zone_indc->{'attc'} = 3;}
					else {$zone_indc->{'attc'} = 2;};
				}
				
				# CEILING TYPE ERROR
				elsif (($CSDDRD->{'flat_ceiling_type'} < 1) || ($CSDDRD->{'flat_ceiling_type'} > 6)) {
# 					&error_msg ('Bad flat roof type', $coordinates);
					&die_msg ('ZONE PRESENCE: Bad flat roof type (<1 or >6)', $CSDDRD->{'flat_ceiling_type'}, $coordinates);
				}
				
				else {
					if (defined($zone_indc->{'bsmt'}) || defined($zone_indc->{'crwl'})) {$zone_indc->{'roof'} = 3;}
					else {$zone_indc->{'roof'} = 2;};
				};
			};

			# -----------------------------------------------
			# CREATE APPROPRIATE FILENAME EXTENTIONS AND FILENAMES FROM THE TEMPLATES FOR USE IN GENERATING THE ESP-r INPUT FILES
			# -----------------------------------------------

			# INITIALIZE OUTPUT FILE ARRAYS FOR THE PRESENT HOUSE RECORD BASED ON THE TEMPLATES
			my $hse_file;	# new hash reference to the ESP-r files for this record

			INITIALIZE_HOUSE_FILES: {
			
				# COPY THE TEMPLATES FOR USE WITH THIS HOUSE (SINGLE USE FILES WILL REMAIN, BUT ZONE FILES (e.g. geo) WILL BE AGAIN COPIED FOR EACH ZONE	
				foreach my $ext (@{$bld_extensions}) {
					if (defined ($template->{$ext})) {
						$hse_file->{$ext} = [@{$template->{$ext}}];	# create the template file for the zone
					}
					else {&die_msg ('INITIALIZE HOUSE FILES: missing template', $ext, $coordinates);};
				};
				
				# CREATE THE BASIC FILES FOR EACH ZONE 
				foreach my $zone (keys (%{$zone_indc})) {
					foreach my $ext ('opr', 'con', 'geo') {	# files required for each zone
						&copy_template($zone, $ext, $hse_file, $coordinates);
					};
					
					my $ext = 'bsm';
					if ($zone eq 'bsmt' || $zone eq 'crwl' || ($zone eq 'main' && $record_indc->{'foundation'} == 10) ) {	# or if slab on grade
						&copy_template($zone, $ext, $hse_file, $coordinates);
					};
				};
				
				# create an obstruction file for MAIN
				my $ext = 'obs';
				&copy_template('main', $ext, $hse_file, $coordinates);;

				# CHECK MAIN WINDOW AREA (m^2) AND CREATE A TMC FILE ([156..159] is Front, Right, Back, Left)
				if ($CSDDRD->{'wndw_area_front'} + $CSDDRD->{'wndw_area_right'} + $CSDDRD->{'wndw_area_back'} + $CSDDRD->{'wndw_area_left'} > 0) {
					$ext = 'tmc';
					&copy_template('main', $ext, $hse_file, $coordinates);
				};
			};

			# -----------------------------------------------
			# GENERATE THE *.cfg FILE
			# -----------------------------------------------
			CFG: {

				&replace ($hse_file->{'cfg'}, "#ROOT", 1, 1, "%s\n", "*root $CSDDRD->{'file_name'}");	# Label with the record name (.HSE stripped)
				
				# Cross reference the weather city to the CWEC weather data
				if ($CSDDRD->{'HOT2XP_PROVINCE_NAME'} eq $climate_ref->{'data'}->{$CSDDRD->{'HOT2XP_CITY'}}->{'HOT2XP_PROVINCE_NAME'}) {	# find a matching climate name that has an appropriate province name
					
					# replate the latitude and logitude and then provide information on the locally selected climate and the CWEC climate
					&replace ($hse_file->{'cfg'}, "#LAT_LONG", 1, 1, "%s\n# %s\n# %s\n", 
						"$climate->{'CWEC_LATITUDE'} $climate->{'CWEC_LONGITUDE_DIFF'}",
						"CSDDRD is $CSDDRD->{'HOT2XP_CITY'}, $climate->{'HOT2XP_PROVINCE_ABBREVIATION'}, lat $climate->{'HOT2XP_EC_LATITUDE'}, long $climate->{'HOT2XP_EC_LONGITUDE'}, HDD \@ 18 C = $climate->{'HOT2XP_EC_HDD_18C'}",
						"CWEC is $climate->{'CWEC_CITY'}, $climate->{'CWEC_PROVINCE_ABBREVIATION'}, lat $climate->{'CWEC_EC_LATITUDE'}, long $climate->{'CWEC_EC_LONGITUDE'}, HDD \@ 18 C = $climate->{'CWEC_EC_HDD_18C'}");
					
					# Use the weather station's lat and long so temp and insolation are in phase, also in a comment show the CSDDRD weather site and compare to CWEC weather site.
					&replace ($hse_file->{'cfg'}, "#CLIMATE", 1, 1, "%s\n", "*clm ../../../climate/clm-bin_Canada/$climate->{'CWEC_FILE'}");	# use the CWEC city weather name
					
					&replace ($hse_file->{'cfg'}, "#CALENDAR_YEAR", 1, 1, "%s\n", "*year  $climate->{'CWEC_YEAR'} # CWEC year which is arbitrary");	# use the CWEC city weather year
					}
					
				else { &die_msg ('CFG: Cannot find climate city', "$CSDDRD->{'HOT2XP_CITY'}, $CSDDRD->{'HOT2XP_PROVINCE_NAME'}", $coordinates);};	# if climate not found print an error
				
# 				&replace ($hse_file->{'cfg'}, "#SITE_RHO", 1, 1, "%s\n", "1 0.2");	# site exposure and ground reflectivity (rho)

				# cycle through the common filename structures and replace the tag and filename. Note the use of concatenation (.) and uppercase (uc)
				foreach my $file ('aim', 'ctl', 'mvnt', 'dhw', 'hvac', 'cnn') {
					&replace ($hse_file->{'cfg'}, '#' . uc($file), 1, 1, "%s\n", "*$file ./$CSDDRD->{'file_name'}.$file");	# file path at the tagged location
				};

				&replace ($hse_file->{'cfg'}, "#PNT", 1, 1, "%s\n", "*pnt ./$CSDDRD->{'file_name'}.elec");	# electrical network path
				&replace ($hse_file->{'cfg'}, "#SIM_PRESET_LINE1", 1, 1, "%s %u %s\n", '*sps 1 2', 60  / $time_step, '1 4 0');	# sim setup: no. data sets retained; startup days; zone_ts (step/hr); plant_ts multiplier?? (step/hr); ?save_lv @ each zone_ts; ?save_lv @ each zone_ts;
# 				&replace ($hse_file->{'cfg'}, "#SIM_PRESET_LINE2", 1, 1, "%s\n", "1 1 1 1 sim_presets");	# simulation start day; start mo.; end day; end mo.; preset name
				&replace ($hse_file->{'cfg'}, "#SIM_PRESET_LINE3", 1, 1, "%s\n", "*sblr $CSDDRD->{'file_name'}.res");	# res file path
				&replace ($hse_file->{'cfg'}, "#SIM_PRESET_LINE4", 1, 1, "%s\n", "*selr $CSDDRD->{'file_name'}.elr");	# electrical load results file path
				&replace ($hse_file->{'cfg'}, "#PROJ_LOG", 1, 2, "%s\n", "$CSDDRD->{'file_name'}.log");	# log file path
				&replace ($hse_file->{'cfg'}, "#BLD_NAME", 1, 2, "%s\n", "$CSDDRD->{'file_name'}");	# name of the building

				my $zone_count = keys (%{$zone_indc});	# scalar of keys, equal to the number of zones
				&replace ($hse_file->{'cfg'}, "#ZONE_COUNT", 1, 1, "%s\n", "$zone_count");	# number of zones
				
				&replace ($hse_file->{'cfg'}, "#AIR", 1, 1, "%s\n", "0");	# air flow network path

				# SET THE ZONE PATHS 
				foreach my $zone (keys (%{$zone_indc})) {	# cycle through the zones
					# add the top line (*zon X) for the zone
					&insert ($hse_file->{'cfg'}, '#ZONE' . $zone_indc->{$zone}, 1, 1, 0, "%s\n", "*zon $zone_indc->{$zone}");
					# cycle through all of the extentions of the house files and find those for this particular zone
					foreach my $ext (sort {$a cmp $b} keys (%{$hse_file})) {
						if ($ext =~ /$zone.(...)/) {
							# insert a path for each valid zone file with the proper name (note use of regex brackets and $1)
							&insert ($hse_file->{'cfg'}, '#END_ZONE' . $zone_indc->{$zone}, 1, 0, 0, "%s\n", "*$1 ./$CSDDRD->{'file_name'}.$ext");
						};
					};
					
					# Provide for the possibility of a shading file for the main zone
					if ($zone eq 'main') {&insert ($hse_file->{'cfg'}, '#END_ZONE' . $zone_indc->{$zone}, 1, 0, 0, "%s\n", "*isi ./$CSDDRD->{'file_name'}.isi");};
					
					# End of the zone files
					&insert ($hse_file->{'cfg'}, '#END_ZONE' . $zone_indc->{$zone}, 1, 0, 0, "%s\n", "*zend");	# provide the *zend at the end
				};
			};

			# -----------------------------------------------
			# Generate the *.aim file
			# -----------------------------------------------
			AIM: {
				
				# declare a variable for storing the ELA pressure (10 or 4 Pa) as a function of ELA indicator (1 or 2) and lookup the pressure
				my $Pa_ELA = {1 => 10, 2 => 4}->{$CSDDRD->{'ELA_Pa_type'}}
						or &die_msg ('AIM: bad ELA value (1-2)', $CSDDRD->{'ELA_Pa_type'}, $coordinates);
				
				# Check air tightness type (i.e. was it tested or does it use a default)
				if ($CSDDRD->{'air_tightness_type'} == 1) {	 # (1 = blower door test)
					&replace ($hse_file->{'aim'}, "#BLOWER_DOOR", 1, 1, "%s\n", "1 3 $CSDDRD->{'ACH'} $Pa_ELA $CSDDRD->{'ELA'} 0.611");	# Blower door test with ACH50 and ELA specified
				}
				
				else { &replace ($hse_file->{'aim'}, "#BLOWER_DOOR", 1, 1, "%s\n", "1 2 $CSDDRD->{'ACH'} $Pa_ELA");};	# Airtightness rating, use ACH50 only (as selected in HOT2XP)
				
				# declare a cross reference for the AIM-2 terrain based on the Rural_Suburb_Urban indicator
				# Rural_Suburb_Urban value | Description | Terrain value | Description
				#             1            |    Rural    |       6       |  Parkland
				#             2            |    Suburb   |       7       | Suburban, Forest
				#             3            |    Urban    |       8       | City Centre
				# declare the cross ref and lookup the appropriate value of terrain
				my $rural_suburb_urban = $dhw_al->{'data'}{$CSDDRD->{'file_name'}.'.HDF'}->{'Rural_Suburb_Urban'};
				my $aim2_terrain = {1 => 6, 2 => 7, 3 => 8}->{$rural_suburb_urban}
						or &die_msg ('AIM: No local terrain key for Rural_Suburb_Urban', $rural_suburb_urban, $coordinates);
				&replace ($hse_file->{'aim'}, "#SHIELD_TERRAIN", 1, 1, "%s\n", "3 $aim2_terrain 2 2 10");	# specify the building terrain based on the Rural_Suburb_Urban indicator
				
				
				# Determine the highest ceiling height
				my $eave_height = $CSDDRD->{'main_wall_height_1'} + $CSDDRD->{'main_wall_height_2'} + $CSDDRD->{'main_wall_height_3'} + $CSDDRD->{'bsmt_wall_height_above_grade'};	# equal to main floor heights + wall height of basement above grade. DO NOT USE HEIGHT OF HIGHEST CEILING, it is strange
				
				($eave_height, $issues) = check_range($eave_height, 1, 12, 'AIM eave height', $coordinates, $issues);
				
				&replace ($hse_file->{'aim'}, "#EAVE_HEIGHT", 1, 1, "%s\n", "$eave_height");	# set the eave height in meters

# PLACEHOLDER FOR MODIFICATION OF THE FLUE SIZE LINE. PRESENTLY AIM2_PRETIMESTEP.F USES HVAC FILE TO MODIFY FURNACE FLUE INPUTS FOR ON/OFF

				# Determine which zones the infiltration is applied to
				unless (defined ($zone_indc->{'bsmt'})) {
					&replace ($hse_file->{'aim'}, '#ZONE_INDICES', 1, 2, "%s\n", "1 1");	# only main recieves AIM calculated infiltration
				}
				
				else {
					&replace ($hse_file->{'aim'}, '#ZONE_INDICES', 1, 2, "%s\n", "2 1 2");	# main and basement recieve AIM calculated infiltration
				};

			};


			# -----------------------------------------------
			# Generate the *.mvnt file
			# -----------------------------------------------
			MVNT: {
				# Check for presence of an HRV
				if ($CSDDRD->{'vent_equip_type'} == 2 || $CSDDRD->{'vent_equip_type'} == 5) {	# HRV is present
					&replace ($hse_file->{'mvnt'}, "#CVS_SYSTEM", 1, 1, "%s\n", 2);	# list CSV as HRV
					&insert ($hse_file->{'mvnt'}, "#HRV_DATA", 1, 1, 0, "%s\n%s\n", "0 $CSDDRD->{'HRV_eff_0_C'} 75", "-25 $CSDDRD->{'HRV_eff_-25_C'} 125");	# list efficiency and fan power (W) at cool (0C) and cold (-25C) temperatures
					&insert ($hse_file->{'mvnt'}, "#HRV_FLOW_RATE", 1, 1, 0, "%s\n", $CSDDRD->{'vent_supply_flowrate'});	# supply flow rate
					&insert ($hse_file->{'mvnt'}, "#HRV_COOL_DATA", 1, 1, 0, "%s\n", 25);	# cool efficiency
					&insert ($hse_file->{'mvnt'}, "#HRV_PRE_HEAT", 1, 1, 0, "%s\n", 0);	# preheat watts
					&insert ($hse_file->{'mvnt'}, "#HRV_TEMP_CTL", 1, 1, 0, "%s\n", "7 0 0");	# this is presently not used (7) but can make for controlled HRV by temp
					&insert ($hse_file->{'mvnt'}, "#HRV_DUCT", 1, 1, 0, "%s\n%s\n", "1 1 2 2 152 0.1", "1 1 2 2 152 0.1");	# use the typical duct values
				}
				
				# Check for presence of a fan central ventilation system (CVS) (i.e. no HRV)
				elsif ($CSDDRD->{'vent_equip_type'} == 3) {	# fan only ventilation
					&replace ($hse_file->{'mvnt'}, "#CVS_SYSTEM", 1, 1, "%s\n", 3);	# list CSV as fan ventilation
					&insert ($hse_file->{'mvnt'}, "#VENT_FLOW_RATE", 1, 1, 0, "%s\n", "$CSDDRD->{'vent_supply_flowrate'} $CSDDRD->{'vent_exhaust_flowrate'} 75");	# supply and exhaust flow rate (L/s) and fan power (W)
					&insert ($hse_file->{'mvnt'}, "#VENT_TEMP_CTL", 1, 1, 0, "%s\n", "7 0 0");	# no temp control
				};	# no need for an else
				
				# Check to see if exhaust fans exist
				if ($CSDDRD->{'vent_equip_type'} == 4 || $CSDDRD->{'vent_equip_type'} == 5) {	# exhaust fans exist
					&replace ($hse_file->{'mvnt'}, "#EXHAUST_TYPE", 1, 1,  "%s\n", 2);	# exhaust fans exist
					
					# HRV + exhaust fans
					if ($CSDDRD->{'vent_equip_type'} == 5) {
						&insert ($hse_file->{'mvnt'}, "#EXHAUST_DATA", 1, 1, 0, "%s %s %.1f\n", 0, $CSDDRD->{'vent_exhaust_flowrate'} - $CSDDRD->{'vent_supply_flowrate'}, 27.7 / 12 * ($CSDDRD->{'vent_exhaust_flowrate'} - $CSDDRD->{'vent_supply_flowrate'}));	# flowrate supply (L/s) = 0, flowrate exhaust = exhaust - supply due to HRV, total fan power (W)
					}
					
					# exhaust fans only
					else {
						&insert ($hse_file->{'mvnt'}, "#EXHAUST_DATA", 1, 1, 0, "%s %s %.1f\n", 0, $CSDDRD->{'vent_exhaust_flowrate'}, 27.7 / 12 * $CSDDRD->{'vent_exhaust_flowrate'});	# flowrate supply (L/s) = 0, flowrate exhaust = exhaust , total fan power (W)
					};
				};	# no need for an else
			};


			# -----------------------------------------------
			# Control file
			# -----------------------------------------------
			CTL: {

				# Link the zones to the control algorithm
				if (defined ($zone_indc->{'bsmt'})) { &replace ($hse_file->{'ctl'}, "#ZONE_LINKS", 1, 1, "%s\n", "1 1 2");}	# link main and bsmt to control loop 1 and attc to control loop 2 (free float)
				else { &replace ($hse_file->{'ctl'}, "#ZONE_LINKS", 1, 1, "%s\n", "1 2 2");};	# no bsmt and crwl spc is not conditioned so zeros other than main, NOTE the extra postion does not matter if no foundation zone exists
			};


			# -----------------------------------------------
			# Obstruction, Shading and Insolation file
			# -----------------------------------------------
			OBS_ISI: {
				my $obs = 0;	# replace this with logic to decide if obstruction is present
				# ALSO FILL OUT THE OBS FILE
				
				# If there are obstructions then leave on the *obs file and *isi (for each zone) tags in the cfg file
				unless ($obs) {	# there is no obstruction desired so uncomment it in the cfg file
				
					foreach my $line (@{$hse_file->{'cfg'}}) {	# check each line of the cfg file
					
						if (($line =~ /^(\*obs.*)/) || ($line =~ /^(\*isi.*)/)) {	# if *obs or *isi tag is present then
							$line = "#$1\n";	# comment out the *obs or *isi tag
							# do not put a 'last' statement here b/c we have to comment both the obs and the isi
						};
					};
				};
			};


			# -----------------------------------------------
			# Preliminary geo file generation
			# -----------------------------------------------
# 			my $glass_to_rough = 0.85;
# 			my $window_area = [$CSDDRD->{'wndw_area_front'} * $glass_to_rough, $CSDDRD->{'wndw_area_right'} * $glass_to_rough, $CSDDRD->{'wndw_area_back'} * $glass_to_rough, $CSDDRD->{'wndw_area_left'} * $glass_to_rough];	# declare an array equal to the total window area for each side
			my $window_area = [$CSDDRD->{'wndw_area_front'}, $CSDDRD->{'wndw_area_right'}, $CSDDRD->{'wndw_area_back'}, $CSDDRD->{'wndw_area_left'}];	# declare an array equal to the total window area for each side
			
			# declare and intialize an array reference to hold the door WIDTHS for each side. The first 4 elements are the main sides in order (front, right, back, left) and the final 2 elements are the basement sides (front and back?)
			my $door_width = [0, 0, 0, 0, 0, 0, 0];
			
			# examine the door variables to attribute the appropriate widths to door sides and to check that the values were not input in reverse. The width consideration is primarily because more than 4 doors could be specified for the main floor but we are limiting the number of doors per side to 1.
			foreach my $index (1..3) { # cycle through the three door types (main 1, main 2, bsmt)
				# not the concatenation use below where the door type ($index) is concatenated to the beginning of the door header label
				if ($CSDDRD->{'door_count_' . $index} != 0) { # check existance of doors
					# check that door width/height entry wasn't reversed by comparing the two values to practical values. Reverse them if this is so
					if (($CSDDRD->{'door_width_' . $index} > 1.5) && ($CSDDRD->{'door_height_' . $index} < 1.5)) {	# check the width and height
						my $temp = $CSDDRD->{'door_width_' . $index};	# store door width temporarily
						$CSDDRD->{'door_width_' . $index} = sprintf('%5.2f', $CSDDRD->{'door_height_' . $index});	# set door width equal to original door height
						$CSDDRD->{'door_height_' . $index} = sprintf('%5.2f', $temp);	# set door height equal to original door width
# 						print GEN_SUMMARY "\tDoor\@[$index] width/height reversed: $coordinates\n";	# print a comment about it
						$issues = set_issue($issues, 'Door', 'width/height reversed', "Now W $CSDDRD->{'door_width_' . $index} H $CSDDRD->{'door_height_' . $index}", $coordinates);
					};
					
					# do a range check on the door width and height
					($CSDDRD->{'door_width_' . $index}, $issues) = check_range(sprintf('%5.2f', $CSDDRD->{'door_width_' . $index}), 0.5, 2.5, "Door Width $index", $coordinates, $issues);
					($CSDDRD->{'door_height_' . $index}, $issues) = check_range(sprintf('%5.2f', $CSDDRD->{'door_height_' . $index}), 1.5, 3, "Door Height $index", $coordinates, $issues);
				};
				
				# Apply appropriate widths to the door width array by considering the number of doors of that type
				if ($CSDDRD->{'door_count_' . $index} == 0) {	# no doors exist of that type
					# Do nothing because we initialized the width array to zero
				}
				
				elsif ($CSDDRD->{'door_count_' . $index} <= 2) {	# 1 or 2 doors exist so their width may be directly applied to the width array
					foreach my $door (1..$CSDDRD->{'door_count_' . $index}) { # cycle through the 1 or 2 doors
						# apply the door widths to the appropriate element in the door_width array.
						# e.g. door index 1 and door 1 results in element 1 + 1 - 2 = 0 (element 0) being set to the door width.
						$door_width->[$index + $door - 2] = $CSDDRD->{'door_width_' . $index};
					};
				}
				
				# There is more than 2 doors, so we have to resize the width of the only two doors we can specify to incorporate the width of the 3+ doors.
				else {
					foreach my $door (1..2) { # only set widths for two doors as we only have two sides for this door type
						# calculate the total door width as the product of number of doors and width. Then divide by two to apply the total width to the two available doors.
						$door_width->[$index + $door - 2] = sprintf('%.2f', $CSDDRD->{'door_width_' . $index} * $CSDDRD->{'door_count_' . $index} / 2);
					};
				};
			};

			my $connections;	# array reference to hold all zones surface connections listing (5 items on each line)

			# DETERMINE WIDTH AND DEPTH OF ZONE (with limitations)
			my $w_d_ratio = 1; # declare and intialize a width to depth ratio (width is front of house) 
			if ($CSDDRD->{'exterior_dimension_indicator'} == 0) {
				($w_d_ratio, $issues) = check_range($w_d_ratio, 0.75, 1.33, 'Exterior width to depth ratio', $coordinates, $issues);
			};	# If auditor input width/depth then check range NOTE: these values were chosen to meet the basesimp range and in an effort to promote enough size for windows and doors
			
			$record_indc->{'vol_conditioned'} = 0;

			GEO: {
				foreach my $zone (sort { $zone_indc->{$a} <=> $zone_indc->{$b} } keys(%{$zone_indc})) {	# sort the keys by their value so main comes first
				
					my $vertex_index = 1;	# index counter
					my $surface_index = 1;	# index counter

					&replace ($hse_file->{"$zone.geo"}, "#ZONE_NAME", 1, 1, "%s\n", "GEN $zone This file describes the $zone");	# set the name at the top of each zone geo file

					# SET THE ORIGIN OF THE ZONE (note the formatting)
					my $x1 = '  0.00'; my $y1 = '  0.00', my $z1 = '  0.00';	# declare and initialize the zone origin

					# DETERMINE WIDTH AND DEPTH OF ZONE (with limitations)
					my $x = sprintf("%6.2f", ($CSDDRD->{'main_floor_area_1'} ** 0.5) * $w_d_ratio);	# determine width of zone based upon main floor area and width to depth ratio
					my $y = sprintf("%6.2f", ($CSDDRD->{'main_floor_area_1'} ** 0.5) / $w_d_ratio);	# determine depth of zone based upon main floor area and width to depth ratio
					my $x2 = sprintf("%6.2f", $x1 + $x);	# set the extremity points
					my $y2 = sprintf("%6.2f", $y1 + $y);	# set the extremity points

					# DETERMINE HEIGHT OF ZONE (this is dependent on the type of zone
					my $z; # declare a z height variable
					
					# note that formatting will be done upon determining the z and z1
					if ($zone eq 'main') {
						# NOTE: this has assumed that all main levels have the same footprint
						$z = $CSDDRD->{'main_wall_height_1'} + $CSDDRD->{'main_wall_height_2'} + $CSDDRD->{'main_wall_height_3'};
					}	# the main zone is height of three potential stories and originates at 0,0,0
					elsif ($zone eq 'bsmt') {
						$z = $CSDDRD->{'bsmt_wall_height'};
						$z1 = -$z;
					}	# basement or crwl space is offset by its height so that origin is below 0,0,0
					elsif ($zone eq 'crwl') {
						$z = $CSDDRD->{'crawl_wall_height'};
						$z1 = -$z;
					}
					elsif ($zone eq 'attc') {
						# attic is assumed to be 5/12 roofline with peak in parallel with long side of house. Attc is mounted to top corner of main above 0,0,0
						$z = &smallest($x, $y) / 2 * 5 / 12;
						$z1 = $CSDDRD->{'main_wall_height_1'} + $CSDDRD->{'main_wall_height_2'} + $CSDDRD->{'main_wall_height_3'};
					}
					elsif ($zone eq 'roof') {
						# create a vented roof airspace, not very thick
						$z = 0.3;
						$z1 = $CSDDRD->{'main_wall_height_1'} + $CSDDRD->{'main_wall_height_2'} + $CSDDRD->{'main_wall_height_3'};
					}
					else {&die_msg ('GEO: Determine height of zone, bad zone name', $zone, $coordinates)};
					
					# perform the formatting
					$z = sprintf('%6.2f', $z);	# sig digits
					$z1 = sprintf('%6.2f', $z1);	# sig digits
					
					# include the offet in the height to place vertices>1 at the appropriate location
					my $z2 = sprintf('%6.2f', $z1 + $z);
					
					# record the present surface areas (note that rectangularism is assumed)
					$record_indc->{$zone}->{'SA'}->{'base'} = $x * $y;
					$record_indc->{$zone}->{'SA'}->{'ceiling'} = $record_indc->{$zone}->{'SA'}->{'base'};
					$record_indc->{$zone}->{'SA'}->{'front'} = $x * $z;
					$record_indc->{$zone}->{'SA'}->{'right'} = $y * $z;
					$record_indc->{$zone}->{'SA'}->{'back'} = $record_indc->{$zone}->{'SA'}->{'front'};
					$record_indc->{$zone}->{'SA'}->{'left'} = $record_indc->{$zone}->{'SA'}->{'right'};
					
					my $SA_sum = 0;
					foreach my $surface (keys (%{$record_indc->{$zone}->{'SA'}})) {
						$SA_sum = $SA_sum + $record_indc->{$zone}->{'SA'}->{$surface};
					};
					$record_indc->{$zone}->{'SA'}->{'total'} = $SA_sum;
					$record_indc->{$zone}->{'SA'}->{'base-sides'} = $SA_sum - $record_indc->{$zone}->{'SA'}->{'ceiling'};

					# ZONE VOLUME
					$record_indc->{$zone}->{'volume'} = sprintf('%.2f', $x * $y * $z);
					if ($zone eq 'main' || $zone eq 'bsmt') {$record_indc->{'vol_conditioned'} = $record_indc->{'vol_conditioned'} + $record_indc->{$zone}->{'volume'};};

					# declare arrays for storage
					my $vertices;	# declare an array reference for the vertices
					my @attc_slop_vert; # declare an array to store the attic sides condition: sloped or vertical
					
					push (@{$vertices},	# base vertices in CCW (looking down)
						"$x1 $y1 $z1 # base v1", "$x2 $y1 $z1 # base v2", "$x2 $y2 $z1 # base v3", "$x1 $y2 $z1 # base v4");
						
					if ($zone ne 'attc') {	# second level of vertices for rectangular zones NOTE: Rework for main sloped ceiling
						# the ceiling or top is assumed rectangular
						push (@{$vertices},"$x1 $y1 $z2 # top v5", "$x2 $y1 $z2 # top v6", "$x2 $y2 $z2 # top v7", "$x1 $y2 $z2 # top v8");
						
						# roof zone has vertical walls (other attics have alternatives)
						if ($zone eq 'roof') {@attc_slop_vert = ("VERT", "VERT", "VERT", "VERT");};
					}
					
					# 5/12 attic shape OR Middle DR type house (hip not possible) with NOTE: slope facing the long side of house and gable ends facing the short side
					elsif (($CSDDRD->{'flat_ceiling_type'} == 2) || ($CSDDRD->{'attachment_type'} == 4)) {	
						if (($w_d_ratio >= 1) || ($CSDDRD->{'attachment_type'} > 1)) {	# the front is the long side OR we have a DR type house, so peak in parallel with x
							my $peak_minus = $y1 + $y / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
							my $peak_plus = $y1 + $y / 2 + 0.05;
							push (@{$vertices},	# second level attc vertices
								"$x1 $peak_minus $z2 # top v5", "$x2 $peak_minus $z2 # top v6", "$x2 $peak_plus $z2 # top v7", "$x1 $peak_plus $z2 # top v8");
							@attc_slop_vert = ("SLOP", "VERT", "SLOP", "VERT");
						}
						else {	# otherwise the sides of the building are the long sides and thus the peak runs parallel to y
							my $peak_minus = $x1 + $x / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
							my $peak_plus = $x1 + $x / 2 + 0.05;
							push (@{$vertices},	# second level attc vertices
								"$peak_minus $y1 $z2 # top v5", "$peak_plus $y1 $z2 # top v6", "$peak_plus $y2 $z2 # top v7", "$peak_minus $y2 $z2 # top v8");
							@attc_slop_vert = ("VERT", "SLOP", "VERT", "SLOP");
						}
					}
					elsif ($CSDDRD->{'flat_ceiling_type'} == 3) {	# Hip roof
						my $peak_y_minus;
						my $peak_y_plus;
						my $peak_x_minus;
						my $peak_x_plus;
						if ($CSDDRD->{'attachment_type'} == 1) {	# SD type house, so place hips but leave a ridge in the middle (i.e. 4 sloped roof sides)
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
							if ($CSDDRD->{'attachment_type'} == 2) {	# left end house type
								$peak_y_minus = $y1 + $y / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_y_plus = $y1 + $y / 2 + 0.05;
								$peak_x_minus = $x1 + $x / 3; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_x_plus = $x2;
								@attc_slop_vert = ("SLOP", "VERT", "SLOP", "SLOP");
							}
							elsif ($CSDDRD->{'attachment_type'} == 3) {	# right end house
								$peak_y_minus = $y1 + $y / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_y_plus = $y1 + $y / 2 + 0.05;
								$peak_x_minus = $x1; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								$peak_x_plus = $x1 + $x * 2 / 3;
								@attc_slop_vert = ("SLOP", "SLOP", "SLOP", "VERT");
							};
						};
						push (@{$vertices},	# second level attc vertices
							"$peak_x_minus $peak_y_minus $z2 # top v5", "$peak_x_plus $peak_y_minus $z2 # top v6", "$peak_x_plus $peak_y_plus $z2 # top v7", "$peak_x_minus $peak_y_plus $z2 # top v8");
					};

					# CREATE THE EXTREMITY SURFACES (does not include windows/doors)
					my $surfaces;	# array reference to hold surface vertex listings
					push (@{$surfaces},	# create the floor and ceiling surfaces for all zone types (CCW from outside view)
						"4 1 4 3 2 # surf1 - floor", "4 5 6 7 8 # surf2 - ceiling");

					# DECLARE CONNECTIONS AND SURFACE ATTRIBUTES ARRAY REFERENCES FOR EXTREMITY SURFACES (does not include windows/doors)
					my $surf_attributes;	# for individual zones
					my $constructions;	# for individual zones

					# DETERMINE THE SURFACES, CONNECTIONS, AND SURFACE ATTRIBUTES FOR EACH ZONE (does not include windows/doors)
					if ($zone eq 'attc' || $zone eq 'roof') {	# build the floor, ceiling, and sides surfaces and attributes for the attc
						# FLOOR AND CEILING
						my $con = "R_MAIN_ceil";
						push (@{$constructions}, [$con, $CSDDRD->{'flat_ceiling_RSI'}, $CSDDRD->{'flat_ceiling_code'}]);	# floor type
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
						foreach my $side (0..3) {
							if ($attc_slop_vert[$side] =~ /SLOP/) {$con = "ATTC_slop";}
							elsif ($attc_slop_vert[$side] =~ /VERT/) {$con = "ATTC_gbl";};
							push (@{$constructions}, [$con, 1, 1]);	# side type NOTE: somewhat arbitrarily set RSI = 1 and type = 1
							if ($CSDDRD->{'attachment_type'} == 2 && $side == 1 || $CSDDRD->{'attachment_type'} == 3 && $side == 3 || $CSDDRD->{'attachment_type'} == 4 && $side == 1 || $CSDDRD->{'attachment_type'} == 4 && $side == 3) {
								push (@{$surf_attributes}, [$surface_index, "Side", $con_name->{$con}{'type'}, $attc_slop_vert[$side], $con, "ADIABATIC"]); # sides face adiabatic (DR)
								push (@{$connections}, "$zone_indc->{$zone} $surface_index 5 0 0 # $zone $attc_slop_vert[$side]");	# add to cnn file
							}
							else {
								push (@{$surf_attributes}, [$surface_index, "Side", $con_name->{$con}{'type'}, $attc_slop_vert[$side], $con, "EXTERIOR"]); # sides face exterior
								push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $attc_slop_vert[$side]");	# add to cnn file
							};
							$surface_index++;
						};
					}
					elsif ($zone eq 'bsmt') {	# build the floor, ceiling, and sides surfaces and attributes for the bsmt
						# FLOOR AND CEILING
						my $con = "BSMT_flor";
						push (@{$constructions}, [$con, &largest($CSDDRD->{'bsmt_interior_insul_RSI'}, $CSDDRD->{'bsmt_exterior_insul_RSI'}), $CSDDRD->{'bsmt_interior_insul_code'}]);	# floor type
						push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "BASESIMP"]); # floor faces the ground
						push (@{$connections}, sprintf ("%s %.f %s", "$zone_indc->{$zone} $surface_index 6 1", $record_indc->{$zone}->{'SA'}->{'base'} / $record_indc->{$zone}->{'SA'}->{'base-sides'} * 100, "# $zone floor"));	# floor is basesimp (6) NOTE insul type (1) loss distribution % (by surface area)
						$surface_index++;
						$con = "MAIN_BSMT";
						push (@{$constructions}, [$con, 1, 1]);	# ceiling type NOTE: somewhat arbitrarily set RSI = 1 and type = 1
						push (@{$surf_attributes}, [$surface_index, "Ceiling", $con_name->{$con}{'type'}, "CEIL", $con, "ANOTHER"]); # ceiling faces main
						push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 1 1 # $zone ceiling");	# ceiling faces main (1)
						$surface_index++;
						# SIDES
						push (@{$surfaces},	# create surfaces for the sides from the vertex numbers
							"4 1 2 6 5 # surf3 - front side", "4 2 3 7 6 # surf4 - right side", "4 3 4 8 7 # surf5 - back side", "4 4 1 5 8 # surf6 - left side");
						my @sides = ("front", "right", "back", "left");
						foreach my $side (0..3) {
							$con = "BSMT_wall";
							push (@{$constructions}, [$con, &largest($CSDDRD->{'bsmt_interior_insul_RSI'}, $CSDDRD->{'bsmt_exterior_insul_RSI'}), $CSDDRD->{'bsmt_interior_insul_code'}]);	# side type
							if ($CSDDRD->{'attachment_type'} == 2 && $side == 1 || $CSDDRD->{'attachment_type'} == 3 && $side == 3 || $CSDDRD->{'attachment_type'} == 4 && $side == 1 || $CSDDRD->{'attachment_type'} == 4 && $side == 3) {
								push (@{$surf_attributes}, [$surface_index, "Side-$sides[$side]", $con_name->{$con}{'type'}, "VERT", $con, "ADIABATIC"]); # sides face adiabatic (DR)
								push (@{$connections}, "$zone_indc->{$zone} $surface_index 5 0 0 # $zone Side-$sides[$side]");	# add to cnn file
							}
							else {
								if (
									($record_indc->{'foundation'} == 3 && ($side == 0 || $side == 1)) ||
									($record_indc->{'foundation'} == 6 && ($side == 1 || $side == 2)) ||
									($record_indc->{'foundation'} == 4 && ($side == 2 || $side == 3)) ||
									($record_indc->{'foundation'} == 5 && ($side == 3 || $side == 0))
								) {
									push (@{$surf_attributes}, [$surface_index, "Side-$sides[$side]", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face ground
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone Side-$sides[$side]");	# side is walkout exposed
								}
								else {
									push (@{$surf_attributes}, [$surface_index, "Side-$sides[$side]", $con_name->{$con}{'type'}, "VERT", $con, "BASESIMP"]); # sides face ground
									push (@{$connections}, sprintf ("%s %.f %s", "$zone_indc->{$zone} $surface_index 6 1", $record_indc->{$zone}->{'SA'}->{$sides[$side]} / $record_indc->{$zone}->{'SA'}->{'base-sides'} * 100, "# $zone Side-$sides[$side]"));	# side is basesimp (6) NOTE insul type (1) loss distribution % (by surface area)
								};
							};
							$surface_index++;
						};

						# BASESIMP
						(my $height_basesimp, $issues) = check_range($z, 1, 2.5, 'BASESIMP height', $coordinates, $issues);
						&replace ($hse_file->{"$zone.bsm"}, "#HEIGHT", 1, 1, "%s\n", "$height_basesimp");	# set height (total)

						(my $height_above_grade_basesimp, $issues) = check_range($CSDDRD->{'bsmt_wall_height_above_grade'}, 0.1, 2.5 - 0.65, 'BASESIMP height above grade', $coordinates, $issues);
						(my $depth, $issues) = check_range($height_basesimp - $height_above_grade_basesimp, 0.65, 2.4, 'BASESIMP grade depth', $coordinates, $issues);

						&replace ($hse_file->{"$zone.bsm"}, "#DEPTH", 1, 1, "%s\n", "$depth");

						foreach my $sides (&largest ($y, $x), &smallest ($y, $x)) {&insert ($hse_file->{"$zone.bsm"}, "#END_LENGTH_WIDTH", 1, 0, 0, "%s\n", "$sides");};

						if (($CSDDRD->{'bsmt_exterior_insul_coverage'} == 4) && ($CSDDRD->{'bsmt_interior_insul_coverage'} > 1)) {	# insulation placed on exterior below grade and on interior
							if ($CSDDRD->{'bsmt_interior_insul_coverage'} == 2) { &replace ($hse_file->{"$zone.bsm"}, "#OVERLAP", 1, 1, "%s\n", "$depth")}	# full interior so overlap is equal to depth
							elsif ($CSDDRD->{'bsmt_interior_insul_coverage'} == 3) { my $overlap = $depth - 0.2; &replace ($hse_file->{"$zone.bsm"}, "#OVERLAP", 1, 1, "%s\n", "$overlap")}	# partial interior to within 0.2 m of slab
							elsif ($CSDDRD->{'bsmt_interior_insul_coverage'} == 4) { &replace ($hse_file->{"$zone.bsm"}, "#OVERLAP", 1, 1, "%s\n", "0.6")}	# partial interior to 0.6 m below grade
							else { die ("Bad basement insul overlap: hse_type=$hse_type; region=$region; record=$CSDDRD->{'file_name'}\n")};
						};

						(my $insul_RSI, $issues) = check_range(largest($CSDDRD->{'bsmt_interior_insul_RSI'}, $CSDDRD->{'bsmt_exterior_insul_RSI'}), 0, 9, 'BASESIMP Insul RSI', $coordinates, $issues); # set the insul value to the larger of interior/exterior insulation of basement
						&replace ($hse_file->{"$zone.bsm"}, "#RSI", 1, 1, "%s\n", "$insul_RSI");

					}
					elsif ($zone eq 'crwl') {	# build the floor, ceiling, and sides surfaces and attributes for the crwl
						# FLOOR AND CEILING
						my $con = "CRWL_flor";
						push (@{$constructions}, [$con, $CSDDRD->{'crawl_slab_RSI'}, $CSDDRD->{'crawl_slab_code'}]);	# floor type
						push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "BASESIMP"]); # floor faces the ground
						push (@{$connections}, "$zone_indc->{$zone} $surface_index 6 28 100 # $zone floor");	# floor is basesimp (6) NOTE insul type (28) loss distribution % (100)
						$surface_index++;
						$con = "R_MAIN_CRWL";
						push (@{$constructions}, [$con, $CSDDRD->{'crawl_floor_above_RSI'}, $CSDDRD->{'crawl_floor_above_code'}]);	# ceiling type
						push (@{$surf_attributes}, [$surface_index, "Ceiling", $con_name->{$con}{'type'}, "CEIL", $con, "ANOTHER"]); # ceiling faces main
						push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 1 1 # $zone ceiling");	# ceiling faces main (1)
						$surface_index++;
						# SIDES
						push (@{$surfaces},	# create surfaces for the sides from the vertex numbers
							"4 1 2 6 5 #surf3 - front side", "4 2 3 7 6 # surf4 - right side", "4 3 4 8 7 # surf5 - back side", "4 4 1 5 8 # surf6 - left side");
						my @sides = ("front", "right", "back", "left");
						foreach my $side (0..3) {
							$con = "CRWL_wall";
							push (@{$constructions}, [$con, $CSDDRD->{'crawl_wall_RSI'}, $CSDDRD->{'crawl_wall_code'}]);	# side type
							if ($CSDDRD->{'attachment_type'} == 2 && $side == 1 || $CSDDRD->{'attachment_type'} == 3 && $side == 3 || $CSDDRD->{'attachment_type'} == 4 && $side == 1 || $CSDDRD->{'attachment_type'} == 4 && $side == 3) {
								push (@{$surf_attributes}, [$surface_index, "Side-$sides[$side]", $con_name->{$con}{'type'}, "VERT", $con, "ADIABATIC"]); # sides face adiabatic (DR)
								push (@{$connections}, "$zone_indc->{$zone} $surface_index 5 0 0 # $zone Side-$sides[$side]");	# add to cnn file
							}
							else {
								push (@{$surf_attributes}, [$surface_index, "Side-$sides[$side]", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior
								push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone Side-$sides[$side]");	# add to cnn file
							};
							$surface_index++;
						};	
						# BASESIMP

						(my $height_basesimp, $issues) = check_range($z, 1, 2.5, 'BASESIMP height', $coordinates, $issues); # check crwl height for range
						&replace ($hse_file->{"$zone.bsm"}, "#HEIGHT", 1, 1, "%s\n", "$height_basesimp");	# set height (total)
						&replace ($hse_file->{"$zone.bsm"}, "#DEPTH", 1, 1, "%s\n", "0.05");	# consider a slab as heat transfer through walls will be dealt with later as they are above grade

						foreach my $sides (&largest ($y, $x), &smallest ($y, $x)) {&insert ($hse_file->{"$zone.bsm"}, "#END_LENGTH_WIDTH", 1, 0, 0, "%s\n", "$sides");};

						(my $insul_RSI, $issues) = check_range($CSDDRD->{'crawl_slab_RSI'}, 0, 9, 'BASESIMP Insul RSI', $coordinates, $issues); # set the insul value to that of the crwl space slab
						&replace ($hse_file->{"$zone.bsm"}, "#RSI", 1, 1, "%s\n", "$insul_RSI");
					}
					elsif ($zone eq 'main') {	# build the floor, ceiling, and sides surfaces and attributes for the main
						my $con;
						# FLOOR AND CEILING
						if (defined ($zone_indc->{'bsmt'}) || defined ($zone_indc->{'crwl'})) {	# foundation zone exists
							if (defined ($zone_indc->{'bsmt'})) {$con = "MAIN_BSMT"; push (@{$constructions}, [$con, 1, 1]);}	# floor type NOTE: somewhat arbitrarily set RSI = 1 and type = 1
							else {$con = "MAIN_CRWL"; push (@{$constructions}, [$con, $CSDDRD->{'crawl_floor_above_RSI'}, $CSDDRD->{'crawl_floor_above_code'}]);};
							push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "ANOTHER"]); # floor faces the foundation ceiling
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 2 2 # $zone floor");	# floor faces (3) foundation zone (2) ceiling (2)
							$surface_index++;
						}
						elsif ($record_indc->{'foundation'} == 10) {	# slab on grade
							$con = "BSMT_flor";
							push (@{$constructions}, [$con, $CSDDRD->{'slab_on_grade_RSI'}, $CSDDRD->{'slab_on_grade_code'}]);	# floor type
							push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "BASESIMP"]); # floor faces the ground
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 6 28 100 # $zone floor");	# floor is basesimp (6) NOTE insul type (28) loss distribution % (100)
							$surface_index++;
						}
						else {	# exposed floor
							$con = "MAIN_CRWL";
							push (@{$constructions}, [$con, $CSDDRD->{'exposed_floor_RSI'}, $CSDDRD->{'exposed_floor_code'}]);	# floor type
							push (@{$surf_attributes}, [$surface_index, "Floor", $con_name->{$con}{'type'}, "FLOR", $con, "EXTERIOR"]); # floor faces the ambient
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone floor");	# floor is exposed to ambient
							$surface_index++;
						};
						if (defined ($zone_indc->{'attc'})) {	# attc exists
							$con = "MAIN_ceil";
							push (@{$constructions}, [$con, $CSDDRD->{'flat_ceiling_RSI'}, $CSDDRD->{'flat_ceiling_code'}]);	# ceiling type
							push (@{$surf_attributes}, [$surface_index, "Ceiling", $con_name->{$con}{'type'}, "CEIL", $con, "ANOTHER"]); # ceiling faces attc
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 $zone_indc->{'attc'} 1 # $zone ceiling");	# ceiling faces attc (1)
							$surface_index++;
						}
						elsif (defined ($zone_indc->{'roof'})) {	# roof exists
							$con = "MAIN_ceil";
							push (@{$constructions}, [$con, $CSDDRD->{'flat_ceiling_RSI'}, $CSDDRD->{'flat_ceiling_code'}]);	# ceiling type
							push (@{$surf_attributes}, [$surface_index, "Ceiling", $con_name->{$con}{'type'}, "CEIL", $con, "ANOTHER"]); # ceiling faces roof
							push (@{$connections}, "$zone_indc->{$zone} $surface_index 3 $zone_indc->{'roof'} 1 # $zone ceiling");	# ceiling faces roof (1)
							$surface_index++;
						}
						else {	# attc does not exist
							die ("attic or roof does not exist!\n");
						};
						# SIDES
						my @side_names = ('front', 'right', 'back', 'left');	# names of the sides
						my $side_names_ref = {0 => 'front', 1 => 'right', 2 => 'back', 3 => 'left'};
						my $side_surface_vertices = [[4, 1, 2, 6, 5], [4, 2, 3, 7, 6], [4, 3, 4, 8, 7], [4, 4, 1, 5, 8]];	# surface vertex numbers in absence of windows and doors
						my @side_width = ($x, $y, $x, $y);	# a temporary variable to compare side lengths with window and door width
						
						push (@window_print, $hse_type, $region);
						if ($CSDDRD->{'vintage'} < 1946) {push (@window_print, 1)}
						elsif ($CSDDRD->{'vintage'} >= 1946 && $CSDDRD->{'vintage'} < 1970) {push (@window_print, 2)}
						elsif ($CSDDRD->{'vintage'} >= 1970 && $CSDDRD->{'vintage'} < 1980) {push (@window_print, 3)}
						elsif ($CSDDRD->{'vintage'} >= 1980 && $CSDDRD->{'vintage'} < 1990) {push (@window_print, 4)}
						elsif ($CSDDRD->{'vintage'} >= 1990 && $CSDDRD->{'vintage'} < 2004) {push (@window_print, 5)};
						push (@window_print, $CSDDRD->{'file_name'}, $CSDDRD->{'front_orientation'});
						
						foreach my $side (0..3) {	# loop over each side of the house
							my @win_dig = (0, 0, 0);
							if ($window_area->[$side] || $door_width->[$side]) {	# a window or door exists
								my $window_height = sprintf('%5.2f', $window_area->[$side] ** 0.5);	# assume a square window
								my $window_width = $window_height;	# assume a square window
								if ($window_height >= ($z - 0.4)) {	# compare window height to zone height. Offset is 0.2 m at top and bottom (total 0.4 m)
									# adjust to fit
									$window_height = sprintf('%5.2f', $z - 0.4);	# readjust  window height to fit
									# note that the width is then made larger to account for this change
									$window_width = sprintf('%5.2f', $window_area->[$side] / $window_height);	# recalculate window width
								};
								my $window_center = sprintf('%5.2f', $side_width[$side] / 2);	# assume window is centrally placed along wall length
								if (($window_width / 2 + $door_width->[$side] + 0.4) > ($side_width[$side] / 2)) {	# check to see that the window and a door will fit on the side. Note that the door is placed to the right side of window with 0.2 m gap between and 0.2 m gap to wall end
								
									# window will not fit centered. So check to see if it will fit at all, then readjust the window center
									if (($window_width + $door_width->[$side] + 0.6) > ($side_width[$side])) {	# window cannot be placed centrally, but see if they will fit at all, with 0.2 m gap from window to wall beginning
										($window_width, $issues) = check_range($window_width, 0, sprintf('%5.2f',$side_width[$side] - $door_width->[$side] - 0.6), "Window width on Side $side_names_ref->{$side}", $coordinates, $issues);
									}
									
									# window cannot be central but will fit with door
									$window_center = sprintf('%5.2f',($side_width[$side] - $door_width->[$side] - 0.4) / 2);	# readjust window location to facilitate the door and correct gap spacing between window/door/wall end
									
								};

								if ($window_area->[$side]) {	# window is true for the side so insert it into the wall (vetices, surfaces, surf attb)
									my $window_vertices;	# declare array ref to hold window vertices
									my $frame_vertices;
									
									my $frame_ratio = 0.15;

									# windows for each side have different vertices (x, y, z) and no simple algorithm exists, so have explicity geometry statement for each side. Vertices are in CCW position, starting from lower left.
									if ($side == 0) {	# front
										# back and forth across window center, all at y = 0, and centered on zone height
										# The window area at this point is the roughed-in area
										# I am putting the frame vertices to the left of the window area (full height) and the aperture area to the right side of windows area (full height).
										# The frame vertices will be used to describe the frame. Note that two of the frame vertices are the same as the aperture area vertices.
										# This is redundancy and makes the wall surface description long (we are returning to the first vertex 3 times), but at least it is clear.
										push (@{$frame_vertices}, [$x1 + $window_center - $window_width / 2, $y1, $z1 + $z / 2 - $window_height / 2]);
										push (@{$frame_vertices}, [$x1 + $window_center - ($window_width / 2 - $window_width * $frame_ratio), $y1, $z1 + $z / 2 - $window_height / 2]);
										push (@{$frame_vertices}, [$x1 + $window_center - ($window_width / 2 - $window_width * $frame_ratio), $y1, $z1 + $z / 2 + $window_height / 2]);
										push (@{$frame_vertices}, [$x1 + $window_center - $window_width / 2, $y1, $z1 + $z / 2 + $window_height / 2]);
										
										push (@{$window_vertices}, [$x1 + $window_center - ($window_width / 2 - $window_width * $frame_ratio), $y1, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x1 + $window_center + $window_width / 2, $y1, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x1 + $window_center + $window_width / 2, $y1, $z1 + $z / 2 + $window_height / 2]);
										push (@{$window_vertices}, [$x1 + $window_center - ($window_width / 2 - $window_width * $frame_ratio), $y1, $z1 + $z / 2 + $window_height / 2]);

									}
									elsif ($side == 1) {
										push (@{$frame_vertices}, [$x2, $y1 + $window_center - $window_width / 2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$frame_vertices}, [$x2, $y1 + $window_center - ($window_width / 2 - $window_width * $frame_ratio), $z1 + $z / 2 - $window_height / 2]);
										push (@{$frame_vertices}, [$x2, $y1 + $window_center - ($window_width / 2 - $window_width * $frame_ratio), $z1 + $z / 2 + $window_height / 2]);
										push (@{$frame_vertices}, [$x2, $y1 + $window_center - $window_width / 2, $z1 + $z / 2 + $window_height / 2]);
										
										push (@{$window_vertices}, [$x2, $y1 + $window_center - ($window_width / 2 - $window_width * $frame_ratio), $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x2, $y1 + $window_center + $window_width / 2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x2, $y1 + $window_center + $window_width / 2, $z1 + $z / 2 + $window_height / 2]);
										push (@{$window_vertices}, [$x2, $y1 + $window_center - ($window_width / 2 - $window_width * $frame_ratio), $z1 + $z / 2 + $window_height / 2]);
									}
									elsif ($side == 2) {
										push (@{$frame_vertices}, [$x2 - $window_center + $window_width / 2, $y2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$frame_vertices}, [$x2 - $window_center + ($window_width / 2 - $window_width * $frame_ratio), $y2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$frame_vertices}, [$x2 - $window_center + ($window_width / 2 - $window_width * $frame_ratio), $y2, $z1 + $z / 2 + $window_height / 2]);
										push (@{$frame_vertices}, [$x2 - $window_center + $window_width / 2, $y2, $z1 + $z / 2 + $window_height / 2]);
									
										push (@{$window_vertices}, [$x2 - $window_center + ($window_width / 2 - $window_width * $frame_ratio), $y2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x2 - $window_center - $window_width / 2, $y2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x2 - $window_center - $window_width / 2, $y2, $z1 + $z / 2 + $window_height / 2]);
										push (@{$window_vertices}, [$x2 - $window_center + ($window_width / 2 - $window_width * $frame_ratio), $y2, $z1 + $z / 2 + $window_height / 2]);
									}
									elsif ($side == 3) {
										push (@{$frame_vertices}, [$x1, $y2 - $window_center + $window_width / 2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$frame_vertices}, [$x1, $y2 - $window_center + ($window_width / 2 - $window_width * $frame_ratio), $z1 + $z / 2 - $window_height / 2]);
										push (@{$frame_vertices}, [$x1, $y2 - $window_center + ($window_width / 2 - $window_width * $frame_ratio), $z1 + $z / 2 + $window_height / 2]);
										push (@{$frame_vertices}, [$x1, $y2 - $window_center + $window_width / 2, $z1 + $z / 2 + $window_height / 2]);
										
										push (@{$window_vertices}, [$x1, $y2 - $window_center + ($window_width / 2 - $window_width * $frame_ratio), $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x1, $y2 - $window_center - $window_width / 2, $z1 + $z / 2 - $window_height / 2]);
										push (@{$window_vertices}, [$x1, $y2 - $window_center - $window_width / 2, $z1 + $z / 2 + $window_height / 2]);
										push (@{$window_vertices}, [$x1, $y2 - $window_center + ($window_width / 2 - $window_width * $frame_ratio), $z1 + $z / 2 + $window_height / 2]);
									};

									foreach my $vertex (0..$#{$frame_vertices}) {	# push the vertex information onto the actual array with a side and window comment
										foreach my $element (0..$#{$frame_vertices->[$vertex]}) {
											$frame_vertices->[$vertex][$element] = sprintf ('%6.2f', $frame_vertices->[$vertex][$element]);
										};
										push (@{$vertices}, "@{$frame_vertices->[$vertex]} # $side_names[$side] window-frame v$vertex");
									};

									push (@{$side_surface_vertices->[$side]}, $side_surface_vertices->[$side][1], $#{$vertices} - 2);	# push the return vertex of the wall onto its array, then add the first corner vertex of the frame
									my @frame_surface_vertices = (4);	# declare an array to hold the vertex numbers of the frame, initialize with "4" as there will be four vertices to follow in the description
									foreach my $vertex (0..3) {
										push (@{$side_surface_vertices->[$side]}, $#{$vertices} + 1 - $vertex);	# push the frame vertices onto the wall surface vertex list in CW order to create an enclosed surface. Return to the first frame vertex and stop (final side vertex is implied)
										push (@frame_surface_vertices, $#{$vertices} -2 + $vertex);	# push the frame vertices onto the frame surface vertex list in CCW order
									};
									push (@{$surfaces},"@frame_surface_vertices # $side_names[$side] frame");	# push the frame surface array onto the actual surface array

									$con = "FRAME_vnl"; #

									push (@{$constructions}, [$con, 1.5, '1234']);	# side type, RSI, code
									push (@{$surf_attributes}, [$surface_index, "$side_names[$side]-Frm", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior 
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $side_names[$side] window-frame");	# add to cnn file
									$surface_index++;




									foreach my $vertex (0..$#{$window_vertices}) {	# push the vertex information onto the actual array with a side and window comment
										foreach my $element (0..$#{$window_vertices->[$vertex]}) {
											$window_vertices->[$vertex][$element] = sprintf ('%6.2f', $window_vertices->[$vertex][$element]);
										};
										push (@{$vertices}, "@{$window_vertices->[$vertex]} # $side_names[$side] window-aperture v$vertex");
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
									foreach my $win_index (1..10) {	# iterate through the 10 windows specified for each side

										if ($CSDDRD->{"wndw_z_$side_names_ref->{$side}_duplicates_" . sprintf("%02u", $win_index)} > 0) {	# check that window duplicates (e.g. 1) exist for that window index
											unless (defined ($win_code_count->{$CSDDRD->{"wndw_z_$side_names_ref->{$side}_code_" . sprintf("%02u", $win_index)}})) {	# if this type has not been encountered then initialize the hash key at the window code equal to zero
												$win_code_count->{$CSDDRD->{"wndw_z_$side_names_ref->{$side}_code_" . sprintf("%02u", $win_index)}} = 0;
											};
											# add then number of window duplicates to the the present number for that window type
											$win_code_count->{$CSDDRD->{"wndw_z_$side_names_ref->{$side}_code_" . sprintf("%02u", $win_index)}} = $win_code_count->{$CSDDRD->{"wndw_z_$side_names_ref->{$side}_code_" . sprintf("%02u", $win_index)}} + $CSDDRD->{"wndw_z_$side_names_ref->{$side}_duplicates_" . sprintf("%02u", $win_index)};
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

									@win_dig = split (//, $win_code_side[0]);	# split the favourite side window code by digits
									$con = "WNDW_$win_dig[0]$win_dig[1]$win_dig[2]"; # use the first three digits to construct the window construction name in ESP-r

									# THIS IS A SHORT TERM WORKAROUND TO THE FACT THAT I HAVE NOT CHECKED ALL THE WINDOW TYPES YET FOR EACH SIDE
									unless (defined ($con_name->{$con})) {
										push (@window_bad, "$win_dig[0]$win_dig[1]$win_dig[2]");
										@win_dig = split (//, $CSDDRD->{'wndw_favourite_code'});	# split the favourite window code by digits
										$con = "WNDW_$win_dig[0]$win_dig[1]$win_dig[2]"; # use the first three digits to construct the window construction name in ESP-r
									};

									push (@{$constructions}, [$con, 1.5, $CSDDRD->{'wndw_favourite_code'}]);	# side type, RSI, code
									push (@{$surf_attributes}, [$surface_index, "$side_names[$side]-Aper", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior 
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $side_names[$side] window-aperture");	# add to cnn file
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
										foreach my $element (0..$#{$door_vertices->[$vertex]}) {
											$door_vertices->[$vertex][$element] = sprintf ('%6.2f', $door_vertices->[$vertex][$element]);
										};
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
										push (@{$constructions}, [$con, $CSDDRD->{'door_RSI_1'}, $CSDDRD->{'door_type_1'}]);	# side type, RSI, code
									}
									elsif ($side == 2 || $side == 3) {
										$con = "DOOR_wood";
										push (@{$constructions}, [$con, $CSDDRD->{'door_RSI_2'}, $CSDDRD->{'door_type_2'}]);	# side type, RSI, code
									};
									push (@{$surf_attributes}, [$surface_index, "$side_names[$side]-Door", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior 
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone $side_names[$side] door");	# add to cnn file
									$surface_index++;
								};

								$side_surface_vertices->[$side][0] = $#{$side_surface_vertices->[$side]};	# reset the count of vertices in the side surface to be representative of any additions due to windows and doors (an addition of 6 for each item)
								push (@{$surfaces},"@{$side_surface_vertices->[$side]} # $side_names[$side] side");	# push the side surface onto the actual surfaces array
								$con = "MAIN_wall";
								push (@{$constructions}, [$con, $CSDDRD->{'main_wall_RSI'}, $CSDDRD->{'main_wall_code'}]);	# side type
								if ($CSDDRD->{'attachment_type'} == 2 && $side == 1 || $CSDDRD->{'attachment_type'} == 3 && $side == 3 || $CSDDRD->{'attachment_type'} == 4 && $side == 1 || $CSDDRD->{'attachment_type'} == 4 && $side == 3) {
									push (@{$surf_attributes}, [$surface_index, "Side-$side_names[$side]", $con_name->{$con}{'type'}, "VERT", $con, "ADIABATIC"]); # sides face adiabatic (DR)
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 5 0 0 # $zone Side-$side_names[$side]");	# add to cnn file
								}
								else {
									push (@{$surf_attributes}, [$surface_index, "Side-$side_names[$side]", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone Side-$side_names[$side]");	# add to cnn file
								};
								$surface_index++;

							}
							else {	# no windows or doors on this side so simply push out the appropriate information for the side
								push (@{$surfaces}, "@{$side_surface_vertices->[$side]} # $side_names[$side] side");
								$con = "MAIN_wall";
								push (@{$constructions}, [$con, $CSDDRD->{'main_wall_RSI'}, $CSDDRD->{'main_wall_code'}]);	# side type
								if ($CSDDRD->{'attachment_type'} == 2 && $side == 1 || $CSDDRD->{'attachment_type'} == 3 && $side == 3 || $CSDDRD->{'attachment_type'} == 4 && $side == 1 || $CSDDRD->{'attachment_type'} == 4 && $side == 3) {
									push (@{$surf_attributes}, [$surface_index, "Side-$side_names[$side]", $con_name->{$con}{'type'}, "VERT", $con, "ADIABATIC"]); # sides face adiabatic (DR)
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 5 0 0 # $zone Side-$side_names[$side]");	# add to cnn file
								}
								else {
									push (@{$surf_attributes}, [$surface_index, "Side-$side_names[$side]", $con_name->{$con}{'type'}, "VERT", $con, "EXTERIOR"]); # sides face exterior
									push (@{$connections}, "$zone_indc->{$zone} $surface_index 0 0 0 # $zone Side-$side_names[$side]");	# add to cnn file
								};
								$surface_index++;
							};
							push (@window_print, "$win_dig[0]$win_dig[1]$win_dig[2]");
						};

						# BASESIMP FOR A SLAB
						if ($record_indc->{'foundation'} == 10) {
							(my $height_basesimp, $issues) = check_range($z, 1, 2.5, 'BASESIMP height', $coordinates, $issues);
							&replace ($hse_file->{"$zone.bsm"}, "#HEIGHT", 1, 1, "%s\n", "$height_basesimp");	# set height (total)
							&replace ($hse_file->{"$zone.bsm"}, "#DEPTH", 1, 1, "%s\n", "0.05");	# consider a slab as heat transfer through walls will be dealt with later as they are above grade

							foreach my $sides (&largest ($y, $x), &smallest ($y, $x)) {&insert ($hse_file->{"$zone.bsm"}, "#END_LENGTH_WIDTH", 1, 0, 0, "%s\n", "$sides");};

							(my $insul_RSI, $issues) = check_range($CSDDRD->{'slab_on_grade_RSI'}, 0, 9, 'BASESIMP Insul RSI', $coordinates, $issues);
							&replace ($hse_file->{"$zone.bsm"}, "#RSI", 1, 1, "%s\n", "$insul_RSI");
						};
					};

					&replace ($hse_file->{"$zone.geo"}, "#BASE", 1, 1, "%s\n", "1 0 0 0 0 0 $CSDDRD->{'main_floor_area_1'}");	# last line in GEO file which lists FLOR surfaces (total elements must equal 6) and floor area (m^2)
					my $rotation = ($CSDDRD->{'front_orientation'} - 1) * 45;	# degrees rotation (CCW looking down) from south
					my @vert_surf = ($#{$vertices} + 1, $#{$surfaces} + 1);
					&replace ($hse_file->{"$zone.geo"}, "#VER_SUR_ROT", 1, 1, "%s\n", "@vert_surf $rotation");
					$vertex_index--;	# decrement count as it is indexed one ahead of total number
					$surface_index--;
					my @zero_array;
					foreach my $zero (1..$surface_index) {push (@zero_array, 0)};
					&replace ($hse_file->{"$zone.geo"}, "#UNUSED_INDEX", 1, 1, "%s\n", "@zero_array");
					&replace ($hse_file->{"$zone.geo"}, "#SURFACE_INDENTATION", 1, 1, "%s\n", "@zero_array");

					foreach my $vertex (@{$vertices}) {&insert ($hse_file->{"$zone.geo"}, "#END_VERTICES", 1, 0, 0, "%s\n", $vertex);};
					foreach my $surface (@{$surfaces}) {&insert ($hse_file->{"$zone.geo"}, "#END_SURFACES", 1, 0, 0, "%s\n", $surface);};
					foreach my $surf_attribute (@{$surf_attributes}) {&insert ($hse_file->{"$zone.geo"}, "#END_SURFACE_ATTRIBUTES", 1, 0, 0, "%3s, %-13s %-5s %-5s %-12s %-15s\n", @{$surf_attribute});};

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
								&insert ($hse_file->{"$zone.con"}, "#END_PROPERTIES", 1, 0, 0, "%s %s %s\n", "0 0 0", $layer->{'thickness_mm'} / 1000, "0 0 0 0 # $con - $mat");	# add the surface layer information
							}
							elsif ($mat eq 'Fbrglas_Batt') {	# modify the thickness if we know it is insulation batt NOTE this precuses using the real construction development
								my $thickness_m = $construction->[1] * $mat_name->{$mat}->{'conductivity_W_mK'};	# thickness equal to RSI * k
								&insert ($hse_file->{"$zone.con"}, "#END_PROPERTIES", 1, 0, 0, "%s %5.3f %s %s\n", "$mat_name->{$mat}->{'conductivity_W_mK'} $mat_name->{$mat}->{'density_kg_m3'} $mat_name->{$mat}->{'spec_heat_J_kgK'}", $thickness_m, "0 0 0 0", " # $con - $mat : database thickness $layer->{'thickness_mm'} mm");	# add the surface layer information
							}
							else { &insert ($hse_file->{"$zone.con"}, "#END_PROPERTIES", 1, 0, 0, "%s %s %s\n", "$mat_name->{$mat}->{'conductivity_W_mK'} $mat_name->{$mat}->{'density_kg_m3'} $mat_name->{$mat}->{'spec_heat_J_kgK'}", $layer->{'thickness_mm'} / 1000, "0 0 0 0 # $con - $mat");};	# add the surface layer information
						};

						my $layer_count = @{$con_name->{$con}{'layer'}};
						&insert ($hse_file->{"$zone.con"}, "#END_LAYERS_GAPS", 1, 0, 0, "%s\n", "$layer_count $gaps # $con");

						if ($con_name->{$con}{'type'} eq "OPAQ") { push (@tmc_type, 0);}
						elsif ($con_name->{$con}{'type'} eq "TRAN") {
							push (@tmc_type, $con_name->{$con}{'optic_name'});
							$tmc_flag = 1;
						};
						if (@pos_rsi) {
							&insert ($hse_file->{"$zone.con"}, "#END_GAP_POS_AND_RSI", 1, 0, 0, "%s\n", "@pos_rsi # $con");
						};

						push (@em_inside, $mat_name->{$con_name->{$con}{'layer'}->[$#{$con_name->{$con}{'layer'}}]->{'mat_name'}}->{'emissivity_in'});
						push (@em_outside, $mat_name->{$con_name->{$con}{'layer'}->[0]->{'mat_name'}}->{'emissivity_out'});
						push (@slr_abs_inside, $mat_name->{$con_name->{$con}{'layer'}->[$#{$con_name->{$con}{'layer'}}]->{'mat_name'}}->{'absorptivity_in'});
						push (@slr_abs_outside, $mat_name->{$con_name->{$con}{'layer'}->[0]->{'mat_name'}}->{'absorptivity_out'});
					};

					&insert ($hse_file->{"$zone.con"}, "#EM_INSIDE", 1, 1, 0, "%s\n", "@em_inside");	# write out the emm/abs of the surfaces for each zone
					&insert ($hse_file->{"$zone.con"}, "#EM_OUTSIDE", 1, 1, 0, "%s\n", "@em_outside");
					&insert ($hse_file->{"$zone.con"}, "#SLR_ABS_INSIDE", 1, 1, 0, "%s\n", "@slr_abs_inside");
					&insert ($hse_file->{"$zone.con"}, "#SLR_ABS_OUTSIDE", 1, 1, 0, "%s\n", "@slr_abs_outside");

					if ($tmc_flag) {
						&replace ($hse_file->{"$zone.tmc"}, "#SURFACE_COUNT", 1, 1, "%s\n", $#tmc_type + 1);
						my %optic_lib = (0, 0);
						foreach my $element (0..$#tmc_type) {
							my $optic = $tmc_type[$element];
							unless (defined ($optic_lib{$optic})) {
								$optic_lib{$optic} = keys (%optic_lib);
								my $layers = @{$optic_data->{$optic}->[0]->{'layer'}};
								&insert ($hse_file->{"$zone.tmc"}, "#END_TMC_DATA", 1, 0, 0, "%s\n", "$layers $optic");
								&insert ($hse_file->{"$zone.tmc"}, "#END_TMC_DATA", 1, 0, 0, "%s\n", "$optic_data->{$optic}->[0]->{'optic_con_props'}->[0]->{'trans_solar'} $optic_data->{$optic}->[0]->{'optic_con_props'}->[0]->{'trans_vis'}");
								foreach my $layer (0..$#{$optic_data->{$optic}->[0]->{'layer'}}) {
									&insert ($hse_file->{"$zone.tmc"}, "#END_TMC_DATA", 1, 0, 0, "%s\n", "$optic_data->{$optic}->[0]->{'layer'}->[$layer]->{'absorption'}");
								};
								&insert ($hse_file->{"$zone.tmc"}, "#END_TMC_DATA", 1, 0, 0, "%s\n", "0");	# optical control flag
							};
							$tmc_type[$element] = $optic_lib{$optic};	# change from optics name to the appearance number in the tmc file
						};
						&replace ($hse_file->{"$zone.tmc"}, "#TMC_INDEX", 1, 1, "%s\n", "@tmc_type");	# print the key that links each surface to an optic (by number)
					};
				};
			};	

			my $cnn_count = $#{$connections} + 1;
			&replace ($hse_file->{"cnn"}, "#CNN_COUNT", 1, 1, "%s\n", "$cnn_count");
			foreach my $connection (@{$connections}) {&insert ($hse_file->{"cnn"}, "#END_CONNECTIONS", 1, 0, 0, "%s\n", "$connection");};


# 			-----------------------------------------------
# 			HVAC file
# 			-----------------------------------------------
			HVAC: {
				# THE HVAC FILE IS DEFINED IN "Modeling HVAC Systems in HOT3000, Kamel Haddad, 2001" which is in the CANMET_ESP-r_Docs_AF folder.
				# THIS FILE DEFINITION WAS USED TO CREATE A HVAC KEY (hvac_key.xml) WHICH IS USED TO CROSS REFERENCE VALUES FROM CSDDRD TO ESP-r
				# THE BELOW LOGIC WAS DEVELOPED TO WRITE OUT THE HVAC FILE BASED ON THE CSDDRD VALUES USING THE KEY
			
			
				# determine the primary heating energy source
				my $primary_energy_src = $hvac->{'energy_type'}->[$CSDDRD->{'heating_energy_src'}];	# make ref to shorten the name
				# determine the primary heat src type, not that it is in array format and the zero index is set to zero for subsequent use in printing that starts from 1.
				my @energy_src = (0, $primary_energy_src->{'ESP-r_energy_num'});
				my @systems = (0, $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_system_num'});
				# determine the primary system type
				my @equip = (0, $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_equip_num'});
				# set the system priority
				my @priority = (0, 1);
				# set the system heating/cooling
				my @heat_cool = (0, 1);	# 1 is heating, 2 is cooling
				
				my @eff_COP = (0);
				
				my $cooling = 0;
				
				if ($systems[1] >= 1 && $systems[1] <= 6) {
					# check conventional primary system efficiency (both steady state and AFUE. Simply treat AFUE as steady state for HVAC since we do not have a modifier
					($CSDDRD->{'heating_eff'}, $issues) = check_range(sprintf('%.0f', $CSDDRD->{'heating_eff'}), 30, 100, "Heat System - Eff", $coordinates, $issues);
					# record sys eff
					push (@eff_COP, $CSDDRD->{'heating_eff'} / 100);
				}

				# if a heat pump system then define the backup (for cold weather usage)
				elsif ($systems[1] >= 7 && $systems[1] <= 9) {	# these are heat pump systems and have a backup (i.e. 2 heating systems)
					
					# Check the COP
					if ($CSDDRD->{'heating_eff_type'} == 1) { # COP rated
						($CSDDRD->{'heating_eff'}, $issues) = check_range(sprintf('%.1f', $CSDDRD->{'heating_eff'}), 1.5, 5, "Heat System - COP", $coordinates, $issues);
					}
					else {	# HSPF rated so assume COP of 2.0 (CSDDRD heating COP avg)
						$CSDDRD->{'heating_eff'} = 2.0;
					};
					# record the sys COP
					push (@eff_COP, $CSDDRD->{'heating_eff'}); # COP, so do not divide by 100
					
					# backup heating system info
					push (@energy_src, $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_backup_energy_num'});	# backup system energy src type
					push (@systems, $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_backup_system_num'});	# backup system type
					push (@equip, $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_backup_equip_num'});	# backup system equipment
					
					($primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_backup_eff'}, $issues) = check_range(sprintf('%.2f', $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_backup_eff'}), 0.30, 1.00, "Heat System - Backup Eff", $coordinates, $issues);
					
					push (@eff_COP, $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_backup_eff'});	# backup system efficiency
					
					push (@priority, 2);	# backup system is second priority
					push (@heat_cool, 1);	# backup system is heating

					# because the HVAC file expects 'conventional' systems to be encountered first within the file, the two systems' locations in the array must be flipped (the backslash is used to pass a reference to the array)
					foreach my $flip (\@energy_src, \@systems, \@equip, \@eff_COP, \@priority, \@heat_cool) {
						my $temp = $flip->[$#{$flip}];	# store backup system value
						$flip->[$#{$flip}] = $flip->[$#{$flip} - 1];	# put primary system value in last position
						$flip->[$#{$flip} - 1] = $temp;	# put backup system value in preceding position
					};
					
					# Since a heat pump in present, assume that it has the capability for cooling
					$cooling = 1;
					push (@energy_src, 1);	# cooling system energy src type
					push (@systems, $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_system_num'});	# cooling system type
					push (@equip, $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_equip_num'});	# cooling system equipment
					
					# cooling COP will be greater than heating COP: we already checked the heating COP range, so simply add 1 to it.
					push (@eff_COP, $CSDDRD->{'heating_eff'} + 1.0);	# cooling system efficiency
					push (@priority, 1);	# cooling system  is first priority
					push (@heat_cool, 2);	# cooling system is cooling
				}
				
				else {&die_msg ('HVAC: Unknown heating system type', $systems[1], $coordinates)}; 
				
				# Also check for a discrete Air Conditioning System
				# The AC must be 1-3 and a HP must not be present, because if a HP is present then we already accounted for cooling capability
				if ($CSDDRD->{'cooling_equip_type'} >= 1 && $CSDDRD->{'cooling_equip_type'} <= 3 && $cooling == 0) {	# there is a cooling system installed
				
					push (@energy_src, 1);	# cooling system energy src type (electricity)
					push (@systems, 7);	# air source AC
					push (@equip, 1);	# air source AC
					
					# Check the COP
					if ($CSDDRD->{'cooling_COP_SEER_selector'} == 1) { # COP rated
						($CSDDRD->{'cooling_COP_SEER_value'}, $issues) = check_range(sprintf('%.1f', $CSDDRD->{'cooling_COP_SEER_value'}), 2, 6, "Cool System - COP", $coordinates, $issues);
					}
					else {	# SEER rated so assume COP of 3.0 (CSDDRD cooling COP avg)
						$CSDDRD->{'cooling_COP_SEER_value'} = 3.0;
					};
					# record the sys COP
					push (@eff_COP, $CSDDRD->{'cooling_COP_SEER_value'}); # COP, so do not divide by 100

					push (@priority, 1);	# cooling system  is first priority
					push (@heat_cool, 2);	# cooling system is cooling
				};
				
				
				# replace the first data line in the hvac file
				&replace ($hse_file->{"hvac"}, "#HVAC_NUM_ALT", 1, 1, "%s %s\n", $#systems, "0 # number of systems and altitude (m)");

				# determine the served zones
				my @served_zones = (1, "1 1.");	# intialize the number of served zones to 1, and set the zone number to 1 (main) with 1. ratio of distribution
				if ($zone_indc->{'bsmt'}) {@served_zones = (2, sprintf ("%u %.2f %u %.2f", 1, $record_indc->{'main'}->{'volume'} / $record_indc->{'vol_conditioned'}, 2, $record_indc->{'bsmt'}->{'volume'} / $record_indc->{'vol_conditioned'}));};	# there is a bsmt so two serviced zones, but give capacity based on volume

				my %energy_src_key = (1 => 'Electricity', 2 => 'Natural gas', 3 => 'Oil', 4 => 'Propane', 5 => 'Wood');
				my %equip_key = (1 => 'Furnace', 2 => 'Boiler', 3 => 'Baseboard/Hydronic/Plenum,etc.', 7 => 'Air source HP w/ Elec backup', 7 => 'Air source HP w/ Natural gas backup', 7 => 'Water source HP w/ Elec backup');
				my %priority_key = (1 => 'Primary', 2 => 'Secondary');
				my %heat_cool_key = (1 => 'Heating', 2 => 'Cooling');
				
				($CSDDRD->{'heating_capacity'}, $issues) = check_range(sprintf('%.1f', $CSDDRD->{'heating_capacity'}), 5, 50, "Heat System - Capacity", $coordinates, $issues);

				# loop through each system and print out appropriate data to the hvac file
				foreach my $system (1..$#systems) {	# note: skip element zero as it is dummy space
					# INFO
					&insert ($hse_file->{"hvac"}, "#INFO_$system", 1, 1, 0, "%s\n", "# $energy_src_key{$energy_src[$system]} $equip_key{$systems[$system]} system serving $served_zones[0] zone(s) with $priority_key{$priority[$system]} $heat_cool_key{$heat_cool[$system]}");
				
					# Fill out the heating system type, priority, and serviced zones
					&insert ($hse_file->{"hvac"}, "#TYPE_PRIORITY_ZONES_$system", 1, 1, 0, "%s %s %s\n", $systems[$system], $priority[$system], $served_zones[0]);	# system #, priority, num of served zones

					# furnace or boiler
					if ($systems[$system] >= 1 && $systems[$system] <= 2) {	# furnace or boiler
						my $draft_fan_W = 0;	# initialize the value
						if ($equip[$system] == 8 || $equip[$system] == 10) {$draft_fan_W = 75;};	# if certain system type then fan value is set
						my $pilot_W = 0;	# initialize the value
						PILOT: foreach (7, 11, 14) {if ($equip[$system] == $_) {$pilot_W = 10; last PILOT;};};	# check to see if the system is of a certain type and then set the pilot if true
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "# equipment_type energy_src served_zones-and-distribution heating_capacity_W efficiency auto_circulation_fan estimate_fan_power draft_fan_power pilot_power duct_system_flag");
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s %s %s %s\n", "$equip[$system] $energy_src[$system] $served_zones[1]", $CSDDRD->{'heating_capacity'} * 1000, $eff_COP[$system], "1 -1 $draft_fan_W $pilot_W 1");
					}
					
					# electric baseboard
					elsif ($systems[$system] == 3) {
						# fill out the information for a baseboard system
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "# served_zones-and-distribution heating_capacity_W efficiency no_circulation_fan circulation_fan_power");
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s %s %s %s\n", "$served_zones[1]", $CSDDRD->{'heating_capacity'} * 1000, $eff_COP[$system], "0 0");
					}
					
					# heat pump or air conditioner
					elsif ($systems[$system] >= 7 && $systems[$system] <= 9) {
						# print the heating/cooling, heat pump type, and zones
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "# heating_or_cooling equipment_type served_zones-and-distribution");
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "$heat_cool[$system] $equip[$system] $served_zones[1]");
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "# capacity_W COP");
						
						if ($heat_cool[$system] == 1) {	# heating mode
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%u %s\n", $CSDDRD->{'heating_capacity'} * 1000, $eff_COP[$system]);
						}
						
						elsif ($heat_cool[$system] == 2) { # air conditioner mode, set to 3/4 of heating capacity
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%u %s\n", $CSDDRD->{'heating_capacity'} * 1000 * 0.75, $eff_COP[$system]);
						}
						
						else {&die_msg ('HVAC: Heat pump system is not heating or cooling (1-2)', $heat_cool[$system], $coordinates)};

						# print the heat pump information (flow rate, flow rate at rating conditions, circ fan mode, circ fan position, circ fan power
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "# flow_rate flow_rate_at_rated_conditions auto_circulation_fan circ_fan_power outdoor_fan_power fan_power_in_auto_mode fan_during_rating fan_power_during_rating");
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "-1 -1 1 1 -1 150 150 1 -1");

					
						if ($heat_cool[$system] == 1) {	# heating mode
							# temperature control and backup system data (note the use of element 1 to direct it to the backup system type
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "# temp_control_algorithm cutoff_temp backup_system_type backup_sys_num");
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "3 -15. $systems[1] 1");
						}
						
						elsif ($heat_cool[$system] == 2) {	# air conditioner mode
							# sensible heat ratio and conventional cooling
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "# sensible_heat_ratio conventional_economizer_type");
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "0.75 1");
							# day types
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "1 #day types for outdoor air");
							# periods and end hour
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "1 8760 # start and end hours");
							# period hours and outdoor air flowrate
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "24 0.0 # period hours and flowrate m^3/s");
							# heating mode system number and cooling function
							&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "1 1 # heating_control_function cooling_control_function (in CTL file)");
						};
					}
					
					else {&die_msg ('HVAC: Bad heating system type (1-3, 7-8)', $systems[$system], $coordinates)};

				};
			};




			# -----------------------------------------------
			# Operations files - air only, casual gains and occupants are dealt with inside BCD
			# -----------------------------------------------
			OPR: {
				my @days = ('WEEKDAY', 'SATURDAY', 'SUNDAY');
				
				foreach my $zone (keys (%{$zone_indc})) { 
# 					&replace ($hse_file->{"$zone.opr"}, "#DATE", 1, 1, "%s\n", "*date $time");	# set the time/date for the main.opr file
					# if no other zones exist then do not modify the main.opr (its only use is for ventilation with the bsmt due to the aim and fcl files

					
					if ($zone eq 'bsmt') {
						foreach my $day (@days) {	# do for each day type
							&replace ($hse_file->{"$zone.opr"}, "#END_AIR_$day", 1, -1, "%s\n", "0 24 0 0.5 1 0");	# add 0.5 ACH ventilation to basement from main. Note they are different volumes so this is based on the basement zone.
							&replace ($hse_file->{"main.opr"}, "#END_AIR_$day", 1, -1, "%s %.2f %s\n", "0 24 0", 0.5 * $record_indc->{$zone}->{'volume'} / $record_indc->{'main'}->{'volume'}, "2 0");	# add ACH ventilation to main from basement. In this line the differences in volume are accounted for
						};
					}
					elsif ($zone eq 'attc' || $zone eq 'roof') {
						foreach my $day (@days) {	# do for each day type
							&replace ($hse_file->{"$zone.opr"}, "#END_AIR_$day", 1, -1, "%s\n", "0 24 0.5 0 1 0");	# add 0.5 ACH infiltration.
						};
					}
					
					# Determine a constant ACH rate for a crawl space based on its foundation type
					elsif ($zone eq 'crwl') {	# crawl requires specification of AC/h
						# delcare a crawl space AC/h per hour hash with foundation_type keys. Lookup the value based on the foundation_type and store it.
						my $crwl_ach = {8 => 0.5, 9 => 0.1}->{$record_indc->{'foundation'}} # foundation type 8 is loose (0.5 AC/h) and type 9 is tight (0.1 AC/h)
							or &die_msg ('OPR: No crawl space AC/h key for foundation', $record_indc->{'foundation'}, $coordinates);
						foreach my $day (@days) {	# do for each day type
							&replace ($hse_file->{"$zone.opr"}, "#END_AIR_$day", 1, -1, "%s\n", "0 24 $crwl_ach 0 1 0") ;	# add infiltration
						};
					};
				};
			};
			
			# -----------------------------------------------
			# Determine DHW and AL bcd file
			# -----------------------------------------------
			BCD: {
				# The following logic selects the most appropriate BCD file for the house.
				
				# Define the array of fields to check for. Note that the AL components Stove and Other are combined here because we cannot differentiate them with the NN
				my @bcd_fields = ('DHW_LpY', 'AL-Stove-Other_GJpY', 'AL-Dryer_GJpY');

# 				# Determine the consumption of the Dryer itself by using the two NN results, but store this at the actual house
# 				$dhw_al->{'data'}->{$CSDDRD->{'file_name'}.'.HDF'}->{'AL-Dryer_GJpY'} = $dhw_al->{'data'}->{$CSDDRD->{'file_name'}.'.HDF'}->{'AL_GJpY'} - $dhw_al->{'data'}->{$CSDDRD->{'file_name'}.'.HDF.No-Dryer'}->{'AL_GJpY'};
# 				
# 				# Store the AL Stove and Other use under the appropriate name at the house for naming simplicity
# 				$dhw_al->{'data'}->{$CSDDRD->{'file_name'}.'.HDF'}->{'AL-Stove-Other_GJpY'} = $dhw_al->{'data'}->{$CSDDRD->{'file_name'}.'.HDF.No-Dryer'}->{'AL_GJpY'};
				
				# intialize an array to store the best BCD filename and the difference between its annual consumption and house's annual consumption
				my $bcd_match;
				foreach my $field (@bcd_fields) {
					$bcd_match->{$field} = {'filename' => 'big-example', 'difference' => 1e9};
				};


				# cycle through all of the available annual BCD files (typically 3 * 3 * 3 = 27 files)
				foreach my $bcd (keys (%{$BCD_dhw_al_ann->{'data'}})) {	# each bcd filename
				
					# Set a value for AL Stove and Other because we cannot differentiate between them with the NN
					$BCD_dhw_al_ann->{'data'}->{$bcd}->{'AL-Stove-Other_GJpY'} = $BCD_dhw_al_ann->{'data'}->{$bcd}->{'AL-Stove_GJpY'} + $BCD_dhw_al_ann->{'data'}->{$bcd}->{'AL-Other_GJpY'};
					
					foreach my $field (@bcd_fields) {	# the DHW and AL fields
						# record the absolute difference between the BCD annual value and the house's annual value
						my $difference = abs ($dhw_al->{'data'}->{$CSDDRD->{'file_name'}.'.HDF'}->{$field} - $BCD_dhw_al_ann->{'data'}->{$bcd}->{$field});

						# if the difference is less than previously noted, replace the filename and update the difference
						if ($difference < $bcd_match->{$field}->{'difference'}) {
							$bcd_match->{$field}->{'difference'} = $difference;	# update the value
							
							# check which field because they have difference search functions
							if ($field eq 'DHW_LpY') {
								# record the important portion of the bcd filename
								($bcd_match->{$field}->{'filename'}) = ($bcd =~ /^(DHW_\d+_Lpd)\..+/);
							}
							elsif ($field eq 'AL-Dryer_GJpY') {
								($bcd_match->{$field}->{'filename'}) = ($bcd =~ /.+_(Dryer-\w+)_Other.+/);
							}
							# because Stove and Other are linked in their level, we only record the Stove level
							elsif ($field eq 'AL-Stove-Other_GJpY') {
								($bcd_match->{$field}->{'filename'}) = ($bcd =~ /.+\.AL_(Stove-\w+)_Dryer.+/);
							}
							else {&die_msg ("BCD ISSUE: there is no search defined for this field: $field", $coordinates);};
						};
					};
				};
				
				$BCD_characteristics->{$CSDDRD->{'file_name'}}->{'hse_type'} = $hse_type;
				$BCD_characteristics->{$CSDDRD->{'file_name'}}->{'region'} = $region;

				
				foreach my $field (@bcd_fields) {	# the DHW and AL fields
					$BCD_characteristics->{$CSDDRD->{'file_name'}}->{$field}->{'filename'} = $bcd_match->{$field}->{'filename'};
				};
				
				
				my $bcd_file;	# declare a scalar to store the name of the most appropriate bcd file
				
				# cycle through the bcd filenames and look for one that matches the most applicable filename for both the DHW and AL 
				foreach my $bcd (keys (%{$BCD_dhw_al_ann->{'data'}})) {
					my $found = 1;	# set an indicator variable to true, if the bcd filename does not match this is turned off
					foreach my $field (@bcd_fields) {	# cycle through DHW and AL
						# check for a match. If there is one then $found is true and if it does not match then false.
						# The logical return is trying to find the bcd_match filename string within the bcd filename
						# Note that in the case of 'AL-Stove-Other_GJpY' we check for the Stove level because it is the same as the Other level
						unless ($bcd =~ $bcd_match->{$field}->{'filename'}) {$found = 0;};
					};
					
					# Check to see if both filename parts were satisfied
					if ($found == 1) {$bcd_file = $bcd;};
					
				};
				
				# replace the bcd filename in the cfg file
				&replace ($hse_file->{'cfg'}, "#BCD", 1, 1, "%s\n", "*bcd ../../../bcd/$bcd_file");	# boundary condition path


				# -----------------------------------------------
				# Appliance and Lighting 
				# -----------------------------------------------
				AL: {
				
					# Delare and then fill out a multiplier hash reference;
					my $mult = {};
					# dryer mult = AL-Dryer / BCD-Dryer
					$mult->{'AL-Dryer'} = $dhw_al->{'data'}->{$CSDDRD->{'file_name'}.'.HDF'}->{'AL-Dryer_GJpY'} / $BCD_dhw_al_ann->{'data'}->{$bcd_file}->{'AL-Dryer_GJpY'};
					# stove and other mult = AL-Stove-Other / (BCD-Stove-Other)
					$mult->{'AL-Stove'} = $dhw_al->{'data'}->{$CSDDRD->{'file_name'}.'.HDF'}->{'AL-Stove-Other_GJpY'} / $BCD_dhw_al_ann->{'data'}->{$bcd_file}->{'AL-Stove-Other_GJpY'};
					# note that the AL-Other is the same multiplier as AL-Stove
					$mult->{'AL-Other'} = $mult->{'AL-Stove'};
					
					
					# Modify the multipliers if the stove or dryer is natural gas. They are increased to account for NG heating inefficiency
					# even for a stove there is more NG required because oven is not sealed
					# note that this can create a difference between the AL-Other and AL-Stove multipliers
					if ($CSDDRD->{'stove_fuel_use'} == 1) {$mult->{'AL-Stove'}  = $mult->{'AL-Stove'} * 1.10};
					if ($CSDDRD->{'dryer_fuel_used'} == 1) {$mult->{'AL-Dryer'}  = $mult->{'AL-Dryer'} * 1.10};
					
					# cycle through the multipliers and format them to two decimal places
					foreach my $key (keys (%{$mult})) {
						$mult->{$key} = sprintf ("%.2f", $mult->{$key});
					};
					
					$BCD_characteristics->{$CSDDRD->{'file_name'}}->{'AL-Dryer_GJpY'}->{'multiplier'} = $mult->{'AL-Dryer'};
					$BCD_characteristics->{$CSDDRD->{'file_name'}}->{'AL-Stove-Other_GJpY'}->{'multiplier'} = $mult->{'AL-Stove'};

					# -----------------------------------------------
					# Place the electrical load profiles onto the Electrical Network File
					# -----------------------------------------------

					# replace the cfg name
					&replace ($hse_file->{'elec'}, '#CFG_FILE', 1, 1, "  %s\n", "./$CSDDRD->{'file_name'}.cfg");

					# insert the data and string items for each component
					my $component = 0;
					foreach my $field (keys (%{$mult})) {
						unless (($field eq 'AL-Stove' && $CSDDRD->{'stove_fuel_use'} == 1) || ($field eq 'AL-Dryer' && $CSDDRD->{'dryer_fuel_used'} == 1)) {
							$component++;
							&insert ($hse_file->{'elec'}, '#END_POWER_ONLY_COMPONENT_INFO', 1, 0, 0, "  %s\n", "$component   18  $field       1-phase         1    0    0");
							&insert ($hse_file->{'elec'}, '#END_POWER_ONLY_COMPONENT_INFO', 1, 0, 0, "  %s\n", "Appliance and Lighting Load due to $field imposed on the Electrical Network Only");
							&insert ($hse_file->{'elec'}, '#END_POWER_ONLY_COMPONENT_INFO', 1, 0, 0, "  %s\n", '4 1');
							&insert ($hse_file->{'elec'}, '#END_POWER_ONLY_COMPONENT_INFO', 1, 0, 0, "  %s %s\n", $mult->{$field}, '1 0 2');
							&insert ($hse_file->{'elec'}, '#END_POWER_ONLY_COMPONENT_INFO', 1, 0, 0, "  %s\n", $field);
						};
					};
					
					&replace ($hse_file->{'elec'}, '#NUM_POWER_ONLY_COMPONENTS', 1, 1, "  %s\n", $component);

					# -----------------------------------------------
					# Place the heat and NG load profiles onto the *.opr file
					# -----------------------------------------------
					my @days = ('WEEKDAY', 'SATURDAY', 'SUNDAY');
					my $adult = 100;
					my $child = 50;
					
					foreach my $zone (keys (%{$zone_indc})) { 
# 					&replace ($hse_file->{"$zone.opr"}, "#DATE", 1, 1, "%s\n", "*date $time");	# set the time/date for the main.opr file
					# if no other zones exist then do not modify the main.opr (its only use is for ventilation with the bsmt due to the aim and fcl files

						my $vol_ratio = sprintf('%.2f', $record_indc->{$zone}->{'volume'} / $record_indc->{'vol_conditioned'});

						# Type 1  is occupants
						# Type 20 is electric stove
						# Type 21 is NG stove
						# Type 22 is AL-Other
						# Type 23 is NG dryer

						if ($zone eq 'main' || $zone eq 'bsmt') {
							foreach my $day (@days) {	# do for each day type
								# count the gains for the day so this may be inserted
								my $gains = 0;
								
								
								
								
								# attribute the AL-Other gains to both main and bsmt by volume
								&insert ($hse_file->{"$zone.opr"}, "#END_CASUAL_$day", 1, 0, 0, "%s %.2f %.2f %s\n",	# AL casual gains (divided by volume).
									'22 0 24',	# type # and begin/end hours of day
									$vol_ratio * $mult->{'AL-Other'},	# sensible fraction (it must all be sensible)
									0,	# latent fraction
									'0.5 0.5');	# rad and conv fractions
								$gains++; # increment the gains counter
								
								if ($zone eq 'main') {
									my $stove_type;
									if ($CSDDRD->{'stove_fuel_use'} == 1) {$stove_type = 21}
									else {$stove_type = 20};
									
									&insert ($hse_file->{"$zone.opr"}, "#END_CASUAL_$day", 1, 0, 0, "%u %s %.2f %.2f %s\n",	# AL casual gains (divided by volume).
										$stove_type,
										'0 24',	# type # and begin/end hours of day
										$mult->{'AL-Stove'},	# sensible fraction (it must all be sensible)
										0,	# latent fraction
										'0.5 0.5');	# rad and conv fractions
									$gains++; # increment the gains counter
									
									if ($CSDDRD->{'dryer_fuel_used'} == 1) {
										&insert ($hse_file->{"$zone.opr"}, "#END_CASUAL_$day", 1, 0, 0, "%s %.2f %.2f %s\n",	# AL casual gains (divided by volume).
											'23 0 24',	# type # and begin/end hours of day
											$mult->{'AL-Dryer'},	# sensible fraction (it must all be sensible)
											0,	# latent fraction
											'0.5 0.5');	# rad and conv fractions
										$gains++; # increment the gains counter
									};
								};
								
								&insert ($hse_file->{"$zone.opr"}, "#CASUAL_$day", 1, 1, 0, "%u\n", $gains);
							};
						}
						
# 						elsif ($zone eq 'bsmt') {
# 							foreach my $day (@days) {	# do for each day type
# 								&insert ($hse_file->{"$zone.opr"}, "#CASUAL_$day", 1, 1, 0, "%s\n%s %s %s %s\n",	# AL casual gains (divided by volume).
# 									'1',	# 1 gain type
# 									'5 0 24',	# type 5 (AL from Elec) and 24 hours per day
# 									sprintf('%.2f', 1. * $record_indc->{$zone}->{'volume'} / $record_indc->{'vol_conditioned'}),	# sensible fraction
# 									sprintf('%.2f', 0. * $record_indc->{$zone}->{'volume'} / $record_indc->{'vol_conditioned'}),	# latent fraction
# 									'0.5 0.5');	# rad and conv fractions
# 							};
# 						}
						
						else {
							foreach my $day (@days) {	# do for each day type
								&insert ($hse_file->{"$zone.opr"}, "#CASUAL_$day", 1, 1, 0, "%s\n", 0);	# no equipment casual gains (set W to zero).
							};
						};
					};
				};


	# 			-----------------------------------------------
	# 			DHW file
	# 			-----------------------------------------------
				DHW: {
					if ($CSDDRD->{'DHW_energy_src'} == 9) {	# DHW is not available, so comment the *dhw line in the cfg file
						foreach my $line (@{$hse_file->{'cfg'}}) {	# read each line of cfg
							if ($line =~ /^(\*dhw.*)/) {	# if the *dhw tag is found then
								$line = "#$1\n";	# comment the *dhw tag
								last DHW;	# when found jump out of loop and DHW all together
							};
						};
					}
					else {	# DHW file exists and is used
						my $multiplier = sprintf ("%.2f", $dhw_al->{'data'}{$CSDDRD->{'file_name'}.'.HDF'}->{'DHW_LpY'} / $BCD_dhw_al_ann->{'data'}->{$bcd_file}->{'DHW_LpY'});
						
						$BCD_characteristics->{$CSDDRD->{'file_name'}}->{'DHW_LpY'}->{'multiplier'} = $multiplier;
					
						&replace ($hse_file->{"dhw"}, "#BCD_MULTIPLIER", 1, 1, "%.2f\n", $multiplier);	# DHW multiplier
						if ($zone_indc->{'bsmt'}) {&replace ($hse_file->{"dhw"}, "#ZONE_WITH_TANK", 1, 1, "%s\n", 2);}	# tank is in bsmt zone
						else {&replace ($hse_file->{"dhw"}, "#ZONE_WITH_TANK", 1, 1, "%s\n", 1);};	# tank is in main zone

						my $energy_src = $dhw_energy_src->{'energy_type'}->[$CSDDRD->{'DHW_energy_src'}];	# make ref to shorten the name
						&replace ($hse_file->{"dhw"}, "#ENERGY_SRC", 1, 1, "%s %s %s\n", $energy_src->{'ESP-r_dhw_num'}, "#", $energy_src->{'description'});	# cross ref the energy src type

						my $tank_type = $energy_src->{'tank_type'}->[$CSDDRD->{'DHW_equip_type'}];	# make ref to shorten the tank type name
						&replace ($hse_file->{"dhw"}, "#TANK_TYPE", 1, 1, "%s %s %s\n", $tank_type->{'ESP-r_tank_num'}, "#", $tank_type->{'description'});	# cross ref the tank type

						&replace ($hse_file->{"dhw"}, "#TANK_EFF", 1, 1, "%s\n", $CSDDRD->{'DHW_eff'});	# tank efficiency

						&replace ($hse_file->{"dhw"}, "#ELEMENT_WATTS", 1, 1, "%s\n", $tank_type->{'Element_watts'});	# cross ref the element watts

						&replace ($hse_file->{"dhw"}, "#PILOT_WATTS", 1, 1, "%s\n", $tank_type->{'Pilot_watts'});	# cross ref the pilot watts
					};
				};
				
			};


			# -----------------------------------------------
			# Print out each esp-r house file for the house record
			# -----------------------------------------------
			FILE_PRINTOUT: {
				# Develop a path and make the directory tree to get to that path
				my $output_path = "../$hse_type/$region/$CSDDRD->{'file_name'}";	# path to the folder for writing the house folder
				mkpath ("$output_path");	# make the output path directory tree to store the house files
				
				foreach my $ext (keys %{$hse_file}) {	# go through each extention inclusive of the zones for this particular record
					open (FILE, '>', "$output_path/$CSDDRD->{'file_name'}.$ext") or die ("can't open datafile: $output_path/$CSDDRD->{'file_name'}.$ext");	# open a file on the hard drive in the directory tree
					foreach my $line (@{$hse_file->{$ext}}) {print FILE "$line";};	# loop through each element of the array (i.e. line of the final file) and print each line out
					close FILE;
				};
				copy ("../templates/input.xml", "$output_path/input.xml") or die ("can't copy file: input.xml");	# add an input.xml file to the house for XML reporting of results
			};


			# DETERMINE THE WINDOW INFO CORRESPONDING TO THE APPROPRIATE SIDE
			if ($window_print[4] == 1 || $window_print[4] == 2 || $window_print[4] == 8) {
				push (@window_print, @window_print[5..8]);
			}
			elsif ($window_print[4] == 3) {
				push (@window_print, $window_print[8]);
				push (@window_print, @window_print[5..7]);
			}
			elsif ($window_print[4] == 4 || $window_print[4] == 5 || $window_print[4] == 6) {
				push (@window_print, @window_print[7..8]);
				push (@window_print, @window_print[5..6]);
			}
			elsif ($window_print[4] == 7) {
				push (@window_print, @window_print[6..8]);
				push (@window_print, $window_print[5]);
			};

			if ($window_print[4] == 1 || $window_print[4] == 2 || $window_print[4] == 8) {
				push (@window_area_print, @window_area_print[0..3]);
			}
			elsif ($window_print[4] == 3) {
				push (@window_area_print, $window_area_print[3]);
				push (@window_area_print, @window_area_print[0..2]);
			}
			elsif ($window_print[4] == 4 || $window_print[4] == 5 || $window_print[4] == 6) {
				push (@window_area_print, @window_area_print[2..3]);
				push (@window_area_print, @window_area_print[0..1]);
			}
			elsif ($window_print[4] == 7) {
				push (@window_area_print, @window_area_print[1..3]);
				push (@window_area_print, $window_area_print[0]);
			};

			# PRINT OUT THE WINDOW INFO CORRESPONDING TO THE APPROPRIATE SIDE
			print WINDOW CSVjoin(@window_print, @window_area_print[4..7], @window_bad);
			print WINDOW "\n";
			
			$models_OK++;
		};	# end of the while loop through the CSDDRD->
		
	close WINDOW;
	close $CSDDRD_FILE;
	
	print "Thread for Model Generation of $hse_type $region - Complete\n";
# 	print Dumper $issues;
# 	return ([$models_attempted, $models_OK]);
	
	my $return = {'issues' => $issues, 'BCD_characteristics' => $BCD_characteristics};

	return ($return);
	
	};	# end of main code
};

# -----------------------------------------------
# Subroutines
# -----------------------------------------------
SUBROUTINES: {

	sub replace {	# subroutine to perform a simple element replace (house file to read/write, keyword to identify row, rows below keyword to replace, replacement text)
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
		
		return (1);
	};

	sub insert {	# subroutine to perform a simple element insert after (specified) the identified element (house file to read/write, keyword to identify row, number of elements after to do insert, replacement text)
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
		return (1);
	};
	
	sub die_msg {	# subroutine to die and give a message
		my $msg = shift (@_);	# the error message to print
		my $value = shift (@_); # the error value
		my $coordinates = shift (@_); # house type, region, house name

		die "MODEL ERROR - $msg; Value = $value; $coordinates\n";
	};

	sub copy_template {	# copy the template file for a particular house
		my $zone = shift;
		my $ext = shift;
		my $hse_file = shift;
		my $coordinates = shift;
		
		if (defined ($template->{$ext})) {
			$hse_file->{"$zone.$ext"} = [@{$template->{$ext}}];	# create the template file for the zone
		}
		else {&die_msg ('INITIALIZE HOUSE FILES: missing template', $ext, $coordinates);};
		return (1);
	};



};
