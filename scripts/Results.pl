#!/usr/bin/perl
# 
#====================================================================
# Results2.pl
# Author:    Lukas Swan
# Date:      Apr 2010
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all]
#
# DESCRIPTION:
# This script aquires results


#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;

use CSV; #CSV-2 (for CSV split and join, this works best)
#use Array::Compare; #Array-Compare-1.15
#use Switch;
use XML::Simple; # to parse the XML results files
use threads; #threads-1.71 (to multithread the program)
#use File::Path; #File-Path-2.04 (to create directory trees)
#use File::Copy; #(to copy files)
use Data::Dumper; # For debugging
use Storable  qw(dclone); # To create copies of arrays so that grep can do find/replace without affecting the original data
use Hash::Merge qw(merge); # To merge the results data

# CHREM modules
use lib ('./modules');
use General; # Access to general CHREM items (input and ordering)
use Results; # Subroutines for results accumulations

# Set Data Dumper to report in an ordered fashion
$Data::Dumper::Sortkeys = \&order;

#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------
my $hse_types; # declare an hash array to store the house types to be modeled (e.g. 1 -> 1-SD)
my $regions; # declare an hash array to store the regions to be modeled (e.g. 1 -> 1-AT)
my $cores; # store the input core info
my @houses_desired; # declare an array to store the house names or part of to look

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if (@ARGV < 3) {die "A minimum Three arguments are required: house_types regions core_information [house names]\n";};
	
	# Pass the input arguments of desired house types and regions to setup the $hse_types and $regions hash references
	($hse_types, $regions) = &hse_types_and_regions(shift (@ARGV), shift (@ARGV));

	# Check the cores arguement which should be three numeric values seperated by a forward-slash
	unless (shift(@ARGV) =~ /^([1-9]?[0-9])\/([1-9]?[0-9])\/([1-9]?[0-9])$/) {
		die ("CORE argument requires three Positive numeric values seperated by a \"/\": #_of_cores/low_core_#/high_core_#\n");
	};
	
	# set the core information
	# 'num' is total number of cores (if only using a single QC (quad-core) then 8, if using two QCs then 16
	# 'low' is starting core, if using two QCs then the first QC has a 1 and the second QC has a 9
	# 'high' is ending core, value is 8 or 16 depending on machine
	@{$cores}{'num', 'low', 'high'} = ($1, $2, $3);
	
	# check the core infomration for validity
	unless (
		$cores->{'num'} >= 1 &&
		($cores->{'high'} - $cores->{'low'}) >= 0 &&
		($cores->{'high'} - $cores->{'low'}) <= $cores->{'num'} &&
		$cores->{'low'} >= 1 &&
		$cores->{'high'} <= $cores->{'num'}
		) {
		die ("CORE argument numeric values are inappropriate (e.g. high_core > #_of_cores)\n");
	};

	# Provide support to only simulate some houses
	@houses_desired = @ARGV;
	# In case no houses were provided, match everything
	if (@houses_desired == 0) {@houses_desired = '.'};
	
	my $localtime = localtime(time);
	print "Start Time: $localtime\n";
};

#--------------------------------------------------------------------
# Identify the house folders for results aquisition
#--------------------------------------------------------------------
my @folders;	#declare an array to store the path to each hse which will be simulated

