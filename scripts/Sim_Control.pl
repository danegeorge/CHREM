#!/usr/bin/perl
# 
#====================================================================
# Sim_Control.pl
# Author:    Lukas Swan
# Date:      Aug 2008
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all] [cores/start_core/end_core]
# Use start and end cores to evenly divide the houses between two machines (e.g. QC2 would be [16/9/16])
#
# DESCRIPTION:
# This script divides the desired house simulations up to match the CPU cores 
# and then intiates the simulations. The script reads the directories based on 
# the house type (SD or DR) and # region (AT, QC, OT, PR, BC). Which types and 
# regions are generated is specified at the beginning of the script to allow for 
# partial generation. Note that the beginning of a house folder name may be specified
# to limit the simulation to only matching houses
# 
# The script adds the list of houses to an array and then divides the array by the
# total number of CPU cores used for simulation. It then writes text files with 
# the paths for each house that the simulator will follow and then simulate,
# as well as prescribes these houses to each cores variables.
# 
# The script then performs a system call to conduct the simulations and 
# stores the output information. This information is returned and merged into
# a large hash ref.


#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;

#use CSV;		#CSV-2 (for CSV split and join, this works best)
#use Array::Compare;	#Array-Compare-1.15
#use Switch;
use threads;		#threads-1.71 (to multithread the program)
# use threads::shared;
#use File::Path;	#File-Path-2.04 (to create directory trees)
#use File::Copy;	#(to copy the input.xml file)
use Data::Dumper;

use Hash::Merge qw(merge); # to support merging the results of different house types and regions

# CHREM modules
use lib ('./modules');
use General;

$Data::Dumper::Sortkeys = \&order;

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
	'Merge where scalars are added, and items are (pre)|(ap)pended to arrays', 
);


#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------
my $hse_types;	# declare an hash array to store the house types to be modeled (e.g. 1 -> 1-SD)
my $regions;	# declare an hash array to store the regions to be modeled (e.g. 1 -> 1-AT)
my $cores;	# store the input core info
my @houses_desired; # declare an array to store the house names or part of to look

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if (@ARGV < 3) {die "A minimum Three arguments are required: house_types regions core_information [house names]\n";};
	
	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
	($hse_types, $regions) = &hse_types_and_regions(shift (@ARGV), shift (@ARGV));

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
	
	# Store an all cores array to divide up the directories
	$cores->{'all'} = [1..$cores->{'num'}];
	
	# Store a simulation array so we only go to desired cores for simulation
	$cores->{'sim'} = [$cores->{'low'}..$cores->{'high'}];

	# Provide support to only simulate some houses
	@houses_desired = @ARGV;
	# In case no houses were provided, match everything
	if (@houses_desired == 0) {@houses_desired = '.'};
	
};
# print Dumper $cores;

#--------------------------------------------------------------------
# Identify the house folders for simulation
#--------------------------------------------------------------------
my @dirs;	#declare an array to store the path to each hse which will be simulated

