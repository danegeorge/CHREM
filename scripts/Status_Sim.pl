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
my $set_name; # Declare a variable to store the set name

# Determine possible set names by scanning the summary_files folder
my $possible_set_names = {map {$_, 1} grep(s/.+Sim_(.+)_Sim-Status.+/$1/, <../summary_files/*>)}; # Map to hash keys so there are no repeats
my @possible_set_names_print = @{&order($possible_set_names)}; # Order the names so we can print them out if an inappropriate value was supplied

# Verify the provided set_name
if (@ARGV == 1) { # A set_name was provided
	$set_name = shift(@ARGV); # Shift the set_name to the variable
	if (defined($possible_set_names->{$set_name})) { # Check to see if it is defined in the list
		$set_name =  '_' . $set_name; # Add and underscore to the start to support subsequent code
	}
	else { # An inappropriate set_name was provided so die and leave a message
		die "Set_name \"$set_name\" was not found\nPossible set_names are: @possible_set_names_print\n";
	};
}
else { # An inappropriate set_name was provided so die and leave a message
	die "Please supply a set_name\nPossible set_names are: @possible_set_names_print\n";
};

#--------------------------------------------------------------------
# Identify the simulating core files
#--------------------------------------------------------------------
my @files = <../summary_files/*>;	# Discover all of the file names in the summary_files directory
# print Dumper @files;

my $status = {}; # Declare a status holding hash ref


# Cycle over each file, read the ones that have sim status info, and store the important variables
foreach my $file (@files) {
	my $check = 'Sim' . $set_name . '_Sim-Status_Core-';
	# Check that the file is a status for a core (e.g. 1 or 16)
	if ($file =~ /$check(\d{1,2})/) {
		my $core = $1; # Store the core number
		open (my $FILE, '<', $file) or die ("can't open $file\n"); # Open the file
		
		# Cycle over each line of the file and read the information
		while (<$FILE>) {
			
			$status->{$core}->{'line'} = rm_EOL_and_trim($_); # Cleanup the line

			# Check to see if this is the line that holds the start or end model time in seconds (since 1970)
			if ($status->{$core}->{'line'} =~ /^\*(mdl_\w+_time),(\d+)$/) { # Look for the tag
				$status->{$core}->{$1} = $2; # Record the start_seconds
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
					if ($status->{$core}->{'sim_status'} eq 'OK') {
						@{$status->{$core}}{qw(sim_num total_sims)} = split(/\//, $status->{$core}->{'sim_numbers'}); # Split the house simulation number from the total number of simulations
					}
					
					# Otherwise the simulation was unsuccessful - so store the folder name
					else {
						push (@{$status->{$core}->{'bad_sims'}}, $status->{$core}->{'folder'} . ' - Incomplete Simulation'); # Push the folder name onto a storage array
					};
					
					if ($status->{$core}->{'bps_status'} =~ /- (Warnings.+)$/) {
						push (@{$status->{$core}->{'bad_sims'}}, $status->{$core}->{'folder'} . " - $1"); # Push the folder name onto a storage array
					};
				};
				# There is no need for an else here - if the number of data items is incorrect, then simply maintain the previous terms
			};
		};


		# Now that all of the houses have been examined - determine the simulation time estimates
		if ($status->{$core}->{'total_sims'}) { # Verify that there has been at least 1 simulation
			
			# Check to see if all simulations are done
			if ($status->{$core}->{'mdl_end_time'}) {
				# Calculate the avg simulation time using the model start/end time
				$status->{$core}->{'sim_avg_seconds'} = sprintf("%.0f", ($status->{$core}->{'mdl_end_time'} - $status->{$core}->{'mdl_start_time'}) / $status->{$core}->{'total_sims'});
			}
			# Otherwise we are still simulating, so use the most recent sim_end_time for avg and projections
			else {
				# Calculate the avg sim time from the most recent time of the last successful sim and the start time
				$status->{$core}->{'sim_avg_seconds'} = ($status->{$core}->{'sim_end_time'} - $status->{$core}->{'mdl_start_time'}) / $status->{$core}->{'sim_num'};
				# Calculate the expected model completion time from the last simulation end time and the avg time
				$status->{$core}->{'expected_mdl_end_time'} = sprintf("%.0f", $status->{$core}->{'sim_end_time'} + $status->{$core}->{'sim_avg_seconds'} * ($status->{$core}->{'total_sims'} - $status->{$core}->{'sim_num'}));
				# Format the avg simulation time, because we wanted to use floating point for above calculation accuracy
				$status->{$core}->{'sim_avg_seconds'} = sprintf("%.0f", $status->{$core}->{'sim_avg_seconds'});
				# Determine how long the ongoing simulation has taken. This may be used to identify stuck simulations
				$status->{$core}->{'present_sim_seconds'} = time - $status->{$core}->{'sim_end_time'};
			};
		};
	};
};
# Now the cores are all complete


# Report the information to the terminal
foreach my $core (@{&order($status)}) { # Order the cores numerically
	print "CORE $core\n"; # Identifier
	
	# Write out the progression, estimated completion, and bad simulation information
	if ($status->{$core}->{'total_sims'}) { # Verify that at least one simulation has been completed
		
		# Check to see if we are complete the simulations
		if ($status->{$core}->{'mdl_end_time'}) {
			print "\tBegan the model at: " . localtime($status->{$core}->{'mdl_start_time'}) . "\n"; # State the start time
			print "\tCompleted the model ($status->{$core}->{'total_sims'} simulations) at: " . localtime($status->{$core}->{'mdl_end_time'}) . "\n"; # State the completion time
			my $total_sim_hours = sprintf("%.1f", ($status->{$core}->{'mdl_end_time'} - $status->{$core}->{'mdl_start_time'}) / 3600); # Calculate the total model hours
			print "\tAverage seconds per simulation = $status->{$core}->{'sim_avg_seconds'}; Total modeling hours: $total_sim_hours\n"; # Report avg sim time and total model hours
		}
		
		# We are not complete all the simulations so report running avg and expected completion time
		else {
			print "\tRecent Status Line = $status->{$core}->{'line'}\n"; # The most recent status line to verify progression
			print "\tBegan the model at: " . localtime($status->{$core}->{'mdl_start_time'}) . "\n"; # State the start time
			# Progression and % of total - and the amount of time on the present simulation for identifying stuck sims
			print "\tStatus of simulations: $status->{$core}->{'sim_num'}/$status->{$core}->{'total_sims'} (" . sprintf("%.0f", $status->{$core}->{'sim_num'} / $status->{$core}->{'total_sims'} * 100) . "%) - present simulation has taken $status->{$core}->{'present_sim_seconds'} seconds so far\n";
			
			print "\tExpect to complete the model at: " . localtime($status->{$core}->{'expected_mdl_end_time'}) . "\n"; # Expected completion time
			my $accrued_sim_hours = sprintf("%.1f", (time - $status->{$core}->{'mdl_start_time'}) / 3600); # Calculate accrued model hours to this point
			my $total_sim_hours = sprintf("%.1f", ($status->{$core}->{'expected_mdl_end_time'} - $status->{$core}->{'mdl_start_time'}) / 3600); # Calculate total model hours
			print "\tAverage seconds per simulation = $status->{$core}->{'sim_avg_seconds'}; Accrued modeling hours: $accrued_sim_hours; Expected total modeling hours: $total_sim_hours\n"; # Report avg sim and accrued/expected-total model hours
		};
		
		# Check for and report on bad houses
		if (defined($status->{$core}->{'bad_sims'})) { # Verify there have been bad houses
			# Totalize the houses
			print "\tThere are " . @{$status->{$core}->{'bad_sims'}} . " BAD HOUSE(S)\n";
			# Cycle over the array and report the bad simulation folders
			foreach my $bad (@{$status->{$core}->{'bad_sims'}}) {
				print "\t\t$bad\n";
			};
		};
	}
	
	else {
		print "\tRecent Status Line = $status->{$core}->{'line'}\n"; # The most recent status line to verify progression
	};
};

