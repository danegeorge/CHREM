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
# Declare variables and defaults
#--------------------------------------------------------------------

#my variables
my @hse_types = (2);							#House types to generate
my %hse_names = (1, "SD", 2, "DR");

my @regions = (1);						#Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");


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

	#The template extentions that will be used in file generation
	my %extensions = ("aim", 1, "bsm", 2, "cfg", 3, "cnn", 4, "con", 5, "ctl", 6, "geo", 7, "opr", 8, "tmc", 9);
	my @template;			#declare an array to hold the original templates for use with the generation house files for each record

	#Open and read the template files
	foreach my $ext (keys %extensions) {			#do for each extention
		open (TEMPLATE, '<', "templates/template.$ext") or die ("can't open tempate: $ext");	#open the template
		$template[$extensions{$ext}]=[<TEMPLATE>];	#Slurp the entire file with one line per array element
		close TEMPLATE;					#close the template file and loop to the next one
	}

	#Open the data source files from the CSDDRD
	my $input_path = "CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref-$hse_names{$hse_type}_subset-$hse_names{$hse_type}-#$region.csv";	#path to the correct CSDDRD type and region file
	open (CSDDRD_DATA, '<', "$input_path") or die ("can't open datafile: $input_path");	#open the correct CSDDRD file to use as the data source
	$_ = <CSDDRD_DATA>;									#strip the first header row from the CSDDRD file

	#Go through each remaining line of the CSDDRD source datafile
	while (<CSDDRD_DATA>) {
		my @CSDDRD = CSVsplit($_);		#split each of the comma delimited fields for use
		$CSDDRD[1] =~ s/.HDF//;			#strip the ".HDF" from the record name
		my $output_path = "$hse_type-$hse_names{$hse_type}/$region_names{$region}/$CSDDRD[1]";	#path to the folder for writing the house folder
		mkpath ("$output_path");		#make the output path directory tree

		#Set the primary indicators which control the number of files generated for the house
		my $bsm_indc=0;								#declare the indicator variables
		my $bsmt_indc=0;
		my $attc_indc=0;
		if ($CSDDRD[15] != 7) {$bsm_indc = 1}					#set *.bsm (BASESIMP) indicator unless "open crawlspace"
		if (($CSDDRD[15] != 7) && ($CSDDRD[15] != 10))  {$bsmt_indc = 1}	#set basement zone indicator unless "open crawlspace" or "slab"
		if (($CSDDRD[18] != 1) && ($CSDDRD[18] != 4))  {$attc_indc = 1}		#set attic zone indicator unless flat ceiling is type "N/A" or "flat"

		#Initialize output file arrays for the present house record based on the templates
		my @hse_file;					#for use of this record
		foreach my $ext (values %extensions) {
			$hse_file[$ext]=[@{$template[$ext]}];	#set equal to templates
		}

		#generate the cfg file
#		& cfg ([@CSDDRD], [@{$hse_file[$extensions{cfg}]}]);
		


		#Print out each esp-r house file for the house record
		foreach my $ext (keys %extensions) {
			open (FILE, '>', "$output_path/$CSDDRD[1].$ext") or die ("can't open datafile: $output_path/$CSDDRD[1].$ext");	#open a file on the hard drive in the directory tree
			foreach my $line (@{$hse_file[$extensions{$ext}]}) {	#loop through each element of the array (i.e. line of the final file)
				print FILE "$line";				#print each line out
			}
			close FILE;
		}
	}	#end of the while loop through the CSDDRD
}	#end of main code

# sub cfg () {
# 	my @CSDDRD = [@{$_[0]};
# 	my @hse_file = @{$_[1]};
# 	push (@{$_[1]}, $_[0]->[1]);
# }