#! /usr/bin/env perl

# THIS SCRIPT SHOULD BE DRIVEN FROM THE NN_Input_Gen.pl DIRECTLY



#COMMENTS ARE DENOTED BY THE "#" SIGN. TYPICALLY COMMENTS ARE CAPITALIZED

#COMPILING CONDITIONS
#use strict;
use warnings;
use CSV;
use Array::Compare;
#END COMPILING CONDITIONS

#USER VARIABLES
$model = $ARGV[0];		#ALC, DHW, SH; appliance lights and cooling, domestic hot water, space heating
#END USER VARIABLES
	
#MAIN SCRIPT
open(NN, '<', "../NN/NN_model/$model-NN.csv")||die("can't open datafile: ../NN/NN_model/$model-NN.csv\n");						#NN CHARACTERISTICS
open(IN_DATA,'<', "../NN/NN_model/$model-Inputs-V2.csv")||die("can't open datafile: ../NN/NN_model/$model-Inputs-V2.csv");				#INPUT DATA
# open(IN_DATA,'<', "../NN/NN_model/$model-Inputs-V2_72_Oceanic.csv")||die("can't open datafile: ../NN/NN_model/$model-Inputs-V2_72_Oceanic.csv");				#INPUT DATA
open(IN_RANGE_BIAS, '<', "../NN/NN_model/$model-Input-min-max-bias.csv")||die("can't open datafile: ../NN/NN_model/$model-Input-min-max-bias.csv");	#INPUT AND OUTPUT RANGE AND BIAS

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
$i=1;

while (<IN_DATA>){						#DO UNTIL THE DATA ARRAY IS EMPTY

	if (/\*header/) {
		$input_data[0]=[CSVsplit($_)];					
		$layer[0][0]=[@{$input_data[0]}];				#SET THE FINAL INPUT HEADER EQUAL TO THE INPUT HEADER
	}
	
	elsif (/\*data/) {
# 		print  "i is $i; *data is $_\n";
		$input_data[$i]=[CSVsplit($_)];			#SPLIT THE INPUT FILE LINE INTO CONSECUTIVE ARRAYS	
		$layer[0][$i][0]=$input_data[$i][0];		#NUMBER
		$layer[0][$i][1]=$input_data[$i][1];		#FILENAME
		for ($z=2;$z<=$#{$input_data[$i]};$z++){		#SCALE AND BIAS ONLY THE INPUT DATA, NOT THE NAME/NUMBER
# 			print "i is $i; data: $input_data[$i][$z]; range low: $range_low[$z]; range high: $range_high[$z]\n";
			if (($input_data[$i][$z]>=$range_low[$z]) && ($input_data[$i][$z]<=$range_high[$z])) {			#CHECK FOR WITHIN RANGE
				$layer[0][$i][$z]=($scale_high-$scale_low)*(($input_data[$i][$z]-$range_low[$z])/($range_high[$z]-$range_low[$z]))+($scale_low)+($scaled_input_bias[$z]);	#SCALE THE VALUE
			}
			else {die ("value out of range\n");};			#THE VALUE IS OUT OF RANGE, INCREMENT ERROR AND DECREMENT $i SO IT CONTINUES
		}
# 		print "Row $i, Parameter 1: $input_data[$i][7]; $layer[0][$i][7]\n";
		$i++;
	};
}
close IN_DATA;


													#PERFORM THE NODE CALCULATIONS
for ($i=1;$i<=$layers;$i++) {
	open($IN_LAYER, '<', "../NN/NN_model/$model-Layer-$i.csv")||die("can't open datafile: ../NN/NN_model/$model-Layer-$i.csv");	#PLACE OPEN HERE SO "WHILE" DOES NOT HAVE PROBLEM WITH ARRAY
	$z=0;
	while (<$IN_LAYER>){									#DO UNTIL THE DATA ARRAY IS EMPTY
# 		print "$_\n";
		$layer_bias_weight[$i][$z]=[CSVsplit($_)];				#SPLIT THE NODAL LAYER FILE LINE INTO CONSECUTIVE ARRAYS	
		$z++;
	}
	close $IN_LAYER;
# 	print "$layer_bias_weight[$i][0][0]\n";
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
# 		print "layer $i:$z	@{$layer[$i][$z]}\n";
	}
}

											#RESCALE THE OUTPUT
$final[0]=[('*header','Filename',"GJ","kWh")];
for ($i=1;$i<=$#{$layer[$layers]};$i++) {
	$final[$i][0]=$layer[$layers][$i][0];				#CARRY SEQ NUMBER FORWARD
	$final[$i][1]=$layer[$layers][$i][1];				#CARRY FILENAME FORWARD
	$energy=($layer[$layers][$i][2]-$scale_low)/($scale_high-$scale_low)*($range_high[0]-$range_low[0])+$range_low[0];	#RESCALE OUTPUT TO ENERGY VALUES
	if ($model=~/ALC/) {$final[$i][2]=$energy*3600/1000000}	#ACCOUNT FOR ALC OUTPUT kWh UNITS
	else {$final[$i][2]=$energy}						#GJ
	$final[$i][3]=$final[$i][2]/3600*1000000;				#kWh
	
	$final[$i][2] = sprintf ("%.2f", $final[$i][2]);	# two decimal places on GJ
	$final[$i][3] = sprintf ("%.f", $final[$i][3]);	# no decimal places on kWh
}

open(RESULTS,'>', "../NN/NN_model/$model-Results.csv")||die("can't open datafile: ../NN/NN_model/$model-Results.csv");	
# open(RESULTS,'>', "../NN/NN_model/$model-Results_72_Oceanic.csv")||die("can't open datafile: ../NN/NN_model/$model-Results_72_Oceanic.csv");
for ($i=0;$i<=$#final;$i++) {
# 	print "@{$final[$i]}\n";
	$tmp=CSVjoin(@{$final[$i]});						#JOIN RESULTS FOR PRINTING
	print RESULTS "$tmp\n";
}
close RESULTS;
if ($error > 0) {print "Number of errors = $error\n";};
#END MAIN SCRIPT
