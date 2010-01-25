#!/usr/bin/perl
# 
#====================================================================
# Sim_Control.pl
# Author:    Lukas Swan
# Date:      Jan 2010
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl
#
# DESCRIPTION:
# This script checks the status of the simulations


#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;

#use CSV;		#CSV-2 (for CSV split and join, this works best)
#use Array::Compare;	#Array-Compare-1.15
#use Switch;
#use threads;		#threads-1.71 (to multithread the program)
#use File::Path;	#File-Path-2.04 (to create directory trees)
#use File::Copy;	#(to copy the input.xml file)
use Data::Dumper;

use lib ('./modules');
use General;

$Data::Dumper::Sortkeys = \&order;

#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------

#--------------------------------------------------------------------
# Identify the simulating core files
#--------------------------------------------------------------------
my @files = <../summary_files/*>;	# discover all of the simulation status files
# print Dumper @files;

my $status = {};

foreach my $file (@files) {
	if ($file =~ /..\/summary_files\/Simulation_Status_for_Core_(\d{1,2})\.txt/) {
		my $core = $1;
		open (SIM_STATUS, '<', $file) or die ("can't open $file\n");	#open the file
		
		while (<SIM_STATUS>) {
			my $line = rm_EOL_and_trim($_);
# 			print "LINE $line\n";
	# 		Folder ../2-DR/1-AT/11DDA00082; ish - Complete; bps - Complete; OK; 1 of 2
			@{$status->{$core}}{qw(folder ish bps ok_bad number)} = split(/;/, $line);
			
			if ($status->{$core}->{'number'}) {
				
				foreach my $key (keys(%{$status->{$core}})) {
					$status->{$core}->{$key} = rm_EOL_and_trim($status->{$core}->{$key});
				};
	# 			print Dumper $status;
				if ($status->{$core}->{'ok_bad'} eq 'OK') {
					@{$status->{$core}}{qw(file total)} = split(/\//, $status->{$core}->{'number'});
	# 				print Dumper $status;
				}
				else {
					$status->{$core}->{'folder'} =~ /Folder (.+)/;
					push (@{$status->{$core}->{'bad'}}, $1);
				};
			};
		};
	};
};

foreach my $core (@{&order($status)}) {
	print "CORE $core\n";
	if ($status->{$core}->{'total'}) {
		print "\tFile $status->{$core}->{'file'}/$status->{$core}->{'total'} (" . sprintf("%.0f", $status->{$core}->{'file'} / $status->{$core}->{'total'} * 100) . "%)\n";
		if (defined($status->{$core}->{'bad'})) {
			print "\tThere are " . @{$status->{$core}->{'bad'}} . " BAD house(s)\n";
			foreach my $bad (@{$status->{$core}->{'bad'}}) {
				print "\t\t$bad\n";
			};
		};
	};
};

