#! /usr/bin/env perl
#DECLARE COMPILING CONDITIONS
#use strict;
use warnings;
use CSV;
use Array::Compare;
use Switch;

#OPEN THE APPROPRIATE SOURCE DATA FILE
open(CSV0,"<2007-10-31_EGHD-HOT2XP.csv")||die("can't open datafile:$!");

#OPEN THE OUTPUT DATA FILES (DATA=DATA, CALCULATION=CALC'D VALUES FOR EACH HOUSE, TOTALS=FREQUENCY)
open(OUTPUT,">2007-10-31_EGHD-HOT2XP_dupl-chk.csv")||die("can't open datafile:$!");

#MAIN CODE

&READ;
&DUPLICATE_CHECK;
&PRINT;

print "original number of records equals $original\n";
print "final number of records equals $#tmp0\n";

sub READ{
	$i=0;
	while (<CSV0>){							#DO UNTIL THE DATA ARRAY IS EMPTY
		$tmp0[$i]=[CSVsplit($_)];				#SPLIT THE INPUT FILE LINE INTO CONSECUTIVE ARRAYS	
		$i++;
		print "CSV0 $i\n";
	}
	close CSV0;
	print "CSV0 END\n";
	$original=$#tmp0;
}

sub DUPLICATE_CHECK{
	for ($i=1;$i<$#tmp0;$i++){
		$z=$i+1;
		$y=0;
		while (($y==0) && ($z<=$#tmp0)){
			if ($tmp0[$i][1] eq $tmp0[$z][1]){
				$y=1;
				splice(@tmp0,$i,1);
				$i--;
			}
			$z++;
		}
		print "Chk duplicate for $i\n";
	}
}

sub PRINT{
	for ($i=0;$i<=$#tmp0;$i++){
		$tmp=CSVjoin(@{$tmp0[$i]});
		print OUTPUT "$tmp\n";
		print "print $i\n";
	}
	close OUTPUT;
}