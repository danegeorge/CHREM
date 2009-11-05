#!/usr/bin/perl

# ====================================================================
# Hse_Gen.pl
# Author: Lukas Swan
# Date: Oct 2009
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
use lib ('./CHREM_modules');

use CSV;	# CSV-2 (for CSV split and join, this works best)
# use Array::Compare;	# Array-Compare-1.15
use threads;	# threads-1.71 (to multithread the program)
use File::Path;	# File-Path-2.04 (to create directory trees)
use File::Copy;	# (to copy the input.xml file)
use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
use Data::Dumper;	# to dump info to the terminal for debugging purposes
use Switch;
use Storable  qw(dclone);
use Hash::Merge qw(merge);


use CHREM_module_General ('hse_types_and_regions', 'one_data_line', 'largest', 'smallest', 'check_range', 'set_issue', 'print_issues');
use CHREM_module_Cross_ref ('cross_ref_readin', 'key_XML_readin');
use CHREM_module_Database ('database_XML');
use CHREM_module_Constructions ('con_layers', 'con_reverse', 'con_10_dig', 'con_5_dig', 'con_6_dig');

$Data::Dumper::Sortkeys = 1;

Hash::Merge::specify_behavior(
	{
		'SCALAR' => {
			'SCALAR' => sub {$_[0] + $_[1]},
			'ARRAY'  => sub {[$_[0], @{$_[1]}]},
			'HASH'   => sub {$_[1]->{$_[0]} = undef},
		},
		'ARRAY' => {
			'SCALAR' => sub {[@{$_[0]}, $_[1]]},
			'ARRAY'  => sub {[@{$_[0]}, @{$_[1]}]},
			'HASH'   => sub {[@{$_[0]}, $_[1]]},
		},
		'HASH' => {
			'SCALAR' => sub {$_[0]->{$_[1]} = undef},
			'ARRAY'  => sub {[@{$_[1]}, $_[0]]},
			'HASH'   => sub {Hash::Merge::_merge_hashes($_[0], $_[1])},
		},
	}, 
	'Merge where scalars are added, and items are appended to arrays', 
);

# --------------------------------------------------------------------
# Declare the global variables
# --------------------------------------------------------------------

my $hse_types;	# declare an hash array to store the house types to be modeled (e.g. 1 -> 1-SD)
my $regions;	# declare an hash array to store the regions to be modeled (e.g. 1 -> 1-AT)

my $time_step;	# declare a scalar to hold the timestep in minutes
my @houses_desired; # declare an array to store the house names or part of to look

# --------------------------------------------------------------------
# Read the command line input arguments
# --------------------------------------------------------------------

COMMAND_LINE: {
	if (@ARGV == 0 || @ARGV == 2) {die "Three arguments are required: house_types regions simulation_time-step_(minutes); or \"db\" for database generation\n";};	# check for proper argument count

	if ($ARGV[0] eq 'db') {database_XML(); exit;};	# construct the databases and leave the information loaded in the variables for use in house generation


	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
	($hse_types, $regions) = hse_types_and_regions(shift (@ARGV), shift (@ARGV));
	
	if (shift (@ARGV) =~ /([1-60])/) {$time_step = $1;}
	else {die "Simulation time-step must be equal to or between 1 and 60 minutes\n";};
	
	@houses_desired = @ARGV;
	if (@houses_desired == 0) {@houses_desired = '.'};
};

# -----------------------------------------------
# Develop the ESP-r databases and cross reference keys
# -----------------------------------------------
(my $mat_data, my $con_data, my $optic_data) = database_XML();	# construct the databases and leave the information loaded in the variables for use in house generation

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
my @BCD_dhw_al_ann_files = <../bcd/ANNUAL_$time_step*>;	# only find cross referencing files that have the correct time-step in minutes

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

