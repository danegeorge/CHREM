#!/usr/bin/perl
# 
#====================================================================
# V1.pl
# Author:    Lukas Swan
# Date:      June 2008
# Copyright: Dalhousie University
#
# Requirements
#
# DEPENDENCIES:
# ???
#--------------------------------------------------------------------

#--------------------------------------------------------------------

#===================================================================

use warnings;
use strict;
use CSV;		#CSV-2 (for CSV split and join, this works best)
use Array::Compare;	#Array-Compare-1.15
use Switch;
use threads;		#threads-1.71 (to multithread the program)
use File::Path;		#File-Path-2.04 (to create directory trees)

#--------------------------------------------------------------------
# Prototypes
#--------------------------------------------------------------------
#sub xxx();

#--------------------------------------------------------------------
# Declare importnat variables and defaults
#--------------------------------------------------------------------
my @hse_types = (2);							#House types to generate
my %hse_names = (1, "SD", 2, "DR");

my @regions = (1);							#Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");
#--------------------------------------------------------------------
# Done
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# Intiate by multi-threading to run each region simulataneously
#--------------------------------------------------------------------
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
		
		if (($CSDDRD->[15] != 7) && ($CSDDRD->[15] != 10))  {$record_indc->{"bsmt"} = 1}		#set basement zone indicator unless "open crawlspace" or "slab"
		elsif (($CSDDRD->[15] >= 1) && ($CSDDRD->[15] <= 10)) {$record_indc->{"bsmt"} = 0}
		else {die ("Bad foundation: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};	#check for foundation validity

		if (($CSDDRD->[18] != 1) && ($CSDDRD->[18] != 5))  {$record_indc->{"attc"} = 1}			#set attic zone indicator unless flat ceiling is type "N/A" or "flat"
		elsif (($CSDDRD->[18] >= 1) && ($CSDDRD->[18] <= 6)) {$record_indc->{"attc"} = 0} 
		else {die ("Bad flat roof: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n")};	#check for flat roof validity

		#Initialize output file arrays for the present house record based on the templates
		my $record_extensions = {%extensions};		#extentions for this record
		my $hse_file;					#esp-r files for this record
		foreach my $ext (values %{$record_extensions}) {
			$hse_file->[$ext]=[@{$template[$ext]}];	#set each esp-r house file equal to templates
		};

		#Check if main zone has a tmc file (windows) and set indicator and make new main.tmc
		if ($CSDDRD->[152]+$CSDDRD->[153]+$CSDDRD->[154]+$CSDDRD->[155]>0) { &hse_file_indc("main", "tmc", $record_indc, $hse_file, $record_extensions); }
		else { $record_indc->{"main.tmc"} = 0; };
		#Check if main zone has a bsm file (slab) and set indicator and make new main.bsm
		if ($CSDDRD->[15] == 10) { &hse_file_indc("main", "bsm", $record_indc, $hse_file, $record_extensions); }
		else { $record_indc->{"main.bsm"} = 0; };
		#fill out the remaining main zone files
		foreach my $insertion ("opr", "con", "geo") { &hse_file_indc("main", $insertion, $record_indc, $hse_file, $record_extensions); };

		#check for basement and attic presence and make suitable files
		if ($record_indc->{"bsmt"}) { foreach my $ext ("bsm", "opr", "con", "geo") { &hse_file_indc("bsmt", $ext, $record_indc, $hse_file, $record_extensions); } }
		if ($record_indc->{"attc"}) { foreach my $ext ("opr", "con", "geo") { &hse_file_indc("attc", $ext, $record_indc, $hse_file, $record_extensions); } };

		#delete the references to the template files which have been trumped by individual zone files XXXX.YYY (don't delete the actual template though as we may use them later
		foreach my $ext ("tmc", "bsm", "opr", "con", "geo") { delete $record_extensions->{$ext};};

		#-----------------------------------------------
		# Generate the *.cfg file
		#-----------------------------------------------
		my $time= localtime();
		# subroutine simple_replace (house file to read/write, keyword to identify row (must be at start of line), rows below keyword to replace, replacement text)
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#DATE", 1, "*date $time");	#Put the time of file generation at the top
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#ROOT", 1, "*root $CSDDRD->[1]");	#Label with the record name (.HSE stripped)
		CHECK_CITY: foreach my $location (1..$#climate_ref) {	#cycle through the climate reference list to find a match
			if (($climate_ref[$location][0] =~ /$CSDDRD->[4]/) && ($climate_ref[$location][1] =~ /$CSDDRD->[3]/)) {	#find a matching climate name and province name
				& simple_replace ($hse_file->[$record_extensions->{cfg}], "#LAT", 1, "$climate_ref[$location][2] $climate_ref[$location][3] # $CSDDRD->[4],$CSDDRD->[3]");	#Use the original weather city lat/long, not CWEC lat/long
				& simple_replace ($hse_file->[$record_extensions->{cfg}], "#CLIMATE", 1, "*clm ../../../climate/$climate_ref[$location][4]");	#use the CWEC city weather name
				last CHECK_CITY;	#if climate city matched jump out of the loop
			}
			elsif ($location == $#climate_ref) {die ("Bad climate: hse_type=$hse_type; region=$region; record=$CSDDRD->[1]\n");};	#if climate not found print an error
		}
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#LAT", 2, "1 0.3");	#site exposure and ground reflectivity (rho)
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#AIM_CTL", 1, "*aim ./$CSDDRD->[1].aim");	#aim path
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#AIM_CTL", 2, "*ctl ./$CSDDRD->[1].ctl");	#ctl path
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#PROJ_LOG", 2, "$CSDDRD->[1].log");	#log file path
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#BLD_NAME", 2, "$CSDDRD->[1]");		#name of the building
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#ZONES", 1, 1+$record_indc->{"bsmt"}+$record_indc->{"attc"});	#number of zones
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#CONNECT", 1, "*cnn ./$CSDDRD->[1].cnn");	#cnn path
		& simple_replace ($hse_file->[$record_extensions->{cfg}], "#AIR", 1, "0");				#air flow network path

		#zone1 (main) paths. 
		& simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE1", 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
		foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /main.(...)/) { & simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE1", 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "main" (note use of regex brackets and $1)
		& simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE1", 1, 0, "*zon 1");	#add the top line (#zon X) for the zone

		#zone2 (bsmt or attc of non-existant)
		if ($record_indc->{"bsmt"}) {
			& simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE2", 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /bsmt.(...)/) { & simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE2", 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "main" (note use of regex brackets and $1)
			& simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE2", 1, 0, "*zon 2");	#add the top line (#zon X) for the zone
		}
		elsif ($record_indc->{"attc"}) {
			& simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE2", 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /attc.(...)/) { & simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE2", 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "main" (note use of regex brackets and $1)
			& simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE2", 1, 0, "*zon 2");	#add the top line (#zon X) for the zone
		};

		#zone3 (attc or non-existant)
		if ($record_indc->{"bsmt"} && $record_indc->{"attc"}) {
			& simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE3", 1, 0, "*zend");	#provide the *zend first as we will continue to insert above it
			foreach my $ext (keys %{$record_extensions}) { if ($ext =~ /attc.(...)/) { & simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE3", 1, 0, "*$1 ./$CSDDRD->[1].$ext");} }	#add a path for each valid record file with "main" (note use of regex brackets and $1)
			& simple_insert ($hse_file->[$record_extensions->{cfg}], "#ZONE3", 1, 0, "*zon 3");	#add the top line (#zon X) for the zone
		}

 
# 		#-----------------------------------------------
# 		# Generate the *.aim file
# 		#-----------------------------------------------
 		




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


sub simple_replace () {		#subroutine to perform a simple element replace (house file to read/write, keyword to identify row, rows below keyword to replace, replacement text)
	my $hse_file = shift (@_);	#the house file to read/write
	my $find = shift (@_);		#the word to identify
	my $beyond = shift (@_);	#rows below the identified word to operate on
	my $replace = shift (@_);	#replacement text for the operated element
	CHECK_LINES: foreach my $line (0..$#{$hse_file}) {		#pass through the array holding each line of the house file
		if ($hse_file->[$line] =~ /^$find/) {			#search for the identification word (start of line)
			$hse_file->[$line+$beyond] = "$replace\n";	#replace the element that is $beyond that where the identification word was found
			last CHECK_LINES;				#If matched, then jump out to save time and additional matching
		}
	}
}

sub simple_insert () {			#subroutine to perform a simple element insert after (specified) the identified element (house file to read/write, keyword to identify row, number of elements after to do insert, replacement text)
	my $hse_file = shift (@_);	#the house file to read/write
	my $find = shift (@_);		#the word to identify
	my $beyond = shift (@_);	#rows below the identified word to remove from and insert too
	my $remove = shift (@_);	#rows to remove
	my $replace = shift (@_);	#replacement text for the operated element
	CHECK_LINES: foreach my $line (0..$#{$hse_file}) {		#pass through the array holding each line of the house file
		if ($hse_file->[$line] =~ /^$find/) {			#search for the identification word (start of line)
			splice (@{$hse_file}, $line+$beyond, $remove, "$replace\n");	#replace the element that is $beyond that where the identification word was found
			last CHECK_LINES;				#If matched, then jump out to save time and additional matching
		}
	}
}