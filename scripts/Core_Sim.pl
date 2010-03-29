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
use Data::Dumper;
use XML::Simple;	# to parse the XML
use Storable  qw(dclone);

use lib ('./modules');
use General;

$Data::Dumper::Sortkeys = \&order;

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
	print $FILE CSVjoin('*mdl_start_time', time) . "\n"; # Model start time
	print $FILE CSVjoin('*header', qw(folder ish_status bps_status sim_status sim_numbers sim_end_time)) . "\n"; # Header for the data fields

	# Declarations to hold house information
	my @good_houses; # Array to hold the directories of the good houses
	my @bad_houses; # Array to hold the directories of the bad houses
	my $house_count = 0; # Index of houses so we know how far along we are

	# The HOUSE LOOP for simulation
	HOUSE: foreach  my $folder (@folders) { # Do until the house list is exhausted
		print $FILE "*data,"; # Start storage of the simulation status for this house
		$house_count++; # Increment the house counter
		
		# Folder information
		$folder = rm_EOL_and_trim($folder); # Clean up the folder name
		print $FILE "$folder,"; # Write the folder name to the status
		chdir ($folder); # Change to the appropriate directory for simulation. Sim has to be in directory for xml output

		# House name and CFG file to determine ish zones
		my ($hse_type, $region, $house_name) = ($folder =~ /^\.\.\/(.+)\/(.+)\/(\w+)(\/$|$)/); # Determine the house name which is the last 10 digits (note that a check is done for an extra slash)
		my $coordinates = {'hse_type' => $hse_type, 'region' => $region, 'file_name' => $house_name};
		
		my $cfg = "./$house_name.cfg";

		
		# Begin ish efforts by deleting any existing files
		print $FILE "ish "; # Denote that ish is about to begin
		unlink "./$house_name.ish"; # Unlink (delete) the previous ish file that held any ish output

		open (my $CFG, '<', $cfg) or die ("\n\nERROR: can't open $cfg\n"); # Open the cfg file to check for isi
		my @cfg;
		while (<$CFG>) {
			push(@cfg,&rm_EOL_and_trim($_));
		};
		close $CFG; # We are done with the CFG file
		
		# Cycle over the CFG file using the grep command and look for *isi tags - when one is found, store the zone name
		my @isi_zones = grep (s/^\*isi \.\/\w+\.(bsmt|main_\d)\.shd$/$1/, @cfg);
		
		# Cycle over the isi zones and do the ish shading analysis on that zone
		foreach my $isi_zone (@isi_zones) {
			system ("ish -mode text -file $cfg -zone $isi_zone -act update_silent >> ./$house_name.ish");	# call the ish shading and insolation analyzer with variables to automate the analysis. Note that ">>" is used so as to append each zone in the log file
		};


		
		# Begin the bps simulation by deleting any existing files
		print $FILE "- Complete,bps "; # Denote that ish is complete and that bps is about to begin
		unlink "./$house_name.bps"; # Unlink (delete) the previous bps file that held any bps output
		system ("bps -mode text -file $cfg -p sim_presets silent >> ./$house_name.bps");	#call the bps simulator with arguements to automate it
		

		
		# Check the bps file for any errors
		my $bps = "./$house_name.bps";
		open (my $BPS, '<', $bps) or die ("\n\nERROR: can't open $bps\n");	# Open the bps file to check for errors

		my $warnings = {}; # Storage for the warnings
		my $previous = ''; # Recall the previous line so we know if we are in the timestepping or not
		
		# Cycle over the bps file lines
		foreach my $line (&rm_EOL_and_trim(<$BPS>)) {
		
			# Check to see if there are any startup file scan warnings
			if ($line =~ /^No\. of warnings\s+:\s+(\d+)$/) { # Remember how many there are
				foreach my $warning (1..$1) { # Cycle over the number of warnings and store in an array - this is to be functional with the method below for other warning types
					push(@{$warnings->{'Startup_Scan'}}, 1);
				};
			}
			# Check to see if we are in the timestep area. If we are then the only allowable line types are those that start with a percentage complete. Everything else is an error. Also check for WARNING, ERROR, etc. in lines.
			elsif ($previous =~ /^Simulation has now commenced|^\d+ %\s+complete/ && $line !~ /^\d+ %\s+complete|^Simulation cpu runtime/ || $line =~ /WARNING|ERROR|FAILURE/i) {
				my $warning = $line; # A new copy for use below
				$warning =~ s/^(.{7}).+$/$1/; # Only store the first 7 digits to keep the warning short and to cover repeats
				push(@{$warnings->{$warning}}, $line); # Push the complete line into the storage at the warning point based on the 7 digits. This is so MZELWE warning will only have 1 key, but will show up the number of times it was warned and perhaps later we could use it to look up what the values were.
			}
			# Otherwise just store the line
			else {$previous = $line};
		};
# 		print Dumper $warnings;

		close $BPS; # We are done with the CFG file
		
		# If there are no warnings, then say complete
		if (keys %{$warnings} == 0) {
			print $FILE "- Complete,"; # Denote that bps is complete
		}
		# If there are warning, then cycle over them, and print 
		else {
			print $FILE "- Warnings";
			foreach my $key (@{&order($warnings)}) { # Cycle over the warnings
				print $FILE ":'$key'=" . @{$warnings->{$key}}; # Print out the start of the warning and the number of times it was encountered
			};
			print $FILE ",";
		}; # Denote that bps has errors

		# Rename the XML reporting files with the house name. If this is true then it may be treated as a proxy for a successful simulation
		if (rename ("out.dictionary", "$house_name.dictionary")) { # If this is true then the simulation was successful (for the most part this is true)
			print $FILE "OK,"; # Denote that the simulation is OK
			push (@good_houses, $folder); # Store the folder as a good house
			print $FILE $house_count . '/' . @folders . ','; # Denote which house this was and of how many
			
			# Cycle over other common XML reporting files and rename these
			foreach my $ext ('csv', 'summary', 'xml') {
				rename ("out.$ext", "$house_name.$ext");
			};
		}
		
		# The simulation was not successful
		else {
			print $FILE "BAD,"; # Denote that the simulation was BAD
			push (@bad_houses, $folder); # Store the folder as a bas house
			print $FILE @bad_houses . ','; # Denote how many houses have been bad up to this point
			
			# Because the simulation was unsuccessful - return to the original directory and jump up to the next house
			chdir ("../../../scripts"); # Return to the original working directory
			next HOUSE; # Jump to the next house
		}

		# Examine the cfg file and create a key of zone numbers to zone names
		my @zones = grep (s/^\*geo \.\/\w+\.(\w+)\.geo$/$1/, @cfg); # Find all *.geo files and filter the zone name from it
		my $zone_name; # Intialize a storage of zone name value at zone number key
		foreach my $element (0..$#zones) { # Cycle over the array of zones by element number so it can be used
			$zone_name->{$element + 1} = $zones[$element]; # key = index + 1, value is zone name
		};
		
# 		print Dumper $zone_name;
		
		# Examine the cfg file and find the line containing the simulation presets, store the start month number so that it may be used as a key for the xml month reporting.
		my @month = grep (s/^(\d{1,2}) (\d{1,2}) (\d{1,2}) (\d{1,2}) sim_presets$/$2/, @cfg);

		# Read in the xml log file
		my $file = "./$house_name.xml";
		my $summary = XMLin($file);
		
		# Remove the 'parameter' field
		$summary = $summary->{'parameter'};
		
# 		print Dumper $summary;
		
		# Create a month index hash which uses the month index as keys and the month name as values
		my $index_month;
		@{$index_month}{1..12} = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec); # Hash slice
		
		# Cycle over the entire summary xml file and reorder it for ease of access
		foreach my $key (keys %{$summary}) {
			# Strip the units value of brackets and store it as 'normal' units
			my ($unit) = ($summary->{$key}->{'units'} =~ /\((.+)\)/);
			$summary->{$key}->{'units'} = {'normal' => $unit};
			
			# Cycle over the binned_data (by month and annual) and relocate the data up the tree
			foreach my $element (@{$summary->{$key}->{'binned_data'}}) {
				my $period; # Define a period variable
				if ($element->{'type'} eq 'annual') { # If the type is annual
					$period = 'Period'; # Store the period
					delete $element->{'type'}; # Delete the redundant information
				}
				elsif ($element->{'type'} eq 'monthly') { # Elsif the type is monthly
					$period = $index_month->{$element->{'index'} + $month[0]}; # Store the period by month index, but add in the start month index as it may not be January
					delete @{$element}{'type', 'index'}; # Delete the redundant information
				}
				else { # Report if the type is unknown
					&die_msg("Bad XML reporting binned data type in $file: should be 'annual' or 'monthly'", $element->{'type'}, $coordinates);
				};
				# Save the information up the tree by cloning the remainder of the element to that period
				$summary->{$key}->{$period} = dclone($element);
			};
			# Delete the redundant information
			delete $summary->{$key}->{'binned_data'};
			
			# Cycle over the integrated data
			foreach my $element (@{$summary->{$key}->{'integrated_data'}->{'bin'}}) {
				my $period; # Define a period variable
				if ($element->{'type'} eq 'annual') { # If the type is annual
					$period = 'Period'; # Store the period
				}
				elsif ($element->{'type'} eq 'monthly') { # Elsif the type is monthly
					$period = $index_month->{$element->{'number'} + $month[0]}; # Store the period by month index, but add in the start month index as it may not be January
				}
				else { # Report if the type is unknown
					&die_msg("Bad XML reporting integrated data bin type in $file: should be 'annual' or 'monthly'", $element->{'type'}, $coordinates);
				};
				# Save the information (integrated value) up the tree under a key of 'integrated'
				$summary->{$key}->{$period}->{'integrated'} = $element->{'content'};
			};
			# Also store the integrated units type
			($summary->{$key}->{'units'}->{'integrated'}) = $summary->{$key}->{'integrated_data'}->{'units'};
			# Delete the redundant information
			delete $summary->{$key}->{'integrated_data'};
		};
		
