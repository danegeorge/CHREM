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

use CSV;		#CSV-2 (for CSV split and join, this works best)
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
my @files = <../summary_files/*>;	# Discover all of the file names in the summary_files directory
# print Dumper @files;

my $status = {}; # Declare a status holding hash ref


# Cycle over each file, read the ones that have sim status info, and store the important variables
foreach my $file (@files) {

	# Check that the file is a status for a core (e.g. 1 or 16)
	if ($file =~ /..\/summary_files\/Simulation_Status_for_Core_(\d{1,2})\.txt/) {
		my $core = $1; # Store the core number
		open (my $FILE, '<', $file) or die ("can't open $file\n"); # Open the file
		
		# Cycle over each line of the file and read the information
		while (<$FILE>) {
			
			$status->{$core}->{'line'} = rm_EOL_and_trim($_); # Cleanup the line

			# Check to see if this is the line that holds the time all simulations of this core started in seconds (since 1970)
			if ($status->{$core}->{'line'} =~ /^\*start_seconds,(\d+)$/) { # Look for the tag
				$status->{$core}->{'start_seconds'} = $1; # Record the start_seconds
			}
			
			# Check to see if this is the line that holds the time all simulations of this core ended in seconds (since 1970)
			elsif ($status->{$core}->{'line'} =~ /^\*end_seconds,(\d+)$/) { # Look for the tag
				$status->{$core}->{'end_seconds'} = $1; # Record the end_seconds
			}
			
			# Store the header information
			elsif ($status->{$core}->{'line'} =~ /^\*header,(.+)$/) { # Look for the tag
				$status->{$core}->{'header'} = [CSVsplit($1)]; # Store the header fields
			}
			
			# Find a *data tag
			elsif ($status->{$core}->{'line'} =~ /^\*data,(.+)$/) { # Look for the tag
				
				# Carefully examine the number of data items and make sure it is a full set equal to header items
				if (CSVsplit($1) == @{$status->{$core}->{'header'}}) {
					# The number of items is the same - so store this information
					@{$status->{$core}}{@{$status->{$core}->{'header'}}} = CSVsplit($1);
					
					# Cycle over the data items and clean them up
					foreach my $key (@{$status->{$core}->{'header'}}) {
						$status->{$core}->{$key} = rm_EOL_and_trim($status->{$core}->{$key});
					};

					# Check to see if the simulation was OK - if it was then store the progress and total number of simulations
					if ($status->{$core}->{'ok_bad'} eq 'OK') {
						@{$status->{$core}}{qw(file total)} = split(/\//, $status->{$core}->{'number'}); # Split the house simulation number from the total number of simulations
					}
					
					# Otherwise the simulation was unsuccessful - so store the folder name
					else {
						push (@{$status->{$core}->{'bad'}}, $status->{$core}->{'folder'}); # Push the folder name onto a storage array
					};
				};
				# There is no need for an else here - if the number of data items is incorrect, then simply maintain the previous terms
			};
		};


		# Now that all of the houses have been examined - determine the simulation time estimates
		if ($status->{$core}->{'total'}) { # Verify that there has been at least 1 simulation
			
			# Check to see if all simulations are done - if they are then set present seconds equal to the end seconds so that the avg and remaining are based on the completion time and not the present time
			if ($status->{$core}->{'end_seconds'}) {
				$status->{$core}->{'present_seconds'} = $status->{$core}->{'end_seconds'};
			}
			# Otherwise we are not done, so use this present time for avg and projections
			else {
				$status->{$core}->{'present_seconds'} = time; # Store the present seconds (since 1970)
			};
			
			
			# Calculate the avg simulation seconds by subtracting the difference in time and dividing by the number of completed simulations. Note this is left in floating point form for accuracy in the subsequent completion calculation
			$status->{$core}->{'avg_sim_seconds'} = ($status->{$core}->{'present_seconds'} - $status->{$core}->{'start_seconds'}) / $status->{$core}->{'file'};
			# Estimate the finish seconds by multiplying the remaining houses for simulation by the avg simulation time. Note this is formatted to the nearest second.
			$status->{$core}->{'finish_seconds'} = sprintf("%.0f", $status->{$core}->{'present_seconds'} + $status->{$core}->{'avg_sim_seconds'} * ($status->{$core}->{'total'} - $status->{$core}->{'file'}));
			# Format the avg simulation time
			$status->{$core}->{'avg_sim_seconds'} = sprintf("%.1f", $status->{$core}->{'avg_sim_seconds'});
			# Calculate the finish date in string format (e.g. Wed Jan 21 2010 14:45:59
			$status->{$core}->{'finish_date_time'} = localtime($status->{$core}->{'finish_seconds'});
		};
	};
};
# Now the cores are all complete


# Report the information to the terminal
foreach my $core (@{&order($status)}) { # Order the cores numerically
	print "CORE $core\n"; # Identifier
	print "\tRecent Status Line = $status->{$core}->{'line'}\n"; # The most recent status line to verify progression
	
	# Write out the progression, estimated completion, and bad simulation information
	if ($status->{$core}->{'total'}) { # Verify that at least one simulation has been completed
		# Progression and % of total
		print "\tFile $status->{$core}->{'file'}/$status->{$core}->{'total'} (" . sprintf("%.0f", $status->{$core}->{'file'} / $status->{$core}->{'total'} * 100) . "%)\n";
		
		# Calculate the accrued and total simulation hours
		my $accrued_sim_hours = sprintf("%.1f", ($status->{$core}->{'present_seconds'} - $status->{$core}->{'start_seconds'}) / 3600); # Accrued hours to this point
		my $total_sim_hours = sprintf("%.1f", ($status->{$core}->{'finish_seconds'} - $status->{$core}->{'start_seconds'}) / 3600); # Total (expected) simulation hours
		
		# Check to see if we are complete the simulations
		if ($status->{$core}->{'end_seconds'}) {
			print "\tCompleted all simulations at: $status->{$core}->{'finish_date_time'}\n"; # State the completion time
			print "\tAverage seconds per simulation = $status->{$core}->{'avg_sim_seconds'}; Total simulation hours: $total_sim_hours\n"; # Report avg sim and total hours
		}
		# We are not complete so report running avg and expected completion time
		else {
			print "\tExpect to complete simulations at: $status->{$core}->{'finish_date_time'}\n"; # Expected completion time
			print "\tAverage seconds per simulation = $status->{$core}->{'avg_sim_seconds'}; Accrued sim hours: $accrued_sim_hours; Expected total sim hours: $total_sim_hours\n"; # Report avg sim and accrued/expected-total sim hours
		};
		
		# Check for and report on bad houses
		if (defined($status->{$core}->{'bad'})) { # Verify there have been bad houses
			# Totalize the houses
			print "\tThere are " . @{$status->{$core}->{'bad'}} . " BAD house(s)\n";
			# Cycle over the array and report the bad simulation folders
			foreach my $bad (@{$status->{$core}->{'bad'}}) {
				print "\t\t$bad\n";
			};
		};
	};
};