foreach my $hse_type (&array_order(values %{$hse_types})) {		#each house type
	foreach my $region (&array_order(values %{$regions})) {		#each region
		push (my @dirs, <../$hse_type/$region/*>);	#read all hse directories and store them in the array
# 		print Dumper @dirs;
		CHECK_FOLDER: foreach my $dir (@dirs) {
			# cycle through the desired house names to see if this house matches. If so continue the house build
			foreach my $desired (@houses_desired) {
				# it matches, so set the flag
				if ($dir =~ /\/$desired/) {
					push (@folders, $dir);
					next CHECK_FOLDER;
				};
			};
		};
	};
};


#--------------------------------------------------------------------
# Delete old summary files
#--------------------------------------------------------------------
my @results_files = grep(/^\.\.\/summary_files\/Results.+$/, <../summary_files/*>); # Discover all of the file names that begin with Results in the summary_files directory
foreach my $file (@results_files) {unlink $file;}; # Delete the file (unlink)


#--------------------------------------------------------------------
# Determine how many houses go to each core for core usage balancing
#--------------------------------------------------------------------
my $interval = int(@folders/$cores->{'num'}) + 1;	#round up to the nearest integer



#--------------------------------------------------------------------
# Multithread to aquire the xml results faster, merge then print them out to csv files
#--------------------------------------------------------------------
MULTITHREAD_RESULTS: {

	my $thread; # Declare threads for each core
	
	foreach my $core (1..$cores->{'num'}) { # Cycle over the cores
		if ($core >= $cores->{'low'} && $core <= $cores->{'high'}) { # Only operate if this is a desireable core
			my $low_element = ($core - 1) * $interval; # Hse to start this particular core at
			my $high_element = $core * $interval - 1; # Hse to end this particular core at
			if ($core == $cores->{'num'}) { $high_element = $#folders}; # If the final core then adjust to end of array to account for rounding process

			$thread->{$core} = threads->new(\&collect_data, @folders[$low_element..$high_element]); # Spawn the threads and send to subroutine, supply the folders
		};
	};

	my $results_all = {}; # Declare a storage variable
	
	foreach my $core (1..$cores->{'num'}) { # Cycle over the cores
		if ($core >= $cores->{'low'} && $core <= $cores->{'high'}) { # Only operate if this is a desireable core
			$results_all = merge($results_all, $thread->{$core}->join()); # Return the threads together for info collation using the merge function
		};
	};
	
	# Call the remaining results printout and pass the results_all
	&print_out($results_all);
	
	my $localtime = localtime(time);
	print "Start Time: $localtime\n";
};

#--------------------------------------------------------------------
# Subroutine to collect the XML data
#--------------------------------------------------------------------
sub collect_data {
	my @folders = @_;
	
	#--------------------------------------------------------------------
	# Cycle through the data and collect the results
	#--------------------------------------------------------------------
	my $results_all = {}; # Declare a storage variable

	# Declare and fill out a set out formats for values with particular units
	my $units = {};
	@{$units}{qw(GJ W kg kWh l m3 tonne)} = qw(%.1f %.0f %.0f %.0f %.0f %.0f %.3f);

	# Cycle over each folder
	FOLDER: foreach my $folder (@folders) {
		# Determine the house type, region, and hse_name
		my ($hse_type, $region, $hse_name) = ($folder =~ /^\.\.\/(\d-\w{2})\/(\d-\w{2})\/(\w+)$/);

		# Open the CFG file and find the province name
		my $filename = $folder . "/$hse_name.cfg";
		open (my $CFG, '<', $filename) or die ("\n\nERROR: can't open $filename\n");
		my @cfg = &rm_EOL_and_trim(<$CFG>); # Clean it up
		my @province = grep(s/^#PROVINCE (.+)$/$1/, @cfg); # Stores the province name at element 0

		# Examine the directory and see if a results file (house_name.xml) exists. If it does than we had a successful simulation. If it does not, go on to the next house.
		unless (grep(/$hse_name.xml$/, <$folder/*>)) {
			# Store the house name so we no it is bad - with a note
			$results_all->{'bad_houses'}->{$region}->{$province[0]}->{$hse_type}->{$hse_name} = 'Missing the XML file';
			next FOLDER;  # Jump to the next house if it does not return a true.
		};
		
		# Otherwise continue by reading the results XML file
		my $results_hse = XMLin($folder . "/$hse_name.xml");

		# Cycle over the results and filter for SCD (secondary consumption), the '' will skip anything else
		foreach my $key (@{&order($results_hse->{'parameter'}, ['CHREM/SCD'], [''])}) {
			# Determine the important aspects of this key's name as they will all be CHREM/SCD. But do it as a second variable so we don't affect the original structure
			my ($param) = ($key =~ /^CHREM\/SCD\/(.+)$/);
			
			# If the parameter is in units for energy (as opposed to GHG or quantity) then we can store the min/max/avg information of watts demand)
			if ($param =~ /energy$/) {
				# Cycle over the different min/max/avg types
				foreach my $val_type (qw(total_average active_average min max)) {
					&check_add_house_result($hse_name, $key, $param, $val_type, $units, $results_hse, $results_all);
				};
			};

			# For all parameters store the integrated value - this will work for GHG and quantities, as well as energy of course
			# It employs the same logic as above so it is not commented
			my $val_type = 'integrated';
			&check_add_house_result($hse_name, $key, $param, $val_type, $units, $results_hse, $results_all);
		};

		# Certain houses have values outside a reasonable range and as such xml reporting gives an 'nan'
		# Cycle over each storage position and check for nan and if so throw it out
		foreach my $key (keys(%{$results_all->{'house_results'}->{$hse_name}})) {
			# Check for 'nan' anywhere in the data
			if ($results_all->{'house_results'}->{$hse_name}->{$key} =~ /nan/i) {
				# Store the house name so we no it is bad - with a note
				$results_all->{'bad_houses'}->{$region}->{$province[0]}->{$hse_type}->{$hse_name} = "Bad XML data - $results_all->{'house_results'}->{$hse_name}->{$key}";
				# Delete this house so it does not affect the multiplier
				delete($results_all->{'house_results'}->{$hse_name});
				next FOLDER;  # Jump to the next house if it does not return a true.
			};
		};
		
		# Store the hse_name at the corresponding region-province-housetype
		push(@{$results_all->{'house_names'}->{$region}->{$province[0]}->{$hse_type}}, $hse_name);
		# Store the simulation period for this particular house (to be used as a verifier)
		$results_all->{'house_results'}->{$hse_name}->{'sim_period'} = $results_hse->{'sim_period'};
		
	};
	# print Dumper $results_all;
	
	return ($results_all);
};


#--------------------------------------------------------------------
# Subroutine to print out the Results
#--------------------------------------------------------------------
sub print_out {
	my $results_all = shift;

	# Declare and fill out a set out formats for values with particular units
	my $units = {};
	@{$units}{qw(GJ W kg kWh l m3 tonne)} = qw(%.1f %.0f %.0f %.0f %.0f %.0f %.3f);

	# List the provinces in the preferred order
	my @provinces = ('NEWFOUNDLAND', 'NOVA SCOTIA' ,'PRINCE EDWARD ISLAND', 'NEW BRUNSWICK', 'QUEBEC', 'ONTARIO', 'MANITOBA', 'SASKATCHEWAN' ,'ALBERTA' ,'BRITISH COLUMBIA');

	my $SHEU03_houses = {}; # Declare a variable to store the total number of desired houses based on SHEU-1993

	# Fill out the number of desired houses for each province. These values are a combination of SHEU-2003 (being the baseline and providing the regional values) and CENSUS 2006 (to distribute the regional values by province)
	@{$SHEU03_houses->{'1-SD'}}{@provinces} = qw(148879 259392 38980 215084 1513497 2724438 305111 285601 790508 910051);
	@{$SHEU03_houses->{'2-DR'}}{@provinces} = qw(26098 38778 6014 23260 469193 707777 34609 29494 182745 203449);


	# Order the results that we want to printout for each house
	my @result_params = @{&order($results_all->{'parameter'}, [qw(site src use)])};

	# Also create a totalizer of integrated units that will sum up for each province and house type individually
	my @result_total = grep(/^site\/\w+\/integrated$/, @{&order($results_all->{'parameter'}, [qw(site src use)])}); # Only store site consumptions
	push(@result_total, grep(/^src\/\w+\/\w+\/integrated$/, @{&order($results_all->{'parameter'}, [qw(site src use)])})); # Append src total consumptions
	push(@result_total, grep(/^use\/\w+\/\w+\/integrated$/, @{&order($results_all->{'parameter'}, [qw(site src use)])})); # Append end use total consumptions

	# Create a file to print out the house results to
	my $filename = '../summary_files/Results_Houses.csv';
	open (my $FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

	# Setup the header lines for printing
	my $header_lines = &results_headers(@result_params);

	# We have a few extra fields to put in place so make some spaces for other header lines
	my @space = ('', '', '', '', '');

	# Print out the header lines to the file. Note the space usage
	print $FILE CSVjoin(qw(*group), @space, @{$header_lines->{'group'}}) . "\n";
	print $FILE CSVjoin(qw(*src), @space, @{$header_lines->{'src'}}) . "\n";
	print $FILE CSVjoin(qw(*use), @space, @{$header_lines->{'use'}}) . "\n";
	print $FILE CSVjoin(qw(*parameter), @space, @{$header_lines->{'parameter'}}) . "\n";
	print $FILE CSVjoin(qw(*field house_name region province hse_type required_multiplier), @{$header_lines->{'field'}}) . "\n";
	print $FILE CSVjoin(qw(*units - - - - -), @{$results_all->{'parameter'}}{@result_params}) . "\n";

	# Declare a variable to store the total results by province and house type
	my $results_tot;

	# Cycle over each region, ,province and house type to store and accumulate the results
	foreach my $region (@{&order($results_all->{'house_names'})}) {
		foreach my $province (@{&order($results_all->{'house_names'}->{$region}, [@provinces])}) {
			foreach my $hse_type (@{&order($results_all->{'house_names'}->{$region}->{$province})}) {
				
				# To determine the multiplier for the house type for a province, we must first determine the total desirable houses
				my $total_houses;
				# If it is defined in SHEU then use the number (this is to account for test cases like 3-CB)
				if (defined($SHEU03_houses->{$hse_type}->{$province})) {$total_houses = $SHEU03_houses->{$hse_type}->{$province};}
				# Otherwise set it equal to the number of present houses so the multiplier is 1
				else {$total_houses = @{$results_all->{'house_names'}->{$region}->{$province}->{$hse_type}};};
				
				# Calculate the house multiplier and format
				my $multiplier = sprintf("%.1f", $total_houses / @{$results_all->{'house_names'}->{$region}->{$province}->{$hse_type}});
				# Store the multiplier in the totalizer where it will be used later to scale the total results
				$results_tot->{$region}->{$province}->{$hse_type}->{'multiplier'} = $multiplier;

				# Cycle over each house with results and print out the results
				foreach my $hse_name (@{&order($results_all->{'house_names'}->{$region}->{$province}->{$hse_type})}) {
					# Print out the desirable fields and hten printout all the results for this house
					print $FILE CSVjoin('*data', $hse_name, $region, $province, $hse_type, $multiplier, @{$results_all->{'house_results'}->{$hse_name}}{@result_params}) . "\n";
					
					# Accumulate the results for this house into the provincial and house type total
					# Only cycle over the desirable fields (integrated only)
					foreach my $res_tot (@result_total) {
						# If this is the first time encountered then set equal to zero
						unless (defined($results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot})) {
							$results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} = 0;
						};
						
						# If the field exists for this house, then add it to the accumulator
						if (defined($results_all->{'house_results'}->{$hse_name}->{$res_tot})) {
							# Note the use of 'simulated'. This is so we can have a 'scaled' and 'per house' later
							$results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} = $results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} + $results_all->{'house_results'}->{$hse_name}->{$res_tot};
						};
					};
				};
			};
		};
	};

	close $FILE; # The individual house data file is complete

	# If there is BAD HOUSE data then print it
	if (defined($results_all->{'bad_houses'})) {
		# Create a file to print out the bad houses
		$filename = '../summary_files/Results_Bad.csv';
		open ($FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

		# Print the header information
		print $FILE CSVjoin(qw(*header region province hse_type hse_name issue)) . "\n";

		# Cycle over each region, ,province and house type to print the bad house issue
		foreach my $region (@{&order($results_all->{'bad_houses'})}) {
			foreach my $province (@{&order($results_all->{'bad_houses'}->{$region}, [@provinces])}) {
				foreach my $hse_type (@{&order($results_all->{'bad_houses'}->{$region}->{$province})}) {
					# Cycle over each house with results and print out the issue
					foreach my $hse_name (@{&order($results_all->{'bad_houses'}->{$region}->{$province}->{$hse_type})}) {
						print $FILE CSVjoin('*data', $region, $province, $hse_type, $hse_name, $results_all->{'bad_houses'}->{$region}->{$province}->{$hse_type}->{$hse_name}) . "\n";
					};
				};
			};
		};
		close $FILE; # The Bas house data file is complete
	};



	# Create a file to print the total scaled provincial results to
	$filename = '../summary_files/Results_Total.csv';
	open ($FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

	# Setup the header lines for printing
	$header_lines = &results_headers(@result_total);

	# We have a few extra fields to put in place so make some spaces for other header lines
	@space = ('', '', '');

	# Print out the header lines to the file. Note the space usage
	print $FILE CSVjoin(qw(*group), @space, @{$header_lines->{'group'}}) . "\n";
	print $FILE CSVjoin(qw(*src), @space, @{$header_lines->{'src'}}) . "\n";
	print $FILE CSVjoin(qw(*use), @space, @{$header_lines->{'use'}}) . "\n";
	print $FILE CSVjoin(qw(*parameter), @space, @{$header_lines->{'parameter'}}) . "\n";
	print $FILE CSVjoin(qw(*field province hse_type multiplier_used), @{$header_lines->{'field'}}) . "\n";
	print $FILE CSVjoin(qw(*units - - -), @{$results_all->{'parameter'}}{@result_total}) . "\n";

	# Cycle over the provinces and house types
	foreach my $region (@{&order($results_tot)}) {
		foreach my $province (@{&order($results_tot->{$region}, [@provinces])}) {
			foreach my $hse_type (@{&order($results_tot->{$region}->{$province})}) {
				# Cycle over the desired accumulated results and scale them to national values using the previously calculated house representation multiplier
				foreach my $res_tot (@result_total) {
					# Note these are placed at 'scaled' so as not to corrupt the 'simulated' results, so that they may be used at a later point
					$results_tot->{$region}->{$province}->{$hse_type}->{'scaled'}->{$res_tot} = $results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} * $results_tot->{$region}->{$province}->{$hse_type}->{'multiplier'};
				};
				# Print out the national total results
				print $FILE CSVjoin('*data',$province, $hse_type, $results_tot->{$region}->{$province}->{$hse_type}->{'multiplier'}, @{$results_tot->{$region}->{$province}->{$hse_type}->{'scaled'}}{@result_total}) . "\n";
			};
		};
	};

	close $FILE; # The national scaled totals are now complete


	# Create a file to print the total scaled provincial results to
	$filename = '../summary_files/Results_Average.csv';
	open ($FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

	# NOTE: We are using the same header lines and spacing as the previous file

	# Print out the header lines to the file. Note the space usage
	print $FILE CSVjoin(qw(*group), @space, @{$header_lines->{'group'}}) . "\n";
	print $FILE CSVjoin(qw(*src), @space, @{$header_lines->{'src'}}) . "\n";
	print $FILE CSVjoin(qw(*use), @space, @{$header_lines->{'use'}}) . "\n";
	print $FILE CSVjoin(qw(*parameter), @space, @{$header_lines->{'parameter'}}) . "\n";
	print $FILE CSVjoin(qw(*field province hse_type multiplier_used), @{$header_lines->{'field'}}) . "\n";
	print $FILE CSVjoin(qw(*units - - -), @{$results_all->{'parameter'}}{@result_total}) . "\n";

	# Cycle over the provinces and house types. NOTE we also cycle over region so we can pick up the total number of houses to divide by
	foreach my $region (@{&order($results_tot)}) {
		foreach my $province (@{&order($results_tot->{$region}, [@provinces])}) {
			foreach my $hse_type (@{&order($results_tot->{$region}->{$province})}) {
				# Cycle over the desired accumulated results and divide them down to the avg house using the total number of simulated houses
				foreach my $res_tot (@result_total) {
					# Note these are placed at 'avg' so as not to corrupt the 'simulated' results, so that they may be used at a later point
					$results_tot->{$region}->{$province}->{$hse_type}->{'avg'}->{$res_tot} = sprintf($units->{$results_all->{'parameter'}->{$res_tot}}, $results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} / @{$results_all->{'house_names'}->{$region}->{$province}->{$hse_type}});
				};
				print $FILE CSVjoin('*data',$province, $hse_type, 'avg per house', @{$results_tot->{$region}->{$province}->{$hse_type}->{'avg'}}{@result_total}) . "\n";
			};
		};
	};

	close $FILE;
};