# 		print Dumper $summary;
		
		# Create an energy results hash reference to store accumulated data
		my $en_results;
		# The data will be sorted into a columnar printout, so store the width of the first column based on its header
		$en_results->{'columns'}->{'variable'} = length('Energy (kWh)');
		
		# Cycle over the entire summary hash and summarize the control volume energy results
		foreach my $key (keys %{$summary}) {
			# Only summarize for energy balance based on zone information and a power type
			if ($key =~ /^CHREM\/zone_0(\d)\/Power\/(.+)$/) {
				my $zone_name2 = $zone_name->{$1}; # Store the zone name
				my $variable = $2; # Store the variable name
				
				# Check the length of the variable and if it is longer, set the column to that width
				if (length($variable) > $en_results->{'columns'}->{'variable'}) {
					$en_results->{'columns'}->{'variable'} = length($variable);
				};
				
				# Check to see if a column has been generated for this zone. If not then set it equal to the zone name length + 2 for spacing
				unless (defined($en_results->{'columns'}->{$zone_name2})) {
					$en_results->{'columns'}->{$zone_name2} = length($zone_name2) + 2;
				};
				
				# Declare a type for sorting the results. Usually, a 1st law energy balance is DeltaE = Q - W.
				# Because the DeltaE is likely to be little, we will show in vertical columns Q, then DeltaE
				my $type;
				if ($variable =~ /^(SH|LH)/) {$type = 'storage';}
				elsif ($variable =~ /Opaq/) {$type = 'opaque';}
				elsif ($variable =~ /Tran/) {$type = 'transparent';}
				else {$type = 'air point'};

				# Store the resulting information. Convert from GJ to kWh and format so the sign is always shown
				if ($summary->{$key}->{'units'}->{'integrated'} eq 'GJ') {
					$en_results->{$type}->{$variable}->{$zone_name2} = sprintf("%+.0f", $summary->{$key}->{'Period'}->{'integrated'} * 277.78);
				}
				else {&die_msg("Bad integrated data units for energy balance: should be 'GJ'", $summary->{$key}->{'units'}->{'integrated'}, $coordinates);};

				# NOTE: Because interior convection with reference to the node is opposite our control volume, it needs a sign reversal
# 				if ($variable =~ /^CV/) {
# 					$en_results->{$type}->{$variable}->{$zone_name2} = sprintf("%+.0f", -$en_results->{$type}->{$variable}->{$zone_name2});
# 				};

				# Compare the length of this value to the column size and modify if necessary
				if (length($en_results->{$type}->{$variable}->{$zone_name2}) > $en_results->{'columns'}->{$zone_name2}) {
					$en_results->{'columns'}->{$zone_name2} = length($en_results->{$type}->{$variable}->{$zone_name2}) + 2;
				};
			};
		};
		