# hash reference to store encountered issues during the house builds
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
	
	my $code_store = {};
	
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
			$code_store = merge($code_store, $thread_return->{$hse_type}->{$region}->{'con_info'});
			
		};
	};

	close BCD_FILE_MULT;
	
	my $code_path_3 = '../summary_files/ALL-types_ALL-regions_code-count';
	
	{	open (my $CODE_COUNT, '>', "$code_path_3.txt") or die ("can't open datafile: $code_path_3.txt");	# open the a CODE REPORT file
	
		{
			local $Data::Dumper::Sortkeys = \&zone_surf_order;
			print $CODE_COUNT Dumper $code_store;
		};
		
	};
	
	{	open (my $CODE_COUNT, '>', "$code_path_3.csv") or die ("can't open datafile: $code_path_3.csv");	# open the a CODE REPORT file
		
		{
			my @header = qw(zone surface);
			foreach my $zone (@{zone_surf_order($code_store)}) {
				foreach my $surface (@{zone_surf_order($code_store->{$zone})}) {
					my @line = ($zone, $surface);
					foreach my $value (@{zone_surf_order($code_store->{$zone}->{$surface})}) {
						
						unless ($value =~ /^name$|^codes$/) {
							unless (@header == 0) {push(@header, $value);};
							push(@line, $code_store->{$zone}->{$surface}->{$value});
						}
						else {
							foreach my $field (sort keys (%{$code_store->{$zone}->{$surface}->{$value}})) {
								push(@line, $field, $code_store->{$zone}->{$surface}->{$value}->{$field});
							};
						};
					};
					unless (@header == 0) {
						push(@header, 'name or code followed by count');
						print $CODE_COUNT CSVjoin(@header) . "\n";
						@header = ();
					};
					print $CODE_COUNT CSVjoin(@line) . "\n";
				};
			};
		};
	};
	
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
		
		# storage for the houses characteristics for looking up BCD information
		my $BCD_characteristics;


		my $code_path = '../summary_files/' . $hse_type . '_' . $region . '_code-report';
		my $code_store;
		open (my $CODE_REPORT, '>', "$code_path.csv") or die ("can't open datafile: $code_path.csv");	# open the a CODE REPORT file
		print $CODE_REPORT "zone,surface,name,RSI,code,\"layers followed by description\"\n";

		# -----------------------------------------------
		# GO THROUGH EACH LINE OF THE CSDDRD SOURCE DATAFILE AND BUILD THE HOUSE MODELS
		# -----------------------------------------------
		
		RECORD: while ($CSDDRD = one_data_line($CSDDRD_FILE, $CSDDRD)) {	# go through each line (house) of the file
# 			print Dumper $CSDDRD;

			# flag to indicate to proceed with house build
			my $desired_house = 0;
			# cycle through the desired house names to see if this house matches. If so continue the house build
			foreach my $house_name (@houses_desired) {
				# it matches, so set the flag
				if ($CSDDRD->{'file_name'} =~ /^$house_name/) {$desired_house = 1};
			};
			# if the flag was not set, go to the next house record
			if ($desired_house == 0) {next RECORD};
			
			
			$models_attempted++;	# count the models attempted

			my $time= localtime();	# note the present time
			
			# house file coordinates to print when an error is encountered
			my $coordinates = {'hse_type' => $hse_type, 'region' => $region, 'file_name' => $CSDDRD->{'file_name'}};
			
			# remove the trailing HDF from the house name and check for bad filename
			$CSDDRD->{'file_name'} =~ s/.HDF// or  &die_msg ('RECORD: Bad record name (no *.HDF)', $CSDDRD->{'file_name'}, $coordinates);


			# DECLARE ZONE AND PROPERTY HASHES.
			my $zones->{'name->num'} = {};	# hash ref of zone_names => zone_numbers

			my $record_indc = {};	# hash for holding the indication of dwelling properties: many of these are building and zone related are held under zone keys
			
			# Determine the climate for this house from the Climate Cross Reference
			my $climate = $climate_ref->{'data'}->{$CSDDRD->{'HOT2XP_CITY'}};	# shorten the name for use this house

			my $high_level = 1;	# initialize the highest main floor level (1-3)

			# key to the attachment: NOTE this is the attached side (adiabatic) and stores the side name
			my $attachment_side = {1 => 'none', 2 => 'right', 3 => 'left', 4 => 'right and left'}->{$CSDDRD->{'attachment_type'}}
						or &die_msg ('Attachment: bad attachment value (1-24', $CSDDRD->{'attachment_type'}, $coordinates);
			
			# describe the basic sides of the house
			my @sides = ('front', 'right', 'back', 'left');
			
			
			# -----------------------------------------------
			# DETERMINE ZONE INFORMATION (NUMBER AND TYPE) FOR USE IN THE GENERATION OF ZONE TEMPLATES
			# -----------------------------------------------
			ZONE_PRESENCE: {
				# FOUNDATION CHECK TO DETERMINE IF A BSMT OR CRWL ZONES ARE REQUIRED, IF SO SET TO ZONE #2
				# ALSO SET A FOUNDATION INDICATOR EQUAL TO THE APPROPRIATE TYPE
				# FLOOR AREAS (m^2) OF FOUNDATIONS ARE LISTED IN CSDDRD[97:99]
				# FOUNDATION TYPE IS LISTED IN CSDDRD[15]- 1:6 ARE BSMT, 7:9 ARE CRWL, 10 IS SLAB (NOTE THEY DONT' ALWAYS ALIGN WITH SIZES, THEREFORE USE FLOOR AREA AS FOUNDATION TYPE DECISION
				
				# foundation key corresponding to HOT2XP
				my $foundation = {1 => 'full', 2 => 'shallow', 3 => 'front', 4 => 'back', 5 => 'left', 6 => 'right', 7 => 'open', 8 => 'ventilated', 9 => 'closed', 10 => 'slab'};
				
				
				# BSMT CHECK
				if (($CSDDRD->{'bsmt_floor_area'} >= $CSDDRD->{'crawl_floor_area'}) && ($CSDDRD->{'bsmt_floor_area'} >= $CSDDRD->{'slab_on_grade_floor_area'})) {	# compare the bsmt floor area to the crawl and slab
					$zones->{'name->num'}->{'bsmt'} = keys(%{$zones->{'name->num'}}) + 1;	# bsmt floor area is dominant, so there is a basement zone
					if ($CSDDRD->{'foundation_type'} <= 6) {$record_indc->{'foundation'} = $foundation->{$CSDDRD->{'foundation_type'}};}	# the CSDDRD foundation type corresponds, use it in the record indicator description
					else {$record_indc->{'foundation'} = $foundation->{1};};	# the CSDDRD foundation type doesn't correspond (but floor area was dominant), assume "full" basement
					
					# examine the exposed sides of a walkout basement
					foreach my $surface (@sides) {
						# check to see if the side matches the walkout foundation type (this is eq not // because we will update the foundation below and don't want to trigger again)
						if ($record_indc->{'foundation'} eq $surface) {
							
							# walkout so check for its side existance being the same as the attachment side and if so set it to back walkout
							if ($attachment_side =~ $record_indc->{'foundation'}) {
								# it is the same, so set it equal to a back walkout and note in the issues
								$issues = set_issue("%s", $issues, 'Walkout', 'walkout side blocked - foundation type is listed; making back walkout', $record_indc->{'foundation'}, $coordinates);
								$record_indc->{'foundation'} = $foundation->{4};
							};
							
							# create a hash reference that stores the second exposed walkout side for comparison purposes. This will be used to select the second exposed side if available
							my $alt_sides;
							# shift-right means front => right, right => back ...
							@{$alt_sides->{'shift-right'}}{@sides} = (@sides[1..$#sides], $sides[0]);
							# shift-left means front => left, right => front
							@{$alt_sides->{'shift-left'}}{@sides} = ($sides[$#sides], @sides[0..($#sides - 1)]);
							
							# compare the shifted sides to see if they are limited by the attachment side
							# check if the side to the right of the walkout side is the attachement side
							if ($attachment_side !~ $alt_sides->{'shift-right'}->{$record_indc->{'foundation'}}) {
								# it is not the attachment side, so rename the  foundation "side-right_shifted_side" (e.g. front-right)
								$record_indc->{'foundation'} = $record_indc->{'foundation'} . '-' . $alt_sides->{'shift-right'}->{$record_indc->{'foundation'}};
							}
							elsif ($attachment_side !~ $alt_sides->{'shift-left'}->{$record_indc->{'foundation'}}) {
								# it is not the attachment side, so rename the  foundation "side-left_shifted_side" (e.g. front-left)
								$record_indc->{'foundation'} = $record_indc->{'foundation'} . '-' . $alt_sides->{'shift-left'}->{$record_indc->{'foundation'}};
							};
							# if neither of these worked then perhaps we have a middle-row house with front or back walkout. In this case only that side is exposed then.
						};
					};
					
				}
				
				# CRWL CHECK
				elsif (($CSDDRD->{'crawl_floor_area'} >= $CSDDRD->{'bsmt_floor_area'}) && ($CSDDRD->{'crawl_floor_area'} >= $CSDDRD->{'slab_on_grade_floor_area'})) {	# compare the crawl floor area to the bsmt and slab
					# crawl space floor area is dominant, but check the type prior to creating a zone
					if ($CSDDRD->{'foundation_type'} != 7) {	# check that the crawl space is either "ventilated" or "closed" ("open" is treated as exposed main floor)
						$zones->{'name->num'}->{'crawl'} = keys(%{$zones->{'name->num'}}) + 1;	# create the crawl zone
						if (($CSDDRD->{'foundation_type'} >= 8) && ($CSDDRD->{'foundation_type'} <= 9)) {$record_indc->{'foundation'} = $foundation->{$CSDDRD->{'foundation_type'}};}	# the CSDDRD foundation type corresponds, use it in the record indicator description
						else {$record_indc->{'foundation'} = $foundation->{8};};	# the CSDDRD foundation type doesn't correspond (but floor area was dominant), assume "ventilated" crawl space
					}
					else {$record_indc->{'foundation'} = $foundation->{7};};	# the crawl is actually "open" with large ventilation, so treat it as an exposed main floor with no crawl zone
				}
				
				# SLAB CHECK
				elsif (($CSDDRD->{'slab_on_grade_floor_area'} >= $CSDDRD->{'bsmt_floor_area'}) && ($CSDDRD->{'slab_on_grade_floor_area'} >= $CSDDRD->{'crawl_floor_area'})) { # compare the slab floor area to the bsmt and crawl
					$record_indc->{'foundation'} = $foundation->{10};	# slab floor area is dominant, so set the foundation to 10
				}
				
				# FOUNDATION ERROR
# 				else {&error_msg ('Bad foundation determination', $coordinates);};
				else {&die_msg ('ZONE PRESENCE: Bad foundation determination', 'foundation areas cannot be used to determine largest',$coordinates);};

				# initialize the main zone levels - there can be up to three levels
				# do level 1 first as it exists in all of the houses
				my $level = 1;
				$zones->{'name->num'}->{"main_$level"} = keys(%{$zones->{'name->num'}}) + 1;	# set the zone numeric value
				
				
				# examine the next main levels to see if they exist (by area)
				$level++;	# operate on level 2
				
				# check to see if level 2 exists, and if so then check level floor area (> 5 m^2)
				if ($CSDDRD->{'main_floor_area_' . $level} > 5) {	# does it exist based on area
					$zones->{'name->num'}->{"main_$level"} = keys(%{$zones->{'name->num'}}) + 1;	# set the zone numeric value
					# record this new high level
					$high_level = $level;
					
					# check for a third level
					$level++;	# since there is a level 2, check for a level 3
					if ($CSDDRD->{'main_floor_area_' . $level} > 5) {	# does it exist based on area
						$zones->{'name->num'}->{"main_$level"} = keys(%{$zones->{'name->num'}}) + 1;	# set the zone numeric value
						$high_level = $level;
					};
				}
				
				# if level 2 did not exist, check level three and make sure it does not exist (impossible)
				elsif ($CSDDRD->{'main_floor_area_' . ($level + 1)} > 5) {	# does it exist based on area
					# level 3 exists, but level 2 did not, so die.
					&die_msg ('ZONE PRESENCE: main_levels', 'main_3 exists but main_2 does not',$coordinates);
				};



				# ATTIC CHECK- COMPARE THE CEILING TYPE TO DISCERN IF THERE IS AN ATTC ZONE
				
				# THE FLAT CEILING TYPE IS LISTED IN CSDDRD AND WILL HAVE A VALUE NOT EQUAL TO 1 (N/A) OR 5 (FLAT ROOF) IF AN ATTIC IS PRESENT
				if (($CSDDRD->{'ceiling_flat_type'} != 1) && ($CSDDRD->{'ceiling_flat_type'} != 5)) {	# set attic zone indicator unless flat ceiling is type "N/A" or "flat"
					$zones->{'name->num'}->{'attic'} = keys(%{$zones->{'name->num'}}) + 1;
				}
				
				# CEILING TYPE ERROR
				elsif (($CSDDRD->{'ceiling_flat_type'} < 1) || ($CSDDRD->{'ceiling_flat_type'} > 6)) {
# 					&error_msg ('Bad flat roof type', $coordinates);
					&die_msg ('ZONE PRESENCE: Bad flat roof type (<1 or >6)', $CSDDRD->{'ceiling_flat_type'}, $coordinates);
				}
				
				# IF IT IS A FLAT CEILING, THEN CREATE A ROOF AIRSPACE ZONE
				else {
					$zones->{'name->num'}->{'roof'} = keys(%{$zones->{'name->num'}}) + 1;
				};
				
				# check to find the dominant ceiling type based on area so that we use that code and RSI in subsequent efforts
				my $ceiling_dominant;
				# check if flat is dominant
				if ($CSDDRD->{'ceiling_flat_area'} >= $CSDDRD->{'ceiling_sloped_area'}) {$ceiling_dominant = 'flat';}
				# check if sloped is dominant
				elsif ($CSDDRD->{'ceiling_flat_area'} < $CSDDRD->{'ceiling_sloped_area'}){$ceiling_dominant = 'sloped';}
				else {die_msg ('INITIALIZE CEILING TYPE: bad areas', $CSDDRD->{'ceiling_flat_area'}, $coordinates);};
				
				# cycle through the CSDDRD and find any field with the dominant ceiling type and make a new variable with 'dominant' to store it
				foreach my $ceiling_var (keys (%{$CSDDRD})) {
					if ($ceiling_var =~ /^ceiling_$ceiling_dominant(\w+)$/) {
						$CSDDRD->{'ceiling_dominant' . $1} = $CSDDRD->{$ceiling_var};
					};
				};
			

				# since we have completed the fill of zone names/numbers in order, reverse the hash ref to be a zone number lookup for a name
				$zones->{'num->name'} = {reverse (%{$zones->{'name->num'}})};
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
				foreach my $zone (keys (%{$zones->{'name->num'}})) {
					# files required for each zone
					foreach my $ext ('opr', 'con', 'geo') {
						&copy_template($zone, $ext, $hse_file, $coordinates);
					};
					
					# create the BASESIMP file for the applicable zone
					my $ext = 'bsm';
					# true for bsmt, crawl, and main_1 with a slab foundation
					if ($zone =~ /^bsmt$|^crawl$/ || ($zone eq 'main_1' && $record_indc->{'foundation'} eq 'slab') ) {	# or if slab on grade
						&copy_template($zone, $ext, $hse_file, $coordinates);
					};
				};
				
				# create an obstruction file for MAIN
# 				&copy_template('main_1', 'obs', $hse_file, $coordinates);;

				# CHECK MAIN WINDOW AREA (m^2) AND CREATE A TMC FILE
				if ($CSDDRD->{'wndw_area_front'} + $CSDDRD->{'wndw_area_right'} + $CSDDRD->{'wndw_area_back'} + $CSDDRD->{'wndw_area_left'} > 1) {
					my $ext = 'tmc';
					# cycle through the zone names
					foreach my $zone (keys (%{$zones->{'name->num'}})) {
						# we will distribute the window areas over all main zones so make a tmc file for each one
						if ($zone =~ /^main_\d$/) {&copy_template($zone, $ext, $hse_file, $coordinates);}
						# check for walkout basements and if so create a tmc file if the window area matches that side
						elsif ($zone eq 'bsmt') {
							# cycle through the surfaces
							CHECK_BSMT_TMC: foreach my $surface (@sides) {
								# make sure that side has both window area and then check to see if that side is a walkout exposed side
								if ($CSDDRD->{'wndw_area_' . $surface} > 0.5 && $record_indc->{'foundation'} =~ $surface) {
									&copy_template($zone, $ext, $hse_file, $coordinates);
									# we only want to create 1 tmc file, so jump out at this point
									last CHECK_BSMT_TMC;
								};
							};
						};
					};
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

				my $zone_count = keys (%{$zones->{'name->num'}});	# scalar of keys, equal to the number of zones
				&replace ($hse_file->{'cfg'}, "#ZONE_COUNT", 1, 1, "%s\n", "$zone_count");	# number of zones
				
				&replace ($hse_file->{'cfg'}, "#AIR", 1, 1, "%s\n", "0");	# air flow network path

				# SET THE ZONE PATHS 
				foreach my $zone (sort { $zones->{'name->num'}->{$a} <=> $zones->{'name->num'}->{$b} } keys(%{$zones->{'name->num'}})) {	# cycle through the zones by their zone number order
					# add the top line (*zon X) for the zone
					&insert ($hse_file->{'cfg'}, '#END_ZONES', 1, 0, 0, "%s\n", "*zon $zones->{'name->num'}->{$zone}");
					# cycle through all of the extentions of the house files and find those for this particular zone
					foreach my $ext (sort {$a cmp $b} keys (%{$hse_file})) {
						if ($ext =~ /$zone.(...)/) {
							# insert a path for each valid zone file with the proper name (note use of regex brackets and $1)
							&insert ($hse_file->{'cfg'}, '#END_ZONES', 1, 0, 0, "%s\n", "*$1 ./$CSDDRD->{'file_name'}.$ext");
						};
					};
					
					# Provide for the possibility of a shading file for the main zone
# 					if ($zone eq 'main') {&insert ($hse_file->{'cfg'}, '#END_ZONE' . $zones->{'name->num'}->{$zone}, 1, 0, 0, "%s\n", "*isi ./$CSDDRD->{'file_name'}.isi");};
					
					# End of the zone files
					&insert ($hse_file->{'cfg'}, '#END_ZONES', 1, 0, 0, "%s\n", "*zend");	# provide the *zend at the end
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
				
				($eave_height, $issues) = check_range("%.1f", $eave_height, 1, 12, 'AIM eave height', $coordinates, $issues);
				
				&replace ($hse_file->{'aim'}, "#EAVE_HEIGHT", 1, 1, "%s\n", "$eave_height");	# set the eave height in meters

# PLACEHOLDER FOR MODIFICATION OF THE FLUE SIZE LINE. PRESENTLY AIM2_PRETIMESTEP.F USES HVAC FILE TO MODIFY FURNACE FLUE INPUTS FOR ON/OFF

				# Determine which zones the infiltration is applied to
				# declare an array to store the number of zones and the zone number list
				my @aim_zones = (0);
				
				# cycle through the zones and look for main_ or bsmt and if so push it onto the zone number array
				foreach my $zone (sort { $zones->{'name->num'}->{$a} <=> $zones->{'name->num'}->{$b} } keys(%{$zones->{'name->num'}})) {	# cycle through the zones by their zone number order
					if ($zone =~ /^main_\d$|^bsmt$/) {
						push (@aim_zones, $zones->{'name->num'}->{$zone});
					};
				};
				# we are done cycling so replace the first element with the number of zones: NOTE: this is equal to the final element position, starting from 0
				$aim_zones[0] = $#aim_zones;
				
				&replace ($hse_file->{'aim'}, '#ZONE_INDICES', 1, 2, "%s\n", "@aim_zones # the number of zones that recieve infiltration followed by the zone number list");

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
				
				# declare an array to store the zone control # links in order of the zones
				my @zone_links;
				
				foreach my $zone (sort { $zones->{'name->num'}->{$a} <=> $zones->{'name->num'}->{$b} } keys(%{$zones->{'name->num'}})) {	# cycle through the zones by their zone number order
					# if it is main_ or bsmt then link it to control 1
					if ($zone =~ /^main_\d$|^bsmt$/) {
						push (@zone_links, 1);
					}
					# otherwise link it to control 2 - free float
					else {push (@zone_links, 2);};
				};
				
				&replace ($hse_file->{'ctl'}, "#ZONE_LINKS", 1, 1, "%s\n", "@zone_links");

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


			my $w_d_ratio = 1; # declare and intialize a width to depth ratio (width is front of house) 

			GEO_VERTICES: {


				# DETERMINE WIDTH AND DEPTH OF ZONE (with limitations)

				if ($CSDDRD->{'exterior_dimension_indicator'} == 0) {
					($w_d_ratio, $issues) = check_range("%.2f", $w_d_ratio, 0.75, 1.33, 'Exterior width to depth ratio', $coordinates, $issues);
				};	# If auditor input width/depth then check range NOTE: these values were chosen to meet the basesimp range and in an effort to promote enough size for windows and doors
				
				# determine the depth of the house based on the main_1. This will set the depth back from the front of the house for all zones such that they start at 0,0 and the x value (front side) is different for the different zones
				$record_indc->{'y'} = sprintf("%6.2f", ($CSDDRD->{'main_floor_area_1'} ** 0.5) / $w_d_ratio);	# determine depth of zone based upon main floor area and width to depth ratio
				
				# intialize the conditioned volume so that it may be added to as conditioned zones are encountered
				$record_indc->{'vol_conditioned'} = 0;
				
				foreach my $zone (sort { $zones->{'name->num'}->{$a} <=> $zones->{'name->num'}->{$b} } keys(%{$zones->{'name->num'}})) {	# sort the keys by their value so main comes first
					# DETERMINE WIDTH AND DEPTH OF ZONE (with limitations)
					
					if ($zone =~ /^bsmt$|^crawl$/) {
						# check to see that the foundation area is not larger than the main_1 area
						# NOTE: this is a special check_range: see the subroutine for the issue handling
						($CSDDRD->{$zone . '_floor_area'}, $issues) = check_range("%6.1f", $CSDDRD->{$zone . '_floor_area'}, 1, $CSDDRD->{'main_floor_area_1'}, 'Foundation floor area size is N/A to main floor area', $coordinates, $issues);
						
						# Because bsmt walls are thicker, the bsmt or crawl floor area is typically a little less than the main_1 level. However, it is really not appropriate to expose main_1 floor area for this small difference.
						# Thus, if the difference between the main_1 and foundation floor area is less than 10% of them main_1 floor area, resize the foundation area to be equal to the main_1 floor area
						if ($CSDDRD->{'main_floor_area_1'} - $CSDDRD->{$zone . '_floor_area'} < 0.1 * $CSDDRD->{'main_floor_area_1'}) {
							$CSDDRD->{$zone . '_floor_area'} = $CSDDRD->{'main_floor_area_1'}
						}
						$record_indc->{$zone}->{'x'} = $CSDDRD->{$zone . '_floor_area'} / $record_indc->{'y'};	# determine width of zone based upon main_1 depth


						# foundation bottom height is below origin so subtract the wall height
						$record_indc->{$zone}->{'z1'} = 0;	# determine height of zone
						# this leaves foundation top height at the origin
						$record_indc->{$zone}->{'z2'} = $CSDDRD->{$zone . '_wall_height'};
					}

					elsif ($zone =~ /^main_(\d)$/) {
						# determine x from floor area and y
						$record_indc->{$zone}->{'x'} = $CSDDRD->{"main_floor_area_$1"} / $record_indc->{'y'};	# determine width of zone based upon main_1 depth
						
						# if the second or third floor, use the preceding zone to determine the new bottom height
						if ($1 > 1) {
							$record_indc->{$zone}->{'z1'} = $record_indc->{'main_' . ($1 - 1)}->{'z2'};
						}
						# this is the first floor, check to see if a foundation zone exists beneath it, and if so set z1 equal to that zones z2
						elsif ($zones->{'name->num'}->{$zone} > 1) {	# true if there is a foundation zone
							# set main_1 z1 equal to the foundation zone 1 (looked up with $zones->{'num->name'}; could be bsmt or crawl) z2
							$record_indc->{$zone}->{'z1'} = $record_indc->{$zones->{'num->name'}->{1}}->{'z2'};
						}
						# this is the first zone and there is no foundation below it, so set to zero
						else {$record_indc->{$zone}->{'z1'} = 0;};
						
						# add the wall height to the starting height to get the top height
						$record_indc->{$zone}->{'z2'} = $record_indc->{$zone}->{'z1'} + $CSDDRD->{"main_wall_height_$1"};	# determine height of zone
					}
					
					else {	# attics and roofs NOTE that there is a die msg built in if it is not either of these
						# use the highest main level to find x
						$record_indc->{$zone}->{'x'} = $CSDDRD->{'main_floor_area_' . $high_level} / $record_indc->{'y'};	# determine width of zone based upon main_1 depth and main_highest width
						
						# use the highest main level to determine z1 as the main levels z2
						$record_indc->{$zone}->{'z1'} = $record_indc->{'main_' . $high_level}->{'z2'};
						
						# determine the z2 based on the zone type
						if ($zone eq 'attic') {
							# attic is assumed to be 5/12 roofline with peak in parallel with long side of house. Attc is mounted to top corner of main above 0,0
							$record_indc->{$zone}->{'z2'} = $record_indc->{$zone}->{'z1'} + &smallest($record_indc->{'y'}, $record_indc->{$zone}->{'x'}) / 2 * 5 / 12;	# determine height of zone
						}
						elsif ($zone eq 'roof') {
							# create a vented roof airspace, not very thick
							$record_indc->{$zone}->{'z2'} = $record_indc->{$zone}->{'z1'} + 0.3;
						}
						# this will die if the wrong type of zone is encountered
						else {&die_msg ('GEO: Determine width and height of zone, bad zone name', $zone, $coordinates)};

					};
					
					
					# format the coordinates
					foreach my $coordinate ('x', 'z1', 'z2') {
						$record_indc->{$zone}->{$coordinate} = sprintf("%6.2f", $record_indc->{$zone}->{$coordinate});
					};
					
					# ZONE VOLUME - record the zone volume and add it to the conditioned if it is a main or bsmt
					$record_indc->{$zone}->{'volume'} = sprintf("%.1f", $record_indc->{'y'} * $record_indc->{$zone}->{'x'} * ($record_indc->{$zone}->{'z2'} - $record_indc->{$zone}->{'z1'}));
					if ($zone =~ /^main_\d$|^bsmt$/) {$record_indc->{'vol_conditioned'} = $record_indc->{'vol_conditioned'} + $record_indc->{$zone}->{'volume'};};

					# SURFACE AREA
					# record the present surface areas (note that rectangularism is assumed)
					$record_indc->{$zone}->{'SA'}->{'base'} = $record_indc->{'y'} * $record_indc->{$zone}->{'x'};
					$record_indc->{$zone}->{'SA'}->{'top'} = $record_indc->{$zone}->{'SA'}->{'base'};
					$record_indc->{$zone}->{'SA'}->{'front'} = $record_indc->{$zone}->{'x'} * ($record_indc->{$zone}->{'z2'} - $record_indc->{$zone}->{'z1'});
					$record_indc->{$zone}->{'SA'}->{'right'} = $record_indc->{'y'} * ($record_indc->{$zone}->{'z2'} - $record_indc->{$zone}->{'z1'});
					$record_indc->{$zone}->{'SA'}->{'back'} = $record_indc->{$zone}->{'SA'}->{'front'};
					$record_indc->{$zone}->{'SA'}->{'left'} = $record_indc->{$zone}->{'SA'}->{'right'};

					# intialize a total surface area storage variable
					$record_indc->{$zone}->{'SA'}->{'total'} = 0;
					
					# determine the total surface area
					foreach my $surface (keys (%{$record_indc->{$zone}->{'SA'}})) {
						# do not sum total with itself
						unless ($surface eq 'total') {
							# format the surface areas for printing
							$record_indc->{$zone}->{'SA'}->{$surface} = sprintf("%.1f", $record_indc->{$zone}->{'SA'}->{$surface});
							# add the surface area to the total
							$record_indc->{$zone}->{'SA'}->{'total'} = $record_indc->{$zone}->{'SA'}->{'total'} + $record_indc->{$zone}->{'SA'}->{$surface};
						};
					};

					# add a base-sides surface area for BASESIMP area calculations (note that formatting is maintained)
					$record_indc->{$zone}->{'SA'}->{'base-sides'} = $record_indc->{$zone}->{'SA'}->{'total'} - $record_indc->{$zone}->{'SA'}->{'top'};
						
				};
			};


			# Declare a window and door margin that is required to fit these items into a wall.
			# Doors are placed on the lower right hand side of the wall
			# the door has a margin on its bottom, top, and right hand side to the zone edges
			# Windows are centered in the remaining portion (if a door exists)
			# they have the margin applied to all sides (bottom, top, left, right)
			
			my $wndw_door_margin = 0.1;

			GEO_DOORS_WINDOWS: {

				
				# cycle over the doors and check the width/height (there are known reversals)
				foreach my $index (1..3) { # cycle through the three door types (main 1, main 2, bsmt)
					if (($CSDDRD->{'door_width_' . $index} > 1.5) && ($CSDDRD->{'door_height_' . $index} < 1.5)) {	# check the width and height
						my $temp = $CSDDRD->{'door_width_' . $index};	# store door width temporarily
						$CSDDRD->{'door_width_' . $index} = sprintf ("%5.2f", $CSDDRD->{'door_height_' . $index});	# set door width equal to original door height
						$CSDDRD->{'door_height_' . $index} = sprintf ("%5.2f", $temp);	# set door height equal to original door width
# 						print GEN_SUMMARY "\tDoor\@[$index] width/height reversed: $coordinates\n";	# print a comment about it
						$issues = set_issue("%s", $issues, 'Door', 'width/height reversed', "Now W $CSDDRD->{'door_width_' . $index} H $CSDDRD->{'door_height_' . $index}", $coordinates);
					};
				
					# do a range check on the door width and height
					if ($CSDDRD->{'door_width_' . $index} > 0 || $CSDDRD->{'door_height_' . $index} > 0) {
						# NOTE: this is a special check_range: see the subroutine for the issue handling
						($CSDDRD->{'door_width_' . $index}, $issues) = check_range("%5.2f", $CSDDRD->{'door_width_' . $index}, 0.5, 2.5, "Door Width $index", $coordinates, $issues);
						($CSDDRD->{'door_height_' . $index}, $issues) = check_range("%5.2f", $CSDDRD->{'door_height_' . $index}, 1.5, 3, "Door Height $index", $coordinates, $issues);
					};
				};

				# BSMT DOORS

				# count the number of basment doors and resize as required to have a maximum 4 (for 4 sides)
				if ($CSDDRD->{'door_count_3'} > 4) {
					$CSDDRD->{'door_width_3'} = $CSDDRD->{'door_width_3'} * $CSDDRD->{'door_count_3'} / 4;
					$CSDDRD->{'door_count_3'} = 4;
				};
				
				# apply the basement doors to the basement
				# check to see if basment doors exist
				if (defined ($zones->{'name->num'}->{'bsmt'})) {
				
				
					# store a temporary count of the bsmt doors so we don't mess with the CSDDRD
					my $bsmt_doors = $CSDDRD->{'door_count_3'};
					
					# cycle through the sides and look for ones that match the walkout basement type, to apply doors to these first (preference)
					foreach my $surface (@sides) {
					
						# create a reference to the location to push the vertices to keep the name short in the following similar segments
						my $door = \%{$record_indc->{'bsmt'}->{'doors'}->{$surface}};
					
						# check to see that doors still exist and if we are on a walkout side
						if ($bsmt_doors >= 1 && $record_indc->{'foundation'} =~ $surface) {
							# check to see if the door is taller than the height
							if ($CSDDRD->{'door_height_3'} > ($CSDDRD->{'bsmt_wall_height'} - 2 * $wndw_door_margin)) {
								# it is to tall, so modify the width to compensate and store the height
								# calculate the new width
								$door->{'width'} = $CSDDRD->{'door_width_3'} * $CSDDRD->{'door_height_3'} / ($CSDDRD->{'bsmt_wall_height'} - 2 * $wndw_door_margin);
								# state the new height
								$door->{'height'} = $CSDDRD->{'bsmt_wall_height'} - 2 * $wndw_door_margin;
								# bsmt door is type 3
								$door->{'type'} = 3;
								
							}
							# simply store the info
							else {
								$door->{'height'} = $CSDDRD->{'door_height_3'};
								$door->{'width'} = $CSDDRD->{'door_width_3'};
								# bsmt door is type 3
								$door->{'type'} = 3;
							};
							# decrement the counter of doors
							$bsmt_doors--;
						}
						# for sides that are not walk out, initialize to values of zero, these will be replaced later if extra doors still exist
						else {
							$door->{'height'} = 0;
							$door->{'width'} = 0;
							# no door exists so type 0
							$door->{'type'} = 0;
						};
					};
					

					# cycle through the surfaces again and check if they are not the walkout type and replace the zeroed height and width
					# this is to attribute the remaining doors to non-walkout sides. It is possible to have non-walkout sides with doors as there is a staircase or such.
					foreach my $surface (@sides) {
					
						# create a reference to the location to push the vertices to keep the name short in the following similar segments
						my $door = \%{$record_indc->{'bsmt'}->{'doors'}->{$surface}};
					
						# check not equal to walkout side
						if ($bsmt_doors >= 1 && $record_indc->{'foundation'} !~ $surface) {
							# same width modifier
							if ($CSDDRD->{'door_height_3'} > ($CSDDRD->{'bsmt_wall_height'} - 2 * $wndw_door_margin)) {
								# calculate the width
								$door->{'width'} = $CSDDRD->{'door_width_3'} * $CSDDRD->{'door_height_3'} / ($CSDDRD->{'bsmt_wall_height'} - 2 * $wndw_door_margin);
								# set the height
								$door->{'height'} = $CSDDRD->{'bsmt_wall_height'} - 2 * $wndw_door_margin;
								# bsmt door is type 3
								$door->{'type'} = 3;
								
							}
							else {
								$door->{'height'} = $CSDDRD->{'door_height_3'};
								$door->{'width'} = $CSDDRD->{'door_width_3'};
								# bsmt door is type 3
								$door->{'type'} = 3;
							};
							# decrement the counter
							$bsmt_doors--;
						# note there is no else here because we do not want to replace the walkout doors
						};
					};
				}
				
				# MAIN DOORS
				
				# count the number of main doors and resize as required to have a maximum of 4 per level
				# check to see that the total doors are greater than the available sides of main levels (e.g. if total is > 8 for a two storey)
				if (($CSDDRD->{'door_count_1'} + $CSDDRD->{'door_count_2'}) > ($high_level * 4)) {
					# determine the component of door type 1 in comparison to 1 and 2 - this is used to determine the door counts for houses that have more doors than sides
					my $ratio = $CSDDRD->{'door_count_1'} / ($CSDDRD->{'door_count_1'} + $CSDDRD->{'door_count_2'});
					# estimate the appropriate number of door type 1 for the new maximum level of doors (e.g. 8 for a two storey)
					my $door_count_1 = sprintf ("%.0f", $ratio * $high_level * 4);
					# check to make sure this door exists
					if ($door_count_1 > 0) {
						# resize the width of door 1 to this new number of doors
						$CSDDRD->{'door_width_1'} = $CSDDRD->{'door_width_1'} * $CSDDRD->{'door_count_1'} / $door_count_1;
						$CSDDRD->{'door_count_1'} = $door_count_1;
					};
					
					# door 2 makes up the remaining surfaces, so resize it based on the remaining number of doors from the available surfaces minus the door_1 count
					$CSDDRD->{'door_width_2'} = $CSDDRD->{'door_width_2'} * ($high_level * 4 - $door_count_1);
					$CSDDRD->{'door_count_2'} = $high_level * 4 - $door_count_1;
				};
				
				# declare a set an array of door types so we can shift() off of it to determine the door type
				my @main_doors;
				foreach my $type (1, 2) {
					foreach (1..$CSDDRD->{'door_count_' . $type}) {
						# push the door type onto the array (type is either 1 or 2)
						push (@main_doors, $type);
					};
				};
				
				# cycle through the main levels
				foreach my $level (1..$high_level) {
					# cycle through each side surface
					foreach my $surface (@sides) {
					
						# create a reference to the location to push the vertices to keep the name short in the following similar segments
						my $door = \%{$record_indc->{'main_' . $level}->{'doors'}->{$surface}};
					
						# check that doors still exist and if so apply them to this side
						if (@main_doors >= 1) {
							# note the type
							my $type = shift (@main_doors);
						
							# check to see if the height is greater than the wall height
							if ($CSDDRD->{'door_height_' . $type} > ($CSDDRD->{'main_wall_height_' . $level} - 2 * $wndw_door_margin)) {
								# resize the width
								$door->{'width'} = $CSDDRD->{'door_width_' . $type} * $CSDDRD->{'door_height_' . $type} / ($CSDDRD->{'main_wall_height_' . $level} - 2 * $wndw_door_margin);
								# set the height
								$door->{'height'} = $CSDDRD->{'main_wall_height_' . $level} - 2 * $wndw_door_margin;
								# remember the door type
								$door->{'type'} = $type;
								
							}
							else {	# the door fits so store it
								$door->{'height'} = $CSDDRD->{'door_height_' . $type};
								$door->{'width'} = $CSDDRD->{'door_width_' . $type};
								$door->{'type'} = $type;
							};
						}
						else {	# there is no door for this side, so set to zeroes
							$door->{'height'} = 0;
							$door->{'width'} = 0;
							$door->{'type'} = 0;
						};
					};
				};

				
				# WINDOWS

				# cycle through the sides and intialize the available side area for windows
				# this information will be used to check that the windows will fit and later used to distribute the windows by surface area
				foreach my $surface (@sides) {
					# initialize the available side area for windows
					$record_indc->{'wndw'}->{'total'}->{'available-SA'}->{$surface} = 0;
				};
				
				# cycle through the zones
				foreach my $zone (keys(%{$zones->{'name->num'}})) {
					# width_key is used to determine the side length (either x or y)
					my $width_key = {'front' => $record_indc->{$zone}->{'x'}, 'right' => $record_indc->{'y'}, 'back' => $record_indc->{$zone}->{'x'}, 'left' => $record_indc->{'y'}};
					
					# cycle through the sides
					foreach my $surface (@sides) { 
						# for the main zone, all sides are available
						if ($zone =~ /^main_(\d)$/) {
							# the available surface area on that side is the side width minus door and three margins multiplied by the height minus two margins
							$record_indc->{'wndw'}->{$zone}->{'available-SA'}->{$surface} = ($width_key->{$surface} - $record_indc->{$zone}->{'doors'}->{$surface}->{'width'} - 3 * $wndw_door_margin) * ($CSDDRD->{'main_wall_height_' . $1} - 2 * $wndw_door_margin);
							# add this area to the total
							$record_indc->{'wndw'}->{'total'}->{'available-SA'}->{$surface} = $record_indc->{'wndw'}->{'total'}->{'available-SA'}->{$surface} + $record_indc->{'wndw'}->{$zone}->{'available-SA'}->{$surface};
						}
						
						# check to see if the zone is bsmt and we are on a walkout side as we can place windows there
						elsif ($zone eq 'bsmt' && $record_indc->{'foundation'} =~ $surface) {
							# the available surface area on that side is the side width minus door and three margins multiplied by the height minus two margins
							$record_indc->{'wndw'}->{$zone}->{'available-SA'}->{$surface} = ($width_key->{$surface} - $record_indc->{$zone}->{'doors'}->{$surface}->{'width'} - 3 * $wndw_door_margin) * ($CSDDRD->{'bsmt_wall_height'} - 2 * $wndw_door_margin);
							# add this area to the total
							$record_indc->{'wndw'}->{'total'}->{'available-SA'}->{$surface} = $record_indc->{'wndw'}->{'total'}->{'available-SA'}->{$surface} + $record_indc->{'wndw'}->{$zone}->{'available-SA'}->{$surface};
						}
						
						# we cannot place windows on this side
						else {
							$record_indc->{'wndw'}->{$zone}->{'available-SA'}->{$surface} = 0;
						};
					};

				};
				
				# cycle through and check the surface area to window size and determine the popular window type for each side
				foreach my $surface (@sides) { 
				
					# check that the window area is less than the available surface area on the side
					($CSDDRD->{'wndw_area_' . $surface}, $issues) = check_range("%6.2f", $CSDDRD->{'wndw_area_' . $surface}, 0, $record_indc->{'wndw'}->{'total'}->{'available-SA'}->{$surface}, "WINDOWS Available Area - $surface", $coordinates, $issues);

					# if windows are present on this side, then determine the window code
					if ($CSDDRD->{'wndw_area_' . $surface} > 0) {
						# intialiaze a hash reference to store window_type => duplicates info
						my $wndw_type = {};

						# cycle over the 10 window instances for each side
						foreach my $index (1..10) {
							# make XX instead of X digits
							$index = sprintf ("%02u", $index);
							
							# if the type is defined then add the number of duplicates to the value
							if (defined ($wndw_type->{$CSDDRD->{"wndw_z_$surface" . "_code_$index"}})) {
								$wndw_type->{$CSDDRD->{"wndw_z_$surface" . "_code_$index"}} = $wndw_type->{$CSDDRD->{"wndw_z_$surface" . "_code_$index"}} + $CSDDRD->{"wndw_z_$surface" . "_duplicates_$index"};
							}
							# otherwise initialize this window type equal to the number of its duplicates
							else {
								$wndw_type->{$CSDDRD->{"wndw_z_$surface" . "_code_$index"}} = $CSDDRD->{"wndw_z_$surface" . "_duplicates_$index"};
							};
						};
						
						# for the facing direction determine the most popular window code for that side
						# initialize to zeroes
						$record_indc->{'wndw'}->{$surface} = {'code' => 0, 'count' => 0};
						# loop over the window types on that side
						foreach my $type (keys (%{$wndw_type})) {
							# if more duplicates are present for this type, replace it as the most popular for that side
							if ($wndw_type->{$type} > $record_indc->{'wndw'}->{$surface}->{'count'}) {
								# store the code
								$record_indc->{'wndw'}->{$surface}->{'code'} = $type;
								# store the duplicates of that window type
								$record_indc->{'wndw'}->{$surface}->{'count'} = $wndw_type->{$type};
							};
						};
						
						$record_indc->{'wndw'}->{$surface}->{'code'} =~ /(\d\d\d)\d\d\d/ or &die_msg ('GEO: Unknown window code', $record_indc->{'wndw'}->{$surface}->{'code'}, $coordinates);
						my $con = "WNDW_$1";
						# THIS IS A SHORT TERM WORKAROUND TO THE FACT THAT I HAVE NOT CHECKED ALL THE WINDOW TYPES YET FOR EACH SIDE
						# check that the window is defined in the database
						unless (defined ($con_data->{$con})) {
							# it is not, so determine the favourite code
							$CSDDRD->{'wndw_favourite_code'} =~ /(\d\d\d)\d\d\d/ or &die_msg ('GEO: Favourite window code is misconstructed', $CSDDRD->{'wndw_favourite_code'}, $coordinates);
							# check that the favourite is in the database
							if (defined ($con_data->{"WNDW_$1"})) {
								# it is, so set an issue and proceed with this code
								$issues = set_issue("%s", $issues, 'Windows', 'Code not find in database - using favourite (ORIGINAL FAVOURITE HOUSE)', "$con $1", $coordinates);
								$record_indc->{'wndw'}->{$surface}->{'code'} = $CSDDRD->{'wndw_favourite_code'};
							}
							# the favourite also does not exist, so die
							else {&die_msg ('GEO: Bad favourite window code', "WNDW_$1", $coordinates);};
						};
					};
				};


			};


			GEO_SURFACES: {
				foreach my $zone (sort { $zones->{'name->num'}->{$a} <=> $zones->{'name->num'}->{$b} } keys(%{$zones->{'name->num'}})) {	# sort the keys by their value so main comes first

					&replace ($hse_file->{"$zone.geo"}, "#ZONE_NAME", 1, 1, "%s\n", "GEN $zone This file describes the $zone");	# set the name at the top of each zone geo file

					# SET THE ORIGIN AND MAJOR VERTICES OF THE ZONE (note the formatting)
					my $x1 = sprintf("%6.2f", 0);	# declare and initialize the zone origin
					my $x2 = $record_indc->{$zone}->{'x'};
					my $y1 = sprintf("%6.2f", 0);
					my $y2 = $record_indc->{'y'};
					my $z1 = $record_indc->{$zone}->{'z1'};
					my $z2 = $record_indc->{$zone}->{'z2'};
									

					# initialize a surface variable as it will be used a lot and can be local and less local
					my $surface;
					
					# BASE
					# the first zone and the attic and roof will only have 4 vertices for the base
					if ($zones->{'name->num'}->{$zone} == 1 || $zone =~ /^attic$|^roof$/) {
						push (@{$record_indc->{$zone}->{'vertices'}->{'base'}},	# base vertices in CCW (looking down)
							"$x1 $y1 $z1", "$x2 $y1 $z1", "$x2 $y2 $z1", "$x1 $y2 $z1");
						$record_indc->{$zone}->{'SA'}->{'floor'} = sprintf("%.1f", ($y2 - $y1) * ($x2 - $x1));
					}
					
					# check the main levels to see if they need 4 or 6 vertices (if other zone is larger)
					else {
						# determine the other zone
						my $x2_other_zone = $record_indc->{$zones->{'num->name'}->{$zones->{'name->num'}->{$zone} - 1}}->{'x'};
						# check if the other zone is same or larger, if so we only need 4 vertices (other zone will have 6)
						if ($x2 <= $x2_other_zone) {
							push (@{$record_indc->{$zone}->{'vertices'}->{'base'}},	# base vertices in CCW (looking down)
								"$x1 $y1 $z1", "$x2 $y1 $z1", "$x2 $y2 $z1", "$x1 $y2 $z1");
							$record_indc->{$zone}->{'SA'}->{'floor'} = sprintf("%.1f", ($y2 - $y1) * ($x2 - $x1));
						}
						# this zone is larger, so push 6 vertices with the interim vertices being based on the other zone
						else {
							# use the other zones x's to create extra vertices
							push (@{$record_indc->{$zone}->{'vertices'}->{'base'}},	# base vertices in CCW (looking down)
								"$x1 $y1 $z1", "$x2_other_zone $y1 $z1", "$x2 $y1 $z1", "$x2 $y2 $z1", "$x2_other_zone $y2 $z1", "$x1 $y2 $z1");
							# overwrite the floor area with the smaller value
							$record_indc->{$zone}->{'SA'}->{'floor'} = sprintf("%.1f", ($y2 - $y1) * ($x2_other_zone - $x1));
							# store the exposed floor area
							$record_indc->{$zone}->{'SA'}->{'floor-exposed'} = sprintf("%.1f", ($y2 - $y1) * ($x2 - $x2_other_zone));
						};
					};
					
					# store the number of vertices
					my $vertices = @{$record_indc->{$zone}->{'vertices'}->{'base'}};
					
					# specify the vertices and the surface number depending on the number of vertices
					if ($vertices == 4) {
						# there in only a floor
						push (@{$record_indc->{$zone}->{'surfaces'}->{'floor'}->{'vertices'}},
							$vertices - 3, $vertices, $vertices - 1, $vertices - 2);
						$record_indc->{$zone}->{'surfaces'}->{'floor'}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
					}
					elsif ($vertices == 6) {
						# there is a floor and floor-exposed so do both
						push (@{$record_indc->{$zone}->{'surfaces'}->{'floor'}->{'vertices'}},
							$vertices - 5, $vertices, $vertices - 1, $vertices - 4);
						$record_indc->{$zone}->{'surfaces'}->{'floor'}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
						push (@{$record_indc->{$zone}->{'surfaces'}->{'floor-exposed'}->{'vertices'}},
							$vertices - 4, $vertices - 1, $vertices - 2, $vertices - 3);
						$record_indc->{$zone}->{'surfaces'}->{'floor-exposed'}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
					}
					else {&die_msg ("GEO: vertices do not equal 4 or 6 for $zone base", $vertices, $coordinates)};

					# storage variable for the attic side orientation
					my $attic_orientation;
					
					# TOP
					
					# the bsmt crawl and roof will only have 4 vertices on the top (NOTE the attic is completed elsewhere because it has sloped surfaces)
					if ($zone =~ /^bsmt$|^crawl$|^roof$/) {
						# second level of vertices for rectangular zones
						# the ceiling or top is assumed rectangular
						push (@{$record_indc->{$zone}->{'vertices'}->{'top'}}, "$x1 $y1 $z2", "$x2 $y1 $z2", "$x2 $y2 $z2", "$x1 $y2 $z2");
						$record_indc->{$zone}->{'SA'}->{'ceiling'} = sprintf("%.1f", ($y2 - $y1) * ($x2 - $x1));
						
						# roof zone has vertical walls (other attics have alternatives)
						if ($zone eq 'roof') {
							foreach $surface (@sides) {
								$attic_orientation->{$surface} = 'VERT';
							};
						};
					}
					
					elsif ($zone eq 'attic') {
						# 5/12 attic shape OR Middle DR type house (hip not possible) with NOTE: slope facing the long side of house and gable ends facing the short side
						if (($CSDDRD->{'ceiling_flat_type'} == 2) || ($CSDDRD->{'attachment_type'} == 4)) {	
							if (($w_d_ratio >= 1) || ($CSDDRD->{'attachment_type'} > 1)) {	# the front is the long side OR we have a DR type house, so peak in parallel with x
								my $peak_minus = sprintf ("%6.2f", $y1 + ($y2 - $y1) / 2 - 0.05); # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								my $peak_plus = sprintf ("%6.2f", $y1 + ($y2 - $y1) / 2 + 0.05);
								push (@{$record_indc->{$zone}->{'vertices'}->{'top'}},	# second level attic vertices
									"$x1 $peak_minus $z2", "$x2 $peak_minus $z2", "$x2 $peak_plus $z2", "$x1 $peak_plus $z2");
								$record_indc->{$zone}->{'SA'}->{'ceiling'} = sprintf("%.1f", ($peak_plus - $peak_minus) * ($x2 - $x1));
								
								# store the orientations correctly
								foreach $surface ('front', 'back') {
									$attic_orientation->{$surface} = 'SLOP';
								};
								foreach $surface ('right', 'left') {
									$attic_orientation->{$surface} = 'VERT';
								};
							}
							else {	# otherwise the sides of the building are the long sides and thus the peak runs parallel to y
								my $peak_minus = sprintf ("%6.2f", $x1 + ($x2 - $x1) / 2 - 0.05); # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
								my $peak_plus = sprintf ("%6.2f", $x1 + ($x2 - $x1) / 2 + 0.05);
								push (@{$record_indc->{$zone}->{'vertices'}->{'top'}},	# second level attic vertices
									"$peak_minus $y1 $z2", "$peak_plus $y1 $z2", "$peak_plus $y2 $z2", "$peak_minus $y2 $z2");
								$record_indc->{$zone}->{'SA'}->{'ceiling'} = sprintf("%.1f",  ($y2 - $y1) * ($peak_plus - $peak_minus));
								
								# store the orientations correctly
								foreach $surface ('front', 'back') {
									$attic_orientation->{$surface} = 'VERT';
								};
								foreach $surface ('right', 'left') {
									$attic_orientation->{$surface} = 'SLOP';
								};
							}
						}
						elsif ($CSDDRD->{'ceiling_flat_type'} == 3) {	# Hip roof
							my $peak_y_minus;
							my $peak_y_plus;
							my $peak_x_minus;
							my $peak_x_plus;
							if ($CSDDRD->{'attachment_type'} == 1) {	# SD type house, so place hips but leave a ridge in the middle (i.e. 4 sloped roof sides)
								if ($w_d_ratio >= 1) {	# ridge runs from side to side
									$peak_y_minus = $y1 + ($y2 - $y1) / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
									$peak_y_plus = $y1 + ($y2 - $y1) / 2 + 0.05;
									$peak_x_minus = $x1 + ($x2 - $x1) / 3; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
									$peak_x_plus = $x1 + ($x2 - $x1) * 2 / 3;
								}
								else {	# the depth is larger then the width
									$peak_y_minus = $y1 + ($y2 - $y1) / 3; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
									$peak_y_plus = $y1 + ($y2 - $y1) * 2 / 3;
									$peak_x_minus = $x1 + ($x2 - $x1) / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
									$peak_x_plus = $x1 + ($x2 - $x1) / 2 + 0.05;
								};
								
								# store the orientations correctly (HIP is all sloped)
								foreach $surface (@sides) {
									$attic_orientation->{$surface} = 'SLOP';
								};
							}
							else {	# DR type house
								if ($CSDDRD->{'attachment_type'} == 2) {	# left end house type
									$peak_y_minus = $y1 + ($y2 - $y1) / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
									$peak_y_plus = $y1 + ($y2 - $y1) / 2 + 0.05;
									$peak_x_minus = $x1 + ($x2 - $x1) / 3; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
									$peak_x_plus = $x2;
									
									# store the orientations correctly - all sloped except the adiabatic side
									foreach $surface (@sides) {
										$attic_orientation->{$surface} = 'SLOP';
									};
									$attic_orientation->{'right'} = 'VERT';
								}
								elsif ($CSDDRD->{'attachment_type'} == 3) {	# right end house
									$peak_y_minus = $y1 + ($y2 - $y1) / 2 - 0.05; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
									$peak_y_plus = $y1 + ($y2 - $y1) / 2 + 0.05;
									$peak_x_minus = $x1; # not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
									$peak_x_plus = $x1 + ($x2 - $x1) * 2 / 3;

									# store the orientations correctly - all sloped except the adiabatic side
									foreach $surface (@sides) {
										$attic_orientation->{$surface} = 'SLOP';
									};
									$attic_orientation->{'left'} = 'VERT';
								};
							};
							
							# format the values
							$peak_y_minus = sprintf ("%6.2f", $peak_y_minus);
							$peak_y_plus = sprintf ("%6.2f", $peak_y_plus);
							$peak_x_minus = sprintf ("%6.2f", $peak_x_minus);
							$peak_x_plus = sprintf ("%6.2f", $peak_x_plus);
							
							# record the top vertices and surface number
							push (@{$record_indc->{$zone}->{'vertices'}->{'top'}},	# second level attic vertices
								"$peak_x_minus $peak_y_minus $z2", "$peak_x_plus $peak_y_minus $z2", "$peak_x_plus $peak_y_plus $z2", "$peak_x_minus $peak_y_plus $z2");
							$record_indc->{$zone}->{'SA'}->{'ceiling'} = sprintf("%.1f",  ($peak_y_plus - $peak_y_minus) * ($peak_x_plus - $peak_x_minus));
						};
					}
					
					# for all other zones we have to check to see if the adjacent zone is larger or smaller
					else {
						# determine the other zone
						my $x2_other_zone = $record_indc->{$zones->{'num->name'}->{$zones->{'name->num'}->{$zone} + 1}}->{'x'};
						
						# it is larger, so only require 4 vertices
						if ($x2 <= $x2_other_zone) {
							# second level of vertices for rectangular zones NOTE: Rework for main sloped ceiling
							# the ceiling or top is assumed rectangular
							push (@{$record_indc->{$zone}->{'vertices'}->{'top'}}, "$x1 $y1 $z2", "$x2 $y1 $z2", "$x2 $y2 $z2", "$x1 $y2 $z2");
							$record_indc->{$zone}->{'SA'}->{'ceiling'} = sprintf("%.1f", ($y2 - $y1) * ($x2 - $x1));
						}
						
						else {
							# it is smaller, so generate 6 vertices using the other zones points
							push (@{$record_indc->{$zone}->{'vertices'}->{'top'}},	# base vertices in CCW (looking down)
								"$x1 $y1 $z2", "$x2_other_zone $y1 $z2", "$x2 $y1 $z2", "$x2 $y2 $z2", "$x2_other_zone $y2 $z2", "$x1 $y2 $z2");
							# update the ceiling surface area
							$record_indc->{$zone}->{'SA'}->{'ceiling'} = sprintf("%.1f", ($y2 - $y1) * ($x2_other_zone - $x1));
							# store the ceiling-exposed surface area
							$record_indc->{$zone}->{'SA'}->{'ceiling-exposed'} = sprintf("%.1f", ($y2 - $y1) * ($x2 - $x2_other_zone));
						};
					};
					
					# add the top vertices
					$vertices = $vertices + @{$record_indc->{$zone}->{'vertices'}->{'top'}};
					
					# generate the surface vertex list based on how many vertices were in the top
					if (@{$record_indc->{$zone}->{'vertices'}->{'top'}} == 4) {
						# just a ceiling
						push (@{$record_indc->{$zone}->{'surfaces'}->{'ceiling'}->{'vertices'}},
							$vertices - 3, $vertices - 2, $vertices - 1, $vertices);
						$record_indc->{$zone}->{'surfaces'}->{'ceiling'}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
					}
					elsif (@{$record_indc->{$zone}->{'vertices'}->{'top'}} == 6) {
						# a ceiling and a ceiling-exposed
						push (@{$record_indc->{$zone}->{'surfaces'}->{'ceiling'}->{'vertices'}},
							$vertices - 5, $vertices - 4, $vertices - 1, $vertices);
						$record_indc->{$zone}->{'surfaces'}->{'ceiling'}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
						push (@{$record_indc->{$zone}->{'surfaces'}->{'ceiling-exposed'}->{'vertices'}},
							$vertices - 4, $vertices - 3, $vertices - 2, $vertices - 1);
						$record_indc->{$zone}->{'surfaces'}->{'ceiling-exposed'}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
					}
					else {&die_msg ("GEO: vertices do not equal 4 or 6 for $zone top", $vertices, $coordinates)};


					
					#SIDES
					# this hash reference keys the side vertices by (# of base vertices => # of top vertice => side_name)
					# it is required because we can have four variations of number of vertices and we need to describe the wall with one of the variations
					my $side_vertices = {
						4 => {
							4 => {'front' => [1, 2, 6, 5], 'right' => [2, 3, 7, 6], 'back' => [3, 4, 8, 7], 'left' => [4, 1, 5, 8]},
							6 => {'front' => [1, 2, 7, 6, 5], 'right' => [2, 3, 8, 7], 'back' => [3, 4, 10, 9, 8], 'left' => [4, 1, 5, 10]}
						},
						6 => {
							4 => {'front' => [1, 2, 3, 8, 7], 'right' => [3, 4, 9, 8], 'back' => [4, 5, 6, 10, 9], 'left' => [6, 1, 7, 10]},
							6 => {'front' => [1, 2, 3, 9, 8, 7], 'right' => [3, 4, 10, 9], 'back' => [4, 5, 6, 12, 11, 10], 'left' => [6, 1, 7, 12]}
						}
					};
					
					# store the width (either x or y length)
					my $width_key = {'front' => $x2 - $x1, 'right' => $y2 - $y1, 'back' => $x2 - $x1, 'left' => $y2 - $y1};
					
					# declare a aper_to_rough ratio. This accounts for the CSDDRD stating roughed in window areas. A large portion will be the aperture and the remaining will be the window frame
					my $aper_to_rough = 0.75;
					
					# cycle over the sides
					foreach $surface (@sides) {
					
						# record the side vertices based on the key (depends on # of top and bottom vertices)
						push (@{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'vertices'}}, 
							@{$side_vertices->{@{$record_indc->{$zone}->{'vertices'}->{'base'}}}->{@{$record_indc->{$zone}->{'vertices'}->{'top'}}}->{$surface}});
						# record the surface index
						$record_indc->{$zone}->{'surfaces'}->{$surface}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
						
						# WINDOWS
						# if the zone is main or a basement walkout side AND there is window area on that side
						if (($zone =~ /^main_\d$/ || ($zone eq 'bsmt' && $record_indc->{'foundation'} =~ $surface)) && $CSDDRD->{'wndw_area_' . $surface} > 0) {
						
							# determine the window area for that side of that zone (do by surface area)
							my $wndw_area = $CSDDRD->{'wndw_area_' . $surface} * $record_indc->{'wndw'}->{$zone}->{'available-SA'}->{$surface} / $record_indc->{'wndw'}->{'total'}->{'available-SA'}->{$surface};
							
							# calculate the height in the same proportions of the zone side width and height
							# SIDE: A = X * Z
							# WINDOW: a = x * z
							# PROPORTIONAL: Z/X = z/x
							# REPLACE X and x and solve for z: z = ((a/A)*Z^2)^0.5
							my $height = ($wndw_area / $record_indc->{'wndw'}->{$zone}->{'available-SA'}->{$surface} * ($z2 - $z1) ** 2) ** 0.5 ;
							# calc the width
							my $width = $wndw_area / $height;
							
							# determine the starting window vertex as the center of the available area (wall width - door width) / 2 minus half the window width
							#  ___________________
							# |    _____     __   |
							# |   |     |   |  |  |
							# |   |_____|   |  |  |
							# |             |__|  |
							# |___________________|
							#
							my $horiz_start = ($width_key->{$surface} - $record_indc->{$zone}->{'doors'}->{$surface}->{'width'}) / 2 - $width / 2;
							my $vert_start = $z1 + ($z2 - $z1) / 2 - $height / 2;
							
							# create a reference to the location to push the vertices to keep the name short in the following similar segments
							my $window = \@{$record_indc->{$zone}->{'vertices'}->{$surface . '-wndw'}};
							
							# The following are the ordered information to place the windows on the appropirate side (i.e. x varies for front, y varies for right)
							# NOTE 6 vertices are added because the window has an aperture and a frame. This uses the $aper_to_rough value
							if ($surface eq 'front') {
								# wndw vertices in CCW order
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $horiz_start, $y1, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $horiz_start + $width * $aper_to_rough, $y1, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $horiz_start + $width, $y1, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $horiz_start + $width, $y1, $vert_start + $height));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $horiz_start + $width * $aper_to_rough, $y1, $vert_start + $height));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $horiz_start, $y1, $vert_start + $height));
							}
							elsif ($surface eq 'right') {
								# wndw vertices in CCW order
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y1 + $horiz_start, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y1 + $horiz_start + $width * $aper_to_rough,  $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y1 + $horiz_start + $width, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y1 + $horiz_start + $width, $vert_start + $height));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y1 + $horiz_start + $width * $aper_to_rough, $vert_start + $height));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y1 + $horiz_start, $vert_start + $height));
							}
							if ($surface eq 'back') {
								# wndw vertices in CCW order
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $horiz_start, $y2, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $horiz_start - $width * $aper_to_rough, $y2, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $horiz_start - $width, $y2, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $horiz_start - $width, $y2, $vert_start + $height));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $horiz_start - $width * $aper_to_rough, $y2, $vert_start + $height));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $horiz_start, $y2, $vert_start + $height));
							}
							elsif ($surface eq 'left') {
								# wndw vertices in CCW order
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y2 - $horiz_start, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y2 - $horiz_start - $width * $aper_to_rough,  $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y2 - $horiz_start - $width, $vert_start));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y2 - $horiz_start - $width, $vert_start + $height));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y2 - $horiz_start - $width * $aper_to_rough, $vert_start + $height));
								push (@{$window}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y2 - $horiz_start, $vert_start + $height));
							};
							
							# add the window vertices
							$vertices = $vertices + @{$record_indc->{$zone}->{'vertices'}->{$surface . '-wndw'}};
							
							# develop the aperture
							push (@{$record_indc->{$zone}->{'surfaces'}->{$surface . '-aper'}->{'vertices'}}, 
								$vertices - 5, $vertices - 4, $vertices - 1, $vertices);
							$record_indc->{$zone}->{'surfaces'}->{$surface . '-aper'}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
							
							# add the vertices to the wall, and note that we return to the first wall vertex prior to doing this
							push (@{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'vertices'}}, $record_indc->{$zone}->{'surfaces'}->{$surface}->{'vertices'}->[0],
								$vertices - 5, $vertices, $vertices - 1, $vertices - 4, $vertices - 5);

							# add the frame vertices
							push (@{$record_indc->{$zone}->{'surfaces'}->{$surface . '-frame'}->{'vertices'}}, 
								$vertices - 4, $vertices - 3, $vertices - 2, $vertices - 1);
							$record_indc->{$zone}->{'surfaces'}->{$surface . '-frame'}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
							
							# also add these to the wall
							push (@{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'vertices'}}, $record_indc->{$zone}->{'surfaces'}->{$surface}->{'vertices'}->[0],
								$vertices - 4, $vertices - 1, $vertices - 2, $vertices - 3, $vertices - 4);

						};
						
						# DOORS
						# if the zone is main or a basement  AND there is a door on that side
						if ($zone =~ /^main_\d$|^bsmt$/ && $record_indc->{$zone}->{'doors'}->{$surface}->{'type'} > 0) {

							# store the width and height
							my $width = $record_indc->{$zone}->{'doors'}->{$surface}->{'width'};
							my $height = $record_indc->{$zone}->{'doors'}->{$surface}->{'height'};
							
							# create a reference to the location to push the vertices to keep the name short in the following similar segments
							my $door = \@{$record_indc->{$zone}->{'vertices'}->{$surface . '-door'}};
							
							# do a similar process for the door - but there is only four vertices
							if ($surface eq 'front') {
								# door vertices in CCW order
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $wndw_door_margin - $width, $y1, $z1 + $wndw_door_margin));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $wndw_door_margin, $y1, $z1 + $wndw_door_margin));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $wndw_door_margin, $y1, $z1 + $wndw_door_margin + $height));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x2 - $wndw_door_margin - $width, $y1, $z1 + $wndw_door_margin + $height));
							}
							elsif ($surface eq 'right') {
								# door vertices in CCW order
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y2 - $wndw_door_margin - $width, $z1 + $wndw_door_margin));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y2 - $wndw_door_margin, $z1 + $wndw_door_margin));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y2 - $wndw_door_margin, $z1 + $wndw_door_margin + $height));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x2, $y2 - $wndw_door_margin - $width, $z1 + $wndw_door_margin + $height));
							}
							if ($surface eq 'back') {
								# door vertices in CCW order
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $wndw_door_margin + $width, $y2, $z1 + $wndw_door_margin));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $wndw_door_margin, $y2, $z1 + $wndw_door_margin));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $wndw_door_margin, $y2, $z1 + $wndw_door_margin + $height));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x1 + $wndw_door_margin + $width, $y2, $z1 + $wndw_door_margin + $height));
							}
							elsif ($surface eq 'left') {
								# door vertices in CCW order
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y1 + $wndw_door_margin + $width, $z1 + $wndw_door_margin));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y1 + $wndw_door_margin, $z1 + $wndw_door_margin));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y1 + $wndw_door_margin, $z1 + $wndw_door_margin + $height));
								push (@{$door}, sprintf ("%6.2f %6.2f %6.2f", $x1, $y1 + $wndw_door_margin + $width, $z1 + $wndw_door_margin + $height));
							};
							
							# add the door vertices to the total
							$vertices = $vertices + @{$record_indc->{$zone}->{'vertices'}->{$surface . '-door'}};
							
							# develope the door surface
							push (@{$record_indc->{$zone}->{'surfaces'}->{$surface . '-door'}->{'vertices'}}, 
								$vertices - 3, $vertices - 2, $vertices - 1, $vertices);
							$record_indc->{$zone}->{'surfaces'}->{$surface . '-door'}->{'index'} = keys(%{$record_indc->{$zone}->{'surfaces'}});
							
							# add these vertices onto the wall as well
							push (@{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'vertices'}}, $record_indc->{$zone}->{'surfaces'}->{$surface}->{'vertices'}->[0],
								$vertices - 3, $vertices, $vertices - 1, $vertices - 2, $vertices - 3);

						};
						
						
					};
					
					# for the attic or roof, store the orientation permanently
					if ($zone =~ /^attic$|^roof$/) {
						foreach $surface (@sides) {
							$record_indc->{$zone}->{'surfaces'}->{$surface}->{'orientation'} = $attic_orientation->{$surface};
						};
					};
				};
				
			};



			GEO_ZONING: {
			
				# store the number of connections
				my $connection_count = 0;
				
				foreach my $zone (sort { $zones->{'name->num'}->{$a} <=> $zones->{'name->num'}->{$b} } keys(%{$zones->{'name->num'}})) {	# sort the keys by their value so main comes first
					
					# SET THE ORIGIN AND MAJOR VERTICES OF THE ZONE (note the formatting)
					my $x1 = sprintf("%6.2f", 0);	# declare and initialize the zone origin
					my $x2 = $record_indc->{$zone}->{'x'};
					my $y1 = sprintf("%6.2f", 0);
					my $y2 = $record_indc->{'y'};
					my $z1 = $record_indc->{$zone}->{'z1'};
					my $z2 = $record_indc->{$zone}->{'z2'};


					# DETERMINE THE SURFACES, CONNECTIONS, AND SURFACE ATTRIBUTES FOR EACH ZONE (does not include windows/doors)
					
					# The general process is:
					# 1) set the surface type
					# 2) run the facing subroutine to determine info
					# 3) set the construction type
					# 4) add the construction info to the array
					# 5) add the surface attributes and connections via the subroutine


					if ($zone eq 'bsmt') {	# build the floor, ceiling, and sides surfaces and attributes for the bsmt
						# logically cycle through the surfaces
						FLOOR_BSMT: {
							# declare the surface only once
							my $surface = 'floor';
							# shorten the construction name
							my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
							# determine the facing conditions
							facing('BASESIMP', $zone, $surface, $zones, $record_indc, $coordinates);
							
							# store the string that leads us to the correct $CSDDRD variables
							my $field_name = 'bsmt_slab_insul';
						
							# If it is BOTTOM INSULATED (5) then code does not apply
							if ($CSDDRD->{$field_name . '_coverage'} == 5) {
								# name the construction
								$con->{'name'} = 'B_slab_bot';
								# record the slab using con_db.xml and compare to the HOT2XP RSI
								con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							}
							
							# if TOP INSULATED (3)
							elsif ($CSDDRD->{$field_name . '_coverage'} == 3) {
								# name the construction
								$con->{'name'} = 'B_slab_top';
								
								# check to see if there is a valid code. This runs the subroutine and returns true if it pushes the construction layers
								if (con_5_dig($field_name, $con, $CSDDRD)) {
									# record a description
									$con->{'description'} = 'CUSTOM: Bsmt slab with top insulation from code';
								};
								
								# There is no need for an ELSE because if the code did not work, it will be built from con_db.xml
								
								# record the slab and compare to the HOT2XP RSI
								con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							}
							
							# the slab is not insulated, so allow the con_db.xml to provide the info and do not check the insulation RSI
							else {
								$con->{'name'} = 'B_slab';
								con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							};
						};

						CEILING_BSMT: {
							my $surface = 'ceiling';
							
							# this will face the main, so simply define the name (use the con_db.xml) and no RSI checking
							my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
							$con->{'name'} = 'B->M';
							
							# it faces the main zone
							facing('ANOTHER', $zone, $surface, $zones, $record_indc, $coordinates);
							con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
						};

						SIDES_BSMT: foreach my $surface (@sides) {
							# do the side and then the windows/doors
							SIDES_ONLY_BSMT: {
								my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};

								# check for ADIABATIC
								if ($attachment_side =~ $surface) {
									# so it faces adiabatic
									facing('ADIABATIC', $zone, $surface, $zones, $record_indc, $coordinates);
									
									# set the name and description
									$con->{'name'} = 'B_wall_adb';
									
									# record the surface; do not check RSI
									con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
								}
								
								# check to see if we are a WALKOUT side
								elsif ($record_indc->{'foundation'} =~ $surface) {
									# so it faces exterior
									facing('EXTERIOR', $zone, $surface, $zones, $record_indc, $coordinates);
									# name it Pony wall type
									$con->{'name'} = 'B_wall_pony';
									
									# set the string for the CSDDRD variable
									my $field_name = 'bsmt_pony_wall';
									
									# so check to see if PONY walls are described, otherwise fall back to a common main wall type
									if (con_10_dig($field_name, $con, $CSDDRD)) {
										$con->{'description'} = 'CUSTOM: Bsmt pony wall from code';
										# the code worked
									}
									
									# otherwise check the main wall code
									elsif (con_10_dig('main_wall', $con, $CSDDRD)) {
										$con->{'description'} = 'CUSTOM: Bsmt pony wall from main code and pony RSI';
										# the main wall code worked
									};
									
									# No ELSE required, just let con_db.xml build the construction
									
									# Build the surface and do check the RSI - but use the Pony only
									con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);

								}

								# otherwise it is a STANDARD BASEMENT WALL
								else {
									
									facing('BASESIMP', $zone, $surface, $zones, $record_indc, $coordinates);
									
									# BECAUSE this can have both interior and exterior insulation or none, start the basic name and description here
									$con->{'name'} = 'B_wall';
									
									# check to see if any insulation exists
									if ($CSDDRD->{'bsmt_exterior_insul_coverage'} =~ /[2-4]/ || $CSDDRD->{'bsmt_interior_insul_coverage'} =~ /[2-4]/) {
										# some does, so set up the definition
										my $custom = 'CUSTOM: Bsmt wall insulated:';
										
										my $field_name; # create a field name holder
										my $RSI = 0; # store the RSI to be added up
										
										# initialize the code because we want to indicate the defined type or let it be replaced by the top insul code
										$con->{'code'} = '';
										
										$field_name = 'bsmt_exterior_insul';
										
										if ($CSDDRD->{$field_name . '_coverage'} =~ /[2-4]/) {
											$custom = $custom . ' exterior';
											
											# add this exterior insulation RSI to the total
											$RSI = $RSI + $CSDDRD->{$field_name . '_RSI'};
											# push the insulation_2 LAYER
											push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => 25, 'component' => 'insulation_2'});	# EPS @ thickness
											
											# concatenate the code with a 1
											$con->{'code'} = $con->{'code'} . 1;
										};
										
										# push on the CONCRETE LAYER
										push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => 203, 'component' => 'wall'});	# Concrete @ thickness
										
										# if INTERIOR INSULATED
										$field_name = 'bsmt_interior_insul';
										
										if ($CSDDRD->{$field_name . '_coverage'} =~ /[2-4]/) {
											# update the name
											$custom = $custom . ' interior';
											
											# add this insulation's RSI
											$RSI = $RSI + $CSDDRD->{$field_name . '_RSI'};
											
											# concatenate the code with a 2
											# This will allow us to determine the defined type as necessary
											# If a top code is true below, it will overwrite this value
											$con->{'code'} = $con->{'code'} . 2;
											
											# check the insulation code
											# the next term is complex: it says, check the code and if true (meaning it made the layers), then do not add the extra EPS, if false (meaning it did not create the layers), then make the EPS layer
											unless (con_5_dig($field_name, $con, $CSDDRD)) {
												push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => 25, 'component' => 'insulation_1'});	# EPS @ thickness
											}
										};	

										# record the description
										$con->{'description'} = $custom;

										# record the slab and compare the RSI to that of the sum of interior and exterior
										con_surf_conn($RSI, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
									
									}
									
									# the wall is not insulated, so allow the con_db.xml to provide the info and do not check the insulation RSI
									else {
										# note that the name is already set
										con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
									};
								};
							};
							
							WNDW_DOOR_BSMT: {

								# check for APERTURES AND FRAMES
								# Do this individually for each level/side because they may change as we go around the house
								if (defined ($record_indc->{$zone}->{'surfaces'}->{$surface . '-aper'})) {
									# store the window code
									$record_indc->{'wndw'}->{$surface}->{'code'} =~ /(\d{3})\d{2}(\d)/ or &die_msg ('GEO: Unknown window code', $record_indc->{'wndw'}->{$surface}->{'code'}, $coordinates);
									
									my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface . '-aper'}->{'construction'}};
									# determine the window type name
									$con->{'name'} = "WNDW_$1";
									
									facing('EXTERIOR', $zone, $surface . '-aper', $zones, $record_indc, $coordinates);
									
									# store the info - we do not need to check the RSI as this was already specified by the detailed window type
									con_surf_conn(0, $zone, $surface . '-aper', $zones, $record_indc, $issues, $coordinates);
									
									# and the frame NOTE: we need to look into different frame types
									$con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface . '-frame'}->{'construction'}};
									
									$con->{'name'} = {0 => 'FRM_Al', 1 => 'FRM_Al_brk', 2 => 'FRM_wood', 3 => 'FRM_wood_Al', 4 => 'FRM_Vnl', 5 => 'FRM_Vnl', 6 => 'FRM_Fbgls'}->{$2};

									facing('EXTERIOR', $zone, $surface . '-frame', $zones, $record_indc, $coordinates);
									
									# again we do not check RSI as we know the specific type
									con_surf_conn(0, $zone, $surface . '-frame', $zones, $record_indc, $issues, $coordinates);
								};
								
								# check for DOORS
								if (defined ($record_indc->{$zone}->{'surfaces'}->{$surface . '-door'})) {
									# shorten the construction name
									my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface . '-door'}->{'construction'}};
									
									# determine the door type
									my $door_type = $record_indc->{$zone}->{'doors'}->{$surface}->{'type'};
									
									# determine the door type name by looking it up with an anonymous hash - fall back to insulated metal door
									$con->{'name'} = {1 => 'D_wood_hlw', 2 => 'D_wood_sld', 3 => 'D_mtl_fbrgls', 4 => 'D_mtl_EPS',  5 => 'D_mtl_Plur', 6 => 'D_fbrgls_EPS', 7 => 'D_fbrgls_Plur'}->{$CSDDRD->{'door_type_' . $door_type}} or $con->{'name'} = 'D_mtl_EPS';

									facing('EXTERIOR', $zone, $surface . '-door', $zones, $record_indc, $coordinates);
									# compare the door RSI
									con_surf_conn($CSDDRD->{'door_RSI_' . $door_type}, $zone, $surface . '-door', $zones, $record_indc, $issues, $coordinates);
								};
							};
						};

						# BASESIMP
						(my $height_basesimp, $issues) = check_range("%.1f", $z2 - $z1, 1, 2.5, 'BASESIMP height', $coordinates, $issues);
						&replace ($hse_file->{"$zone.bsm"}, "#HEIGHT", 1, 1, "%s\n", "$height_basesimp");	# set height (total)

						(my $height_above_grade_basesimp, $issues) = check_range("%.2f", $CSDDRD->{'bsmt_wall_height_above_grade'}, 0.1, 2.5 - 0.65, 'BASESIMP height above grade', $coordinates, $issues);
						
						(my $depth, $issues) = check_range("%.2f", $height_basesimp - $height_above_grade_basesimp, 0.65, 2.4, 'BASESIMP grade depth', $coordinates, $issues);
						&replace ($hse_file->{"$zone.bsm"}, "#DEPTH", 1, 1, "%s\n", "$depth");

						foreach my $sides (&largest ($y2 - $y1, $x2 - $x1), &smallest ($y2 - $y1, $x2 - $x1)) {&insert ($hse_file->{"$zone.bsm"}, "#END_LENGTH_WIDTH", 1, 0, 0, "%s\n", "$sides");};

						if (($CSDDRD->{'bsmt_exterior_insul_coverage'} == 4) && ($CSDDRD->{'bsmt_interior_insul_coverage'} > 1)) {	# insulation placed on exterior below grade and on interior
							if ($CSDDRD->{'bsmt_interior_insul_coverage'} == 2) { &replace ($hse_file->{"$zone.bsm"}, "#OVERLAP", 1, 1, "%s\n", "$depth")}	# full interior so overlap is equal to depth
							elsif ($CSDDRD->{'bsmt_interior_insul_coverage'} == 3) { my $overlap = $depth - 0.2; &replace ($hse_file->{"$zone.bsm"}, "#OVERLAP", 1, 1, "%s\n", "$overlap")}	# partial interior to within 0.2 m of slab
							elsif ($CSDDRD->{'bsmt_interior_insul_coverage'} == 4) { &replace ($hse_file->{"$zone.bsm"}, "#OVERLAP", 1, 1, "%s\n", "0.6")}	# partial interior to 0.6 m below grade
							else { die ("Bad basement insul overlap: hse_type=$hse_type; region=$region; record=$CSDDRD->{'file_name'}\n")};
						};

						(my $insul_RSI, $issues) = check_range("%.1f", largest($CSDDRD->{'bsmt_interior_insul_RSI'}, $CSDDRD->{'bsmt_exterior_insul_RSI'}), 0, 9, 'BASESIMP Insul RSI', $coordinates, $issues); # set the insul value to the larger of interior/exterior insulation of basement
						&replace ($hse_file->{"$zone.bsm"}, "#RSI", 1, 1, "%s\n", "$insul_RSI");
					}



					
					elsif ($zone eq 'crawl') {	# build the floor, ceiling, and sides surfaces and attributes for the crawl
						FLOOR_CRAWL: {
							my $surface = 'floor';
							
							my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
							
							facing('BASESIMP', $zone, $surface, $zones, $record_indc, $coordinates);
							
							my $field_name = 'crawl_slab';
						
							# If it is BOTTOM INSULATED then code does not apply, so create 
							if ($CSDDRD->{$field_name . '_coverage'} == 5) {
								$con->{'name'} = 'C_slab_bot';
								# record the slab using con_db.xml and compare the RSI
								con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							}
							
							# if TOP INSULATED
							elsif ($CSDDRD->{$field_name . '_coverage'} == 3) {
								$con->{'name'} = 'C_slab_top';
								
								# check to see if there is a valid code
								if (con_5_dig($field_name, $con, $CSDDRD)) {
									$con->{'description'} = 'CUSTOM: Crawl slab with top insulation from code';
								};
								
								# There is no need for an ELSE because it will be built from con_db.xml
								
								# record the slab and compare the RSI
								con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							}
							
							# the slab is not insulated, so allow the con_db.xml to provide the info and do not check the insulation RSI
							else {
								$con->{'name'} = 'C_slab';
								con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							};
						};

						CEILING_CRAWL: {
							my $surface = 'ceiling';

							my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
							$con->{'name'} = 'C->M';
							
							facing('ANOTHER', $zone, $surface, $zones, $record_indc, $coordinates);

							
							my $field_name = 'crawl_floor_above';
							
							# so check to see if floor above is described, otherwise fall back to a common main wall type
							if (con_10_dig($field_name, $con, $CSDDRD)) {
								$con->{'description'} = 'CUSTOM: Crawl ceiling from code';
								# the code worked
							};
							
							# No ELSE required, just let con_db.xml build the construction
							
							# Build the surface and do check the RSI
							con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
						};

						SIDES_CRAWL: foreach my $surface (@sides) {
							
							my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};

							# check for the adiabatic side
							if ($attachment_side =~ $surface) {
								$con->{'name'} = 'C_wall_adb';
								facing('ADIABATIC', $zone, $surface, $zones, $record_indc, $coordinates);
								# Build the surface and do not check the RSI
								con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							}
							
							else {
								$con->{'name'} = 'C_wall';
								facing('EXTERIOR', $zone, $surface, $zones, $record_indc, $coordinates);
								
								my $field_name = 'crawl_wall';
								
								# so check to see if walls are described, otherwise fall back to a common main wall type
								if (con_10_dig($field_name, $con, $CSDDRD)) {
									$con->{'description'} = 'CUSTOM: Crawl wall from code';
									# the code worked
								}
								
								# otherwise check the main wall code
								elsif (con_10_dig('main_wall', $con, $CSDDRD)) {
									$con->{'description'} = 'CUSTOM: Crawl wall from main code and crawl wall RSI';
									# the main wall code worked
								};
								
								# No ELSE required, just let con_db.xml build the construction
								
								# Build the surface and do check the RSI
								con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							};
						};
						
						# BASESIMP
						(my $height_basesimp, $issues) = check_range("%.1f", $z2 - $z1, 1, 2.5, 'BASESIMP height', $coordinates, $issues); # check crawl height for range
						&replace ($hse_file->{"$zone.bsm"}, "#HEIGHT", 1, 1, "%s\n", "$height_basesimp");	# set height (total)
						&replace ($hse_file->{"$zone.bsm"}, "#DEPTH", 1, 1, "%s\n", "0.05");	# consider a slab as heat transfer through walls will be dealt with later as they are above grade

						foreach my $sides (&largest ($y2 - $y1, $x2 - $x1), &smallest ($y2 - $y1, $x2 - $x1)) {&insert ($hse_file->{"$zone.bsm"}, "#END_LENGTH_WIDTH", 1, 0, 0, "%s\n", "$sides");};

						(my $insul_RSI, $issues) = check_range("%.1f", $CSDDRD->{'crawl_slab_RSI'}, 0, 9, 'BASESIMP Insul RSI', $coordinates, $issues); # set the insul value to that of the crawl space slab
						&replace ($hse_file->{"$zone.bsm"}, "#RSI", 1, 1, "%s\n", "$insul_RSI");
					}

					
					elsif ($zone =~ /^main_(\d)$/) {	# build the floor, ceiling, and sides surfaces and attributes for the main
						my $level = $1;
						
						FLOOR_MAIN: {
							my $surface = 'floor';
							my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
							
							# check to see if this is main_1
							if ($level == 1) {
								# it is, so check to see if a foundation zone exists for BASESIMP purposes
								
								# check if a DIFFERENT FOUNDATION ZONE EXISTS
								if ($zones->{'name->num'}->{$zone} != 1) {
									my $facing = facing('ANOTHER', $zone, $surface, $zones, $record_indc, $coordinates);
									con_reverse($con, $record_indc, $facing);

									# do not check the RSI as this was set by the bsmt or crawl
									con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
								}
								
								# check SLAB ON GRADE
								elsif ($record_indc->{'foundation'} eq 'slab') {
									
									facing('BASESIMP', $zone, $surface, $zones, $record_indc, $coordinates);
									
									my $field_name = 'slab_on_grade';
								
									# If it is BOTTOM INSULATED then code does not apply, so create 
									if ($CSDDRD->{$field_name . '_coverage'} == 5) {
										$con->{'name'} = 'M_slab_bot';
										# record the slab using con_db.xml and compare the RSI
										con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
									}
									
									# if TOP INSULATED
									elsif ($CSDDRD->{$field_name . '_coverage'} == 3) {
										$con->{'name'} = 'M_slab_top';
										
										# check to see if there is a valid code
										if (con_5_dig($field_name, $con, $CSDDRD)) {
											$con->{'description'} = 'CUSTOM: Main slab with top insulation from code';
										};
										
										# There is no need for an ELSE because it will be built from con_db.xml
										
										# record the slab and compare the RSI
										con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
									}
									
									# the slab is not insulated, so allow the con_db.xml to provide the info and do not check the insulation RSI
									else {
										$con->{'name'} = 'M_slab';
										con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
									};
									
								}
								
								# remaining is exposed floor
								else {
									$con->{'name'} = 'M_floor_exp';
									facing('EXTERIOR', $zone, $surface, $zones, $record_indc, $coordinates);
									
									my $field_name = 'exposed_floor';
									# so check to see if exposed floor is described, otherwise fall back to a con_db.xml
									if (con_10_dig($field_name, $con, $CSDDRD)) {
										$con->{'description'} = 'CUSTOM: Exposed floor from code';
										# the code worked
									}
									
									con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
								};
							}
							
							# not the first level, so it is facing others
							else {;
								my $facing = facing('ANOTHER', $zone, $surface, $zones, $record_indc, $coordinates);
								# make the main floor construction the same as the previous levels ceiling
								# we do this because the other lower main level was developed first
								con_reverse($con, $record_indc, $facing);
								# don't check the RSI because it comes with the facing surface construction
								con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							};
						};
						
						FLOOR_EXPOSED_MAIN: {
							my $surface = 'floor-exposed';
							
							if (defined ($record_indc->{$zone}->{'surfaces'}->{$surface})) {
								my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
								$con->{'name'} = 'M_floor_exp';
								facing('EXTERIOR', $zone, $surface, $zones, $record_indc, $coordinates);
								
								my $field_name = 'exposed_floor';
								# so check to see if exposed floor is described, otherwise fall back to a con_db.xml
								if (con_10_dig($field_name, $con, $CSDDRD)) {
									$con->{'description'} = 'CUSTOM: Exposed floor from code';
									# the code worked
								}
								
								con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							};
						};
						
						CEILING_MAIN: {
							my $surface = 'ceiling';
							my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
							
							facing('ANOTHER', $zone, $surface, $zones, $record_indc, $coordinates);

							# check if facing the attic
							if ($level == $high_level) {
								$con->{'name'} = 'M->A_or_R';
								
								my $field_name = 'ceiling_dominant';

								# so check to see if ceiling code is described, otherwise fall back to a con_db.xml
								if (con_10_dig($field_name, $con, $CSDDRD)) {
									$con->{'description'} = 'CUSTOM: Main ceiling from code';
									# the code worked
								}
								
								con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							}
							
							# otherwise facing the next main zone so use the thin Main->Main interface
							else {
								$con->{'name'} = 'M->M';
								con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							};
						};
						
						CEILING_EXPOSED_MAIN: {
							my $surface = 'ceiling-exposed';
							
							if (defined ($record_indc->{$zone}->{'surfaces'}->{$surface})) {
								my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
								
								$con->{'name'} = 'M_ceil_exp';
								
								facing('EXTERIOR', $zone, $surface, $zones, $record_indc, $coordinates);
								
								my $field_name = 'ceiling_dominant';

								# so check to see if ceiling code is described, otherwise fall back to a con_db.xml
								if (con_10_dig($field_name, $con, $CSDDRD)) {
								
									$con->{'description'} = 'CUSTOM: Main exposed ceiling from code';
									
									# the code worked, but is meant for the main/attic interface and does not include sheathing or roofing.
									# because this is exposed ceiling, we have to add these component. 
									# do this with 'unshift'. It simply pushes on to the beginning of an array instead of the end.
									# do the sheathing first so that the roofing goes outside of it
									unshift (@{$con->{'layers'}}, {'mat' => 'OSB', 'thickness_mm' => 17, 'component' => 'sheathing'});
									unshift (@{$con->{'layers'}}, {'mat' => 'Asph_Shngl', 'thickness_mm' => 5, 'component' => 'roofing'});
								}
								
								con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							};
						};
						
						SIDES_MAIN: foreach my $surface (@sides) {
							SIDES_ONLY_MAIN: {
								my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
								
								# check for the ADIABATIC SIDE and if so push a half wall - standard construction
								if ($attachment_side =~ $surface) {
									$con->{'name'} = 'M_wall_adb';
									facing('ADIABATIC', $zone, $surface, $zones, $record_indc, $coordinates);
									
									# do not modify for RSI because this is shared wall
									con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
								}
								
								# otherwise EXTERIOR - check to see if this is the main_1 front as all other walls will be identical construction
								elsif ($zone eq 'main_1' && $surface eq 'front') {

									facing('EXTERIOR', $zone, $surface, $zones, $record_indc, $coordinates);

									$con->{'name'} = 'M_wall';
									
									my $field_name = 'main_wall';
									
									# so check to see if Main walls are described, otherwise fall back to a common main wall type
									if (con_10_dig($field_name, $con, $CSDDRD)) {
										$con->{'description'} = 'CUSTOM: Main wall from code';
										# the code worked
									};
									
									# we do not need an else, because we have already declared the M_wall construction and it will fall back to con_db.xml
									
									# Do check the RSI and set the surf attributes and connections
									con_surf_conn($CSDDRD->{$field_name . '_RSI'}, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
								}
								
								# the rest of the walls are the same construction as main_1 front
								else {
									# it is regular wall so it faces exterior
									facing('EXTERIOR', $zone, $surface, $zones, $record_indc, $coordinates);
									# copy the construction from the main_1 front
									%{$con} = %{$record_indc->{'main_1'}->{'surfaces'}->{'front'}->{'construction'}};
									# We DO NOT have to check the RSI as this was already completed for main_1 front
									con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
								};
							};
							
							
							WNDW_DOOR_MAIN: {

								# check for APERTURES AND FRAMES
								# Do this individually for each level/side because they may change as we go around the house
								if (defined ($record_indc->{$zone}->{'surfaces'}->{$surface . '-aper'})) {
									# store the window code
									$record_indc->{'wndw'}->{$surface}->{'code'} =~ /(\d{3})\d{2}(\d)/ or &die_msg ('GEO: Unknown window code', $record_indc->{'wndw'}->{$surface}->{'code'}, $coordinates);
									
									my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface . '-aper'}->{'construction'}};
									# determine the window type name
									$con->{'name'} = "WNDW_$1";
									
									facing('EXTERIOR', $zone, $surface . '-aper', $zones, $record_indc, $coordinates);
									
									# store the info - we do not need to check the RSI as this was already specified by the detailed window type
									con_surf_conn(0, $zone, $surface . '-aper', $zones, $record_indc, $issues, $coordinates);
									
									# and the frame NOTE: we need to look into different frame types
									$con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface . '-frame'}->{'construction'}};
									
									$con->{'name'} = {0 => 'FRM_Al', 1 => 'FRM_Al_brk', 2 => 'FRM_wood', 3 => 'FRM_wood_Al', 4 => 'FRM_Vnl', 5 => 'FRM_Vnl', 6 => 'FRM_Fbgls'}->{$2};

									facing('EXTERIOR', $zone, $surface . '-frame', $zones, $record_indc, $coordinates);
									
									# again we do not check RSI as we know the specific type
									con_surf_conn(0, $zone, $surface . '-frame', $zones, $record_indc, $issues, $coordinates);
								};
								
								# check for DOORS
								if (defined ($record_indc->{$zone}->{'surfaces'}->{$surface . '-door'})) {
									# shorten the construction name
									my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface . '-door'}->{'construction'}};
									
									# determine the door type
									my $door_type = $record_indc->{$zone}->{'doors'}->{$surface}->{'type'};
									
									# determine the door type name by looking it up with an anonymous hash - fall back to insulated metal door
									$con->{'name'} = {1 => 'D_wood_hlw', 2 => 'D_wood_sld', 3 => 'D_mtl_fbrgls', 4 => 'D_mtl_EPS',  5 => 'D_mtl_Plur', 6 => 'D_fbrgls_EPS', 7 => 'D_fbrgls_Plur'}->{$CSDDRD->{'door_type_' . $door_type}} or $con->{'name'} = 'D_mtl_EPS';

									facing('EXTERIOR', $zone, $surface . '-door', $zones, $record_indc, $coordinates);
									# compare the door RSI
									con_surf_conn($CSDDRD->{'door_RSI_' . $door_type}, $zone, $surface . '-door', $zones, $record_indc, $issues, $coordinates);
								};
							};
						};

						# BASESIMP FOR A SLAB
						if ($level == 1 && $record_indc->{'foundation'} eq 'slab') {
							(my $height_basesimp, $issues) = check_range("%.1f", $z2 - $z1, 1, 2.5, 'BASESIMP height', $coordinates, $issues);
							&replace ($hse_file->{"$zone.bsm"}, "#HEIGHT", 1, 1, "%s\n", "$height_basesimp");	# set height (total)
							&replace ($hse_file->{"$zone.bsm"}, "#DEPTH", 1, 1, "%s\n", "0.05");	# consider a slab as heat transfer through walls will be dealt with later as they are above grade

							foreach my $sides (&largest ($y2 - $y1, $x2 - $x1), &smallest ($y2 - $y1, $x2 - $x1)) {&insert ($hse_file->{"$zone.bsm"}, "#END_LENGTH_WIDTH", 1, 0, 0, "%s\n", "$sides");};

							(my $insul_RSI, $issues) = check_range("%.1f", $CSDDRD->{'slab_on_grade_RSI'}, 0, 9, 'BASESIMP Insul RSI', $coordinates, $issues);
							&replace ($hse_file->{"$zone.bsm"}, "#RSI", 1, 1, "%s\n", "$insul_RSI");
						};
					}
					
					
					elsif ($zone =~ /^attic$|^roof$/) {	# build the floor, ceiling, and sides surfaces and attributes for the attic
						FLOOR_ATTIC_ROOF: {
							my $surface = 'floor';
							# shorten the construction name by referencing
							my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
							
							# determine the facing zone and surface so that we can reverse the construction
							my $facing = facing('ANOTHER', $zone, $surface, $zones, $record_indc, $coordinates);
							
							# make the attic floor construction the same as the main ceiling by reversing the name and layer order
							con_reverse($con, $record_indc, $facing);

							# don't check the RSI as it was already set by the previous zone's surface
							con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
						};
						
						CEILING_ATTIC_ROOF: {
							my $surface = 'ceiling';
							# shorten the construction name by referencing
							my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
							
							# This is the peak horizontal section, so it must have roofing material, thus use 'slop' as it comes with roofing
							$con->{'name'} = 'A_or_R_slop';
							
							# the attic ceiling faces exterior
							facing('EXTERIOR', $zone, $surface, $zones, $record_indc, $coordinates);
							
							# don't check the RSI as there is no value for comparison
							con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
						};

						SIDES_ATTIC_ROOF: {
							foreach my $surface (@sides) {
								# shorten the construction name by referencing
								my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};

								my $facing;
								# check to see if the surface is adiabatic or exterior
								if ($attachment_side =~ $surface) {
									$facing = facing('ADIABATIC', $zone, $surface, $zones, $record_indc, $coordinates);
								}
								else {
									$facing = facing('EXTERIOR', $zone, $surface, $zones, $record_indc, $coordinates);
								};
								
								# determine the construction based on the orientiation: sloped has roofing material and vertical has siding material
								$con->{'name'} = {'SLOP' => 'A_or_R_slop', 'VERT' => 'A_or_R_gbl'}->{$facing->{'orientation'}};

								# do not check the RSI value as we have no comparison
								con_surf_conn(0, $zone, $surface, $zones, $record_indc, $issues, $coordinates);
							};
						};
					};

					# declare an array to hold the base surface indexes and total FLOR surface area
					my @base;
					
					
					
					# push on the floor index
					push (@base, $record_indc->{$zone}->{'surfaces'}->{'floor'}->{'index'});
					# if a floor-exposed exists then push on its index
					if (defined ($record_indc->{$zone}->{'surfaces'}->{'floor-exposed'})) {
						push (@base, $record_indc->{$zone}->{'surfaces'}->{'floor-exposed'}->{'index'});
					}
					# otherwise push on a zero
					else {push (@base, 0);};
					
					# push the remaining zeros and base suface area (strange ESP-r format)
					push (@base, 0, 0, 0, 0, $record_indc->{$zone}->{'SA'}->{'base'}, 0);

					# last line in GEO file which lists FLOR surfaces (total elements must equal 6) and floor area (m^2) plus another zero
					&replace ($hse_file->{"$zone.geo"}, "#BASE", 1, 1, "%s\n", "@base");

					# store the number of vertices
					my $vertex_count = 0;
					
					# loop over all 6 normal surfaces for defining vertices (not typical surfaces)
					# we expect base, top, side-wndw, and side-door
					foreach my $surface ('base', 'top', @sides) {
						# note the use of '' as a blank string
						foreach my $other ('', '-wndw', '-door') {
							# concatenate
							my $vertex_surface = $surface . $other;
							# if it is defined
							if (defined ($record_indc->{$zone}->{'vertices'}->{$vertex_surface})) {
								# loop over the vertices in the array
								foreach my $vertex (0..$#{$record_indc->{$zone}->{'vertices'}->{$vertex_surface}}) {
									# increment the counter
									$vertex_count++;
									# insert the vertex with some information
									&insert ($hse_file->{"$zone.geo"}, "#END_VERTICES", 1, 0, 0, "%s # %s%u; %s\n", $record_indc->{$zone}->{'vertices'}->{$vertex_surface}->[$vertex], "$vertex_surface v", $vertex + 1, "total v$vertex_count");
								};
							};
						};
					};

					# store the number of surfaces
					my $surface_count = 0;

					my @tmc_type;	# initialize arrays to hold optical reference data
					my $tmc_flag = 0; # to note if real optics are present
					my $em_abs; # store the solar absorbtivity and IR emissivity
					
					# loop over the basic surfaces (we expect floor, ceiling, and the sides)
					foreach my $surface_basic ('floor', 'ceiling', @sides) {
						# add the options: we expect things like ceiling-exposes, front-aper and back-door
						# note the use of '' as a blank string
						foreach my $other ('', '-exposed', '-aper', '-frame', '-door') {
							# concatenate
							my $surface = $surface_basic . $other;

							# check to see if it is defined
							if (defined ($record_indc->{$zone}->{'surfaces'}->{$surface})) {
							
								# increment the surface and connection counts. NOTE that the surface count is for the zone and that the connection count is for the building
								$surface_count++;	# zone wise
								$connection_count++; # building wise (all zones)
								
								# determine the number of vertices describing the surface (typical is 4, but due to windows and doors can be 9, 14, or 19)
								my $surface_vertices = @{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'vertices'}};
								
								# inser the surface vertices with the count of data items first
								&insert ($hse_file->{"$zone.geo"}, '#END_SURFACES', 1, 0, 0, "%u %s # %s\n", $surface_vertices, "@{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'vertices'}}", $surface);
								
								# insert the surface attributes
								&insert ($hse_file->{"$zone.geo"}, '#END_SURFACE_ATTRIBUTES', 1, 0, 0, "%3s, %-13s %-5s %-5s %-12s %-15s\n", @{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'surf_attributes'}});
								
								# insert the surface connection information
								&insert ($hse_file->{'cnn'}, '#END_CONNECTIONS', 1, 0, 0, "%s\n", "@{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'connections'}}");
							
								my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
								my $gaps = 0;	# holds a count of the number of gaps
								my @pos_rsi;	# holds the position of the gaps and RSI
								my $layer_count = 0;
								
								&insert ($hse_file->{"$zone.con"}, "#END_PROPERTIES", 1, 0, 0, "#\n%s\n", "# CONSTRUCTION: $surface - $con->{'name'} - RSI orig $con->{'RSI_orig'} final $con->{'RSI_final'} expected $con->{'RSI_expected'} - $con->{'description'} ");

# 								print Dumper $con;
								
								foreach my $layer (@{$con->{'layers'}}) {
# 									print Dumper $layer;
								
									$layer_count++;
									my $mat = $layer->{'mat'};
# 									print "mat $mat\n";
									if ($mat eq 'Gap') {
										$gaps++;
										push (@pos_rsi, $layer_count, $layer->{'gap_RSI'}->{'vert'});	# FIX THIS LATER SO THE RSI IS LINKED TO THE POSITION (VERT, HORIZ, SLOPE)
										&insert ($hse_file->{"$zone.con"}, "#END_PROPERTIES", 1, 0, 0, "%s %s %s\n", "0 0 0", $layer->{'thickness_mm'} / 1000, "0 0 0 0 # $layer->{'component'} - $mat");	# add the surface layer information
									}
									elsif (defined ($layer->{'thickness_mm_orig'})) {
										&insert ($hse_file->{"$zone.con"}, "#END_PROPERTIES", 1, 0, 0, "%s %s %s\n", "$mat_data->{$mat}->{'conductivity_W_mK'} $mat_data->{$mat}->{'density_kg_m3'} $mat_data->{$mat}->{'spec_heat_J_kgK'}", $layer->{'thickness_mm'} / 1000, "0 0 0 0 # $layer->{'component'} - $mat; $layer->{'component'} ; thickness_mm - orig: $layer->{'thickness_mm_orig'} final: $layer->{'thickness_mm'}");
									}
									else {
										&insert ($hse_file->{"$zone.con"}, "#END_PROPERTIES", 1, 0, 0, "%s %s %s\n", "$mat_data->{$mat}->{'conductivity_W_mK'} $mat_data->{$mat}->{'density_kg_m3'} $mat_data->{$mat}->{'spec_heat_J_kgK'}", $layer->{'thickness_mm'} / 1000, "0 0 0 0 # $layer->{'component'} - $mat");
									};	# add the surface layer information
								};

								&insert ($hse_file->{"$zone.con"}, "#END_LAYERS_GAPS", 1, 0, 0, "%s\n", "$layer_count $gaps # $surface $con->{'name'}");
# print Dumper $con;
								if ($con->{'type'} eq "OPAQ") { push (@tmc_type, 0);}
								elsif ($con->{'type'} eq "TRAN") {
									push (@tmc_type, $con->{'optic_name'});
									$tmc_flag = 1;
								};
								if (@pos_rsi) {
									&insert ($hse_file->{"$zone.con"}, "#END_GAP_POS_AND_RSI", 1, 0, 0, "%s\n", "@pos_rsi # $surface $con->{'name'}");
								};

								push (@{$em_abs->{'em'}->{'inside'}}, $mat_data->{$con->{'layers'}->[$#{$con->{'layers'}}]->{'mat'}}->{'emissivity_in'});
								push (@{$em_abs->{'em'}->{'outside'}}, $mat_data->{$con->{'layers'}->[0]->{'mat'}}->{'emissivity_out'});
								push (@{$em_abs->{'abs'}->{'inside'}}, $mat_data->{$con->{'layers'}->[$#{$con->{'layers'}}]->{'mat'}}->{'absorptivity_in'});
								push (@{$em_abs->{'abs'}->{'outside'}}, $mat_data->{$con->{'layers'}->[0]->{'mat'}}->{'absorptivity_out'});
							
							};
						};
					};


					&insert ($hse_file->{"$zone.con"}, "#EM_INSIDE", 1, 1, 0, "%s\n", "@{$em_abs->{'em'}->{'inside'}}");	# write out the emm/abs of the surfaces for each zone
					&insert ($hse_file->{"$zone.con"}, "#EM_OUTSIDE", 1, 1, 0, "%s\n", "@{$em_abs->{'em'}->{'outside'}}");
					&insert ($hse_file->{"$zone.con"}, "#SLR_ABS_INSIDE", 1, 1, 0, "%s\n", "@{$em_abs->{'abs'}->{'inside'}}");
					&insert ($hse_file->{"$zone.con"}, "#SLR_ABS_OUTSIDE", 1, 1, 0, "%s\n", "@{$em_abs->{'abs'}->{'inside'}}");

					if ($tmc_flag) {
						&replace ($hse_file->{"$zone.tmc"}, "#SURFACE_COUNT", 1, 1, "%s\n", $#tmc_type + 1);
						my %optic_lib = (0, 0);
						foreach my $element (0..$#tmc_type) {
							my $optic = $tmc_type[$element];
							unless (defined ($optic_lib{$optic})) {
								$optic_lib{$optic} = keys (%optic_lib);
								my $layers = @{$optic_data->{$optic}->{'layers'}};
								&insert ($hse_file->{"$zone.tmc"}, "#END_TMC_DATA", 1, 0, 0, "%s\n", "$layers $optic");
								&insert ($hse_file->{"$zone.tmc"}, "#END_TMC_DATA", 1, 0, 0, "%s\n", "$optic_data->{$optic}->{'optic_con_props'}->{'trans_solar'} $optic_data->{$optic}->{'optic_con_props'}->{'trans_vis'}");
								foreach my $layer (@{$optic_data->{$optic}->{'layers'}}) {
									&insert ($hse_file->{"$zone.tmc"}, "#END_TMC_DATA", 1, 0, 0, "%s\n", $layer->{'absorption'});
								};
								&insert ($hse_file->{"$zone.tmc"}, "#END_TMC_DATA", 1, 0, 0, "%s\n", "0");	# optical control flag
							};
							$tmc_type[$element] = $optic_lib{$optic};	# change from optics name to the appearance number in the tmc file
						};
						&replace ($hse_file->{"$zone.tmc"}, "#TMC_INDEX", 1, 1, "%s\n", "@tmc_type");	# print the key that links each surface to an optic (by number)
					};


					# replace the number of vertices, surfaces, and the rotation angle
					&replace ($hse_file->{"$zone.geo"}, "#VER_SUR_ROT", 1, 1, "%u %u %u\n", $vertex_count, $surface_count, ($CSDDRD->{'front_orientation'} - 1) * 45);
					

					# fill out the unused and indentation indexes with array of zeroes equal in length to number of surfaces
					my @zero_array;
					foreach (1..$surface_count) {push (@zero_array, 0)};
					&replace ($hse_file->{"$zone.geo"}, "#UNUSED_INDEX", 1, 1, "%s\n", "@zero_array");
					&replace ($hse_file->{"$zone.geo"}, "#SURFACE_INDENTATION", 1, 1, "%s\n", "@zero_array");


				}; # end of the zones loop
				
				# PRINT THE CODE REPORT FOR THIS HOUSE
				
				print $CODE_REPORT "\n\n$CSDDRD->{'file_name'}";
				foreach my $zone (sort { $zones->{'name->num'}->{$a} <=> $zones->{'name->num'}->{$b} } keys(%{$zones->{'name->num'}})) {
					print $CODE_REPORT "\n";
					# loop over the basic surfaces (we expect floor, ceiling, and the sides)
					foreach my $surface_basic ('floor', 'ceiling', @sides) {
						# add the options: we expect things like ceiling-exposes, front-aper and back-door
						# note the use of '' as a blank string
						foreach my $other ('', '-exposed', '-aper', '-frame', '-door') {
							# concatenate
							my $surface = $surface_basic . $other;
							if (defined ($record_indc->{$zone}->{'surfaces'}->{$surface})) {
								my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};

								print $CODE_REPORT "$zone,$surface,$con->{'name'},$con->{'RSI_expected'},$con->{'code'},";
								foreach my $layer (@{$con->{'layers'}}) {
									print $CODE_REPORT "\"$layer->{'component'} : $layer->{'mat'} : $layer->{'thickness_mm'}\",";
								};
								print $CODE_REPORT "$con->{'description'}\n";
							};
						};
					};
				};
				
				foreach my $zone (keys(%{$zones->{'name->num'}})) {
					# loop over the basic surfaces (we expect floor, ceiling, and the sides)
					foreach my $surface_basic ('floor', 'ceiling', @sides) {
						# add the options: we expect things like ceiling-exposes, front-aper and back-door
						# note the use of '' as a blank string
						foreach my $other ('', '-exposed', '-aper', '-frame', '-door') {
							# concatenate
							my $surface = $surface_basic . $other;
							
							if (defined ($record_indc->{$zone}->{'surfaces'}->{$surface})) {
							
								# initialize the code/default counters
								unless (defined ($code_store->{$zone}->{$surface})) {
									$code_store->{$zone}->{$surface} = {'coded' => 0, 'default' => 0, 'reversed' => 0, 'defined' => 0};
								};
							
								# link to this particular construction
								my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};
								my $name = $con->{'name'};
								my $code = $con->{'code'};
								
								# check to see if the construction name has been specified
								unless (defined ($code_store->{$zone}->{$surface}->{'name'}->{$name})) {
									# intialize this name
									$code_store->{$zone}->{$surface}->{'name'}->{$name} = 1;
								}
								
								# increment the name key
								else {
									$code_store->{$zone}->{$surface}->{'name'}->{$name}++;
								};
								
								# if the code is '0' then it is a default construction so note it
								if ($code eq '0') {
									$code_store->{$zone}->{$surface}->{'default'}++;
								}
								
								# if the code is '-10' then it is a reversed construction so note it
								elsif ($code eq '-1') {
									$code_store->{$zone}->{$surface}->{'reversed'}++;
								}
								
								# if the code is two digits then it is a defined construction but does not have a code (e.g. we know it has slab bottom insulation but it doesn't have a code)
								elsif ($code =~ /^\w{1,2}$/) {
									$code_store->{$zone}->{$surface}->{'defined'}++;
								}
								
								# otherwise there is a code, so note it and count the type
								else {
									# note the code
									$code_store->{$zone}->{$surface}->{'coded'}++;
									
# 									# initialize this code key
# 									unless (defined ($code_store->{$zone}->{$surface}->{'codes'}->{$code})) {
# 										$code_store->{$zone}->{$surface}->{'codes'}->{$code} = 1;
# 									}
# 									
# 									# increment the code key
# 									else {
# 										$code_store->{$zone}->{$surface}->{'codes'}->{$code}++;
# 									};
								};
							};
						};
					};
				};
				
				# replace the count of connections for the building
				&replace ($hse_file->{'cnn'}, '#CNN_COUNT', 1, 1, "%u\n", $connection_count);
			}; # end of the GEO loop

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
					($CSDDRD->{'heating_eff'}, $issues) = check_range("%.0f", $CSDDRD->{'heating_eff'}, 30, 100, "Heat System - Eff", $coordinates, $issues);
					# record sys eff
					push (@eff_COP, $CSDDRD->{'heating_eff'} / 100);
				}

				# if a heat pump system then define the backup (for cold weather usage)
				elsif ($systems[1] >= 7 && $systems[1] <= 9) {	# these are heat pump systems and have a backup (i.e. 2 heating systems)
					
					# Check the COP
					if ($CSDDRD->{'heating_eff_type'} == 1) { # COP rated
						($CSDDRD->{'heating_eff'}, $issues) = check_range("%.1f", $CSDDRD->{'heating_eff'}, 1.5, 5, "Heat System - COP", $coordinates, $issues);
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
					
					($primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_backup_eff'}, $issues) = check_range("%.2f", $primary_energy_src->{'system_type'}->[$CSDDRD->{'heating_equip_type'}]->{'ESP-r_backup_eff'}, 0.30, 1.00, "Heat System - Backup Eff", $coordinates, $issues);
					
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
						# check that the auditor did not put in a SEER number and select COP
						if ($CSDDRD->{'cooling_COP_SEER_value'} > 7) {
							# Because they did this, we have to assume it is a nominal 3.0
							$issues = set_issue("%.1f", $issues, 'Cool System - COP', 'COP value greater than 7.0, so it must be SEER, setting it to a representative 3.0', $CSDDRD->{'cooling_COP_SEER_value'}, $coordinates);
							$CSDDRD->{'cooling_COP_SEER_value'} = sprintf ("%.1f", 3.0);
						}
						# the COP is within reason, so do a range check up to COP of 6.0
						else {
						($CSDDRD->{'cooling_COP_SEER_value'}, $issues) = check_range("%.1f", $CSDDRD->{'cooling_COP_SEER_value'}, 2, 6, "Cool System - COP", $coordinates, $issues);
						};
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
				my @served_zones = (0);	# intialize the number of served zones to 1, and set the zone number to 1 (main) with 1. ratio of distribution
				
				foreach my $zone (sort { $zones->{'name->num'}->{$a} <=> $zones->{'name->num'}->{$b} } keys(%{$zones->{'name->num'}})) {	# cycle through the zones by their zone number order
					if ($zone =~ /^main_\d$|^bsmt$/) {
						push (@served_zones, $zones->{'name->num'}->{$zone}, sprintf ("%.2f", $record_indc->{$zone}->{'volume'} / $record_indc->{'vol_conditioned'}));
					};
				};
				# we are done cycling so replace the first element with the number of zones: NOTE: this is equal to the final element position, starting from 0
				$served_zones[0] = $#served_zones / 2; # the number of zones that recieve infiltration followed by the zone number list

				# Keys to provide comment information into the HVAC file for user friendliness
				my %energy_src_key = (1 => 'Electricity', 2 => 'Natural gas', 3 => 'Oil', 4 => 'Propane', 5 => 'Wood');
				my %equip_key = (1 => 'Furnace', 2 => 'Boiler', 3 => 'Baseboard/Hydronic/Plenum,etc.', 7 => 'Air source HP w/ Elec backup', 8 => 'Air source HP w/ Natural gas backup', 9 => 'Water source HP w/ Elec backup');
				my %priority_key = (1 => 'Primary', 2 => 'Secondary');
				my %heat_cool_key = (1 => 'Heating', 2 => 'Cooling');
				
				($CSDDRD->{'heating_capacity'}, $issues) = check_range("%.1f", $CSDDRD->{'heating_capacity'}, 5, 70, "Heat System - Capacity", $coordinates, $issues);

				# loop through each system and print out appropriate data to the hvac file
				foreach my $system (1..$#systems) {	# note: skip element zero as it is dummy space
					# INFO
# 					print "system $system; systems $systems[$system]; equip $equip_key{$systems[$system]}\n";
					
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
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s %s %s %s %s\n", "$equip[$system] $energy_src[$system]", "@served_zones[1..$#served_zones]", $CSDDRD->{'heating_capacity'} * 1000, $eff_COP[$system], "1 -1 $draft_fan_W $pilot_W 1");
					}
					
					# electric baseboard
					elsif ($systems[$system] == 3) {
						# fill out the information for a baseboard system
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "# served_zones-and-distribution heating_capacity_W efficiency no_circulation_fan circulation_fan_power");
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s %s %s %s\n", "@served_zones[1..$#served_zones]", $CSDDRD->{'heating_capacity'} * 1000, $eff_COP[$system], "0 0");
					}
					
					# heat pump or air conditioner
					elsif ($systems[$system] >= 7 && $systems[$system] <= 9) {
						# print the heating/cooling, heat pump type, and zones
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s\n", "# heating_or_cooling equipment_type served_zones-and-distribution");
						&insert ($hse_file->{"hvac"}, "#END_DATA_$system", 1, 0, 0, "%s %s\n", "$heat_cool[$system] $equip[$system]", "@served_zones[1..$#served_zones]");
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
				# declare the day types
				my @days = ('WEEKDAY', 'SATURDAY', 'SUNDAY');
				
				# declare a hash reference to store the infiltration source=>ACH and ventilation zone=>ACH at the appropriate zone
				# example $infil_vent->{main_1}->{'ventilation'} = {2 => 0.5} (this means ventilation of 0.5 ACH to zone 2
				my $infil_vent;
				
				foreach my $zone (sort { $zones->{'name->num'}->{$a} <=> $zones->{'name->num'}->{$b} } keys(%{$zones->{'name->num'}})) {	# cycle through the zones by their zone number order
				
					if ($zone =~ /^attic$|^roof$/) {
						$infil_vent->{$zone}->{'infiltration'}->{1} = 0.5;	# add infiltration
					}
					
					elsif ($zone eq 'crawl') {
						# declare a crawl space AC/h per hour hash with foundation_type keys. Lookup the value based on the foundation_type and store it.
						my $crawl_ach = {'ventilated' => 0.5, 'closed' => 0.1}->{$record_indc->{'foundation'}} # foundation type 8 is loose (0.5 AC/h) and type 9 is tight (0.1 AC/h)
							or &die_msg ('OPR: No crawl space AC/h key for foundation', $record_indc->{'foundation'}, $coordinates);
						
						$infil_vent->{$zone}->{'infiltration'}->{1} = $crawl_ach;	# add infiltration
					}

					elsif ($zone eq 'main_2') {
						# add ventilation between the zones, with the dominant zone taking volume preference. The secondary zone is attributed 0.5 ACH.
						# this ventilation will make the air masses similar between these connected zones
						$infil_vent->{$zone}->{'ventilation'}->{$zones->{'name->num'}->{'main_1'}} = 0.5;
						$infil_vent->{'main_1'}->{'ventilation'}->{$zones->{'name->num'}->{$zone}} = sprintf("%.2f", 0.5 * $record_indc->{$zone}->{'volume'} / $record_indc->{'main_1'}->{'volume'});
					}
					
					elsif ($zone eq 'main_3') {
						# add ventilation between the zones, with the dominant zone taking volume preference. The secondary zone is attributed 0.5 ACH.
						# this ventilation will make the air masses similar between these connected zones
						$infil_vent->{$zone}->{'ventilation'}->{$zones->{'name->num'}->{'main_2'}} = 0.5;
						$infil_vent->{'main_2'}->{'ventilation'}->{$zones->{'name->num'}->{$zone}} = sprintf("%.2f", 0.5 * $record_indc->{$zone}->{'volume'} / $record_indc->{'main_2'}->{'volume'});
					}

					elsif ($zone eq 'bsmt') {
						# add ventilation between the zones, with the dominant zone taking volume preference. The secondary zone is attributed 0.5 ACH.
						# this ventilation will make the air masses similar between these connected zones
						$infil_vent->{$zone}->{'ventilation'}->{$zones->{'name->num'}->{'main_1'}} = 0.5;
						$infil_vent->{'main_1'}->{'ventilation'}->{$zones->{'name->num'}->{$zone}} = sprintf("%.2f", 0.5 * $record_indc->{$zone}->{'volume'} / $record_indc->{'main_1'}->{'volume'});
					};
				};

				# cycle through the recorded zones to write this information
				foreach my $zone (keys (%{$infil_vent})) {
					foreach my $day (@days) {	# do for each day type
					
						# insert the total number of periods for the zone at that day type. This includes ventilation and infiltration
						&insert ($hse_file->{"$zone.opr"}, "#END_AIR_$day", 1, 0, 0, "%u\n", keys(%{$infil_vent->{$zone}->{'infiltration'}}) + keys(%{$infil_vent->{$zone}->{'ventilation'}}));
						
						# list the infiltration first, note the order of the elements listed
						# start_hr end_hr infiltration_ACH ventilation_ACH infiltration_type-or-ventilation_zone data
						foreach my $key (keys (%{$infil_vent->{$zone}->{'infiltration'}})) {
							&insert ($hse_file->{"$zone.opr"}, "#END_AIR_$day", 1, 0, 0, "%s\n", "0 24 $infil_vent->{$zone}->{'infiltration'}->{$key} 0 $key 0");
						};
						# list the ventilation second, note the order of the elements listed
						foreach my $key (keys (%{$infil_vent->{$zone}->{'ventilation'}})) {
							&insert ($hse_file->{"$zone.opr"}, "#END_AIR_$day", 1, 0, 0, "%s\n", "0 24 0 $infil_vent->{$zone}->{'ventilation'}->{$key} $key 0");
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
					
					foreach my $zone (keys (%{$zones->{'name->num'}})) { 
# 					&replace ($hse_file->{"$zone.opr"}, "#DATE", 1, 1, "%s\n", "*date $time");	# set the time/date for the main.opr file

						# Type 1  is occupants
						# Type 20 is electric stove
						# Type 21 is NG stove
						# Type 22 is AL-Other
						# Type 23 is NG dryer

						if ($zone =~ /^main_\d$|^bsmt$/) {
						
							my $vol_ratio = sprintf ("%.2f", $record_indc->{$zone}->{'volume'} / $record_indc->{'vol_conditioned'});
						
							foreach my $day (@days) {	# do for each day type
								# count the gains for the day so this may be inserted
								my $gains = 0;
								
								
								
								
								# attribute the AL-Other gains to both main levels and bsmt by volume
								&insert ($hse_file->{"$zone.opr"}, "#END_CASUAL_$day", 1, 0, 0, "%s %.2f %.2f %s\n",	# AL casual gains (divided by volume).
									'22 0 24',	# type # and begin/end hours of day
									$vol_ratio * $mult->{'AL-Other'},	# sensible fraction (it must all be sensible)
									0,	# latent fraction
									'0.5 0.5');	# rad and conv fractions
								$gains++; # increment the gains counter
								
								if ($zone eq 'main_01') {
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
						if ($zones->{'name->num'}->{'bsmt'}) {&replace ($hse_file->{"dhw"}, "#ZONE_WITH_TANK", 1, 1, "%s\n", 2);}	# tank is in bsmt zone
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

			
			$models_OK++;
		};	# end of the while loop through the CSDDRD->
		
	close $CSDDRD_FILE;
	
	print "Thread for Model Generation of $hse_type $region - Complete\n";
# 	print Dumper $issues;

	my $code_path_2 = '../summary_files/' . $hse_type . '_' . $region . '_code-count';
	open (my $CODE_COUNT, '>', "$code_path_2.csv") or die ("can't open datafile: $code_path_2.csv");	# open the a CODE REPORT file
	
	{
		local $Data::Dumper::Sortkeys = \&zone_surf_order;
		print $CODE_COUNT Dumper $code_store;
	};
	
	
	
	my $return = {'issues' => $issues, 'BCD_characteristics' => $BCD_characteristics, 'con_info' => $code_store};

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

# 				print "$find\n";
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

		my $message = "MODEL ERROR - $msg; Value = $value;";
		foreach my $key (sort {$a cmp $b} keys (%{$coordinates})) {
			$message = $message . " $key $coordinates->{$key}"
		};
		die "$message\n";
		
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


	sub facing {	# determining the facing zone and surface for the connections file zones that face another zone

		my $condition = shift; # the condition present on the side of the surface which is located outside the thermal zone
		my $zone = shift; # the present zone
		my $surface = shift; # the present surface (e.g. floor, ceiling)
		my $zones = shift; # has zone_num => zone_name and zone_name => zone_num
		my $record_indc = shift; # info about the zones and surfaces (e.g. surface indices)
		my $coordinates = shift;
		
		# DECLARE a hash reference to store the information regarding what the surface is facing
		my $facing = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'facing'}};

		# check to see if we have already DEFINED THE ORIENTATION and if so set it equal to it
		if (defined($record_indc->{$zone}->{'surfaces'}->{$surface}->{'orientation'})) {
			$facing->{'orientation'} = $record_indc->{$zone}->{'surfaces'}->{$surface}->{'orientation'};
		}
		# otherwise LOOK UP THE ORIENTATION  if it is a floor or ceiling
		elsif ($surface =~ /^floor|^ceiling/) {
			$facing->{'orientation'} = {'floor' => 'FLOR', 'floor-exposed' => 'FLOR', 'ceiling' => 'CEIL', 'ceiling-exposed' => 'CEIL'}->{$surface};
		}
		# otherwise, the side, window, and door surface types are all VERTICAL
		else {
			$facing->{'orientation'} = 'VERT';
		};
		
		# Use the FACING CONDITION to determine information
		
		# faces another zone
		if ($condition eq 'ANOTHER') {
			# determine the facing zone's name by looking up the name of the zone one above or below
			# this depends on the present surface type (floor looks one down (-1) and ceiling looks one up (+1))
			$facing->{'zone_name'} = $zones->{'num->name'}->{$zones->{'name->num'}->{$zone} + {'floor' => -1, 'ceiling' => 1}->{$surface}};
			# determine the facing zone's number
			$facing->{'zone_num'} = $zones->{'name->num'}->{$facing->{'zone_name'}};
			# determine the facing surface name by being opposite
			$facing->{'surface_name'} = {'floor' => 'ceiling', 'ceiling' => 'floor'}->{$surface};
			# determine the facing zone's surface number
			$facing->{'surface_num'} = $record_indc->{$facing->{'zone_name'}}->{'surfaces'}->{$facing->{'surface_name'}}->{'index'};
		}
		
		# faces exterior
		elsif ($condition eq 'EXTERIOR') {
			$facing->{'zone_name'} = 'exterior';
			# exterior faces 0
			$facing->{'zone_num'} = 0;
			# exterior
			$facing->{'surface_name'} = 'exterior';
			# exterior faces 0
			$facing->{'surface_num'} = 0;
		}
		
		# faces adiabatic
		elsif ($condition eq 'ADIABATIC') {
			$facing->{'zone_name'} = 'adiabatic';
			# adiabatic faces 0
			$facing->{'zone_num'} = 0;
			# adiabatic 			
			$facing->{'surface_name'} = 'adiabatic';
			# exterior faces 0
			$facing->{'surface_num'} = 0;
		}
		
		# faces BASESIMP
		elsif ($condition eq 'BASESIMP') {
			$facing->{'zone_name'} = 'basesimp';
			$facing->{'surface_name'} = 'basesimp';
			
			# determine the BASESIMP type
			# for basements
			if ($zone =~ /^bsmt$/) {
				# basement corresponds to basesimp type 1
				$facing->{'zone_num'} = 1;
				# allocation of heat loss (%) is equal to this surface's area divided by the base-sides. This is also true for walkouts because we do not want the total to be 100%
				$facing->{'surface_num'} = sprintf("%.0f", $record_indc->{$zone}->{'SA'}->{$surface} / $record_indc->{$zone}->{'SA'}->{'base-sides'} * 100);
			}
			# for crawl or slab on grade which is treated as a slab
			elsif ($zone =~ /^crawl$|^main_1$/) {
				# these correspond to basesimp type 28 (slab)
				$facing->{'zone_num'} = 28;
				# allocation of heat loss (%)
				$facing->{'surface_num'} = 100;
			}
			else {&die_msg ('FACING: BASESIMP called by wrong zone', $zone, $coordinates);};
		}
		
		else {&die_msg ('FACING: Bad type of surface facing condition', $condition, $coordinates);};
		
		# Remember the facing condition
		$facing->{'condition'} = $condition;
		
		return ($facing);
	};


	sub con_surf_conn {	# fill out the construction, surface attributes, and connections for each particular surface
		my $RSI_desired = sprintf ("%.2f", shift); #
		my $zone = shift; # the present zone
		my $surface = shift; # the present surface (either floor or ceiling)
		my $zones = shift; # has zone_num => zone_name and zone_name => zone_num
		my $record_indc = shift; # info about the zones and surfaces (e.g. surface indices)
		my $issues = shift; # issue storage
		my $coordinates = shift; # coordinates for issues

		
		# determine the surface index
		my $surface_index = $record_indc->{$zone}->{'surfaces'}->{$surface}->{'index'};
		
		# shorten the construction name
		my $con = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'construction'}};

		
		# shorten the facing name
		my $facing = \%{$record_indc->{$zone}->{'surfaces'}->{$surface}->{'facing'}};
		
		# check to see if the full construction is defined, if it is not, the use the construction database to build it.
		unless (defined ($con->{'layers'})) {
			# Note we are cloning the database so that it is not used itself (messing up subseuqent calls to the database)
			%{$con} = %{dclone($con_data->{$con->{'name'}})};

		}
		# otherwise, determine the type (OPAQ or TRAN) from the database
		else {
			$con->{'type'} = $con_data->{$con->{'name'}}->{'type'};
		};
		
		# record the surface attributes to an array
		$record_indc->{$zone}->{'surfaces'}->{$surface}->{'surf_attributes'} = [$surface_index, $surface, $con->{'type'}, $facing->{'orientation'}, $con->{'name'}, $facing->{'condition'}]; # floor faces the foundation ceiling
		
		# record the surface connections to an array with supplementary information
		$record_indc->{$zone}->{'surfaces'}->{$surface}->{'connections'} = [$zones->{'name->num'}->{$zone}, $surface_index, {'ANOTHER' => 3, 'EXTERIOR' => 0, 'BASESIMP' => 6, 'ADIABATIC' => 5}->{$facing->{'condition'}}, $facing->{'zone_num'}, $facing->{'surface_num'},"# $zone $surface facing $facing->{'zone_name'} ($facing->{'condition'})"];	# floor faces (3) foundation zone () ceiling ()


		# initialize an hash ref to store links to the insulation components
		my $insulation = {};
		
		# intialiaze an RSI value
		$con->{'RSI_orig'} = 0;
		$con->{'RSI_expected'} = $RSI_desired;
		
		# cycle through the layer and determine the total RSI and the insulation layers
		foreach my $layer (@{$con->{'layers'}}) {
			# RSI = (mm/1000)/k
			$con->{'RSI_orig'} = $con->{'RSI_orig'} + ($layer->{'thickness_mm'} / 1000) / $mat_data->{$layer->{'mat'}}->{'conductivity_W_mK'};
			
			# if the layers component type begins with insulation then
			if ($layer->{'component'} =~ /^insulation/) {
				# store the reference to the insulation layer properties
				$insulation->{$layer->{'component'}} = $layer;
			};
		};
		
		# format the calculated value
		$con->{'RSI_orig'} = sprintf ("%.2f", $con->{'RSI_orig'});

		# if the desired RSI is 0 that means do not modify for an RSI value
		# if it is other than zero, modify the insulation to achieve the desired value
		unless ($RSI_desired == 0) {
		
			# create a local RSI so we can modify it with the insulation layers without affecting the original value
			my $RSI = $con->{'RSI_orig'};
			
			# cycle through the insulation layers to adjust their thickness to equate the RSI to that desired
			INSUL_CHECK: foreach my $layer (sort {$a cmp $b} keys (%{$insulation})) {
				# calculate the RSI diff (negative means make insulation less thick)
				my $RSI_diff = $RSI_desired - $RSI;
				# calculate the thickness difference required for this insulation layer to make that change in RSI (RSI * k * 1000)
				my $thickness_diff_mm = $RSI_diff * $mat_data->{$insulation->{$layer}->{'mat'}}->{'conductivity_W_mK'} * 1000;
				# store the original thickness for later printout
				$insulation->{$layer}->{'thickness_mm_orig'} = $insulation->{$layer}->{'thickness_mm'};
				
				# pick a minimum allowable mm
				my $min_thickness_mm = 0.1;

				
				# if the thickness difference is greater than the existing thickness, we have to set a minimum so we move onto the next insulation layer
				if ($insulation->{$layer}->{'thickness_mm'} + $thickness_diff_mm <= $min_thickness_mm) {
					

					# calculate the change in RSI with the limitation ((min - thickness)/1000) / k
					$RSI_diff = (($min_thickness_mm - $insulation->{$layer}->{'thickness_mm'}) / 1000) / $mat_data->{$insulation->{$layer}->{'mat'}}->{'conductivity_W_mK'};
					# note this change to the RSI for the next insulation layer
					$RSI = $RSI + $RSI_diff;
					# store the new insulation thickness
					$insulation->{$layer}->{'thickness_mm'} = $min_thickness_mm;
					# now loop out and check the next insulation layer
				}
				else {
					# there is sufficient thickness to modify the insulation layer and still have a positive thickness.
					# so do the modification
					$insulation->{$layer}->{'thickness_mm'} = sprintf ("%.0f", $insulation->{$layer}->{'thickness_mm'} + $thickness_diff_mm);
					# jump out because we no longer need to check the next insulation layer
					last INSUL_CHECK;
				};
				
			};

		};
	
		$con->{'RSI_final'} = 0;
		# cycle through the layer and determine the total RSI for comparison NOTE: this is a double check
		foreach my $layer (@{$con->{'layers'}}) {
			# RSI = (mm/1000)/k
			$con->{'RSI_final'} = $con->{'RSI_final'} + ($layer->{'thickness_mm'} / 1000) / $mat_data->{$layer->{'mat'}}->{'conductivity_W_mK'};
		};
		
		# format the calculated value
		$con->{'RSI_final'} = sprintf ("%.2f", $con->{'RSI_final'});
		
		# report if the values is not as expected
		if ($RSI_desired != 0 && $con->{'RSI_final'} != $RSI_desired) {
			$issues = set_issue("%s", $issues, 'Insulation', 'Cannot alter insulation to equal RSI_desired (RSI RSI_desired zone surface house)', "$con->{'RSI_final'} $RSI_desired $zone $surface", $coordinates);
		};


		return (1);
	};

	sub zone_surf_order {
		my $hash = shift;
		
		#create an initial ordering of the hash keys based on cmp
		my @order_no_presedence = sort {$a cmp $b} keys %{$hash};
		
		# a hash reference to store the presendence order (e.g. $key = {'bsmt' => 1, 'crawl' => 2}) 
		my $key = {};
		
		# zone ordering from foundation to attic/roof
		foreach my $zone qw(bsmt crawl main_1 main_2 main_3 attic roof) {
			# store the key with its presendence number
			$key->{$zone} = keys %{$key};
		};
		
		# surface ordering from floor to ceiling to sides
		foreach my $surface_basic qw(floor ceiling front right back left) {
		# add the options: we expect things like ceiling-exposes, front-aper and back-door
		# note the use of '' as a blank string
			foreach my $other ('', '-exposed', '-aper', '-frame', '-door') {
				# concatenate
				my $surface = $surface_basic . $other;
				# store the key with its presendence number
				$key->{$surface} = keys %{$key};
			};
		};

		# code/default ordering
		foreach my $zone qw(coded defined reversed default name codes) {
			# store the key with its presendence number
			$key->{$zone} = keys %{$key};
		};

		# now provide presendence values for the remaining keys
		foreach my $other (@order_no_presedence) {
			unless (defined ($key->{$other})) {
				$key->{$other} = keys %{$key};
			};
		}
		
		# now return a reference to the ordered keys with presendence
		return [sort {$key->{$a} <=> $key->{$b}} @order_no_presedence];
	};


};
