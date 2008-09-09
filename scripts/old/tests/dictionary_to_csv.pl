#!/usr/bin/perl
# 
#====================================================================
# .pl
# Author:    Lukas Swan
# Date:      Aug 2008
# Copyright: Dalhousie University
#
# DESCRIPTION:


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
#use File::Path;	#File-Path-2.04 (to create directory trees)
use Cwd;		#(to determine current working directory)



open (LIST, '<', "./out.dictionary") or die ("can't open dictionary");	#open the file
print "opened dictionary\n";

#--------------------------------------------------------------------
# Perform a simulation of each house in the directory list
#--------------------------------------------------------------------
my @data;
while (<LIST>) { 
	my @split = CSVsplit($_);
	push (@data, @split); print "$_\n";
}
close LIST;

my @organized;
my $i = 0;
while ($i <= $#data) {
	$data[$i] =~ s/:$//;
	$data[$i+1] =~ s/^\s*//;
	push (@organized, "<summary_variable>$data[$i]</summary_variable>,$data[$i+1]");
	print "$data[$i],$data[$i+1]\n";
	$i = $i + 2;
}

open (LIST, '>', "./dictionary.csv") or die ("can't open csv");	#open the file
print "opened output\n";
foreach my $line (@organized) {print LIST "$line\n"}
close LIST;
