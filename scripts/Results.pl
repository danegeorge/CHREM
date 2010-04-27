#!/usr/bin/perl
# 
#====================================================================
# Results2.pl
# Author:    Lukas Swan
# Date:      Apr 2010
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all] set_name [cores/start_core/end_core]
# Use start and end cores to evenly divide the houses between two machines (e.g. QC2 would be [16/9/16]) [house names that are the only desired]
#
# DESCRIPTION:
# This script aquires results


#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;

use CSV; #CSV-2 (for CSV split and join, this works best)
#use Array::Compare; #Array-Compare-1.15
#use Switch;
use XML::Simple; # to parse the XML results files
use XML::Dumper;
use threads; #threads-1.71 (to multithread the program)
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

#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------
my $hse_types; # declare an hash array to store the house types to be modeled (e.g. 1 -> 1-SD)
my $regions; # declare an hash array to store the regions to be modeled (e.g. 1 -> 1-AT)
my $set_name; # store the results set name
my $cores; # store the input core info
my @houses_desired; # declare an array to store the house names or part of to look

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if (@ARGV < 4) {die "A minimum FOUR arguments are required: house_types regions set_name core_information  [house names]\n";};
	
	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
	($hse_types, $regions, $set_name) = &hse_types_and_regions_and_set_name(shift(@ARGV), shift(@ARGV), shift(@ARGV));

	# Check the cores arguement which should be three numeric values seperated by a forward-slash
	unless (shift(@ARGV) =~ /^([1-9]?[0-9])\/([1-9]?[0-9])\/([1-9]?[0-9])$/) {
		die ("CORE argument requires three Positive numeric values seperated by a \"/\": #_of_cores/low_core_#/high_core_#\n");
	};
	
	# set the core information
	# 'num' is total number of cores (if only using a single QC (quad-core) then 8, if using two QCs then 16
	# 'low' is starting core, if using two QCs then the first QC has a 1 and the second QC has a 9
	# 'high' is ending core, value is 8 or 16 depending on machine
	@{$cores}{'num', 'low', 'high'} = ($1, $2, $3);
	
	# check the core infomration for validity
	unless (
		$cores->{'num'} >= 1 &&
		($cores->{'high'} - $cores->{'low'}) >= 0 &&
		($cores->{'high'} - $cores->{'low'}) <= $cores->{'num'} &&
		$cores->{'low'} >= 1 &&
		$cores->{'high'} <= $cores->{'num'}
		) {
		die ("CORE argument numeric values are inappropriate (e.g. high_core > #_of_cores)\n");
	};

	# Provide support to only simulate some houses
	@houses_desired = @ARGV;
	# In case no houses were provided, match everything
	if (@houses_desired == 0) {@houses_desired = '.'};
	
	my $localtime = localtime(time);
	print "Start Time: $localtime\n";
};

#--------------------------------------------------------------------
# Identify the house folders for results aquisition
#--------------------------------------------------------------------
my @folders;	#declare an array to store the path to each hse which will be simulated