# 		print Dumper $en_results;
		
		# Create a results file
		$file = "./$house_name.energy_balance";
		open (my $PERIOD, '>', $file);
		
		# Print the first column name of the header row, using the width specifified and a format involving a vertical bar afterwards
		printf $PERIOD ("%-$en_results->{'columns'}->{'variable'}s |", 'Energy (kWh)');
		
		# Select the printout orders
		my $print->{'zones'} = &order($en_results->{'columns'}, [qw(main bsmt crawl attic roof)], ['']); # Only print desired zones
		$print->{'type'} = [qw(opaque transparent), 'air point', qw(storage)]; # Print the following energy types
		# The following three lines control the types of fluxes to be output
		$print->{'opaque'} = &order($en_results->{'opaque'}, [qw(CD SW LW)], ['']); # CD CV SW LW
		$print->{'transparent'} = &order($en_results->{'transparent'}, [qw(CD SW LW)], ['']); # CD CV SW LW
		$print->{'air point'} = &order($en_results->{'air point'}, [qw(AV GN)], ['']); #AV GN
		$print->{'storage'} = &order($en_results->{'storage'}, [qw(SH LH)], []); # SH LH
		
		# Print the zone names for each column using the width information and a double space afterwards
		foreach my $zone (@{$print->{'zones'}}) {
			printf $PERIOD ("%$en_results->{'columns'}->{$zone}s", $zone);
		};

		# Declare a sum so that we can print the summations and energy balance info
		my $sum;

		# Cycle over the desired energy types
		foreach my $type (@{$print->{'type'}}) {

			# This is not expected to be tripped until the fluxes have been determined
			# The following cycles back through the previous types (e.g. opaque, transparent, and air point) to sum them all up. It is expected that individually their sums will be non-zero, but together they will be close to zero and balance the upcoming storage values
			if ($type eq 'storage') {
				# Print header info
				print $PERIOD ("\n\n--" . 'SUMMATION OF PREVIOUS FLUXES' . "--\n");
				printf $PERIOD ("%-$en_results->{'columns'}->{'variable'}s |", '++SUM++');
				# Cycle over the zones
				foreach my $zone (@{$print->{'zones'}}) {
					my $sum2 = 0; # Create a second summation
					foreach my $type2 (keys(%{$sum->{$zone}})) { # Cycle over all the previously calculated types
						$sum2 = sprintf("%+.0f", $sum2 + $sum->{$zone}->{$type2}); # Add them together
					};
					# Finally print out the formatted total within the column
					printf $PERIOD ("%$en_results->{'columns'}->{$zone}s", $sum2);
				};
			};
			
			# Print a header line for indication of this flux type
			print $PERIOD ("\n\n--" . uc($type) . "--\n");
			
			# Cycle over each matching  variable
			foreach my $variable (@{$print->{$type}}) {
				# Print the variable information
				printf $PERIOD ("%-$en_results->{'columns'}->{'variable'}s |", $variable);
				# Cycle over the zones
				foreach my $zone (@{$print->{'zones'}}) {
					# Initialize the summation of this energy flux type
					unless (defined($sum->{$zone}->{$type})) {
						$sum->{$zone}->{$type} = 0;
					};
					# Print the  formatted value
					printf $PERIOD ("%$en_results->{'columns'}->{$zone}s", $en_results->{$type}->{$variable}->{$zone});
					# Add it to the summation
					$sum->{$zone}->{$type} = sprintf("%  +.0f", $sum->{$zone}->{$type} + $en_results->{$type}->{$variable}->{$zone});
				};
				print $PERIOD ("\n"); # Because we are columnar information we have multiple zones and when complete print an end of line
			};
			
			# Print the sum for this type of energy flux (e.g. opaque)
			printf $PERIOD ("%-$en_results->{'columns'}->{'variable'}s |", '++SUM++');
			# Cycle over the zones and print the sum
			foreach my $zone (@{$print->{'zones'}}) {
				printf $PERIOD ("%$en_results->{'columns'}->{$zone}s", $sum->{$zone}->{$type});
			};
		};
		# Close up the file
		close $PERIOD;

		# Print the simulation time for this house (seconds since 1970)
		print $FILE time . "\n";

            
		chdir ("../../../scripts");	#return to the original working directory
		$simulations++;			#increment the simulations counter
	}	#end of the while loop through the simulations
	
	# Print some status information at the top of the file
	print $FILE CSVjoin('*mdl_end_time', time) . "\n";
};

#--------------------------------------------------------------------
# Do a final print of the times and simulations (discover using "tail" command on ../summary_files/sim_output_core_X.txt)
#--------------------------------------------------------------------
my $end_time= localtime();
print "\n\nstart time $start_time; end time $end_time; $simulations simulations\n";