#! /usr/bin/env perl

#COMMENTS ARE DENOTED BY THE "#" SIGN. TYPICALLY COMMENTS ARE CAPITALIZED

#COMPILING CONDITIONS
#use strict;
use warnings;
use CSV;
use Array::Compare;
use Switch;
#END COMPILING CONDITIONS

#USER VARIABLES
$model="ALC";		#ALC, DHW, SH; appliance lights and cooling, domestic hot water, space heating
#END USER VARIABLES
	
#MAIN SCRIPT
open(NN,"<$model-NN.csv")||die("can't open datafile:$!");						#NN CHARACTERISTICS
open(IN_DATA,"<$model-Inputs-V1.csv")||die("can't open datafile:$!");				#INPUT DATA
open(IN_RANGE_BIAS,"<$model-Input-min-max-bias.csv")||die("can't open datafile:$!");	#INPUT AND OUTPUT RANGE AND BIAS

$_=<NN>;					#HEADER
$_=<NN>;					#VALUES
@vals=CSVsplit($_);
$layers=$vals[0];				#Number of hidden and output layers STARTING AT ONE
$scale_low=$vals[1];			#Lower value of scaling range
$scale_high=$vals[2];			#High value of scaling range

									#SET THE PRELIMINARY VALUES
$_=<IN_RANGE_BIAS>;						#HEADER
$_=<IN_RANGE_BIAS>;						#RANGE LOW VALUE
@range_low=CSVsplit($_);
#print "the low range array should be @range_low";
$_=<IN_RANGE_BIAS>;						#RANGE HIGH VALUE
@range_high=CSVsplit($_);
$_=<IN_RANGE_BIAS>;						#SCALED INPUT BIAS
@scaled_input_bias=CSVsplit($_);
close IN_RANGE_BIAS;

$error=0;

									#READ THE INPUT DATA AND SCALE IT
$i=0;
$_=<IN_DATA>;							#HEADER ROW
$input_data[$i]=[CSVsplit($_)];					
$layer[0][$i]=[@{$input_data[$i]}];				#SET THE FINAL INPUT HEADER EQUAL TO THE INPUT HEADER

$i++;
while (<IN_DATA>){						#DO UNTIL THE DATA ARRAY IS EMPTY
	$input_data[$i]=[CSVsplit($_)];			#SPLIT THE INPUT FILE LINE INTO CONSECUTIVE ARRAYS	
	$layer[0][$i][0]=$input_data[$i][0];		#NUMBER
	$layer[0][$i][1]=$input_data[$i][1];		#FILENAME
	for ($z=2;$z<=$#{$input_data[$i]};$z++){		#SCALE AND BIAS ONLY THE INPUT DATA, NOT THE NAME/NUMBER
		if (($input_data[$i][$z]>=$range_low[$z]) && ($input_data[$i][$z]<=$range_high[$z])) {			#CHECK FOR WITHIN RANGE
			$layer[0][$i][$z]=($scale_high-$scale_low)*(($input_data[$i][$z]-$range_low[$z])/($range_high[$z]-$range_low[$z]))+($scale_low)+($scaled_input_bias[$z]);	#SCALE THE VALUE
		}
		else {$error++; $i--;}				#THE VALUE IS OUT OF RANGE, INCREMENT ERROR AND DECREMENT $i SO IT CONTINUES
	}
	print "Row $i, Parameter 1: $input_data[$i][7]; $layer[0][$i][7]\n";
	$i++;
}
close IN_DATA;


													#PERFORM THE NODE CALCULATIONS
for ($i=1;$i<=$layers;$i++) {
	open($IN_LAYER,"<$model-Layer-$i.csv")||die("can't open datafile:$!");	#PLACE OPEN HERE SO "WHILE" DOES NOT HAVE PROBLEM WITH ARRAY
	$z=0;
	while (<$IN_LAYER>){									#DO UNTIL THE DATA ARRAY IS EMPTY
		print "$_\n";
		$layer_bias_weight[$i][$z]=[CSVsplit($_)];				#SPLIT THE NODAL LAYER FILE LINE INTO CONSECUTIVE ARRAYS	
		$z++;
	}
	close $IN_LAYER;
	print "$layer_bias_weight[$i][0][0]\n";
	$layer[$i][0]=[@{$layer_bias_weight[$i][0]}];
	
	for ($z=1;$z<=$#{$layer[$i-1]};$z++){												#DO FOR EACH HOUSE FILE
		$layer[$i][$z][0]=$layer[$i-1][$z][0];											#CARRY THE SEQ NUMBER FORWARD
		$layer[$i][$z][1]=$layer[$i-1][$z][1];											#CARRY THE FILENAME FORWARD
		for ($y=1;$y<=$#{$layer_bias_weight[$i]};$y++) {									#DO FOR EACH NODE IN THE LAYER
			$sum=0;
			for ($x=2;$x<=$#{$layer_bias_weight[$i][$y]};$x++) {								#DO FOR EACH WEIGHTING FOR THE NODE
				$sum=$sum+$layer[$i-1][$z][$x]*$layer_bias_weight[$i][$y][$x];					#SUM THE PRODUCT OF VALUE AND WEIGHT
			}
			$sum_bias=$sum+$layer_bias_weight[$i][$y][1];									#ADD THE NODE BIAS
			if ($layer_bias_weight[$i][0][0]=~/identity/) {$layer[$i][$z][$y+1]=$sum_bias}			#IDENTITY FUNCTION; Y+1 TO MOVE TO THIRD POSIITON
			elsif ($layer_bias_weight[$i][0][0]=~/logistic/) {$layer[$i][$z][$y+1]=1/(1+exp(-($sum_bias)))}	#LOGISITIC FUNCTION; Y+1 TO MOVE TO THIRD POSIITON
			else {$error++; $layer[$i][$z][$y]="error"; print "error: no activation function; layer $z\n";}	#FUNCTION IS MISSING. INCREMENT ERROR AND CAUSE PROBLEM
		}
	}
}

											#CHECK THE DATA
for ($i=0;$i<=$layers;$i++) {
	for ($z=0;$z<=$#{$layer[$i]};$z++) {
		print "layer $i:$z	@{$layer[$i][$z]}\n";
	}
}

											#RESCALE THE OUTPUT
$final[0]=[("Final Energy","Filename","GJ","kWh")];
for ($i=1;$i<=$#{$layer[$layers]};$i++) {
	$final[$i][0]=$layer[$layers][$i][0];				#CARRY SEQ NUMBER FORWARD
	$final[$i][1]=$layer[$layers][$i][1];				#CARRY FILENAME FORWARD
	$energy=($layer[$layers][$i][2]-$scale_low)/($scale_high-$scale_low)*($range_high[0]-$range_low[0])+$range_low[0];	#RESCALE OUTPUT TO ENERGY VALUES
	if ($model=~/ALC/) {$final[$i][2]=$energy*3600/1000000}	#ACCOUNT FOR ALC OUTPUT kWh UNITS
	else {$final[$i][2]=$energy}						#GJ
	$final[$i][3]=$final[$i][2]/3600*1000000;				#kWh
}

open(RESULTS,">$model-Results.csv")||die("can't open datafile:$!");	
for ($i=0;$i<=$#final;$i++) {
	print "@{$final[$i]}\n";
	$tmp=CSVjoin(@{$final[$i]});						#JOIN RESULTS FOR PRINTING
	print RESULTS "$tmp\n";
}
close RESULTS;
print "Number of errors = $error\n";
#END MAIN SCRIPT
