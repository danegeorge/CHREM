#! /usr/bin/env perl
#DECLARE COMPILING CONDITIONS
#use strict;
use warnings;



#OPEN THE OUTPUT DATA FILES (DATA=DATA, CALCULATION=CALC'D VALUES FOR EACH HOUSE, TOTALS=FREQUENCY)
#MAIN CODE

for ($z=1;$z<=5;$z++){
	mkdir("region_$z",0777);
	for ($i=1;$i<=3000;$i++){
		mkdir("region_$z/test_$i",0777);
		for ($j=1;$j<=10;$j++){
			open(OUTPUT,">./region_$z/test_$i/test_$z-$i-$j.csv")||die("can't open datafile:$!");
			print "test $z $i $j\n";
			print OUTPUT "test $z $i $j";
			close OUTPUT;
		}
	}
}