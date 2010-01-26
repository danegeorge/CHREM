#!/usr/bin/perl
# 
#====================================================================
# Core_Sim.pl
# Author:    Lukas Swan
# Date:      Aug 2008
# Copyright: Dalhousie University
#
# DESCRIPTION:
# This script is called from the simulation control script (Sim_Control_xx.pl).
# It reads the supplied core number arguement and opens the appropriate file 
# that lists the house directories to be simulated by that core.
# 
# The script determined the house name, changes directories to the appropriate 
# folder (to get RES and XML files right) and then simulates using bps and the 
# automation arguements.

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
use Cwd;		#(to determine current working directory)

use lib ('./modules');
use General;


#--------------------------------------------------------------------
# Read the input arguments to determine which set of houses to simulate
#--------------------------------------------------------------------
my $core = $ARGV[0]; #store the core input arguments
print "The ARGV says Core $core\n";


#--------------------------------------------------------------------
# Declare time and simulation count variables and open the appropriate file with the hse directories to be simulated
#--------------------------------------------------------------------
my $start_time= localtime(); # Note the start time of the file generation
my $simulations = 0; # Set a variable to count the simulations

my @folders; # Storage for the folders to be simulated

# Open and Read the Houses that will be simulated
{	
	my $file = "../summary_files/House_List_for_Core_$core"; # Name
	my $ext = '.csv'; # Extention
	open (my $FILE, '<', "$file$ext") or die ("can't open $file$ext\n"); # Open a readable file
	@folders = <$FILE>; # Slurp in the entire file (each line is an element in the array)
}