foreach my $hse_type (&array_order(values %{$hse_types})) {		#each house type
	foreach my $region (&array_order(values %{$regions})) {		#each region
		push (my @folders, <../$hse_type/$region/*>);	#read all hse directories and store them in the array
# 		print Dumper @folders;
		CHECK_FOLDER: foreach my $folder (@folders) {
			# cycle through the desired house names to see if this house matches. If so continue the house build
			foreach my $desired (@houses_desired) {
				# it matches, so set the flag
				if ($folder =~ /\/$desired/) {
					push (@dirs, $folder);
					next CHECK_FOLDER;
				};
			};
		};
	};
};

# print Dumper @dirs;

#--------------------------------------------------------------------
# Determine how many houses go to each core for core usage balancing
#--------------------------------------------------------------------
my $interval = int(@dirs/$cores->{'num'}) + 1;	#round up to the nearest integer
# print Dumper $interval;
my $core_dirs = {};	# store the directories for later lookup during simulation

#--------------------------------------------------------------------
# Generate and print lists of directory paths for each core to simulate
#--------------------------------------------------------------------
SIMULATION_LIST: {
	# only print out one file now as it is simply for reporting
	my $file = "../summary_files/hse_listing_per_core";
	my $ext = '.csv';
	open (my $FILE, '>', $file . $ext) or die ("can't open $file$ext");	#open the file to print the list for the core
	
	# Cycle over all the cores
	foreach my $core (@{$cores->{'all'}}) {
		print $FILE "CORE $core\n"; # reporting
		
		# initialize here so that later we can loop on this even if no houses are specified
		$core_dirs->{$core} = [];
		
		# Typical path to get the first interval many houses
		if (@dirs > 0 && $interval <= @dirs) {
			# Cycle over the houses and store them
			foreach (1..$interval) {
				my $folder = shift(@dirs);
				push (@{$core_dirs->{$core}}, $folder);
				print $FILE "\t" . $folder . "\n";	#print the hse path to the list
			};
		}
		# This is for when there are houses left but not as many as the interval
		elsif (@dirs > 0) {
			foreach (0..$#dirs) {
				my $folder = shift(@dirs);
				push (@{$core_dirs->{$core}}, $folder);
				print $FILE "\t" . $folder . "\n";	#print the hse path to the list
			};
		}
		# This is for when we are empty of houses
		else {
			print $FILE "\n";	#print the hse path to the list
		};
		
		print $FILE "\n\n";
	};
};

# print Dumper $core_dirs


#--------------------------------------------------------------------
# Call the simulations.
#--------------------------------------------------------------------
SIMULATION: {

	my $thread = {}; # declare threads

	my $summary = {}; # declare a summary storage

	# Multithread
	foreach my $core (@{$cores->{'sim'}}) {
		$thread->{$core} = threads->new(\&main, $core, $core_dirs);	# Spawn the threads and send to main subroutine
	};

	# Return the multithread
	foreach my $core (@{$cores->{'sim'}}) {
		$thread->{$core} = $thread->{$core}->join();	# Return the threads together for info collation
# 		print Dumper $thread->{$core};

		# Merge in the summary results to the total hash
		$summary = merge($summary, $thread->{$core});
	};
	
# 	print Dumper $summary;
	my $file = '../summary_files/Combined_Results';
	my $ext = '.csv';

	open (my $FILE, '>', $file . $ext) or die ("can't open $file$ext");	#open the file to print the list for the core
	print $FILE Dumper $summary;
# 	foreach my $hse_type (&order(values %{$hse_types})) {		#each house type
# 		foreach my $region (&array_order(values %{$regions})) {		#each region

};


SUBROUTINES: {
# MAIN subroutine to do the simulations
	sub main {
		# determine the passed variables
		my $core = shift;
		my $core_dirs = shift;
		
# 		print Dumper $core_dirs;
		
		# The log file with reference to folder 'scripts'
		my $log = "../summary_files/sim_output_core_$core.txt";
		# Delete the file
		unlink $log;
		
		# Relocate the log relative to the house folders
		$log = '../../' . $log;
		
		# Local summary storage variables
		my $summary = {};
		
		my $counter = 0;
		my $total = @{$core_dirs->{$core}};
		
		# Cycle over the house directories
		foreach my $dir (@{$core_dirs->{$core}}) {
			# Determine the type, region, and house
			my ($hse_type, $region, $house) = ($dir =~ /(\w+-\w+)\/(\w+-\w+)\/(\w+)$/);
			
			# Shorten the name using a ref
			my $summ = \%{$summary->{$hse_type}->{$region}};
			
			# Append the cfg to the house for the filename to simulate
			my $file = $house . '.cfg';
			
			open (my $FILE, '<', "$dir/$file") or die ("can't open $dir/$file");	#open the file to read
			
			my @ish;
			
			while (<$FILE>) {
				if ($_ =~ /^\*isi \.\/\w+\.(\w+)\.shd$/) {
					push (@ish, $1);
				};
			};
			close $FILE;
			
# 			print Dumper @ish;
			
			# System call - NOTE: The 'cd' is within the system call as multithreading does not support different working directories (global variable). If one thread does a chdir then it would also affect other threads
			
			foreach my $zone (@ish) {
# 				system "cd $dir\nish -mode text -file $file -zone $zone -act update_silent >> $log";
				system "cd $dir\nish -mode text -file $file -zone $zone -act update_silent";
			};
			
# 			system "cd $dir\nbps -mode text -file $file -p sim_presets silent >> $log";
			system "cd $dir\nbps -mode text -file $file -p sim_presets silent";
			
			$counter++;
			my $percent = sprintf("%.0f%s", $counter/$total * 100, '%');
			print "Core $core: Completed sim $counter/$total ($percent)\n";
			
			# locate the summary file
			$file = $dir . '/out';
			my $ext = '.summary';
			
			# If a summary file exists
			if (-e $file . $ext) {
				# Open the summary file for readin
				open (my $FILE, '<', $file . $ext) or die ("can't open $file$ext");	#open the file to print the list for the core
				
				# cycle over the lines and store the info
				while (<$FILE>) {
					# the trim
					my $line = rm_EOL_and_trim($_);
					
					# Split into field and result based on the double colon (xml output style)
					my ($field, $result) = split(/::/, $line);
					
					# Determine the type (e.g. min, max, annual), the value and units
					my ($type, $value, $unit) = split(/\s+/, $result);
					
					# Strip the surrounding paranthesis off the units
					$unit =~ s/^\((.+)\)$/$1/;
					
					# Delcare a unit format and check to see if it is defined, otherwise consider it a string
					my $format;
					$format = {'GJ' => "%.1f", 'W' => "%.0f", 'oC' => "%.1f", '%' => "%.1f", 'K' => "%.1f", , 'cm' => "%.1f"}->{$unit} or $format = "%s";
					$value = sprintf($format, $value);
					
					# Store these things in the summary
					@{$summ->{$field}->{$house}->{$type}}{qw(value unit)} = ($value, $unit);
					
					$summary->{'fields'}->{$field} = 0;
					$summary->{'type'}->{$type} = 0;
					
					
				};
			}
			
			# If the out.summary does not exist, then record this
			else {
				$summary->{'no-summary'} = $house;
			};
		};
# 	print Dumper $summary;
	# Return the summary
	return ($summary);
	};

	print "THE HOUSE LISTINGS FOR EACH CORE TO SIMULATE ARE LOCATED IN ../summary_files/hse_listing_per_core.csv\n";
	print "THE HOUSE SIMULATION OUTPUT FROM EACH CORE IS LOCATED IN ../summary_files/sim_output_core_X.txt\n";
};
