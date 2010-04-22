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
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all]
#
# DESCRIPTION:
# This script aquires results


#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;

use CSV;		#CSV-2 (for CSV split and join, this works best)
#use Array::Compare;	#Array-Compare-1.15
#use Switch;
use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
#use threads;		#threads-1.71 (to multithread the program)
#use File::Path;	#File-Path-2.04 (to create directory trees)
#use File::Copy;	#(to copy the input.xml file)
use Data::Dumper;

# CHREM modules
use lib ('./modules');
use General;

$Data::Dumper::Sortkeys = \&order;

#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------
my $hse_types;	# declare an hash array to store the house types to be modeled (e.g. 1 -> 1-SD)
my $regions;	# declare an hash array to store the regions to be modeled (e.g. 1 -> 1-AT)
my @houses_desired; # declare an array to store the house names or part of to look

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if (@ARGV < 2) {die "A minimum two arguments are required: house_types regions [house names]\n";};
	
	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
	($hse_types, $regions) = &hse_types_and_regions(shift (@ARGV), shift (@ARGV));
	
	# Provide support to only simulate some houses
	@houses_desired = @ARGV;
	# In case no houses were provided, match everything
	if (@houses_desired == 0) {@houses_desired = '.'};
	
};

#--------------------------------------------------------------------
# Identify the house folders for results aquisition
#--------------------------------------------------------------------
my @folders;	#declare an array to store the path to each hse which will be simulated

foreach my $hse_type (&array_order(values %{$hse_types})) {		#each house type
	foreach my $region (&array_order(values %{$regions})) {		#each region
		push (my @dirs, <../$hse_type/$region/*>);	#read all hse directories and store them in the array
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
my @results_files = grep(/^\.\.\/summary_files\/(Results)\.csv/, <../summary_files/*>); # Discover all of the file names that begin with Results in the summary_files directory
foreach my $file (@results_files) {unlink $file;}; # Delete the file (unlink)

my $results_all = {};

# print Dumper(@folders);

my @provinces = ('NEWFOUNDLAND', 'NOVA SCOTIA' ,'PRINCE EDWARD ISLAND', 'NEW BRUNSWICK', 'QUEBEC', 'ONTARIO', 'MANITOBA', 'SASKATCHEWAN' ,'ALBERTA' ,'BRITISH COLUMBIA');

my $SHEU03_houses = {};
@{$SHEU03_houses->{'1-SD'}}{@provinces} = qw(148879 259392 38980 215084 1513497 2724438 305111 285601 790508 910051);
@{$SHEU03_houses->{'2-DR'}}{@provinces} = qw(26098 38778 6014 23260 469193 707777 34609 29494 182745 203449);

my $units = {};
@{$units}{qw(GJ W kg kWh l m3 tonne)} = qw(%.1f %.0f %.0f %.0f %.0f %.0f %.3f);

FOLDER: foreach my $folder (@folders) {
	my ($hse_type, $region, $hse_name) = ($folder =~ /^\.\.\/(\d-\w{2})\/(\d-\w{2})\/(\w+)$/);
	
	my $filename = $folder . "/$hse_name.cfg";
	open (my $CFG, '<', $filename) or die ("\n\nERROR: can't open $filename\n"); # Open the cfg file to check for isi
	my @cfg = &rm_EOL_and_trim(<$CFG>);
	my @province = grep(s/^#PROVINCE (.+)$/$1/, @cfg);

	unless (grep(/$hse_name.xml$/, <$folder/*>)) {next FOLDER;};
	my $results_hse = XMLin($folder . "/$hse_name.xml");
	
	push(@{$results_all->{'house_names'}->{$region}->{$province[0]}->{$hse_type}}, $hse_name);
	$results_all->{'house_results'}->{$hse_name}->{'sim_period'} = $results_hse->{'sim_period'};

	foreach my $key (@{&order($results_hse->{'parameter'}, ['CHREM/SCD'], [''])}) {
		my ($param) = ($key =~ /^CHREM\/SCD\/(.+)$/);
		
		if ($param =~ /energy$/) {
			foreach my $val_type (qw(total_average active_average min max)) {
				if (defined($results_hse->{'parameter'}->{$key}->{'P00_Period'}->{$val_type})) {
					my $unit = $results_hse->{'parameter'}->{$key}->{'units'}->{'normal'};
					unless (defined($results_all->{'parameter'}->{$param . '/' . $val_type})) {
						$results_all->{'parameter'}->{$param . '/' . $val_type} = $unit;
					};
					$results_all->{'house_results'}->{$hse_name}->{$param . '/' . $val_type} = sprintf($units->{$unit}, $results_hse->{'parameter'}->{$key}->{'P00_Period'}->{$val_type});
				};
			};
		};

		my $val_type = 'integrated';
		if (defined($results_hse->{'parameter'}->{$key}->{'P00_Period'}->{$val_type})) {
			my $unit = $results_hse->{'parameter'}->{$key}->{'units'}->{$val_type};
			unless (defined($results_all->{'parameter'}->{$param . '/' . $val_type})) {
				$results_all->{'parameter'}->{$param . '/' . $val_type} = $unit;
			};
			$results_all->{'house_results'}->{$hse_name}->{$param . '/' . $val_type} = sprintf($units->{$unit}, $results_hse->{'parameter'}->{$key}->{'P00_Period'}->{$val_type});
		};
	};
};

my @result_params = @{&order($results_all->{'parameter'}, [qw(site src use)])};

my $filename = '../summary_files/Results.csv';
open (my $FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

print $FILE CSVjoin(qw(*header house_name region province hse_type multiplier), @result_params) . "\n";
print $FILE CSVjoin(qw(*units - - - - -), @{$results_all->{'parameter'}}{@result_params}) . "\n";

foreach my $region (@{&order($results_all->{'house_names'})}) {
	foreach my $province (@{&order($results_all->{'house_names'}->{$region}, [@provinces])}) {
		foreach my $hse_type (@{&order($results_all->{'house_names'}->{$region}->{$province})}) {
			
			my $total_houses;
			if (defined($SHEU03_houses->{$hse_type}->{$province})) {$total_houses = $SHEU03_houses->{$hse_type}->{$province};}
			else {$total_houses = @{$results_all->{'house_names'}->{$region}->{$province}->{$hse_type}};};
			
			my $multiplier = sprintf("%.1f", $total_houses / @{$results_all->{'house_names'}->{$region}->{$province}->{$hse_type}});
		
			foreach my $hse_name (@{&order($results_all->{'house_names'}->{$region}->{$province}->{$hse_type})}) {
				print $FILE CSVjoin('*data', $hse_name, $region, $province, $hse_type, $multiplier, @{$results_all->{'house_results'}->{$hse_name}}{@result_params}) . "\n";
			};
		};
	};
};

close $FILE;


