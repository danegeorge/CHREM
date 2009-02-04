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
		$thr[$i][$z] = threads->new(\&FILE_OPEN, $i, $z, $minutes); #SPAWN THE THREAD; JUMP TO SUBROUTINE FILE_OPEN
	}
}
for ($i=1;$i<=3;$i++){									#RETURN THE THREADS TOGETHER
	for ($z=1;$z<=3;$z++){								
		$normalized[$i][$z]=$thr[$i][$z]->join();
	}
}
#END THREADS

open(CSV,"<ALC-Results.csv")||die("can't open datafile:$!");
open(OUTPUT,">2007-11-22_AL-profile-minutes$minutes.csv")||die("can't open datafile:$!");
open(OUTPUT2,">2007-11-22_AL-profile-minutes$minutes-Excel-columns.csv")||die("can't open datafile:$!");

$i=0;
while (<CSV>){							#DO UNTIL THE DATA ARRAY IS EMPTY
	$NN_results[$i]=[CSVsplit($_)];			#MAKE ARRAY OF INPUT ENERGY CONSUMPTION VALUES					
	print "NN CSV $i\n";
	$i++;
}
close CSV;

$tmp=CSVjoin(@{$NN_results[0]});
print OUTPUT "$tmp\n";

for ($i=1;$i<=$#NN_results;$i++) {
	if ($NN_results[$i][3]<6460) {$consumption=1}							#LOCATE THE PROPER PROFILE BASED ON CONSUMPTION LEVEL
	elsif ($NN_results[$i][3]>10605) {$consumption=3}
	else {$consumption=2}		
	$random=int(rand(3))+1;											#GENERATE A RANDOM NUMBER FOR THE PROFILE YEAR
	for ($z=0;$z<=$#{$normalized[$consumption][$random]};$z++) {				#CYCLE THROUGH EACH PROFILE TIME INTERVAL
		$NN_profile[$z]=$NN_results[$i][3]*$normalized[$consumption][$random][$z];	#MULTIPLY THE ENERGY CONSUMPTION BY THE NORMALIZED PROFILE
	}
	#PRINT THE OUTPUTS
	print "$normalized[$consumption][$random][0]; consumption is $consumption; random is $random\n";
	$tmp=CSVjoin(@{$NN_results[$i]},"following is Watts profile for each $minutes minutes");
	$tmp2=CSVjoin(@NN_profile);
	print OUTPUT "$tmp,$tmp2\n";
	
	#CONSTRUCT A LONG SINGLE COLUMN OF FIRST DWELLING TO VERIFY IN SPREADSHEET PROGRAM
	if ($i==1) {
		for ($z=0;$z<=$#{$NN_results[$i]};$z++) {print OUTPUT2 "$NN_results[$i][$z]\n";}
		for ($z=0;$z<=$#NN_profile;$z++) {print OUTPUT2 "$NN_profile[$z]\n";}
	}
}
close OUTPUT;
close OUTPUT2;
#END MAIN SCRIPT

#SUBROUTINES	
sub FILE_OPEN{			#MAIN CODE THAT THE THREAD JUMP TO
	$consumption=$_[0];	#PASS IN VALUES
	$year=$_[1];
	$minutes=$_[2];

				#OPEN THE APPROPRIATE SOURCE DATA FILE
	open(CSV,"<2007-11-14_AL-consumption$consumption-year$year-minutes$minutes-normalized.csv")||die("can't open datafile:$!");	
	$trash=<CSV>;	#REMOVE HEADER LINE 1
	$trash=<CSV>;	#REMOVE HEADER LINE 2
	$i=0;
	while (<CSV>){							#DO UNTIL THE DATA ARRAY IS EMPTY
		#@tmp=CSVsplit($_);
		push (@input,$_);						#READ THE PROFILE INTO ARRAY	
#		print "consumption$consumption; year$year; CSV $i\n";
		$i++;
	}
	close CSV;
	$tmp=[@input];
	return ($tmp);							#RETURN THE PROFILE TO THE MAIN PROGRAM
}
#END SUBROUTINES