foreach my $hse_type (&array_order(values %{$hse_types})) {		#each house type
	foreach my $region (&array_order(values %{$regions})) {		#each region
		push (my @dirs, <../$hse_type$set_name/$region/*>);	#read all hse directories and store them in the array
# 		print Dumper @dirs;
		CHECK_FOLDER: foreach my $dir (@dirs) {
			# cycle through the desired house names to see if this house matches. If so continue the house build
			foreach my $desired (@houses_desired) {
				# it matches, so set the flag
				if ($dir =~ /\/$desired/) {
					push (@folders, $dir);
					next CHECK_FOLDER;
				};
			};
		};
	};
};


#--------------------------------------------------------------------
# Delete old summary files
#--------------------------------------------------------------------
foreach my $file (<../summary_files/*>) { # Loop over the files
	my $check = 'Results' . $set_name . '_';
	if ($file =~ /$check/) {unlink $file;};
};


#--------------------------------------------------------------------
# Determine how many houses go to each core for core usage balancing
#--------------------------------------------------------------------
my $interval = int(@folders/$cores->{'num'}) + 1;	#round up to the nearest integer



#--------------------------------------------------------------------
# Multithread to aquire the xml results faster, merge then print them out to csv files
#--------------------------------------------------------------------
MULTITHREAD_RESULTS: {

	my $thread; # Declare threads for each core
	
	foreach my $core (1..$cores->{'num'}) { # Cycle over the cores
		if ($core >= $cores->{'low'} && $core <= $cores->{'high'}) { # Only operate if this is a desireable core
			my $low_element = ($core - 1) * $interval; # Hse to start this particular core at
			my $high_element = $core * $interval - 1; # Hse to end this particular core at
			if ($core == $cores->{'num'}) { $high_element = $#folders}; # If the final core then adjust to end of array to account for rounding process

			$thread->{$core} = threads->new(\&collect_results_data, @folders[$low_element..$high_element]); # Spawn the threads and send to subroutine, supply the folders
		};
	};

	my $results_all = {}; # Declare a storage variable
	
	foreach my $core (1..$cores->{'num'}) { # Cycle over the cores
		if ($core >= $cores->{'low'} && $core <= $cores->{'high'}) { # Only operate if this is a desireable core
			$results_all = merge($results_all, $thread->{$core}->join()); # Return the threads together for info collation using the merge function
		};
	};
	
	# Create a file to print out the xml results
	my $xml_dump = new XML::Dumper;
	my $filename = '../summary_files/Results' . $set_name . '_All.xml';
	$xml_dump->pl2xml($results_all, $filename);

	# Re-read the file to check that this works
# 	$results_all = $xml_dump->xml2pl($filename);
	
	# Call the remaining results printout and pass the results_all
	&print_results_out($results_all, $set_name);
	
	my $localtime = localtime(time);
	print "End Time: $localtime\n";
};

#--------------------------------------------------------------------
# Subroutine to collect the XML data
#--------------------------------------------------------------------
sub collect_results_data {
	my @folders = @_;
	
	#--------------------------------------------------------------------
	# Cycle through the data and collect the results
	#--------------------------------------------------------------------
	my $results_all = {}; # Declare a storage variable

	# Declare and fill out a set out formats for values with particular units
	my $units = {};
	@{$units}{qw(GJ W kg kWh l m3 tonne)} = qw(%.1f %.0f %.0f %.0f %.0f %.0f %.3f);

	# Cycle over each folder
	FOLDER: foreach my $folder (@folders) {
		# Determine the house type, region, and hse_name
		my ($hse_type, $region, $hse_name) = ($folder =~ /^\.\.\/(\d-\w{2}).+\/(\d-\w{2})\/(\w+)$/);

		# Open the CFG file and find the province name
		my $filename = $folder . "/$hse_name.cfg";
		open (my $CFG, '<', $filename) or die ("\n\nERROR: can't open $filename\n");
		my @cfg = &rm_EOL_and_trim(<$CFG>); # Clean it up
		my @province = grep(s/^#PROVINCE (.+)$/$1/, @cfg); # Stores the province name at element 0

		# Examine the directory and see if a results file (house_name.xml) exists. If it does than we had a successful simulation. If it does not, go on to the next house.
		unless (grep(/$hse_name.xml$/, <$folder/*>)) {
			# Store the house name so we no it is bad - with a note
			$results_all->{'bad_houses'}->{$region}->{$province[0]}->{$hse_type}->{$hse_name} = 'Missing the XML file';
			next FOLDER;  # Jump to the next house if it does not return a true.
		};
		
		# Otherwise continue by reading the results XML file
		my $results_hse = XMLin($folder . "/$hse_name.xml");

		# Cycle over the results and filter for SCD (secondary consumption), the '' will skip anything else
		foreach my $key (@{&order($results_hse->{'parameter'}, ['CHREM/SCD'], [''])}) {
			# Determine the important aspects of this key's name as they will all be CHREM/SCD. But do it as a second variable so we don't affect the original structure
			my ($param) = ($key =~ /^CHREM\/SCD\/(.+)$/);
			
			# If the parameter is in units for energy (as opposed to GHG or quantity) then we can store the min/max/avg information of watts demand)
			if ($param =~ /energy$/) {
				# Cycle over the different min/max/avg types
				foreach my $val_type (qw(total_average active_average min max)) {
					&check_add_house_result($hse_name, $key, $param, $val_type, $units, $results_hse, $results_all);
				};
			};

			# For all parameters store the integrated value - this will work for GHG and quantities, as well as energy of course
			# It employs the same logic as above so it is not commented
			my $val_type = 'integrated';
			&check_add_house_result($hse_name, $key, $param, $val_type, $units, $results_hse, $results_all);
		};

		# Certain houses have values outside a reasonable range and as such xml reporting gives an 'nan'
		# Cycle over each storage position and check for nan and if so throw it out
		foreach my $key (keys(%{$results_all->{'house_results'}->{$hse_name}})) {
			# Check for 'nan' anywhere in the data
			if ($results_all->{'house_results'}->{$hse_name}->{$key} =~ /nan/i) {
				# Store the house name so we no it is bad - with a note
				$results_all->{'bad_houses'}->{$region}->{$province[0]}->{$hse_type}->{$hse_name} = "Bad XML data - $results_all->{'house_results'}->{$hse_name}->{$key}";
				# Delete this house so it does not affect the multiplier
				delete($results_all->{'house_results'}->{$hse_name});
				next FOLDER;  # Jump to the next house if it does not return a true.
			};
		};
		
		# Store the hse_name at the corresponding region-province-housetype
		push(@{$results_all->{'house_names'}->{$region}->{$province[0]}->{$hse_type}}, $hse_name);
		# Store the simulation period for this particular house (to be used as a verifier)
		$results_all->{'house_results'}->{$hse_name}->{'sim_period'} = $results_hse->{'sim_period'};
		
	};
	# print Dumper $results_all;
	
	return ($results_all);
};

