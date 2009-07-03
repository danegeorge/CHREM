#!/usr/bin/perl
# 
#====================================================================
# BCD_DHW_AL_avg.pl
# Author:    Lukas Swan
# Date:      May 2009
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl path_to_files_for_conversion orig_DHW_time-step_minutes path_to_files_for_output final_time-step_minutes
#
# DESCRIPTION:
# This script reads the contents of a src directory that contains DHW (1 column, not header) and
# AL data (*.fcl type) at a certain timestep, averages the values to an appropriate timestep and
# then outputs the variety of combinations into bcd files. For example, if 2 DHW levels and 2 AL
# levels were specified, then 4 combinations and thus 4 bcd files would be generated.
#
#
# NOTE that the final_time-step_minutes must be divisible by the orig_DHW_time-step_minutes to a whole number
# NOTE that the AL file includes time-step information and it will be read and used
# NOTE that DHW files are identified by xxDHWyyy.txt and AL files are identified by can_gen_USAGE_yX.fcl
# where xx is the DHW minutes time-step, and yyy is L/day divided by 100 (i.e. 100 L/day is 001)
# and wheree USAGE is low, med, or high, and X is year 1, 2, or 3


#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;
use CSV;		#CSV-2 (for CSV split and join, this works best)
#use Array::Compare;	#Array-Compare-1.15
#use Switch;
#use threads;		#threads-1.71 (to multithread the program)
#use File::Path;	#File-Path-2.04 (to create directory trees)
#use File::Copy;	#(to copy the input.xml file)


#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------


#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------

