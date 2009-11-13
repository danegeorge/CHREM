#!/usr/bin/perl

# ====================================================================
# PostalCode_combine.pl
# Author: Lukas Swan
# Date: June 2009
# Copyright: Dalhousie University

# INPUT USE:
# filename.pl

# DESCRIPTION:
# This script reads in the postal information from the three Censuses
# (1996, 2001, 2006) and then prints out all unique postal codes, 
# with presendence given to the more recent Census.
# NOTE: It appears that the 2006 trumps all. So this is relatively useless

# ===================================================================

# --------------------------------------------------------------------
# Declare modules which are used
# --------------------------------------------------------------------

use warnings;
use strict;

use CSV;	# CSV-2 (for CSV split and join, this works best)
# use Array::Compare;	# Array-Compare-1.15
# use threads;	# threads-1.71 (to multithread the program)
# use File::Path;	# File-Path-2.04 (to create directory trees)
# use File::Copy;	# (to copy the input.xml file)
use Data::Dumper;




my $data;	# create an reference to hold all data for a particular postal code hash key 
my @header;	# declare array to hold header info
my $header_key;	# declare a key location b/c I will shift the first element off the header array for simplicity
my $info;	# store all of the info in the file above the data (and not including the header)

# paths to the files we will use
my $dir = "../keys/";
my $file = "Census_PCCF_Postal-Code_Urban-Rural-Type.csv";

# loop over the census years
foreach my $year (1996, 2001, 2006) {

	# open the file
	open (IN, '<', "$dir$year\_$file") or die ("can't open datafile: $dir$year\_$file");
	print "Reading file: $year\_$file\n";
	
	while (<IN>) {
	
		$_ = rm_EOL_and_trim($_);

		if ($_ =~ s/^\*header,//) {	# header row has *header tag
			@header = CSVsplit($_);	# split the header onto the array
# 			print "header @header\n";

			# shift off the first element and store it. This will make hash slice easier below
			$header_key = shift(@header);
		}
			
		elsif ($_ =~ s/^\*data,//) {	# data lines will begin with the *data tag
			@_ = CSVsplit($_);	# split the data onto the @_ array
			
			# shift the postal code off the array as it will be used as the key
			my $key = shift(@_);
			
			# fill out the array slice with header keys and the postal code info
			@{$data->{$key}}{@header} = @_;
		}
		
		# only capture the info for one year. I have arbitrarily chosen 2006
		elsif ($year == 2006) {
			# store the info for later printing
			push (@{$info}, [CSVsplit($_)]);
		};
	};
	close IN;	# close the Census Postal Code file
};

# Open an output file to store the information
open (OUT, '>', "$dir$file") or die ("can't open datafile: $dir$file");
print "Starting printout: $file\n";

# loop through and print all the info at the top
foreach my $element (@{$info}) {
	my $line = CSVjoin(@{$element});
	print OUT "$line\n";
};

# print the header line. I have added the tag and the header_key (first shifted element) as well
my $head_line = CSVjoin ("*header", $header_key, @header);
print OUT "$head_line\n";

# sort the postal codes in alphabetical order
my @PostalCodes = sort keys (%{$data});

# loop through the postal codes (in order)
foreach my $PostalCode (@PostalCodes) {
	# join the tag, the postal code, and all of the postal code information
	my $line = CSVjoin ("*data", $PostalCode, @{$data->{$PostalCode}}{@header});
	print OUT "$line\n";
};

# close file
close OUT;
# print Dumper $data;