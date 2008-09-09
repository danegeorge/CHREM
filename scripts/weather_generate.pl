#!/usr/bin/perl -w
#/home/lswan/CSDDRD_to_esp-r
@files = <../climate/HOT3000_climate/ascii/*.a>;
foreach $file (@files) {
	print $file . "\n";
	my $file_short = $file;
	$file_short =~ s/..\/climate\/HOT3000_climate\/ascii\///;
	$file_short =~ s/\.a//;
	system ("clm -mode text -file ../climate/2008-07_linux_climate/$file_short -act asci2bin silent $file");
}
