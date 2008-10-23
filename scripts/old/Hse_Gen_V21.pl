#!/usr/bin/perl
# 
#====================================================================
# Hse_Gen_V21.pl
# Author:    Lukas Swan
# Date:      Aug 2008
# Copyright: Dalhousie University
#
# DESCRIPTION:
# This script generates the esp-r house files for each house of the CSDDRD.
# It uses a multithreading approach based on the house type (SD or DR) and 
# region (AT, QC, OT, PR, BC). Which types and regions are generated is 
# specified at the beginning of the script to allow for partial generation.
# 
# The script builds a directory structure for the houses which begins with 
# the house type as top level directories, regions as second level directories 
# and the house name (10 digit w/o ".HDF") for each house directory. It places 
# all house files within that directory (all house files in the same directory). 
# 
# The script reads a set of input files:
# 1) CSDDRD type and region database (csv)
# 2) esp-r file templates (template.xxx)
# 3) weather station cross reference list
# 
# The script copies the template files for each house of the CSDDRD and replaces
# and inserts within the templates based on the values of the CSDDRD house. Each 
# template file is explicitly dealt with in the main code (actually a sub) and 
# utilizes insert and replace subroutines to administer the specific house 
# information.
# 
# The script is easily extendable to addtional CSDDRD files and template files.
# Care must be taken that the appropriate lines of the template file are defined 
# and that any required changes in other template files are completed.
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
use File::Path;		#File-Path-2.04 (to create directory trees)
use File::Copy;		#(to copy the input.xml file)


#--------------------------------------------------------------------
# Declare important variables and defaults
#--------------------------------------------------------------------
my @hse_types = (2);							#House types to generate
my %hse_names = (1, "SD", 2, "DR");

my @regions = (1);							#Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");


#--------------------------------------------------------------------
# Initiate multi-threading to run each region simulataneously
#--------------------------------------------------------------------
mkpath ("../summary_files");
print "PLEASE CHECK THE gen_summary.out FILE IN THE ../summary_files DIRECTORY FOR ERROR LISTING\n";
open (GEN_SUMMARY, '>', "../summary_files/gen_summary.out") or die ("can't open ../summary_files/gen_summary.out");	#open a error and summary writeout file
my $start_time= localtime();	#note the start time of the file generation

my @thread;		#Declare threads
my @thread_return;	#Declare a return array for collation of returning thread data

foreach my $hse_type (@hse_types) {								#Multithread for each house type
	foreach my $region (@regions) {								#Multithread for each region
		$thread[$hse_type][$region] = threads->new(\&main, $hse_type, $region); 	#Spawn the thread
	}
}
foreach my $hse_type (@hse_types) {
	foreach my $region (@regions) {
		$thread_return[$hse_type][$region] = [$thread[$hse_type][$region]->join()];	#Return the threads together for info collation
	}
}

my $end_time= localtime();	#note the end time of the file generation
print GEN_SUMMARY "start time $start_time; end time $end_time\n";	#print generation characteristics
close GEN_SUMMARY;



