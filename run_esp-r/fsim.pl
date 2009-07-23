#!/usr/bin/perl
# 
#====================================================================
# fsim.pl
# Author:    Lukas Swan
# Date:      Mar 2009
# Copyright: Dalhousie University
#
# DESCRIPTION:
# This script performs an in directory ish and bps

#===================================================================

use warnings;
use strict;
use Data::Dumper;
use CSV;	# CSV-2 (for CSV split and join, this works best)

$ARGV[0] =~ /^(.*).$/;
my $house_name = $1;

my $file = "./$house_name.cfg";

		open (CFG, '<', $file) or die ("can't open $file\n");	#open the cfg file to check for isi
		
		my @month;
		SEARCH: while (<CFG>) {
			if ($_ =~ /^#SIM_PRESET_LINE2/) {	# find the simulation months line
				@month = split (/\s/, <CFG>);	# split and store the start day/month and end day/month
				print "month begin: $month[1]; month end: $month[3]\n";
			}
			elsif ($_ =~ /^\*isi/) {
				system ("ish -mode text -file ./$house_name.cfg -zone main -month_begin $month[1] -month_end $month[3] -act update_silent");	# call the ish shading and insolation analyzer
				last SEARCH;
			};
		};
		close CFG;

		system ("bps -mode text -file ./$house_name.cfg -p sim_presets silent");	#call the bps simulator with arguements to automate it

		# rename the xml output files with the house name
		foreach my $ext ('csv', 'dictionary', 'summary', 'xml') {
			rename ("out.$ext", "$house_name.$ext");
		};


		$file = "./$house_name.summary";
		
		open (SUMMARY, '<', $file) or die ("can't open $file\n");     #open the summary file to reorder it
		my $results;
		while (<SUMMARY>) {
		# Lukas/zone_01/active_cool::Total_Average -311.102339 (W)
		# Lukas/MCOM::Minimum 28.000000 (#)
		#       if ($_ =~ /(.*)::(\w*)\s*(\w*\.\w*)\s*(\(.*\))/) {
			my @split = split (/::|\s/, $_);
			$results->{$split[0]}->{$split[1]} = [$split[2], $split[3]];
		# 	};
		};
		close SUMMARY;
# 		print Dumper ($results);

		$file = "./$house_name.dictionary";
		open (DICTIONARY, '<', $file) or die ("can't open $file\n");     #open the dictionary file to cross reference
		
		my $parameter;
		while (<DICTIONARY>) {
		# "Lukas/zone_01/active_cool","active cooling required by zone","(W)"
			$_ =~ /"(.*)","(.*)","(.*)"/;
			$parameter->{$1}->{'description'} = $2;
			$parameter->{$1}->{'units'} = $3;
		};
		# print Dumper ($parameter);
		close DICTIONARY;

		$file = "./$house_name.results";
		open (RESULTS, '>', $file) or die ("can't open $file\n");     #open the a results file to write out the organized summary results
		printf RESULTS ("%10s %10s %10s %10s %10s %10s %10s %-50s %-s\n", 'Integrated', 'Int units', 'Total Avg', 'Active avg', 'Min', 'Max', 'Units', 'Name', 'Description');

		my @keys = sort {$a cmp $b} keys (%{$results});  # sort results
		my @values = ('AnnualTotal', 'Total_Average', 'Active_Average', 'Minimum', 'Maximum');
		foreach my $key (@keys) {
			foreach (@values) {unless (defined ($results->{$key}->{$_})) {$results->{$key}->{$_} = ['0', '-']};};
			printf RESULTS ("%10.2f %10s %10.2f %10.2f %10.2f %10.2f %10s %-50s %-s\n",
				$results->{$key}->{$values[0]}->[0],
				$results->{$key}->{$values[0]}->[1],
				$results->{$key}->{$values[1]}->[0],
				$results->{$key}->{$values[2]}->[0],
				$results->{$key}->{$values[3]}->[0],
				$results->{$key}->{$values[4]}->[0],
				$results->{$key}->{$values[4]}->[1],
				$key,
				$parameter->{$key}->{'description'});
		};
		close RESULTS;

open (CSV, '<', "./$house_name.csv") or die ("can't open ./$house_name.csv");     #open the csv file to reorder it
my $results_csv;
while (<CSV>) {
	push (@{$results_csv},[CSVsplit ($_)]);
};
close CSV;

open (RESULTS2, '>', "./$house_name.organized.csv") or die ("can't open ./$house_name.organized.csv");     #open the csv output file
print RESULTS2 "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24\n";
foreach my $column (0..$#{$results_csv->[0]}) {
	foreach my $row (0..$#{$results_csv}) {
		print RESULTS2 "$results_csv->[$row][$column],";
	};
	print RESULTS2 "\n";
};
close RESULTS2;