#--------------------------------------------------------------------
# Perform a simulation of each house in the directory list
#--------------------------------------------------------------------
SIMULATION: {

	# Begin a file to store the simulation status information
	my $file = "../summary_files/Simulation_Status_for_Core_$core"; # Name
	my $ext = '.txt'; # Extention
	open (my $FILE, '>', "$file$ext") or die ("can't open $file$ext\n"); # Open a writeable file
	
	# Print some status information at the top of the file
	print $FILE CSVjoin('*start_seconds', time) . "\n";
	print $FILE CSVjoin('*header', qw(folder ish bps ok_bad number)) . "\n";

	# Declarations to hold house information
	my @good_houses; # Array to hold the directories of the good houses
	my @bad_houses; # Array to hold the directories of the bad houses
	my $house_count = 0; # Index of houses so we know how far along we are

	# The HOUSE LOOP for simulation
	HOUSE: foreach  my $folder (@folders) { # Do until the house list is exhausted
		print $FILE '*data,'; # Start storage of the simulation status for this house
		$house_count++; # Increment the house counter
		
		# Folder information
		$folder = rm_EOL_and_trim($folder); # Clean up the folder name
		print $FILE "$folder,"; # Write the folder name to the status
		chdir ($folder); # Change to the appropriate directory for simulation. Sim has to be in directory for xml output

		# House name and CFG file to determine ish zones
		my ($house_name) = ($folder =~ /^.+(\w{10})(\/$|$)/); # Determine the house name which is the last 10 digits (note that a check is done for an extra slash)
		my $cfg = "./$house_name.cfg";
		open (my $CFG, '<', $cfg) or die ("\n\nERROR: can't open $cfg\n");	#open the cfg file to check for isi
		
		# Being ish efforts by deleting any existing files
		print $FILE "ish "; # Denote that ish is about to begin
		unlink "./$house_name.ish"; # Unlink (delete) the previous ish file that held any ish output

		# Cycle over the CFG file and look for *isi tags - the perform shading analysis ish on this zone(s)
		while (<$CFG>) {
			my $line = rm_EOL_and_trim($_); # Clean it up
			if ($line =~ /^\*isi \.\/\w+\.(\w+)\.shd$/) { # Find the *isi tag and identify the zone
				system ("ish -mode text -file $cfg -zone $1 -act update_silent >> ./$house_name.ish");	# call the ish shading and insolation analyzer with variables to automate the analysis. Note that ">>" is used so as to append each zone in the log file
			};
		};
		close $CFG; # We are done with the CFG file
		
		# Begin the bps simulation by deleting any existing files
		print $FILE "- Complete,bps "; # Denote that ish is complete and that bps is about to begin
		unlink "./$house_name.bps"; # Unlink (delete) the previous bps file that held any bps output
		system ("bps -mode text -file $cfg -p sim_presets silent >> ./$house_name.bps");	#call the bps simulator with arguements to automate it
		print $FILE "- Complete,"; # Denote that bps is complete

		# Rename the XML reporting files with the house name. If this is true then it may be treated as a proxy for a successful simulation
		if (rename ("out.dictionary", "$house_name.dictionary")) { # If this is true then the simulation was successful (for the most part this is true)
			print $FILE "OK,"; # Denote that the simulation is OK
			push (@good_houses, $folder); # Store the folder as a good house
			print $FILE $house_count . '/' . @folders . "\n"; # Denote which house this was and of how many
			
			# Cycle over other common XML reporting files and rename these
			foreach my $ext ('csv', 'summary', 'xml') {
				rename ("out.$ext", "$house_name.$ext");
			};
		}
		
		# The simulation was not successful
		else {
			print $FILE "BAD,"; # Denote that the simulation was BAD
			push (@bad_houses, $folder); # Store the folder as a bas house
			print $FILE @bad_houses . "\n"; # Denote how many houses have been bad up to this point
			
			# Because the simulation was unsuccessful - return to the original directory and jump up to the next house
			chdir ("../../../scripts"); # Return to the original working directory
			next HOUSE; # Jump to the next house
		}


		my $file = "./$house_name.summary";
		
		if (open (SUMMARY, '<', $file)) {     #open the summary file to reorder it
			my $results;
			while (<SUMMARY>) {
			# Lukas/zone_01/active_cool::Total_Average -311.102339 (W)
			# Lukas/MCOM::Minimum 28.000000 (#)
			#       if ($_ =~ /(.*)::(\w*)\s*(\w*\.\w*)\s*(\(.*\))/) {
				my @split = split (/::|\s/, $_);
				$results->{$split[0]}->{$split[1]} = [$split[2], $split[3]];
			# 	};
			};
			close SUMMARY;
	# 		print Dumper ($results);
		};

		$file = "./$house_name.dictionary";
		if (open (DICTIONARY, '<', $file)) {     #open the dictionary file to cross reference
			my $results;
			my $parameter;
			while (<DICTIONARY>) {
			# "Lukas/zone_01/active_cool","active cooling required by zone","(W)"
				$_ =~ /"(.*)","(.*)","(.*)"/;
				$parameter->{$1}->{'description'} = $2;
				$parameter->{$1}->{'units'} = $3;
			};
			# print Dumper ($parameter);
			close DICTIONARY;
			
			$file = "./$house_name.results";
			open (RESULTS, '>', $file) or die ("can't open $file\n");     #open the a results file to write out the organized summary results
			printf RESULTS ("%10s %10s %10s %10s %10s %10s %10s %-50s %-s\n", 'Integrated', 'Int units', 'Total Avg', 'Active avg', 'Min', 'Max', 'Units', 'Name', 'Description');

			my @keys = sort keys (%{$results});  # sort results
			my @values = ('AnnualTotal', 'Total_Average', 'Active_Average', 'Minimum', 'Maximum');
			foreach my $key (@keys) {
				foreach (@values) {unless (defined ($results->{$key}->{$_})) {$results->{$key}->{$_} = ['0', '-']};};
				printf RESULTS ("%10.2f %10s %10.2f %10.2f %10.2f %10.2f %10s %-50s %-s\n",
					$results->{$key}->{$values[0]}->[0],
					$results->{$key}->{$values[0]}->[1],
					$results->{$key}->{$values[1]}->[0],
					$results->{$key}->{$values[2]}->[0],
					$results->{$key}->{$values[3]}->[0],
					$results->{$key}->{$values[4]}->[0],
					$results->{$key}->{$values[4]}->[1],
					$key,
					$parameter->{$key}->{'description'});
			};
			close RESULTS;
			
		};


            
		chdir ("../../../scripts");	#return to the original working directory
		$simulations++;			#increment the simulations counter
	}	#end of the while loop through the simulations
	
	# Print some status information at the top of the file
	print $FILE CSVjoin('*end_seconds', time) . "\n";
};

#--------------------------------------------------------------------
# Do a final print of the times and simulations (discover using "tail" command on ../summary_files/sim_output_core_X.txt)
#--------------------------------------------------------------------
my $end_time= localtime();
print "\n\nstart time $start_time; end time $end_time; $simulations simulations\n";