#--------------------------------------------------------------------
# Main code that each thread evaluates
#--------------------------------------------------------------------
sub main () {
	my $hse_type = $_[0];		#house type number for the thread
	my $region = $_[1];		#region number for the thread


	#-----------------------------------------------
	# Declare important variables for file generation
	#-----------------------------------------------
	#The template extentions that will be used in file generation (alphabetical order)
	my %extensions = ("aim", 1, "bsm", 2, "cfg", 3, "cnn", 4, "con", 5, "ctl", 6, "geo", 7, "log", 8, "opr", 9, "tmc", 10);


	#-----------------------------------------------
	# Read in the templates
	#-----------------------------------------------
	my @template;		#declare an array to hold the original templates for use with the generation house files for each record

	#Open and read the template files
	foreach my $ext (keys %extensions) {			#do for each extention
		open (TEMPLATE, '<', "../templates/template.$ext") or die ("can't open tempate: $ext");	#open the template
		$template[$extensions{$ext}]=[<TEMPLATE>];	#Slurp the entire file with one line per array element
		close TEMPLATE;					#close the template file and loop to the next one
	}


	#-----------------------------------------------
	# Read in the CWEC weather data crosslisting
	#-----------------------------------------------	
	#Open and read the climate crosslisting (city name to CWEC file)
	open (CWEC, '<', "../climate/city_to_CWEC.csv") or die ("can't open datafile: ../climate/city_to_CWEC.csv");
	my @climate_ref;	#create an climate referece crosslisting array
	while (<CWEC>) {push (@climate_ref, [CSVsplit($_)]);};	#append the next line of data to the climate_ref array
	close CWEC;		#close the CWEC file


	#-----------------------------------------------
	# Open the CSDDRD source
	#-----------------------------------------------
	#Open the data source files from the CSDDRD
	my $input_path = "../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref-$hse_names{$hse_type}_subset-$hse_names{$hse_type}-#$region.csv";	#path to the correct CSDDRD type and region file
	open (CSDDRD_DATA, '<', "$input_path") or die ("can't open datafile: $input_path");	#open the correct CSDDRD file to use as the data source
	$_ = <CSDDRD_DATA>;									#strip the first header row from the CSDDRD file


	#-----------------------------------------------
	# Go through each remaining line of the CSDDRD source datafile
	#-----------------------------------------------
	while (<CSDDRD_DATA>) {
 		my $CSDDRD = [CSVsplit($_)];											#split each of the comma delimited fields for use
		$CSDDRD->[1] =~ s/.HDF// or die ("Bad record name: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n");	#strip the ".HDF" from the record name, check for bad filename
		my $output_path = "../$hse_type-$hse_names{$hse_type}/$region_names{$region}/$CSDDRD->[1]";			#path to the folder for writing the house folder
		mkpath ("$output_path");											#make the output path directory tree

		my $record_indc;	#hash for holding the indication of dwelling properties
		my $zone_indc;		#hash for holding the indication of particular zone type for use with foreach statements to quickly cycle through the zones
		$zone_indc->{"main"} = 1;

		if (($CSDDRD->[15] >= 1) && ($CSDDRD->[15] <= 6))  { $record_indc->{"bsmt"} = 1; $record_indc->{"crwl"} = 0; $zone_indc->{"bsmt"} = 1;}	#set basement zone indicator unless "crawlspace" or "slab"
		elsif (($CSDDRD->[15] >= 8) && ($CSDDRD->[15] <= 9)) { $record_indc->{"crwl"} = 1; $record_indc->{"bsmt"} = 0; $zone_indc->{"crwl"} = 1;}	#set the crawlspace indicator for ventilated and closed, not open crawlspace
		elsif (($CSDDRD->[15] == 7) || ($CSDDRD->[15] == 10)) { $record_indc->{"crwl"} = 0; $record_indc->{"bsmt"} = 0;}	#foundation is a open crawlspace (treat as exposed floor) or slab
		else { die ("Bad foundation: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};	#check for foundation validity
		if (($CSDDRD->[15] >= 3) && ($CSDDRD->[15] <= 6)) { $record_indc->{"walk"} = 1} else { $record_indc->{"walk"} = 0;};	#check if a walkout basement

		if (($CSDDRD->[18] != 1) && ($CSDDRD->[18] != 5))  { $record_indc->{"attc"} = 1, $zone_indc->{"attc"} = 1;}			#set attic zone indicator unless flat ceiling is type "N/A" or "flat"
		elsif (($CSDDRD->[18] >= 1) && ($CSDDRD->[18] <= 6)) { $record_indc->{"attc"} = 0} 
		else { die ("Bad flat roof: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};	#check for flat roof validity

		#Initialize output file arrays for the present house record based on the templates
		my $record_extensions = {%extensions};		#extentions for this record
		my $hse_file;					#esp-r files for this record
		foreach my $ext (values %{$record_extensions}) {
			$hse_file->[$ext]=[@{$template[$ext]}];	#set each esp-r house file equal to templates
		};

		#Check if main zone has a tmc file (windows) and set indicator and make new main.tmc
#		if ($CSDDRD->[152]+$CSDDRD->[153]+$CSDDRD->[154]+$CSDDRD->[155]>0) { &hse_file_indc("main", "tmc", $record_indc, $hse_file, $record_extensions); }
#		else { $record_indc->{"main.tmc"} = 0; };
		#Check if main zone has a bsm file (slab) and set indicator and make new main.bsm
		if ($CSDDRD->[15] == 10) { &hse_file_indc("main", "bsm", $record_indc, $hse_file, $record_extensions); }
		else { $record_indc->{"main.bsm"} = 0; };
		#fill out the remaining main zone files
		foreach my $insertion ("opr", "con", "geo") { &hse_file_indc("main", $insertion, $record_indc, $hse_file, $record_extensions); };

		#check for basement, crawlspace and attic presence and make suitable files
		if ($record_indc->{"bsmt"}) { foreach my $ext ("bsm", "opr", "con", "geo") { &hse_file_indc("bsmt", $ext, $record_indc, $hse_file, $record_extensions); } };
		if ($record_indc->{"crwl"}) { foreach my $ext ("bsm", "opr", "con", "geo") { &hse_file_indc("crwl", $ext, $record_indc, $hse_file, $record_extensions); } };
		if ($record_indc->{"attc"}) { foreach my $ext ("opr", "con", "geo") { &hse_file_indc("attc", $ext, $record_indc, $hse_file, $record_extensions); } };

		#delete the references to the template files which have been trumped by individual zone files XXXX.YYY (don't delete the actual template though as we may use them later
		foreach my $ext ("tmc", "bsm", "opr", "con", "geo") { delete $record_extensions->{$ext};};


		#-----------------------------------------------
		# Generate the *.cfg file
		#-----------------------------------------------
		my $time= localtime();
		# subroutine simple_replace (house file to read/write, keyword to identify row, location on line (1=front, 2=inside, 3=end), rows below keyword to replace, replacement text)
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#DATE", 1, 1, "*date $time");	#Put the time of file generation at the top
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#ROOT", 1, 1, "*root $CSDDRD->[1]");	#Label with the record name (.HSE stripped)
		CHECK_CITY: foreach my $location (1..$#climate_ref) {	#cycle through the climate reference list to find a match
			if (($climate_ref[$location][0] =~ /$CSDDRD->[4]/) && ($climate_ref[$location][1] =~ /$CSDDRD->[3]/)) {	#find a matching climate name and province name
				& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#LAT", 1, 1, "$climate_ref[$location][2] $climate_ref[$location][3] # $CSDDRD->[4],$CSDDRD->[3]");	#Use the original weather city lat/long, not CWEC lat/long
				& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#CLIMATE", 1, 1, "*clm ../../../climate/$climate_ref[$location][4]");	#use the CWEC city weather name
				last CHECK_CITY;	#if climate city matched jump out of the loop
			}
			elsif ($location == $#climate_ref) {die ("Bad climate: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n");};	#if climate not found print an error
		}
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#LAT", 1, 2, "1 0.3");	#site exposure and ground reflectivity (rho)
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#AIM_CTL", 1, 1, "*aim ./$CSDDRD->[1].aim");	#aim path
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#AIM_CTL", 1, 2, "*ctl ./$CSDDRD->[1].ctl");	#ctl path
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_SETUP", 1, 2, "*sps 1 10 1 10 5 0");	# sim setup: no. data sets retained; startup days; zone_ts (step/hr); plant_ts (step/hr); ?save_lv @ each zone_ts; ?save_lv @ each zone_ts;
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_SETUP", 1, 3, "1 1 31 12  default");	#simulation start day; start mo.; end day; end mo.; preset name
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#SIM_SETUP", 1, 4, "*sblr $CSDDRD->[1].res");	#res file path
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#PROJ_LOG", 1, 2, "$CSDDRD->[1].log");	#log file path
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#BLD_NAME", 1, 2, "$CSDDRD->[1]");		#name of the building
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#ZONES", 1, 1, 1+$record_indc->{"bsmt"}+$record_indc->{"crwl"}+$record_indc->{"attc"});	#number of zones
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#CONNECT", 1, 1, "*cnn ./$CSDDRD->[1].cnn");	#cnn path
		& simple_replace ($hse_file->[$record_extensions->{"cfg"}], "#AIR", 1, 1, "0");				#air flow network path

		#zone1 (main) paths. 
		& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE1", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
		foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /main.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE1", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "main" (note use of regex brackets and $1)
		& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE1", 1, 1, 0, "*zon 1");	#add the top line (#zon X) for the zone

		#zone2 (bsmt or crwl or attc or non-existant)
		if ($record_indc->{"bsmt"}) {
			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /bsmt.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "bsmt" (note use of regex brackets and $1)
			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zon 2");	#add the top line (#zon X) for the zone
		}
		elsif ($record_indc->{"crwl"}) {
			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /crwl.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "crwl" (note use of regex brackets and $1)
			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zon 2");	#add the top line (#zon X) for the zone
		}
		elsif ($record_indc->{"attc"}) {
			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /attc.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "attc" (note use of regex brackets and $1)
			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE2", 1, 1, 0, "*zon 2");	#add the top line (#zon X) for the zone
		};

		#zone3 (attc or non-existant)
		if (($record_indc->{"bsmt"} || $record_indc->{"crwl"}) && $record_indc->{"attc"}) {
			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE3", 1, 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /attc.(...)/) { & simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE3", 1, 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "attc" (note use of regex brackets and $1)
			& simple_insert ($hse_file->[$record_extensions->{"cfg"}], "#ZONE3", 1, 1, 0, "*zon 3");	#add the top line (#zon X) for the zone
		}


# 		#-----------------------------------------------
# 		# Generate the *.aim file
# 		#-----------------------------------------------
		my $Pa_ELA;
		if ($CSDDRD->[32] == 1) {$Pa_ELA = 10} elsif ($CSDDRD->[32] == 2) {$Pa_ELA = 4} else {die ("Bad Pa_ELA: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};	#set the ELA pressure
		if ($CSDDRD->[28] == 1) {	#Check air tightness type (1= blower door test)
			& simple_replace ($hse_file->[$record_extensions->{"aim"}], "BLOWER_DOOR", 2, 0, "1 $CSDDRD->[31] $Pa_ELA 1 $CSDDRD->[33]");	#Blower door test with ACH50 and ELA specified
		}
		else { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "BLOWER_DOOR", 2, 0, "1 $CSDDRD->[31] $Pa_ELA 0 0"); };			#Airtightness rating, use ACH50 only (as selected in HOT2XP)
		& simple_replace ($hse_file->[$record_extensions->{"aim"}], "EAVE_HEIGHT", 2, 0, "$CSDDRD->[118]");						#set the eave height in meters
#PLACEHOLDER FOR MODIFICATION OF THE FLUE SIZE LINE. PRESENTLY AIM2_PRETIMESTEP.F USES HVAC FILE INSTEAD OF THESE INPUTS
		if ($record_indc->{"bsmt"}) { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "ZONE_INDICES", 2, 2, "2 1 2");}			#main and basement recieve infiltration
		else { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "ZONE_INDICES", 2, 2, "1 1");};						#only main recieves infiltration
		if ($record_indc->{"bsmt"}) { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "ZONE_INDICES", 2, 3, "2 0 0")}				#identify the basement zone for AIM, do not identify the crwl or attc as these will be dealt with in the opr file
		else { & simple_replace ($hse_file->[$record_extensions->{"aim"}], "ZONE_INDICES", 2, 3, "0 0 0")};						#no bsmt, all additional zone infiltration is dealt with in the opr file


# 		#-----------------------------------------------
# 		# Generate the *.bsm file
# 		#-----------------------------------------------
		#placeholder for replacing the VERSION number to invoke the Moore Model for ground temp
		#& simple_replace ($hse_file->[$record_extensions->{bsmt.bsm}], "#VERSION", 1, 0, "1")
		
		#basement
		if ($record_indc->{"bsmt"}) {		#fill out the bsm file based on basement values
			#the height and depth ranges need to be addressed in the source code (esrubld/basesimp.F) to see if they can be extended. Presently we are effectively reducing the size of overly large basements.
			my $height = $CSDDRD->[109];
			if ($height < 1) { $height = 1; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# HEIGHT", 2, 0, "$height");}		#min range of bsmt height (total)
			elsif ($height > 2.5) { $height = 2.5; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# HEIGHT", 2, 0, "$height");}	#max range of bsmt height (total)
			else { & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# HEIGHT", 2, 0, "$height");};				#set bsmt height (total)

			my $depth = $height - $CSDDRD->[115];					#difference between total height and above grade, used below for insul placement as well
			if ($record_indc->{"walk"}) { $depth = ($CSDDRD->[109] - 0.3) / 2};		#walkout basement, attribute 0.3 m above grade and divide remaining by 2 to find equivalent area below grade
			if ($depth < 0.65) { $depth = 0.65; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# DEPTH", 2, 0, "0.65");}		#min range of bsmt depth (below grade), if less than 0.65 m it ESP-r will fault unless it is a slab (0.05 m )
			elsif ($depth > 2.4) { $depth = 2.4; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# DEPTH", 2, 0, "2.4")}	#max range of bsmt depth (below grade)
			else {	& simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# DEPTH", 2, 0, "$depth");			#write out the depth
			};

			my $side_length = $CSDDRD->[97] ** 0.5;			#assume a square building
			if ($side_length < 5) { 
				foreach my $sides ("# LENGTH", "# WIDTH") { & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "$sides", 2, 0, "5")};
				print GEN_SUMMARY "Foundation side length < 5 m, resizing to 5 m square : hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n";
			}	#basement is too small, so increase size to minimum allowable by BSM
			elsif ($side_length <= 12) { foreach my $sides ("# LENGTH", "# WIDTH") { & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "$sides", 2, 0, "$side_length")}}	#fits within the required  range (12 m width) (see earubld/basesimp.F, JP has increased this and we should adopt it)
			else { 	#side lengths do not fit in required range so set width to 12 and lenth suitable to equate area
				my $length = $CSDDRD->[97] / 12;
				if ($length > 100) {	#check the long side length for appropriate range
					$length = 100; 
					print GEN_SUMMARY "Foundation long side length > 100 m, resizing to 100 m : hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n";
				}
				& simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# WIDTH", 2, 0, "12");	
				& simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# LENGTH", 2, 0, "$length");
			};

			if (($CSDDRD->[41] == 4) && ($CSDDRD->[38] > 1)) {	#insulation placed on exterior below grade and on interior
				if ($CSDDRD->[38] == 2) { & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# OVERLAP", 2, 0, "$depth")}	#full interior so overlap is equal to depth
				elsif ($CSDDRD->[38] == 3) { my $overlap = $depth - 0.2; & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# OVERLAP", 2, 0, "$overlap")}	#partial interior to within 0.2 m of slab
				elsif ($CSDDRD->[38] == 4) { & simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# OVERLAP", 2, 0, "0.6")}	#partial interior to 0.6 m below grade
				else { die ("Bad basement insul overlap: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};
			};

			#I have assumed that we only account for the RSI of interior or exterior. Must VERIFY this in source code
			my $insul_RSI = $CSDDRD->[40];						#set the insul value to interior
			if ($CSDDRD->[42] > $CSDDRD->[40]) { $insul_RSI = $CSDDRD->[42]};	#check it exterior value is larger
			if ($insul_RSI > 9) { $insul_RSI = 9};					#check that value is not greater than RSI=9
			& simple_replace ($hse_file->[$record_extensions->{"bsmt.bsm"}], "# RSI", 2, 0, "$insul_RSI");
		}
		#crawl space
		elsif ($record_indc->{"crwl"}) {		#fill out the bsm file based on crawlspace values
			if ($CSDDRD->[110] < 1) { & simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# HEIGHT", 2, 0, "1");}		#min range of crwl height (total)
			elsif ($CSDDRD->[110] > 2.5) { & simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# HEIGHT", 2, 0, "2.5");}	#max range of crwl height (total)
			else { & simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# HEIGHT", 2, 0, "$CSDDRD->[110]");};				#set crwl height (total)

			& simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# DEPTH", 2, 0, "0.05");			#consider crwl space a slab as heat transfer through walls will be dealt with later as they are above grade

			my $side_length = $CSDDRD->[98] ** 0.5;			#assume a square building
			if ($side_length <= 12) { foreach my $sides ("# LENGTH", "# WIDTH") { & simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "$sides", 2, 0, "$side_length")}}	#fits within the required  range (12 m width) (see earubld/basesimp.F, JP has increased this and we should adopt it)
			else { 	#does not fit in required range so set width to 12 and lenth suitable to equate area
				& simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# WIDTH", 2, 0, "12");	
				my $length = $CSDDRD->[98] / 12;
				& simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# LENGTH", 2, 0, "$length");
			}

			my $insul_RSI = $CSDDRD->[56];						#set the insul value to that of the crwl space slab
			if ($insul_RSI > 9) { $insul_RSI = 9};					#check that value is not greater than RSI=9
			& simple_replace ($hse_file->[$record_extensions->{"crwl.bsm"}], "# RSI", 2, 0, "$insul_RSI")
		}

		#slab on grade
		elsif ($CSDDRD->[15] == 10) {		#fill out the bsm file based on slab on grade values
			if ($CSDDRD->[112] < 1) { & simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# HEIGHT", 2, 0, "1");}		#min range of main height (total)
			elsif ($CSDDRD->[112] > 2.5) { & simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# HEIGHT", 2, 0, "2.5")}	#max range of main height (total)
			else { & simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# HEIGHT", 2, 0, "$CSDDRD->[112]");};				#set main height (total)

			& simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# DEPTH", 2, 0, "0.05");			#consider the slab only as heat transfer through walls will be dealt with later as they are above grade

			my $side_length = $CSDDRD->[99] ** 0.5;			#assume a square building
			if ($side_length <= 12) { foreach my $sides ("# LENGTH", "# WIDTH") { & simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "$sides", 2, 0, "$side_length")}}	#fits within the required  range (12 m width) (see earubld/basesimp.F, JP has increased this and we should adopt it)
			else { 	#does not fit in required range so set width to 12 and lenth suitable to equate area
				& simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# WIDTH", 2, 0, "12");	
				my $length = $CSDDRD->[99] / 12;
				& simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# LENGTH", 2, 0, "$length");
			}

			my $insul_RSI = $CSDDRD->[63];						#set the insul value to that of the crwl space slab
			if ($insul_RSI > 9) { $insul_RSI = 9};					#check that value is not greater than RSI=9
			& simple_replace ($hse_file->[$record_extensions->{"main.bsm"}], "# RSI", 2, 0, "$insul_RSI")
		};


		#-----------------------------------------------
		# Control file
		#-----------------------------------------------
		my $heat_watts = $CSDDRD->[79] * 1000;	#multiply kW by 1000 for watts. this is based on HOT2XP's heating sizing protocol
		my $cool_watts = 0;			#initialize a cooling variable
		if (($CSDDRD->[88] >= 1) && ($CSDDRD->[88] <= 3)) { $cool_watts = 0.25 *$heat_watts;};	#if cooling is present size it to 25% of heating capacity
		& simple_replace ($hse_file->[$record_extensions->{"ctl"}], "# DATA_LINE1", 3, 0, "$heat_watts 0 $cool_watts 0 $CSDDRD->[69] $CSDDRD->[70] 0");	#insert the data line (heat_watts_on heat_watts_off, cool_watts_on cool_watts_off heating_setpoint_C cooling_setpoint_C RH_control
		if ($record_indc->{"bsmt"}) { & simple_replace ($hse_file->[$record_extensions->{"ctl"}], "#ZONE_LINKS", 1, 1, "1,1,0");}	#link main and bsmt to control loop. If no attic is present the extra zero will not bomb the prj (hopefully not bomb the bps as well)
		else { & simple_replace ($hse_file->[$record_extensions->{"ctl"}], "#ZONE_LINKS", 1, 1, "1,0,0");}	#no bsmt and crwl spc is not conditioned so zeros other than main

		#-----------------------------------------------
		# Operations files
		#-----------------------------------------------
		foreach my $zone (keys %{$zone_indc}) { & simple_replace ($hse_file->[$record_extensions->{"$zone.opr"}], "#DATE", 1, 1, "*date $time")};	#set the time/date for the main.opr file
		#if no other zones exist then do not modify the main.opr (its only use is for ventilation with the bsmt due to the aim and fcl files
		if ($record_indc->{"bsmt"}) {
			foreach my $days ("WEEKDAY", "SATURDAY", "SUNDAY") {								#do for each day type
				& simple_replace ($hse_file->[$record_extensions->{"main.opr"}], "#AIR_$days", 1, 2, "0 24 0 0.5 2 0");	#add 0.5 ACH ventilation to main from basement. Note they are different volumes so this technically creates imbalance. ESP-r does not seem to account for this (zonal model). This technique should be modified in the future when volumes are known for consistency
				& simple_replace ($hse_file->[$record_extensions->{"bsmt.opr"}], "#AIR_$days", 1, 2, "0 24 0 0.5 1 0");	#add same ACH ventilation to bsmt from main
			};
		}
		elsif ($record_indc->{"crwl"}) {
			my $crwl_ach;
			if ($CSDDRD->[15] == 8) { $crwl_ach = 0.5;}		#set the crwl ACH infiltration based on tightness level. 0.5 and 0.1 ACH come from HOT2XP
			else { $crwl_ach = 0.1;};
			foreach my $days ("WEEKDAY", "SATURDAY", "SUNDAY") { & simple_replace ($hse_file->[$record_extensions->{"crwl.opr"}], "#AIR_$days", 1, 2, "0 24 $crwl_ach 0 0 0");};	#add it as infiltration and not ventilation. It comes from ambient.
		};
		if ($record_indc->{"attc"}) {
			foreach my $days ("WEEKDAY", "SATURDAY", "SUNDAY") { & simple_replace ($hse_file->[$record_extensions->{"attc.opr"}], "#AIR_$days", 1, 2, "0 24 0.5 0 0 0");};	#fixed 0.5 ACH to attic from ambient
		};


		#-----------------------------------------------
		# Preliminary geo file generation
		#-----------------------------------------------
		#for now make square and size it based on main only, no windows.
		foreach my $zone (keys %{$zone_indc}) { 
			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#ZONE_NAME", 1, 1, "GEN $zone This file describes the $zone");	#set the time at the top of each zone geo file

			my $side_length = $CSDDRD->[100] ** 0.5;	#assume a square house and use the main level to dictate size of other zones. CHANGE THIS LATER
			my $height;					#initialize height and vertical offset. Offset is not required for ESP-r but allows for visualization using prj
			my $vert_offset;
			if ($zone eq "main") { $height = $CSDDRD->[112] + $CSDDRD->[113] + $CSDDRD->[114]; $vert_offset = 0;}	#the main zone is height of three potential stories and originates at 0,0,0
			elsif ($zone eq "bsmt") { $height = $CSDDRD->[109]; $vert_offset = -$height;}	#basement or crwl space is offset by its height so that origin is below 0,0,0
			elsif ($zone eq "crwl") { $height = $CSDDRD->[110]; $vert_offset = -$height;}
			elsif ($zone eq "attc") { $height = $side_length * 5 / 12;  $vert_offset = $CSDDRD->[112] + $CSDDRD->[113] + $CSDDRD->[114];};	#attic is assumed to be 5/12 roofline and mounted to top corner of main above 0,0,0
			$height = $height + $vert_offset;	#include the offet in the height to place vertices>1 at the appropriate location
			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 1, "0 0 $vert_offset");	#origin
			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 2, "$side_length 0 $vert_offset");	#procced in CCW (looking down) and rise in levels
			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 3, "$side_length $side_length $vert_offset");
			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 4, "0 $side_length $vert_offset");

			if ($zone ne "attc") {	#box shape for bsmt, crwl, and main
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 5, "0 0 $height");
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 6, "$side_length 0 $height");
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 7, "$side_length $side_length $height");
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 8, "0 $side_length $height");
			}
			else {	#5/12 attic shape
				my $side_length_minus = $side_length / 2 - 0.1; #not a perfect peak, create a centered flat spot to maintain 6 surfaces instead of 5
				my $side_length_plus = $side_length / 2 + 0.1;
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 5, "0 $side_length_minus $height");
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 6, "$side_length $side_length_minus $height");
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 7, "$side_length $side_length_plus $height");
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#VERTICES", 1, 8, "0 $side_length_plus $height");
			}
			
			#adjust the surface descriptions to represent conditions such as facing another zone and basesimp, RECOGNIZE the spacing as it is required by prj (maybe not bps)
			if (($zone eq "main") && ($record_indc->{"bsmt"} || $record_indc->{"crwl"})) { & simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 6, "  6, Base-6        OPAQ  FLOR  CNST-1       ANOTHER        ");}	#if bsmt or crwl then set the main zone floor into another zone
			elsif (($zone eq "main") && $CSDDRD->[15] == 10) { & simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 6, "  6, Base-6        OPAQ  FLOR  CNST-1       BASESIMP       ");};	#if no bsmt or crwl, then if slab set the main floor to basesimp
			if (($zone eq "bsmt") || ($zone eq "crwl")) {	#for bsmt or crwl mate the ceiling to main and the floor to basesimp
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 5, "  5, Top-5         OPAQ  CEIL  CNST-1       ANOTHER        ");
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 6, "  6, Base-6        OPAQ  FLOR  CNST-1       BASESIMP       ");
			};
			if ($zone eq "bsmt") { foreach my $side (1..4) {	#if bsmt then match all walls to basesimp
				& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, $side, "  $side, Wall-$side        OPAQ  VERT  CNST-1       BASESIMP       ");};	
			};
			if (($zone eq "main") && $record_indc->{"attc"}) { & simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 5, "  5, Top-5         OPAQ  CEIL  CNST-1       ANOTHER        ");};	#map roof of main to attc
			if ($zone eq "attc") {& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#SURFACE_ATTRIBUTES", 1, 6, "  6, Base-6        OPAQ  FLOR  CNST-1       ANOTHER        ");};	#map floor of attc to main
			& simple_replace ($hse_file->[$record_extensions->{"$zone.geo"}], "#BASE", 1, 1, "6 0 0 0 0 0 $CSDDRD->[100] 0");	#last line in GEO file which uses surface count and floor area
		}


		#-----------------------------------------------
		# Connections file
		#-----------------------------------------------
		& simple_replace ($hse_file->[$record_extensions->{"cnn"}], "#DATE", 1, 1, "*date $time");	#add the date stamp
		my $cnn_count = 0;	#declare a variable for number of connections
		foreach my $zone (keys %{$zone_indc}) { $cnn_count = $cnn_count + 6;};	#total the number of connections, THIS IS SIMPLIFIED (no windows)
		& simple_replace ($hse_file->[$record_extensions->{"cnn"}], "#CONN_NUM", 1, 1, "$cnn_count");
		if ($record_indc->{"attc"} && ($record_indc->{"bsmt"} || $record_indc->{"crwl"})) {	#make attic the third zone
			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "3 6 3 1 5");	#attach floor of attic to main ceiling
			foreach my $side (5, 4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "3 $side 0 0 0");};	#all remaining attc to ambient
		}
		elsif ($record_indc->{"attc"}) {	#there is no bsmt or crwl so attc is zone #2
			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 6 3 1 5");
			foreach my $side (5, 4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 $side 0 0 0");};
		};
		if ($record_indc->{"bsmt"}) {	#bsmt exists
			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 6 6 1 20");	#attach slab to basesimp, assume inside wall insul, 20% heat loss
			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 5 3 1 6");	#attach bsmt ceiling to main floor
			foreach my $side (4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 $side 6 1 20");};	#remaining sides of bsmt to basesimp, same assumptions
		}
		elsif ($record_indc->{"crwl"}) {	#bsmt exists
			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 6 6 28 100");	#attach slab to basesimp, assume ino slab insul, 100% heat loss
			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 5 3 1 6");	#attach crwl ceiling to main floor
			foreach my $side (4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "2 $side 0 0 0");};	#remaining sides of crwl to ambient
		}
		if ($record_indc->{"bsmt"} || $record_indc->{"crwl"}) {
			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 6 3 2 5");	#check if main is attached to a bsmt or crwl
			if ($record_indc->{"attc"}) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 5 3 3 6");};	#if attc exist then it is zone 3
		}
		elsif ($CSDDRD->[15] == 10) {
			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 6 6 28 100");	#main slab so use basesimp
			if ($record_indc->{"attc"}) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 5 3 2 6");};	#if attc exists then it is zone 2
		}
		else {
			& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 6 0 0 0");	#main has exposed floor
			if ($record_indc->{"attc"}) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 5 3 2 6");};	#if attc exists then it is zone 2
		}
		if (!$record_indc->{"attc"}) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 5 0 0 0");};	#attc was not filled out so expose main ceiling to ambient
		foreach my $side (4, 3, 2, 1) {& simple_insert ($hse_file->[$record_extensions->{"cnn"}], "#CONNECTIONS", 1, 1, 0, "1 $side 0 0 0");};	#expose main walls to ambient


		#-----------------------------------------------
		# Constructions file
		#-----------------------------------------------
		foreach my $zone (keys %{$zone_indc}) {
			my $surface_count = 6;
			foreach (1..$surface_count) {& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#LAYERS_GAPS", 1, 1, 0, "1 0");};
			foreach (1..$surface_count) {& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#PROPERTIES", 1, 1, 0, "0.03 250 2000 0.040 0 0 0 0");};
			my $emm_inside = "";
			my $emm_outside = "";
			my $slr_abs_inside = "";
			my $slr_abs_outside = "";
	
			foreach (1..$surface_count) {
				$emm_inside = "0.9 $emm_inside";
				$emm_outside = "0.9 $emm_outside";
				$slr_abs_inside = "0.75 $slr_abs_inside";
				$slr_abs_outside = "0.78 $slr_abs_outside";
			}
			& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#EMM_INSIDE", 1, 1, 0, "$emm_inside");
			& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#EMM_OUTSIDE", 1, 1, 0, "$emm_outside");
			& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#SLR_ABS_INSIDE", 1, 1, 0, "$slr_abs_inside");
			& simple_insert ($hse_file->[$record_extensions->{"$zone.con"}], "#SLR_ABS_OUTSIDE", 1, 1, 0, "$slr_abs_outside");
		}


		#-----------------------------------------------
		# Print out each esp-r house file for the house record
		#-----------------------------------------------
		foreach my $ext (keys %{$record_extensions}) {				#go through each extention inclusive of the zones for this particular record
			open (FILE, '>', "$output_path/$CSDDRD->[1].$ext") or die ("can't open datafile: $output_path/$CSDDRD->[1].$ext");	#open a file on the hard drive in the directory tree
			foreach my $line (@{$hse_file->[$record_extensions->{$ext}]}) {	#loop through each element of the array (i.e. line of the final file)
				print FILE "$line";					#print each line out
			}
			close FILE;
		}
		copy ("../templates/input.xml", "$output_path/input.xml") or die ("can't copy file: input.xml");


	}	#end of the while loop through the CSDDRD->
}	#end of main code


#-----------------------------------------------
# Subroutines
#-----------------------------------------------
sub hse_file_indc() {				#subroutine to add and appropriately name another copy of a template file to support multiple zones (i.e. main.geo, bsmt.geo) and then notes it in the cross reference hash
	my $zone = shift (@_);			#the zone title
	my $ext = shift (@_);			#the extension title
	my $record_indc = shift (@_);		#hash of house characteristics to add too
	my $hse_file = shift (@_);		#array of house esp-r files to add too
	my $record_extensions = shift (@_);	#array of house extentions to add too for the zone and extension
	$record_indc->{"$zone.$ext"} = 1;	#set the indicator true
	push (@{$hse_file},[@{$hse_file->[$record_extensions->{$ext}]}]);	#copy the template file to the new location
	$record_extensions->{"$zone.$ext"} = $#{$hse_file};			#use the hash to record the zone's file and extension and cross reference its location in the array
}


sub simple_replace () {			#subroutine to perform a simple element replace (house file to read/write, keyword to identify row, rows below keyword to replace, replacement text)
	my $hse_file = shift (@_);	#the house file to read/write
	my $find = shift (@_);		#the word to identify
	my $location = shift (@_);	#where to identify the word: 1=start of line, 2=anywhere within the line, 3=end of line
	my $beyond = shift (@_);	#rows below the identified word to operate on
	my $replace = shift (@_);	#replacement text for the operated element
	CHECK_LINES: foreach my $line (0..$#{$hse_file}) {		#pass through the array holding each line of the house file
		if ((($location == 1) && ($hse_file->[$line] =~ /^$find/)) || (($location == 2) && ($hse_file->[$line] =~ /$find/)) || (($location == 3) && ($hse_file->[$line] =~ /$find$/))) {	#search for the identification word at the appropriate position in the line
			$hse_file->[$line+$beyond] = "$replace\n";	#replace the element that is $beyond that where the identification word was found
			last CHECK_LINES;				#If matched, then jump out to save time and additional matching
		}
	}
}

sub simple_insert () {			#subroutine to perform a simple element insert after (specified) the identified element (house file to read/write, keyword to identify row, number of elements after to do insert, replacement text)
	my $hse_file = shift (@_);	#the house file to read/write
	my $find = shift (@_);		#the word to identify
	my $location = shift (@_);	#1=start of line, 2=anywhere within the line, 3=end of line
	my $beyond = shift (@_);	#rows below the identified word to remove from and insert too
	my $remove = shift (@_);	#rows to remove
	my $replace = shift (@_);	#replacement text for the operated element
	CHECK_LINES: foreach my $line (0..$#{$hse_file}) {		#pass through the array holding each line of the house file
		if ((($location == 1) && ($hse_file->[$line] =~ /^$find/)) || (($location == 2) && ($hse_file->[$line] =~ /$find/)) || (($location == 3) && ($hse_file->[$line] =~ /$find$/))) {	#search for the identification word at the appropriate position in the line
			splice (@{$hse_file}, $line+$beyond, $remove, "$replace\n");	#replace the element that is $beyond that where the identification word was found
			last CHECK_LINES;				#If matched, then jump out to save time and additional matching
		}
	}
}
