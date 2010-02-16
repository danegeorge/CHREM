#! /usr/bin/env perl
#DECLARE COMPILING CONDITIONS
#use strict;
use warnings;
use CSV;
use Array::Compare;
use Switch;

#OPEN THE APPROPRIATE SOURCE DATA FILE
open(CSV0,"<2007-10-31_EGHD-HOT2XP_dupl-chk2.csv")||die("can't open datafile:$!");

#OPEN THE OUTPUT DATA FILES (DATA=DATA, CALCULATION=CALC'D VALUES FOR EACH HOUSE, TOTALS=FREQUENCY)
open(OUTPUT,">2007-10-31_EGHD-HOT2XP_dupl-chk_A-files.csv")||die("can't open datafile:$!");

#MAIN CODE

$i=0;
	while (<CSV0>){							#DO UNTIL THE DATA ARRAY IS EMPTY
		$tmp0=[CSVsplit($_)];				#SPLIT THE INPUT FILE LINE INTO CONSECUTIVE ARRAYS	
		print "CSV0 $i\n";
		if ($i==0 || $tmp0->[1]=~/^....A......HDF$/) {
			$tmp=CSVjoin(@{$tmp0});
			print OUTPUT "$tmp\n";
			print "print $i\n";		
		}
		$i++;
	}
close OUTPUT;