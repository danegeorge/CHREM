#! /usr/bin/env perl
#DECLARE COMPILING CONDITIONS
#use strict;
use warnings;
use CSV;
use Array::Compare;
use Switch;
use threads;

$desired_houses=3590;	#15000;	#3590;								#THE DESIRED NUMBER OF HOUSES TO REMAIN IN THE SELECTED DATASET

for ($i=1;$i<=5;$i++){								#MULTI-THREAD TO RUN EACH REGION SIMULTANEOUSLY
	$thr[$i] = threads->new(\&MAIN_CODE, $i, $desired_houses); 	#SPAWN THE THREAD
}
for ($i=1;$i<=5;$i++){								#RETURN THE THREADS TOGETHER
	$return1[$i]=[$thr[$i]->join()];
}

&LABELS;										#CREATE LABELS FOR FILES
											#OPEN AN ALL REGIONS FREQUENCY FILE
open(OUTPUT_FINAL,">2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref-DR_subset-DR-freq.csv")||die("can't open datafile:$!");
$sum0=CSVjoin(@freq_titles1);
print OUTPUT_FINAL "EGH,$desired_houses\n$sum0\n";			#TITLE THE FREQUENCY FILE

											#PRINT THE ALL REGIONS FREQUENCY OUTPUT
for ($z=1;$z<=$#{$return1[1][0]};$z++){					#CYCLE THROUGH THE NUMBER OF FREQUENCY DISTRIBUTIONS
	print "filter number is {$z-1}\n";
	for ($y=1;$y<=$#{$return1[1][0][$z]};$y++){			#CYCLE THORUGH THE REGIONS
		print "region number is $y\n";
		print OUTPUT_FINAL "$region{$y},";
		for ($x=0;$x<=$#{$return1[$y][0][$z][$y]};$x++){	#CYCLE THROUGH THE PARAMETERS
			print "info number is $x\n";
			print OUTPUT_FINAL ",";
			for ($w=1;$w<=$#{$return1[$y][0][$z][$y][$x]};$w++){	#CYCLE THROUGH THE PARAMETER ALTERATIVES
				print OUTPUT_FINAL "$return1[$y][0][$z][$y][$x][$w],";
				print "info value is $w and the answer is $return1[$y][0][$z][$y][$x][$w]\n";
			}
		}
		print OUTPUT_FINAL "\n";
	}
	print OUTPUT_FINAL "\n";
} 
close OUTPUT_FINAL;


