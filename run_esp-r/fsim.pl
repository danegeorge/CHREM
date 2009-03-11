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

$ARGV[0] =~ /(^.*).$/;
my $folder_name = $1;

open (CFG, '<', "./$folder_name.cfg") or die ("can't open ./$folder_name.cfg");	#open the cfg file to check for isi
SEARCH: while (<CFG>) {
	if ($_ =~ /^\*isi/) {
		system ("ish -mode text -file ./$folder_name.cfg -zone main -act update_silent");	# call the ish shading and insolation analyzer
		last SEARCH;
	};
};
close CFG;

system ("bps -mode text -file ./$folder_name.cfg -p default silent");	#call the bps simulator with arguements to automate it

# rename the xml output files with the house name
rename ("out.csv", "$folder_name.csv");
rename ("out.dictionary", "$folder_name.dictionary");
rename ("out.summary", "$folder_name.summary");
rename ("out.xml", "$folder_name.xml");

open (SUMMARY, '<', "./$folder_name.summary") or die ("can't open ./$folder_name.summary");     #open the summary file to reorder it

my @lines;
my @totals;
while (<SUMMARY>) {push (@lines, $_);};
foreach my $line (@lines) {
      if ($line =~ /(.*)::AnnualTotal(.*)(\(.*\))/) {push (@totals, sprintf ("%8.2f  %5s  %s", $2, $3, $1));};
};
close SUMMARY;
open (TOTALS, '>', "./$folder_name.total") or die ("can't open ./$folder_name.total");     #open the a total file to write out the integrated totals
print TOTALS "Integrated totals over simulation period. Taken from $folder_name.summary\n";
foreach my $line (@totals) {print TOTALS "$line\n";};
close TOTALS;



