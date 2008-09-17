#!/usr/bin/perl
# This is a RUDIMENTARY script to extract the name, latitude, and longitude
# from the ascii weather data files of esp-r, held at extras/climate.
# It simply drops down a suitable
# number of lines and prints out what it find in comma delimited format.
# It has errors such as not condensing a two-word location.

use warnings;
use strict;
#use CSV;		#CSV-2 (for CSV split and join, this works best)
#use Array::Compare;	#Array-Compare-1.15
#use Switch;
#use threads;		#threads-1.71 (to multithread the program)
#use File::Path;	#File-Path-2.04 (to create directory trees)
#use Cwd;		#(to determine current working directory)

my @stations;	#placeholder for weather directory listing
push (@stations, <./clm-dat_Canada/*>);	#note all the ascii files in the Canada CWEC directory
print "@stations\n\n\n\n";		#print for good measure
open (LAT_LONG, '>', "./LAT_LONG.csv") or die ("can't open ./LAT_LONG.csv");	#open CSV file to write the desired info too


foreach my $station (@stations) {	#for each ascii fiel found
	open (CLIMATE, '<', "$station") or die ("can't open $station");	#open the file
	foreach (0..8) {<CLIMATE>};	#bypass the first nine lines of info
	my $data = <CLIMATE>;	#strip the weather station name line
	print "$data\n";
	my @data = split (/\W+/, $data);	#split based on spaces
	print LAT_LONG "$data[0],$data[1],";	#print the name and region (hopefully)
	$data = <CLIMATE>;	#strip the lat/long line
	@data = split (/\s+/, $data);	#split
	print LAT_LONG "$data[1],$data[2],$data[3]\n";	#print the weather year, latitude, and longitude in CSV format
	close CLIMATE
}

close LAT_LONG;
