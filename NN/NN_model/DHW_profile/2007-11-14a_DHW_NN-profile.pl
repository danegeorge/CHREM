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
$minutes_desired=60;								#DESIRED MINUTES FOR OUTPUT DATAPOINTS; REQUIRED TO BE DIVISOR OF 525600 (1yr)
#END USER VARIABLES

#MAIN SCRIPT
#THREADS
for ($i=1;$i<=3;$i++){								#MULTI-THREAD TO RUN EACH PROFILE SIMULTANEOUSLY; CONSUMPTION LEVEL
	$thr[$i] = threads->new(\&PROFILES, $i, $minutes_desired); 	#SPAWN THE THREAD
}
for ($i=1;$i<=3;$i++){								#RETURN THE THREADS TOGETHER							
	$normalized[$i]=$thr[$i]->join();
}
#END THREADS

open(CSV,"<DHW-Results.csv")||die("can't open datafile:$!");
open(OUTPUT,">2007-11-22_DHW-profle-minutes$minutes_desired.csv")||die("can't open datafile:$!");
open(OUTPUT2,">2007-11-22_DHW-profle-minutes$minutes_desired-Excel-columns.csv")||die("can't open datafile:$!");

$i=0;
while (<CSV>){						#DO UNTIL THE DATA ARRAY IS EMPTY
	$NN_results[$i]=[CSVsplit($_)];		#READ THE NN ANNUAL ENERGY CONSUMPTION IN				
	print "NN CSV $i\n";
	$i++;
}
close CSV;

$tmp=CSVjoin(@{$NN_results[0]});
print OUTPUT "$tmp\n";

for ($i=1;$i<=$#NN_results;$i++) {
	if ($NN_results[$i][3]<(8.7*365)) {$consumption=1}					#CHOOSE THE PROPER PROFILE BASED ON DAILY LOAD
	elsif ($NN_results[$i][3]>(14.51*365)) {$consumption=3}
	else {$consumption=2}
	for ($z=0;$z<=$#{$normalized[$consumption]};$z++) {					#CYCLE THROUGH EACH TIME INTERVAL
		$NN_profile[$z]=$NN_results[$i][3]*$normalized[$consumption][$z];		#MULTIPLY THE ANNUAL ENERGY CONSUMPTION BY THE NORMALIZED PROFILE VALUES
	}
	print "$normalized[$consumption][0]\n";
	$tmp=CSVjoin(@{$NN_results[$i]},"following is Watts profile for each $minutes_desired minutes");
	$tmp2=CSVjoin(@NN_profile);
	print OUTPUT "$tmp,$tmp2\n";									#PRINT THE OUTPUT FILE
	
	if ($i==1) {											#PRINT THE FIRST DWELLING FOR VALIDATION IN A SPREADSHEET PROGRAM
		for ($z=0;$z<=$#{$NN_results[$i]};$z++) {print OUTPUT2 "$NN_results[$i][$z]\n";}
		for ($z=0;$z<=$#NN_profile;$z++) {print OUTPUT2 "$NN_profile[$z]\n";}
	}
}
close OUTPUT;
close OUTPUT2;
#END MAIN SCRIPT


#SUBROUTINES
sub PROFILES {				#SUB FOR THREADS TO JUMP TO
	$consumption=$_[0]*100;		#PASS VARIABLES
	$minutes_desired=$_[1];

	open(CSV,"<2007-11-14_DHW_minute$minutes_desired-litre$consumption-normalized.csv")||die("can't open datafile:$!");	
	$trash=<CSV>;			#REMOVE HEADER LINE 1
	$trash=<CSV>;			#REMOVE HEADER LINE 2
	$i=0;
	while (<CSV>){			#DO UNTIL THE DATA ARRAY IS EMPTY
		push (@input,$_);		#CALL IN THE PROFILE
		$i++;
	}
	close CSV;
	$tmp=[@input];
	return ($tmp);
}
#END SUBROUTINES