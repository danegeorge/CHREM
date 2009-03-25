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

$ARGV[0] =~ /(^.*).$/;
my $folder_name = $1;

open (CFG, '<', "./$folder_name.cfg") or die ("can't open ./$folder_name.cfg");	#open the cfg file to check for isi
my @month;
SEARCH: while (<CFG>) {
	if ($_ =~ /^#SIM_PRESET_LINE2/) {	# find the simulation months line
		@month = split (/\s/, <CFG>);	# split and store the start day/month and end day/month
		print "month begin: $month[1]; month end: $month[3]\n";
	}
	elsif ($_ =~ /^\*isi/) {
		system ("ish -mode text -file ./$folder_name.cfg -zone main -month_begin $month[1] -month_end $month[3] -act update_silent");	# call the ish shading and insolation analyzer
		last SEARCH;
	};
};
close CFG;

system ("bps -mode text -file ./$folder_name.cfg -p sim_presets silent");	#call the bps simulator with arguements to automate it

# rename the xml output files with the house name
rename ("out.csv", "$folder_name.csv");
rename ("out.dictionary", "$folder_name.dictionary");
rename ("out.summary", "$folder_name.summary");
rename ("out.xml", "$folder_name.xml");

open (SUMMARY, '<', "./$folder_name.summary") or die ("can't open ./$folder_name.summary");     #open the summary file to reorder it
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
# print Dumper ($results);

open (DICTIONARY, '<', "./$folder_name.dictionary") or die ("can't open ./$folder_name.dictionary");     #open the dictionary file to cross reference
my $parameter;
while (<DICTIONARY>) {
# "Lukas/zone_01/active_cool","active cooling required by zone","(W)"
      $_ =~ /"(.*)","(.*)","(.*)"/;
      $parameter->{$1}->{'description'} = $2;
      $parameter->{$1}->{'units'} = $3;
};
# print Dumper ($parameter);
close DICTIONARY;

open (RESULTS, '>', "./$folder_name.results") or die ("can't open ./$folder_name.results");     #open the a results file to write out the organized summary results
printf RESULTS ("%1s %10s %10s %10s %10s %10s %10s %10s %-50s %-s\n", '-', 'Integrated', 'Int units', 'Total Avg', 'Active avg', 'Min', 'Max', 'Units', 'Name', 'Description');

my @keys = sort {$a cmp $b} keys (%{$results});  # sort results
my @values = ('AnnualTotal', 'Total_Average', 'Active_Average', 'Minimum', 'Maximum');
foreach my $key (@keys) {
	foreach (@values) {unless (defined ($results->{$key}->{$_})) {$results->{$key}->{$_} = ['0', '-']};};
      printf RESULTS ("%1s %10.4f %10s %10.2f %10.2f %10.2f %10.2f %10s %-50s \"%-s\"\n",
		'-',
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


