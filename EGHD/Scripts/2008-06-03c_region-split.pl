#! /usr/bin/env perl
#DECLARE COMPILING CONDITIONS
#use strict;
use warnings;
use CSV;
use Array::Compare;
use Switch;

#OPEN THE APPROPRIATE SOURCE DATA FILE
open(CSV0,"<2007-10-31_EGHD-HOT2XP_dupl-chk_A-files.csv")||die("can't open datafile:$!");

#OPEN THE OUTPUT DATA FILES (DATA=DATA, CALCULATION=CALC'D VALUES FOR EACH HOUSE, TOTALS=FREQUENCY)
for ($i=1;$i<=5;$i++){
	open($OUTPUT[$i],">2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region-#$i.csv")||die("can't open datafile:$!");
}

#MAIN CODE
$_=<CSV0>;
$tmp0=[CSVsplit($_)];
$tmp1=CSVjoin(@{$tmp0});
for ($i=1;$i<=$#OUTPUT;$i++){print {$OUTPUT[$i]} "$tmp1\n"}
$i=1;
while (<CSV0>){						#DO UNTIL THE DATA ARRAY IS EMPTY
	$tmp0=[CSVsplit($_)];				#SPLIT THE INPUT FILE LINE INTO CONSECUTIVE ARRAYS
	&REGION;	
	if ($reg>0){
		$tmp1=CSVjoin(@{$tmp0});
		print {$OUTPUT[$reg]} "$tmp1\n";
	}
	print "$i\n";
	$i++;
}
for ($i=1;$i<=$#OUTPUT;$i++){close $OUTPUT[$i]}


for ($i=0;$i<=$#region_count;$i++){print "region $i records equals $region_count[$i]\n"}

sub REGION{
	#(1=Atlantic,2=QU,3=OT,4=Prairies,5=BC,0=other)
	$val=$tmp0->[3];
	if ($val=~/BRUNSWICK|SCOTIA|EDWARD|FOUND/) {$reg=1}
	elsif ($val=~/QU/) {$reg=2}
	elsif ($val=~/ONTARIO/) {$reg=3}
	elsif ($val=~/MANITOBA|ALBERTA|SASKATCH/) {$reg=4}
	elsif ($val=~/BRITISH/) {$reg=5}
	else {$reg=0}
	$region_count[$reg]++;
}