sub MAIN_CODE{			#MAIN CODE THAT THE THREAD JUMP TO
	$file=$_[0];		#REGION NUMBER
	$total_houses=$_[1];	#THE TOTAL NUMBER OF HOUSES TO END UP WITH

	$house_type1=2;		#1 IS SINGLE DETACHED, 2 IS ROW (END), 3 IS ROW (MIDDLE)
	$house_type2=3;		#OPTIONAL SECOND TYPE (e.g. set #1=2 and #2=3 for all "row" type)
	$house_type3=3;		#OPTIONAL THIRD TYPE (e.g. set each equal to a type for all houses)

	$placement_trigger=1;	#1/0 TO PLACE EGH ACCORDING TO SHEU DISTRIBUTIONS

	&SHEU_DISTRIBUTIONS;	#DETERMINE THE SHEU DISTRIBUTIONS FOR THE PROPER DWELLING TYPE

	&LABELS;										#CREATE LABELS FOR FILES
	%space=(0,5,1,6,2,4,3,4,4,3,5,9,6,6,7,5,8,6,9,9);			#SPACING FOR DISTRIBUTION ARRAYS

	for ($i=0;$i<=$#sheu_canada_ratio;$i++) {
		$sheu_houses0[$i]=$total_houses*$sheu_canada_ratio[$i];	#THE NUMBER OF DESIRED HOUSES FOR EACH REGION OF OUTPUT DATASET BASED ON SHEU DISTRIBUTION AND TOTAL DESIRED
		print "region $file; $sheu_houses0[$i]\n";
	}

	for ($i=1;$i<=$#sheu_filter0;$i++){						#CONSTRUCT THE ARRAY OF DESIRED HOUSE PARAMETERS
		for ($z=0;$z<=$#{$sheu_filter0[$i]};$z++){
			for ($y=0;$y<=$#{$sheu_filter0[$i][$z]};$y++){
				$sheu_count0[$i][$z][$y]=$sheu_filter0[$i][$z][$y]*$sheu_houses0[$i];	#ARRAY OF REQUIRED HOUSES # FOR EACH TYPE OF PARAMETER
				print "region $file; $sheu_count0[$i][$z][$y]\n";
			}
		}
	}	
	@sheu_count1=@sheu_count0;							#TO MAINTAIN THE ORIGINAL COUNT REQUIREMENT AND MAKE A NEW ARRAY TO DECREMENT

	#OPEN THE APPROPRIATE SOURCE DATA FILE
	open(CSV,"<2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref-SD-#$file.csv")||die("can't open datafile:$!");

	#OPEN THE OUTPUT DATA FILES (DATA=DATA, CALCULATION=CALC'D VALUES FOR EACH HOUSE, TOTALS=FREQUENCY)
	open(CALCULATION0,">2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref-DR_subset-DR-param-#$file.csv")||die("can't open datafile:$!");
	open($TOTALS[0],">2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref-DR_subset-DR-freq-#$file.csv")||die("can't open datafile:$!");
	open(OUTPUT_ALL,">2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref-DR_subset-DR-#$file.csv")||die("can't open datafile:$!");

	#MAIN CODE

	#PARSE THE ENTIRE INPUT FILE LINE INTO AN 2D ARRAY tmp0(house #,data..n)
	$p=0;									#SET THE CYCLE NUMBER
	$i=0;
	while (<CSV>){							#DO UNTIL THE DATA ARRAY IS EMPTY
		$tmp[$p][$i]=[CSVsplit($_)];				#SPLIT THE INPUT FILE LINE INTO CONSECUTIVE ARRAYS	
		#if ($tmp[$p][$i]->[742]=~/end/){print "region $file; CSV $i\n"}		
		#print "region $file; CSV $i\n";
		$i++;
	}
	close CSV;


	#APPROPRIATELY SIZE AND OPEN WRITEABLE DATA FILES AND PRINT FIRST ROW
	$i=1;	#Use first data line to count required columns since header line may not work.
	&PARSE($tmp[$p][$i],$info[$p][$i],$hse_type[$p][$i]);	#PARSE INTO 100 COLUMN ARRAYS
	for ($z=0;$z<=$#data;$z++){
		open($OUTPUT[$z],">2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref-DR_subset-DR-100-columns-#$file-file-#$z.csv")||die("can't open datafile:$!")
	}	#OPEN AS MANY DATAFILES AS REQUIRED (EQUAL TO # OF 100 COLUMN ARRAYS)

	$i=0;									#SET TO HEADER LINE
	$info[$p][$i]=[@freq_titles0];
	$hse_type[$p][$i]="Dwelling Type";
	&PARSE($tmp[$p][$i],$info[$p][$i],$hse_type[$p][$i]);	#PARSE INTO 100 COLUMN ARRAYS
	&PRINT;								#PRINT THE HEADER LINE TO THE FILES
	print "region $file; Titled all files\n";

	&ARRAY_SPACE;


	#CATEGORIZE, REMOVE ZEROS, INFO VALIDITY CHECK, AND FREQUENCY
	for ($i=1;$i<=$#{$tmp[$p]};$i++){				#DO UNTIL THE ENTIRE DATASET HAS BEEN READ (SKIP THE HEADER LINE)
		&CATEGORY;							#DETERMINE CATEGORY VALUES (STORE 2D @info0 and 1D @hse_type)
		#print "region $file; CAT $i\n";
	
		#VALIDITY OF VALUES IS {$g=0} (OTHERWISE DISCARD {$g=1})
		$g=1;																		#SET THE FAIL FLAG g
		if (($hse_type[$p][$i]==$house_type1||$hse_type[$p][$i]==$house_type2||$hse_type[$p][$i]==$house_type3)) {	#CHECK THAT HOUSE TYPE IS DESIRED
			for ($z=0;$z<=$#{$info[$p][$i]};$z++) {if ($info[$p][$i]->[$z]==0) {$g=0}}					#CHECK ALL CATEGORY COLUMNS FOR REASONABLE VALUE
		}
		else {$g=0}																	#OTHERWISE DROP THIS HOUSE FILE AS IT IS UNDESIREABLE
		#print "region $file; g is $g\n";

		&FREQUENCY_COUNT;

	}
	print "region $file; finished CAT and REMOVE and FREQ 1\n";



	if ($placement_trigger>0) {					#DO A PLACEMENT
		$p++;
		&ARRAY_SPACE;
		for ($i=0;$i<=$#{$tmp[$p]};$i++){
			&ADD_PASS;
			&FREQUENCY_COUNT;
		}
	}

	$p++;

	#CHECK THAT DATA IS CORRECT
	for ($i=0;$i<=$#{$tmp[$p]};$i++){						
		&PARSE($tmp[$p][$i],$info[$p][$i],$hse_type[$p][$i]);
		&PRINT;
		#if ($info[$p][$i]->[0]==1){print "region $file; parse&print $i\n";}
		#print "region $file; p&p $i\n";
		undef @{$tmp[$p][$i]};					#UNDEFINE DATA FOR SPACE
		undef @{$info[$p][$i]};					#UNDEFINE CATEGORY FOR SPACE
		undef $hse_type[$p][$i];				#UNDEFINE HOUSE TYPE FOR SPACE
	}


	#JOIN AND OUTPUT THE FREQUENCY RESULTS (BOTH SD AND ROW)
	$sum0=CSVjoin(@freq_titles1);
	print {$TOTALS[0]} "EGH Frequency\n$sum0\n";

	$freq_ref=[@frequency];

	for ($p=1;$p<=$#{$freq_ref};$p++){&FREQ_PRINT(0,$freq_ref);}

	#CLOSE ALL FILES
	for ($z=0;$z<=$#OUTPUT;$z++){close $OUTPUT[$z]}
	for ($z=0;$z<=$#TOTALS;$z++){close $TOTALS[$z]}
	close CALCULATION0;

	return ($freq_ref);
}	#END OF THE MAIN CODE SUBROUTINE


#SUBROUTINES

sub LABELS{
	@freq_titles0=("Region","Construction Period (yr)","Total Occupants","Storeys",
		"DHW Energy Source","Temperature-Daytime (C)","Floor Area (m^2)",
		"Space Heating Fuel","Space Heating Equipment Type","Values-drop");

	%region=(1,"Atlantic",2,"Quebec",3,"Ontario",4,"Prairies",5,"British Columbia",6,"Canada");

	@freq_titles1=("Region","",
		"Atlantic","Quebec","Ontario","Prairies","British Columbia","",
		"<1946","1946-1969","1970-1979","1980-1989","1990-2003",">=2004","",
		"1 person","2","3",">=4","",
		"1 storey","1.5","2",">=2.5","",
		"DHW-Electricity","Oil","Natural Gas","",
		"<=16C","17C","18C","19C","20C","21C","22C","23C",">=24C","",
		"<=56m^2","57-93","94-139","140-186","187-232",">=232","",
		"Spc.Heat-Electricity","Natural Gas","Oil","Wood","Propane","",
		"Air Furnace","Electric Baseboard","Wood Stove","Water Boiler","Electric Radiant","Other","",
		"Region-drop","Construction Period (yr)-drop","Total Occupants-drop","Storeys-drop",
		"DHW Energy Source-drop","Temperature-Daytime (C)-drop","Floor Area (m^2)-drop",
		"Space Heating Fuel-drop","Space Heating Equipment Type-drop");
}

sub SHEU_DISTRIBUTIONS{
	if ($house_type1==1){
		@sheu_canada_ratio=(0,0.09,0.21,0.38,0.19,0.13);	#THE SHEU RATIO FOR THE TYPE OF HOUSE DESIRED IN OUTPUT DATASET (SINGLE DETACHED)

							#Region							Constr						Occ								Storeys					DHW Src.								Temp										Floor A								Spc Ht Src						Spc Ht Type
		$sheu_filter0[1]=[[0,1,0,0,0,0],	[0,0.22,0.22,0.20,0.18,0.18,0.00],		[0,0.165,0.395,0.18,0.26],	[0,0.60,0.14,0.26,0.00],	[0,0.76,0.24,0.00],	[0,0.17,0.00,0.10,0.00,0.36,0.19,0.12,0.00,0.07],	[0,0.00,0.315,0.485,0.20,0.00,0.00],	[0,0.30,0.00,0.49,0.21,0.00],	[0,0.39,0.30,0.12,0.19,0.00,0.00]];
		$sheu_filter0[2]=[[0,0,1,0,0,0],	[0,0.11,0.24,0.26,0.20,0.19,0.00],		[0,0.13,0.40,0.15,0.32],	[0,0.65,0.10,0.25,0.00],	[0,1.00,0.00,0.00],	[0,0.00,0.00,0.10,0.07,0.36,0.18,0.19,0.09,0.00],	[0,0.00,0.39,0.42,0.19,0.00,0.00],		[0,0.76,0.00,0.11,0.13,0.00],	[0,0.21,0.66,0.13,0.00,0.00,0.00]];
		$sheu_filter0[3]=[[0,0,0,1,0,0],	[0,0.15,0.34,0.15,0.17,0.19,0.00],		[0,0.13,0.35,0.15,0.37],	[0,0.45,0.13,0.42,0.00],	[0,0.29,0.00,0.71],	[0,0.06,0.00,0.13,0.09,0.34,0.22,0.12,0.05,0.00],	[0,0.00,0.15,0.39,0.25,0.10,0.11],		[0,0.11,0.77,0.12,0.00,0.00],	[0,0.91,0.04,0.00,0.05,0.00,0.00]];
		$sheu_filter0[4]=[[0,0,0,0,1,0],	[0,0.175,0.30,0.19,0.145,0.19,0.00],	[0,0.15,0.36,0.20,0.29],	[0,0.70,0.10,0.20,0.00],	[0,0.17,0.00,0.83],	[0,0.07,0.04,0.10,0.07,0.33,0.17,0.10,0.05,0.06],	[0,0.00,0.31,0.48,0.21,0.00,0.00],		[0,0.15,0.85,0.00,0.00,0.00],	[0,0.97,0.03,0.00,0.00,0.00,0.00]];
		$sheu_filter0[5]=[[0,0,0,0,0,1],	[0,0.10,0.27,0.17,0.21,0.25,0.00],		[0,0.16,0.395,0.155,0.29],	[0,0.60,0.11,0.29,0.00],	[0,0.41,0.00,0.59],	[0,0.15,0.07,0.17,0.00,0.32,0.22,0.08,0.00,0.00],	[0,0.00,0.16,0.37,0.21,0.11,0.15],		[0,0.18,0.71,0.00,0.11,0.00],	[0,0.73,0.11,0.10,0.06,0.00,0.00]];
		for ($z=1;$z<=5;$z++){
		 $sheu_skip0[$z]={	0,1,  							1,0,							2,1,					3,0,					4,0,								5,1,											6,0,							7,0,							8,1};
		}
	}
	elsif (($house_type1==2)||($house_type1==3)){
		@sheu_canada_ratio=(0,0.05,0.27,0.41,0.14,0.12);	#THE SHEU RATIO FOR THE TYPE OF HOUSE DESIRED IN OUTPUT DATASET (ROW (MIDDLE))

							#Region							Constr						Occ								Storeys					DHW Src.								Temp										Floor A								Spc Ht Src						Spc Ht Type
		$sheu_filter0[1]=[[0,1,0,0,0,0],	[0,0.155,0.22,0.235,0.19,0.20,0.00],	[0,0.20,0.33,0.19,0.28],	[0,0.36,0.05,0.53,0.06],	[0,0.76,0.24,0.00],	[0,0.12,0.00,0.10,0.08,0.28,0.24,0.17,0.00,0.00],	[0,0.07,0.295,0.485,0.15,0.00,0.00],	[0,0.30,0.00,0.49,0.21,0.00],	[0,0.39,0.30,0.12,0.19,0.00,0.00]];
		$sheu_filter0[2]=[[0,0,1,0,0,0],	[0,0.155,0.22,0.235,0.19,0.20,0.00],	[0,0.20,0.33,0.19,0.28],	[0,0.36,0.05,0.53,0.06],	[0,1.00,0.00,0.00],	[0,0.12,0.00,0.10,0.08,0.28,0.24,0.17,0.00,0.00],	[0,0.07,0.295,0.485,0.15,0.00,0.00],	[0,0.76,0.00,0.11,0.13,0.00],	[0,0.21,0.66,0.13,0.00,0.00,0.00]];
		$sheu_filter0[3]=[[0,0,0,1,0,0],	[0,0.155,0.22,0.235,0.19,0.20,0.00],	[0,0.20,0.33,0.19,0.28],	[0,0.36,0.05,0.53,0.06],	[0,0.29,0.00,0.71],	[0,0.12,0.00,0.10,0.08,0.28,0.24,0.17,0.00,0.00],	[0,0.07,0.295,0.485,0.15,0.00,0.00],	[0,0.11,0.77,0.12,0.00,0.00],	[0,0.91,0.04,0.00,0.05,0.00,0.00]];
		$sheu_filter0[4]=[[0,0,0,0,1,0],	[0,0.155,0.22,0.235,0.19,0.20,0.00],	[0,0.20,0.33,0.19,0.28],	[0,0.36,0.05,0.53,0.06],	[0,0.17,0.00,0.83],	[0,0.12,0.00,0.10,0.08,0.28,0.24,0.17,0.00,0.00],	[0,0.07,0.295,0.485,0.15,0.00,0.00],	[0,0.15,0.85,0.00,0.00,0.00],	[0,0.97,0.03,0.00,0.00,0.00,0.00]];
		$sheu_filter0[5]=[[0,0,0,0,0,1],	[0,0.155,0.22,0.235,0.19,0.20,0.00],	[0,0.20,0.33,0.19,0.28],	[0,0.36,0.05,0.53,0.06],	[0,0.41,0.00,0.59],	[0,0.12,0.00,0.10,0.08,0.28,0.24,0.17,0.00,0.00],	[0,0.07,0.295,0.485,0.15,0.00,0.00],	[0,0.18,0.71,0.00,0.11,0.00],	[0,0.73,0.11,0.10,0.06,0.00,0.00]];
#																								[0,0.46,0.00,0.54],																[0,0.38,0.58,0.05,0.00,0.00],
		for ($z=1;$z<=5;$z++){
		 $sheu_skip0[$z]={0,1,  		1,0,						2,1,					3,0,					4,0,				5,1,									6,0,						7,0,					8,1};
		}
	}
}

sub FREQ_PRINT{
	$i=$_[0];
	$value=$_[1];
	for($z=1;$z<=$#{$value->[$p]};$z++){
		print {$TOTALS[$i]} "$region{$z},";
		for ($y=0;$y<=$#{$value->[$p][$z]};$y++){
			$sum0=CSVjoin(@{$value->[$p][$z]->[$y]});
			print {$TOTALS[$i]} "$sum0,"
		}
		print {$TOTALS[$i]} "\n";
	}
	print {$TOTALS[$i]} "\n";
}

sub PARSE {
	$data_list=$_[0];
	$info_list=$_[1];
	$housing_type=$_[2];

	for ($z=0;$z<($#{$data_list}/100);$z++){
		if (($z+1)*100>$#{$data_list}){$data[$z]=CSVjoin(@{$data_list}[$z*100..$#{$data_list}])}
		else {$data[$z]=CSVjoin(@{$data_list}[$z*100..($z+1)*100-1],$data_list->[0])}
	}
	$calc0=CSVjoin($data_list->[0],@{$info_list},$housing_type);
	$data_all=CSVjoin(@{$data_list});
}

sub PRINT{
	for ($z=0;$z<=$#data;$z++){print {$OUTPUT[$z]} "$data[$z]\n"}
	print CALCULATION0 "$calc0\n";
	print OUTPUT_ALL "$data_all\n";
}
sub CATEGORY{
	#CREATE A REGIONAL COLUMN WITH NUMBERS 1-5 LIKE SHEU2003 Table 1.1 
	#(1=Atlantic,2=QU,3=OT,4=Prairies,5=BC,0=other)
	$c=0;	$d=3;	#632;	#777;
	$val=$tmp[$p][$i][$d];
	if ($val=~/BRUNSWICK|SCOTIA|EDWARD|FOUND/) {$info[$p][$i][$c]=1}
	elsif ($val=~/QU/) {$info[$p][$i][$c]=2}
	elsif ($val=~/ONTARIO/) {$info[$p][$i][$c]=3}
	elsif ($val=~/MANITOBA|ALBERTA|SASKATCH/) {$info[$p][$i][$c]=4}
	elsif ($val=~/BRITISH/) {$info[$p][$i][$c]=5}
	else {$info[$p][$i][$c]=0}

	#CREATE A CONSTRUCTION PERIOD COLUMN WITH NUMBER 1-5 LIKE SHEU2003 Table 1.1  
	#(1=<1946,2=1946-1969,3=1970-1079, 4=1980-1989,5=1990-2003,0=other)
	$c++;	$d=6;	#620;	#765;
	$val=$tmp[$p][$i][$d];
	if (($val>=1900) && ($val<1946)) {$info[$p][$i][$c]=1}
	elsif (($val>=1946) && ($val<1970)) {$info[$p][$i][$c]=2}
	elsif (($val>=1970) && ($val<1980)) {$info[$p][$i][$c]=3}
	elsif (($val>=1980) && ($val<1990)) {$info[$p][$i][$c]=4}
	elsif (($val>=1990) && ($val<2004)) {$info[$p][$i][$c]=5}
	elsif (($val>=2004) && ($val<2007)) {$info[$p][$i][$c]=6}
	else {$info[$p][$i][$c]=0}

	#CREATE A OCCUPANT HOUSEHOLD SIZE COLUMN WITH NUMBER 1-4 LIKE SHEU2003 Table 1.1  
	#(1=1,2=2,3=2, 4=4 or more)
	$c++; $d=65;	#629;	#774;
	$val=$tmp[$p][$i][$d];
	if ($val==1) {$info[$p][$i][$c]=1}
	elsif ($val==2) {$info[$p][$i][$c]=2}
	elsif ($val==3) {$info[$p][$i][$c]=3}
	elsif (($val>=4) && ($val<=9)) {$info[$p][$i][$c]=4}
	else {$info[$p][$i][$c]=0}

	#CREATE A NUMBER OF STOREYS COLUMN WITH NUMBER 1-4 LIKE SHEU2003 Table 2.1  
	#(1=1 storey,2=1.5 storeys,3=2 storeys,4=2 storeys or more)
	$c++;	$d=13;	#606;	#743;
	$val=$tmp[$p][$i][$d];
	if ($val=~/1/) {$info[$p][$i][$c]=1;$h=1}
	elsif ($val=~/2/) {$info[$p][$i][$c]=2;$h=2}
	elsif ($val=~/3/) {$info[$p][$i][$c]=3;$h=3}
	elsif ($val=~/4|5/) {$info[$p][$i][$c]=4;$h=4}
	else {$info[$p][$i][$c]=0}

	#CREATE A DHW ENERGY COLUMN WITH NUMBER 1-3 LIKE SHEU2003 Table 2.1  
	#(1=electricity,2=oil,3=natural gas)
	$c++;	$d=80;	#611;	#750;
	$val=$tmp[$p][$i][$d];
	if ($val=~/1/) {$info[$p][$i][$c]=1}
	elsif ($val=~/3/) {$info[$p][$i][$c]=2}
	elsif ($val=~/2/) {$info[$p][$i][$c]=3}
	else {$info[$p][$i][$c]=0}	

	#CREATE A DAYTIME TEMPERATURE COLUMN WITH NUMBER 1-9 LIKE SHEU2003 Table 3.7  
	#(1<=16C,2=17C,3=18C,4=19C,5=20C,5=21C,7=22C,8=23C,9>=24C)
	$c++; $d=69;	#1;	#1;	
	$val=$tmp[$p][$i][$d];
	if ($val>=14 && $val<17) {$info[$p][$i][$c]=1}
	elsif ($val>=17 && $val<18) {$info[$p][$i][$c]=2}
	elsif ($val>=18 && $val<19) {$info[$p][$i][$c]=3}
	elsif ($val>=19 && $val<20) {$info[$p][$i][$c]=4}
	elsif ($val>=20 && $val<21) {$info[$p][$i][$c]=5}
	elsif ($val>=21 && $val<22) {$info[$p][$i][$c]=6}
	elsif ($val>=22 && $val<23) {$info[$p][$i][$c]=7}
	elsif ($val>=23 && $val<24) {$info[$p][$i][$c]=8}
	elsif ($val>=24 && $val<27) {$info[$p][$i][$c]=9}
	else {$info[$p][$i][$c]=0}

	#CREATE A FLOOR AREA COLUMN WITH NUMBER 1-6 LIKE SHEU2003 Table 2.4  
	#(1=<56,2=57-93,3=94-139,4=140-186,5=187-232,6>=233,0=other)
	$c++; $d=100;	#622;	#768;
	$val=$tmp[$p][$i][$d]+$tmp[$p][$i][$d+1]+$tmp[$p][$i][$d+2];
	if (($val>25) && ($val<=56)) {$info[$p][$i][$c]=1}
	elsif (($val>56) && ($val<=93)) {$info[$p][$i][$c]=2}
	elsif (($val>93) && ($val<=139)) {$info[$p][$i][$c]=3}
	elsif (($val>139) && ($val<=186)) {$info[$p][$i][$c]=4}
	elsif (($val>186) && ($val<=232)) {$info[$p][$i][$c]=5}
	elsif (($val>232) && ($val<300)) {$info[$p][$i][$c]=6}
	else {$info[$p][$i][$c]=0}

	#CREATE A SPACE HEATING ENERGY SOURCE COLUMN WITH NUMBER 1-5 LIKE SHEU2003 Table 3.1  
	#(1=electricity,2=natural gas,3=oil,4=wood,5=propane)
	$c++;	$d=75;	#604;	#741;
	$val=$tmp[$p][$i][$d];
	if ($val=~/1/) {$info[$p][$i][$c]=1}
	elsif ($val=~/2/) {$info[$p][$i][$c]=2}
	elsif ($val=~/3/) {$info[$p][$i][$c]=3}
	elsif ($val=~/5|6|7|8/) {$info[$p][$i][$c]=4}
	elsif ($val=~/4/) {$info[$p][$i][$c]=5}
	else {$info[$p][$i][$c]=0}

	#CREATE A SPACE HEATING TYPE COLUMN WITH NUMBER 1-5 LIKE SHEU2003 Table 3.1  
	#(1=furnace (air),2=electric baseboard,3=wood stove,4=boiler (water),5=electric radiant,6=other)
	$c++; $d=75;	#608;	#747;
	$val0=$tmp[$p][$i][$d];	#Space heat energy source
	$val1=$tmp[$p][$i][$d+3];	#Space heat equip type
	if (($val0=~/1/) && ($val1=~/2|5|6|7/)) {$info[$p][$i][$c]=1}		#electric furnace or HP
	elsif (($val0=~/2|4/) && ($val1=~/1|3|5|7|9/)) {$info[$p][$i][$c]=1}	#NG or propane furnace
	elsif (($val0=~/3/) && ($val1=~/1|3|5|7|9|11/)) {$info[$p][$i][$c]=1}	#oil furnace
	elsif (($val0=~/5|6|7|8/) && ($val1=~/3/)) {$info[$p][$i][$c]=1}		#wood furnace

	elsif (($val0=~/1/) && ($val1=~/1/)) {$info[$p][$i][$c]=2}			#Electric baseboard

	elsif (($val0=~/5|6|7|8/) && ($val1=~/1|2|5|6/)) {$info[$p][$i][$c]=3}	#Wood stove

	elsif (($val0=~/2|4/) && ($val1=~/2|4|6|8|10/)) {$info[$p][$i][$c]=4}	#NG or propane boiler
	elsif (($val0=~/3/) && ($val1=~/2|4|6|8|10/)) {$info[$p][$i][$c]=4}	#oil boiler
	elsif (($val0=~/5|6|7|8/) && ($val1=~/4/)) {$info[$p][$i][$c]=4}		#Wood boiler

	elsif (($val0=~/1/) && ($val1=~/3|4/)) {$info[$p][$i][$c]=5}		#Electric radiant

	elsif (($val0=~/5|6|7|8/) && ($val1=~/7|8|9|10/)) {$info[$p][$i][$c]=6}	#Wood other
	else {$info[$p][$i][$c]=0}


	#CREATE A DWELLING TYPE COLUMN WITH NUMBER 1-4 LIKE SHEU2003 Table 1.1  
	#(1=single detached,2=Row(end),3=Row(middle)
	$d=16;	#605;	#742;
	$val=$tmp[$p][$i][$d];
	if ($val=~/1/) {$hse_type[$p][$i]=1}
	elsif ($val=~/2|3/) {$hse_type[$p][$i]=2}
	elsif ($val=~/4/) {$hse_type[$p][$i]=3}
	else {$hse_type[$p][$i]=0}

}

sub ARRAY_SPACE{
	for ($z=1;$z<=6;$z++){						#ALLOT SPACE REQUIREMENTS FOR PROPER COMBINE AND PRINTOUT OF ARRAYS
		for ($y=0;$y<=$#freq_titles0;$y++){
			for ($x=1;$x<=$space{$y};$x++){
				$frequency[$p+1][$z]->[$y][$x]=0;
			}
		}
	}
}

sub FREQUENCY_COUNT{
	#IF VALID STORE 2D @tmp2 AND INCREMENT THE FREQUENCY COUNTER
	if ($g==1) {									#IF DESIREABLE HOUSE THE STORE AND INCREMENT
	#if ($info[$p][$i]->[1]==5) {print "region $file; $i category, remove zero, and store 2\n"}
		for ($z=0;$z<=$#{$info[$p][$i]};$z++) {						#CYCLE THROUGH ALL CATEGORY TYPES
			$frequency[$p+1][$info[$p][$i]->[0]]->[$z][$info[$p][$i]->[$z]]++;		#INCREMENT REGIONAL CATEGORY TYPE VALUE
			$frequency[$p+1][6]->[$z][$info[$p][$i]->[$z]]++;					#INCREMENT CANADIAN CATEGORY TYPE VALUE
		}	
		push @{$tmp[$p+1][@{$tmp[$p+1]}]},@{$tmp[$p][$i]};							#DESIREABLE HOUSE SO STORE DATA IN NEW 2D ARRAY tmp
		push @{$info[$p+1][@{$info[$p+1]}]},@{$info[$p][$i]};						#ALSO STORE CATEGORY DATA
		$hse_type[$p+1][@{$hse_type[$p+1]}]=$hse_type[$p][$i];						#ALSO STORE HOUSE TYPE
	}
	else {												#UNDESIREABLE, BUT STORE THE CATEGORY OF WHY
		$g=0;												#SET A FLAG
		for ($z=0;$z<=$#{$info[$p][$i]};$z++) {						#CYCLE THROUGH THE CATEGORY DATA
			if ($info[$p][$i]->[$z]==0 && $g==0) {						#LOOK FOR OUT OF RANGE CATEGORY (i.e. 0)
				$g=1;
				$frequency[$p+1][$info[$p][$i]->[0]]->[$#{$info[$p][$i]}+1][$z+1]++;	#INCREMENT UNDESIREABLE REGIONAL CATEGORY TYPE
				$frequency[$p+1][6]->[$#{$info[$p][$i]}+1][$z+1]++;			#INCREMENT UNDESIREABLE CANADIAN CATEGORY TYPE
			}
		}
		#print "region $file; #$i	dud\n";
	}
	undef @{$tmp[$p][$i]};			#UNDEFINE DATA FOR SPACE
	undef @{$info[$p][$i]};			#UNDEFINE CATEGORY FOR SPACE
	undef $hse_type[$p][$i];		#UNDEFINE HOUSE TYPE FOR SPACE
	#print "region $file; undef $i\n";
}

sub ADD_PASS{
	#print "region $file; #$i	enter filter pass\ntotal in info is $#{$info[$p]}\ntotal for house file is $#{$info[$p][$i]}";															#IF THE HOUSE FILE SATISFIES THE FILTER REQUIREMENT (OVERREPRESENTED) THEN IT IS DROPPED
	$g=1;			#IF G=1 THEN DON'T ADD									#ALL HOUSES ARE INTIALLY FILTERABLE (REMOVABLE)
	$h=0;			#FILTER DEPTH TAG (DEPRECATED DUE TO AUTOMATIC FILL ABOVE (NOT-ORDERED)
	for ($z=0;$z<=$#{$info[$p][$i]};$z++) {
		#print "region $file; first filter for loop\n";												#CYCLE THROUGH CATEGORY
		if ($g==1) {

			$g=0;
			if (($sheu_skip0[$info[$p][$i]->[0]]->{$z})||($sheu_count1[$info[$p][$i]->[0]]->[$z][$info[$p][$i]->[$z]]>0)){$g=1;}	#IF WE SKIP (DON'T CARE) OR IF THE HOUSE CATEGORY VALUE EQUALS THE FILTER CATEGORY VALUE, TRUE THAN MAINTAIN ITS FILTERABLE STATUS																	
		}
	}
	if ($g==1) {
		for ($z=0;$z<=$#{$info[$p][$i]};$z++) {
			$sheu_count1[$info[$p][$i]->[0]]->[$z][$info[$p][$i]->[$z]]--;
		}
	}
	#if ($g==1){print "region $file; filter out $i\n";}
}
