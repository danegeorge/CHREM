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
$minutes_data=1;		#NUMBER OF MINUTES FOR EACH DATAPOINT
$minutes_desired=30;	#DESIRED MINUTES FOR OUTPUT DATAPOINTS; REQUIRED TO BE DIVISOR OF 525600 (1yr)
#END USER VARIABLES

#MAIN SCRIPT
#THREADS
for ($i=1;$i<=3;$i++){											#MULTI-THREAD TO RUN EACH PROFILE SIMULTANEOUSLY; CONSUMPTION LEVEL
	$thr[$i] = threads->new(\&MAIN_SUB, $i, $minutes_data, $minutes_desired); 	#SPAWN THE THREAD
}
for ($i=1;$i<=3;$i++){											#RETURN THE THREADS TOGETHER							
	$return1[$i]=[$thr[$i]->join()];
}
#END THREADS
#END MAIN SCRIPT

#SUBROUTINES
sub MAIN_SUB{				#SUBROUTINE THAT THE THREAD JUMPS TO
	$consumption=$_[0]*100;		#PASS IN VARIABLES
	$minutes_data=$_[1];
	$minutes_desired=$_[2];


						#OPEN THE APPROPRIATE SOURCE DATA FILE
	open(CSV,"<DHW_minute$minutes_data-litre$consumption.txt")||die("can't open datafile:$!");	

						#OPEN THE OUTPUT DATA FILE
	open(OUTPUT,">2007-11-14_DHW_minute$minutes_desired-litre$consumption-normalized.csv")||die("can't open datafile:$!");

	$i=0;
	while (<CSV>){								#DO UNTIL THE DATA ARRAY IS EMPTY
		@tmp=CSVsplit($_);
		push (@input,@tmp);						#MAKE A LONG ARRAY BASED ON PROFILE				
#		print "consumption$consumption; year$year; CSV $i\n";
		$i++;
	}
	close CSV;
	
	$sum=0;
	for ($i=0;$i<=$#input;$i++) {
		$input_time[$i]=$input[$i]*($minutes_data/60);						#MULTIPLE INPUT BY TIME TO GET LITRES
		$sum=$sum+$input_time[$i]
	}
	$total=$sum/1000;												#CALCULATE THE TOTAL LITRES/1000 FOR THE YEAR
#	print "consumption$consumption; year$year; total kWh $total_kWh\n";

	for ($i=0;$i<=$#input_time;$i++) {$input_normalized[$i]=$input_time[$i]/$total}	#NORMALIZE THE INPUT BY THE TOTAL

	for ($i=0;$i<=(8760*60/$minutes_desired-1);$i++) {						#CONSTRUCT ARRAY ACCORDING TO DESIRED TIME INTERVALS
		$sum=0;
		for($z=0;$z<=($minutes_desired/$minutes_data-1);$z++) {				#ALL VALUES TO OBTAIN NEW TIME INTERVAL
			$sum=$sum+$input_normalized[$i*$minutes_desired/$minutes_data+$z]		#TOTAL THE NORMALIZED VALUES
		}
		$output_normalized[$i]=$sum*60/$minutes_desired;					#OUTPUT IN % FOR TIMESTEP TO BE MULTIPLIED BY ANNUAL kWh TO OBTAIN Watts PROFILE
	}
	
	print OUTPUT "$minutes_desired\nload averaged over above minutes; below values are Watts normalized by kWh; Multiply values by kWh to obtain W over time interval\n";
	for ($i=0;$i<=$#output_normalized;$i++) {print OUTPUT "$output_normalized[$i]\n"}
}
#END SUBROUTINES
