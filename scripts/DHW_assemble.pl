#!/usr/bin/perl
# 
#====================================================================
# DHW_assemble.pl
# Author:    Lukas Swan
# Date:      Mar 2009
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl file_to_convert (@../fcl/) file_to_result (../fcl/)
#
# DESCRIPTION:
# This script simply assembles the specified columnar format DHW draw 
# profile and assembles it in the hourly (row) format of 5 minute intervals.


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
#use File::Copy;	#(to copy the input.xml file)


#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------


#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------




open (DHW_COLUMN, '<', "../fcl/$ARGV[0]") or die ("can't open ../fcl/$ARGV[0]");	#open the file to read DHW data
my @data = <DHW_COLUMN>;
close DHW_COLUMN;
chomp (@data);

open (DHW_ROW, '>', "../fcl/$ARGV[1]") or die ("can't open ../fcl/$ARGV[1]");	#open the file to write DHW data
print DHW_ROW "1,,,,,,,,,,,\n";
print DHW_ROW "12,,,,,,,,,,,\n";

while (@data) {
	printf DHW_ROW ("%s\n", CSVjoin(splice(@data, 0, 12)));
# 	print DHW_ROW CSVjoin(splice(@data, 0, 12));
# 	print DHW_ROW "\n";
};

close DHW_ROW;
