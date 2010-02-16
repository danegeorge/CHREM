#! /usr/bin/env perl
#DECLARE COMPILING CONDITIONS
#use strict;
use warnings;
use CSV;
use Array::Compare;
use Switch;
use threads;


for ($i=1;$i<=5;$i++){								#MULTI-THREAD TO RUN EACH REGION SIMULTANEOUSLY
	$thr[$i] = threads->new(\&MAIN_CODE, $i); 	#SPAWN THE THREAD
}
for ($i=1;$i<=5;$i++){								#RETURN THE THREADS TOGETHER
	$return1[$i]=[$thr[$i]->join()];
}

sub MAIN_CODE{
	$reg=$_[0];		#REGION NUMBER
	#OPEN THE APPROPRIATE SOURCE DATA FILE
	open(CSV0,"<2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region-#$reg.csv")||die("can't open datafile:$!");

	#OPEN THE OUTPUT DATA FILES (DATA=DATA, CALCULATION=CALC'D VALUES FOR EACH HOUSE, TOTALS=FREQUENCY)
	open(OUTPUT,">2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual-#$reg.csv")||die("can't open datafile:$!");
	
	&READ;

	@info_prob=(0,0,0,0,0,0,0,0,0);
	$hse_prob=0;
	for($i=1;$i<=$#{$tmp[$p]};$i++){
		&CATEGORY;
		$g=0;
		for($z=0;$z<=$#{$info[$p][$i]};$z++){			#MAY MEET MULTIPLE CRITERIA
			if ($info[$p][$i][$z]==0) {$g=1; $info_prob[$z]++}
		}
		if($hse_type[$p][$i]==0){$g=1; $hse_prob++}
		if ($g) {
			splice(@{$tmp[$p]},$i,1);
			splice(@{$info[$p]},$i,1);
			$i--;
		}
	}

#	for($i=0;$i<=$#{$tmp[$p]};$i++){
#		&PARAMETERS;
#	}

	for($i=0;$i<=$#{$tmp[$p]};$i++){
		$tmp0=CSVjoin(@{$tmp[$p][$i]});
		print OUTPUT "$tmp0\n";
	}

#	print "Region $reg original records $original\n";
#	print "Region $reg final records $#{$tmp[$p]}\n";
#	print "Region $reg info prob @info_prob\n";
#	print "Region $reg hse prob $hse_prob\n";
	print "$reg $original $#{$tmp[$p]} @info_prob $hse_prob\n";
}


sub READ{
	$i=0;
	$p=0;
	while (<CSV0>){							#DO UNTIL THE DATA ARRAY IS EMPTY
		$tmp[$p][$i]=[CSVsplit($_)];				#SPLIT THE INPUT FILE LINE INTO CONSECUTIVE ARRAYS	
		$i++;
#		print "CSV0 $i\n";
	}
	close CSV0;
#	print "CSV0 END\n";
	$original=$#{$tmp[$p]};
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

#	#CREATE A SPACE HEATING TYPE COLUMN WITH NUMBER 1-5 LIKE SHEU2003 Table 3.1  
#	#(1=furnace (air),2=electric baseboard,3=wood stove,4=boiler (water),5=electric radiant,6=other)
#	$c++; $d=608;	#747;
#	$val=$tmp[$p][$i][$d];
#	if ($val=~/urnace/) {$info[$p][$i][$c]=1}
#	elsif ($val=~/aseboard/) {$info[$p][$i][$c]=2}
#	elsif ($val=~/tove/) {$info[$p][$i][$c]=3}
#	elsif ($val=~/oiler/) {$info[$p][$i][$c]=4}
#	elsif ($val=~/adiant/) {$info[$p][$i][$c]=5}
#	else {$info[$p][$i][$c]=6}


	#CREATE A DWELLING TYPE COLUMN WITH NUMBER 1-4 LIKE SHEU2003 Table 1.1  
	#(1=single detached,2=Row(end),3=Row(middle)
	$d=16;	#605;	#742;
	$val=$tmp[$p][$i][$d];
	if ($val=~/1/) {$hse_type[$p][$i]=1}
	elsif ($val=~/2|3/) {$hse_type[$p][$i]=2}
	elsif ($val=~/4/) {$hse_type[$p][$i]=3}
	else {$hse_type[$p][$i]=0}

}

sub PARAMETERS{
	#HOUSE VOLUME (m^2)
	$c++; $d=11;
	$info[$p][$i][$c]=$tmp[$p][$i][$d];

	#HEAT PUMP PRESENCE (1 IS YES, 0 IS NO)
	$c++; $d=14;
	$val=$tmp[$p][$i][$d];
	if ($val=~/Y/) {$info[$p][$i][$c]=1}
	else {$info[$p][$i][$c]=0}

	#AIR CONDITIONER PRESENCE (1 IS YES, 0 IS NO)
	$c++; $d=15;
	$val=$tmp[$p][$i][$d];
	if ($val=~/Y/) {$info[$p][$i][$c]=1}
	else {$info[$p][$i][$c]=0}

	#HRV (0 IS NO, 1 IS W/ HR, 2 IS W/O HR)
	$c++; $d=39;
	$info[$p][$i][$c]=$tmp[$p][$i][$d]-1;

	#ORIENTATION (1 IS NORTH, 2 IS NORTHEAST, ETC.)
	$c++; $d=607;
	$val=$tmp[$p][$i][$d];
	if ($val=~/ortheast/) {$info[$p][$i][$c]=2}
	elsif ($val=~/outheast/) {$info[$p][$i][$c]=4}
	elsif ($val=~/outhwest/) {$info[$p][$i][$c]=6}
	elsif ($val=~/orthwest/) {$info[$p][$i][$c]=8}
	elsif ($val=~/orth/) {$info[$p][$i][$c]=1}
	elsif ($val=~/ast/) {$info[$p][$i][$c]=3}
	elsif ($val=~/outh/) {$info[$p][$i][$c]=5}
	elsif ($val=~/est/) {$info[$p][$i][$c]=7}
	else {$info[$p][$i][$c]=0}

	#HAS A BASEMENT (0 IS NO, 1 IS YES)
	$c++; $d=616;
	$info[$p][$i][$c]=$tmp[$p][$i][$d];
	
}