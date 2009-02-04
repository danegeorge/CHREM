#! /usr/bin/env perl

#COMMENTS ARE DENOTED BY THE "#" SIGN. TYPICALLY COMMENTS ARE CAPITALIZED

#COMPILING CONDITIONS
#use strict;
use warnings;
use CSV;
use Array::Compare;
use Switch;
use threads;
#END COMPILING CONDITIONS

#USER VARIABLES
$minutes=60;										#MULTIPLE OF 5 MINUTES WHICH CAN TOTAL TO 8760hr
#END USER VARIABLES

#MAIN SCRIPT
#THREADS
for ($i=1;$i<=3;$i++){									#MULTI-THREAD TO RUN EACH PROFILE SIMULTANEOUSLY; CONSUMPTION LEVEL
	for ($z=1;$z<=3;$z++){								#YEAR
		$thr[$i][$z] = threads->new(\&MAIN_CODE, $i, $z, $minutes); #SPAWN THE THREAD
	}
}
for ($i=1;$i<=3;$i++){									#RETURN THE THREADS TOGETHER
	for ($z=1;$z<=3;$z++){								
		$return1[$i][$z]=[$thr[$i][$z]->join()];
	}
}
#END THREADS
#END MAIN SCRIPT

#SUBROUTINES
sub MAIN_CODE{										#MAIN CODE THAT THE THREAD JUMP TO
	$consumption=$_[0];
	$year=$_[1];
	$minutes=$_[2];

										#OPEN THE APPROPRIATE SOURCE DATA FILE
	open(CSV,"<can_gen_c$consumption-y$year.fcl")||die("can't open datafile:$!");	

										#OPEN THE OUTPUT DATA FILE
	open(OUTPUT,">2007-11-14_AL-consumption$consumption-year$year-minutes$minutes-normalized.csv")||die("can't open datafile:$!");


	$trash=<CSV>;							#REMOVE HEADER LINE 1
	$trash=<CSV>;							#REMOVE HEADER LINE 2
	$i=0;
	while (<CSV>){							#DO UNTIL THE DATA ARRAY IS EMPTY
		@tmp=CSVsplit($_);
		push (@input,@tmp);					#DEVELOP A LONG PROFILE ARRAY
#		print "consumption$consumption; year$year; CSV $i\n";
		$i++;
	}
	close CSV;
	
	$sum=0;
	for ($i=0;$i<=$#input;$i++) {$sum=$sum+$input[$i]}					#SUM THE 5 MINUTE INPUT WATTS
	$total_kWh=$sum*5/60/1000;									#CALCULATE THE TOTAL kWh FOR THE YEAR
	print "consumption$consumption; year$year; total kWh $total_kWh\n";
	for ($i=0;$i<=$#input;$i++) {$input_normalized[$i]=$input[$i]/$total_kWh}	#NORMALIZE THE INPUT BY THE TOTAL kWh; W(5min)/kWh


	for ($i=0;$i<=(8760*60/$minutes-1);$i++) {						#CREATE ARRAY OF LENGTH FOR DESIRED MINUTES
		$sum=0;		
		for($z=0;$z<=($minutes/5-1);$z++) {							#CYCLE THROUGH ENOUGH VALUES FOR NEW TIME INTERVAL
			$sum=$sum+$input_normalized[$i*$minutes/5+$z]				#SUM VALUES
		}
		$output_normalized[$i]=$sum/($minutes/5);						#AVERAGE THE VALUES
	}
														#PRINT THE OUTPUT
	print OUTPUT "$minutes\nload averaged over above minutes; below values are Watts normalized by kWh; Multiply values by kWh to obtain W over time interval\n";
	for ($i=0;$i<=$#output_normalized;$i++) {print OUTPUT "$output_normalized[$i]\n"}
}
#END SUBROUTINES