COMMAND_LINE: {
	# check the number of arguements
	if ($#ARGV != 3) {die "Four arguments are required: path_to_files_for_conversion orig_time-step_minutes path_to_files_for_output final_time-step_minutes\n";};
	$ARGV[0] =~ s/\/$//;	# remove any trailing slash from paths
	$ARGV[2] =~ s/\/$//;
};

my @files = <$ARGV[0]/*>;	# read the files in the directory

print "FILES IN THE DIRECTORY\n";
foreach my $file (@files) {print "$file\n";};

my $DHW_input;	# declare a hash reference to store DHW input data
my $AL_input;	# declare a hash reference to store AL input data
my $AL_timestep; # declare a hash reference to store AL time-step increment value in minutes

#--------------------------------
# READIN OF THE APPROPRIATE FILES
#--------------------------------

print "FILES USED\n";

foreach my $file (@files) {	# go through the files and only use the desired ones (disregard temp~ files and non-desirable time-steps)

	# DHW file (xxDHWyyy.txt)
	if ($file =~ /^.+\/(..)DHW00(.)\.txt$/i && $ARGV[1] == $1) {	# check the filename and that the time-step is correct
	
		open (DHW, '<', $file) or die ("can't open $file");	# open the file to read DHW data 
		
		$DHW_input->{$2 * 100} = [<DHW>];	# slurp the DHW data into an array with the end of line characters
		
		# cleanup the data
		foreach my $line (@{$DHW_input->{$2 * 100}}) {
			$line =~ s/\r\n|\n|\r//g;	# chomp the end of line characters off (dos, unix, or mac)
			$line =~ s/^\s+|\s+$//g;	# remove leading and trailing whitespace
		};
		
		close DHW;
		
		print "$file\n";	# for user reference
	}
	
	# AL file (can_gen_USAGE_yX.fcl)
	elsif ($file =~ /^.+\/can_gen_(.+).fcl$/) {	# check the filename
	
		open (AL, '<', $file) or die ("can't open $file");	# open the file to read AL data
		
		$_ = <AL>;	# strip the first line (year info?)
		$_ = <AL>;	# strip the second line (time-steps per line info where each line is an hour [therefore this is timesteps per hour])
		@_ = CSVsplit($_);	# split the comma delimited format
		$AL_timestep->{$1} = 60 / $_[0];	# determine the minutes of time-step
		
		while (<AL>) {
			push (@{$AL_input->{$1}}, CSVsplit($_));	# This will place each time-step value in consecutive elements (it also takes care of end of line characters)
		};
		
		close AL;
		
		print "$file\n";	# for user reference
	};
};

#------------------------
# AVERAGING OF THE VALUES
#------------------------
my $DHW_avg;	# declare a hash reference to store DHW avg data
my $AL_avg;	# declare a hash reference to store AL avg data

print "AVERAGING\n";

# DHW avg
foreach my $use (keys(%{$DHW_input})) {	# cycle through all the DHW types
	my $sum = 0;	# initialize sum and indexs
	my $index = 0;
	
	foreach my $element (@{$DHW_input->{$use}}) {	# go through each element of the array
		$sum = $sum + $element;	# sum the values
		$index++;	# increment the index
		
		if ($index == ($ARGV[3] / $ARGV[1])) {	# if we have reached the averaging ratio for DHW, then calculate avg
			push (@{$DHW_avg->{$use}}, $sum / $index);	# push the average onto the avg array
			$sum = 0;	# reset the sum and index
			$index = 0;
		};
	};
	print "DHW use = $use; orig elements = $#{$DHW_input->{$use}}; final elements = $#{$DHW_avg->{$use}}\n";	# for user info
};

# AL avg
foreach my $use (keys(%{$AL_input})) {
	my $sum = 0;	# initialize sum and indexs
	my $index = 0;
	
	foreach my $element (@{$AL_input->{$use}}) {
		$sum = $sum + $element;	# sum the values
		$index++;	# increment the index
		
		if ($index == ($ARGV[3] / $AL_timestep->{$use})) {	# if we have reached the averaging ratio for AL (note use of its own timestep), then calculate avg
			push (@{$AL_avg->{$use}}, $sum / $index);	# push the average onto the avg array
			$sum = 0;	# reset the sum and index
			$index = 0;
		};
	};
	print "AL use = $use; orig elements = $#{$AL_input->{$use}}; final elements = $#{$AL_avg->{$use}}\n";	# for user info
};

#----------------------------------------------------
# CHECK FOR EQUAL ARRAY LENGTHS OF THE DHW AND AL AVG
#----------------------------------------------------
foreach my $DHW_use (keys(%{$DHW_avg})) {	# DHW
	foreach my $AL_use (keys(%{$AL_avg})) {	# AL
		if ($#{$DHW_avg->{$DHW_use}} != $#{$AL_avg->{$AL_use}}) {	# compare all combinations, if there is a difference then die
			die (sprintf ("%s %s %s %s", 'Unequal avg array sizes: DHW =', $#{$DHW_avg->{$DHW_use}} + 1, '; AL =', $#{$AL_avg->{$AL_use}} + 1));
		};
	};
};

print "SUCCESSFUL COMPARE OF AVG ARRAY SIZES\n";

#-------------------------
# PRINTOUT OF THE BCD FILE
#-------------------------

open (BCD_TEMPLATE, '<', '../templates/template.bcd') or die ("can't open ../bcd/template.bcd");	#open the BCD template file
my @bcd_template = <BCD_TEMPLATE>;	# slurp in the template
chomp (@bcd_template);	# chomp the end of line characters
close BCD_TEMPLATE;

print "SUCCESSFUL READ OF BCD TEMPLATE\n";
print "NOW PRINTING THE BCD FILES\n";

# Open a file to store the cumulative annual values. This is used to relate the estimated annual values of the NN to the most appropriate profile and to determine a multiplier
open (ANNUAL, '>', "$ARGV[2]/ANNUAL_$ARGV[3]_min_avg_from_$ARGV[1]_min_src.csv") or die ("can't open $ARGV[2]/ANNUAL_$ARGV[3]_min_avg_from_$ARGV[1]_min_src.csv");	#open the a file to store annual values
print ANNUAL "*comment,This file cross references the bcd files to integrated annual values of each data field.\n";
print ANNUAL "*comment,It is used to determine 'best fit' of profiles and to calculate a multiplier for the profiles.\n";
print ANNUAL "*header,bcd_file,DHW_ann,AL_ann\n";
print ANNUAL "*units,-,Litres,GJ\n";

# Cycle through each DHW type and each AL type so that all potential variations (i.e. DHW vs AL) are encountered
foreach my $DHW_use (sort {$a cmp $b} keys(%{$DHW_avg})) {	# cycle through DHW

	print "\tDHW $DHW_use\n";
	
	foreach my $AL_use (sort {$a cmp $b} keys(%{$AL_avg})) {	# cycle through AL
	
		print "\t\tAL $AL_use\n";
	
		my @bcd = @bcd_template;	# copy the template for use in this file
		
		# Provide all of the required information for the bcd
		
		my $line = 0;	# intialize for use with while loop as we will insert elements into the array
		while ($line <= $#bcd) {	# cycle through the template lines
		
			# adjust the frequency and add notes
			if ($bcd[$line] =~ /^\*frequency/) {	# found freq tag
				my $freq = $ARGV[3] * 60;	# seconds per datapoint
				$bcd[$line] = "*frequency $freq";
			}
			elsif ($bcd[$line] =~ /^#NOTES/) {	# found the notes tag
				splice (@bcd, $line + 1, 0,
					'# The below DHW and AL average data come from the source files:',
					sprintf("%s%02u%s%03u%s", '# DHW: ', $ARGV[1], 'DHW', $DHW_use / 100, '.txt'),
					"# AL: can_gen_$AL_use.fcl",
					"# These were averaged to a timestep of $ARGV[3] seconds using BCD_DHW_AL_avg.pl"
					);
			}
			
			# add the data header and units information (use sprintf so columns appear for visual)
			elsif ($bcd[$line] =~ /^\*data_header/) {	# data header tag
				$bcd[$line] = sprintf ("%-15s %10s %10s", '*data_header', 'DHW', 'AL');
			}
			elsif ($bcd[$line] =~ /^\*data_units/) {	# data units tag
				$bcd[$line] = sprintf ("%-15s %10s %10s", '*data_units', 'L/h', 'W');
			}
			
			# This is the location to add the data
			elsif ($bcd[$line] =~ /^\*data_start/) {	# must apply the data
			
				# because we are filling from the start tag, we must decrement through the array from the end to the beginning
				my $data_line = $#{$DHW_avg->{$DHW_use}};	# we already checked that the arrays were the same length, so just use DHW length
				
				my $DHW_annual = 0;	# intialize annual storage variables for DHW and AL. DHW is Litres
				my $AL_annual = 0;	# AL is GJ
				
				while ($data_line >= 0) {	# as long as there is anything left in the array
					# space delimit the DHW and AL data
					splice (@bcd, $line + 1, 0,
						sprintf ("%-15s %10.2f %10.1f", '', $DHW_avg->{$DHW_use}->[$data_line], $AL_avg->{$AL_use}->[$data_line]),
						);
					# Accumulate the annual values
					$DHW_annual = $DHW_annual + $DHW_avg->{$DHW_use}->[$data_line] * $ARGV[3] / 60;	# Litres
					$AL_annual = $AL_annual + $AL_avg->{$AL_use}->[$data_line] * $ARGV[3] * 60 / 1e9;	# GJ
					
					$data_line--;	# decrement the counter so we head to zero
				};

			# print the annual values to the key with the appropriate heading
			printf ANNUAL ("%s,%s,%.0f,%.3f\n", '*data', 'DHW_' . $DHW_use . '_Lpd.AL_' . $AL_use . "_W.$ARGV[3]_min_avg_from_$ARGV[1]_min_src.bcd", $DHW_annual, $AL_annual);

			};
			$line++;	# increment the line number
		};
		
		# open a BCD file with appropriate name to store the bcd information
		my $file_name = "$ARGV[2]/DHW_" . $DHW_use . '_Lpd.AL_' . $AL_use . "_W.$ARGV[3]_min_avg_from_$ARGV[1]_min_src.bcd";
		open (BCD, '>', $file_name) or die ("can't open $file_name");	#open the BCD writeout file
		
		foreach my $line (@bcd) {
			print BCD "$line\n";	# printout all of the info
		};
	};
};

close ANNUAL;

print "COMPLETE\n";
