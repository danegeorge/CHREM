#!/usr/bin/perl
#  
#====================================================================
# New_houses.pl
# Author:    Lukas Swan
# Date:      Nov 2008
# Copyright: Dalhousie University
#
##
# DESCRIPTION:
# This script 
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
#use threads;		#threads-1.71 (to multithread the program)
#use File::Path;		#File-Path-2.04 (to create directory trees)
#use File::Copy;		#(to copy the input.xml file)




my $audit = {"A", 1, "B", 2, "C", 3, "N", 4, "U", 5};
print "test\n";
my $audit_rev = {reverse (%{$audit})};
my $region = {"NEWFOUNDLAND", 0, "NOVA SCOTIA", 0, "PRINCE EDWARD ISLAND", 0, "NEW BRUNSWICK", 0, "QUEBEC", 1, "ONTARIO", 2, "MANITOBA", 3, "SASKATCHEWAN", 3, "ALBERTA", 3, "BRITISH COLUMBIA", 4};
my $hse_type = {"1", 1, "2", 6, "3", 6, "4", 6};
print "$hse_type->{2}\n";
my $array;
push (@{$array->[0]}, [("-", "SD", "SD", "SD", "SD", "SD", "DR", "DR", "DR", "DR", "DR")]);
foreach my $letter (keys %{$audit}) {push (@{$array->[$audit->{$letter}]}, [("$letter", "AT", "QC", "OT", "PR", "BC", "AT", "QC", "OT", "PR", "BC")]);};


open (EGHD, '<', "./2007-10-31_EGHD-HOT2XP_dupl-chk.csv") or die ("can't open input file");	# open the correct EGHD file to use as the data source
$_ = <EGHD>;	# strip the first header row from the CSDDRD file
print "$_\n";

my $i = 0;
RECORD: while (<EGHD>) {
	# SPLIT THE DWELLING DATA, CHECK THE FILENAME, AND CREATE THE APPROPRIATE PATH ../TYPE/REGION/RECORD
	my $house = [CSVsplit($_)];											#split each of the comma delimited fields for use

	$i++;
#	if ($i > 2000) {last RECORD};
	print "$i, $house->[1], $house->[16], $house->[3], $house->[6]\n";

	unless (defined ($region->{$house->[3]})) {print "region\n"; next RECORD};
	unless (defined ($hse_type->{$house->[16]})) {print "hse_type\n"; next RECORD};
	unless (($house->[6] > 1800) && ($house->[6] < 2007)) {print "vintage\n"; next RECORD};

	unless ($house->[1] =~ /^....(.).....\.HDF$/) {print "name structure\n"; next RECORD};
#	print "$1\n";
	unless (defined ($audit->{$1})) {print "letter\n"; next RECORD};

	$array->[$audit->{$1}][$house->[6]][0] = $house->[6];
	$array->[$audit->{$1}][$house->[6]][$hse_type->{$house->[16]} + $region->{$house->[3]}]++;


}	#end of the while loop through the EGHD

close EGHD;

open (RESULTS, '>', "./new_housing.csv") or die ("can't open output file");	# open the correct EGHD file to use as the data source
my $string = CSVjoin(@{$array->[0][0]});
print RESULTS "$string\n";
foreach my $section (1..$#{$array}) {
	foreach my $line (0,1998..2006) {
		my $string = CSVjoin(@{$array->[$section][$line]});
		print RESULTS "$string\n";
	};
};
close RESULTS;