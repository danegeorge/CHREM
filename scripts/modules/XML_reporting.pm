# ====================================================================
# XML_reporting.pm
# Author: Lukas Swan
# Date: Mar 2010
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# 
# ====================================================================

# Declare the package name of this perl module
package XML_reporting;

# Declare packages used by this perl module
use strict;
# use CSV;	# CSV-2 (for CSV split and join, this works best)
use Data::Dumper;
use XML::Simple;
use General;
use Storable  qw(dclone);


# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = qw(Exporter);

# Place the routines that are to be automatically exported here
our @EXPORT = qw(organize_xml_log zone_energy_balance);
# Place the routines that must be requested as a list following use in the calling script
our @EXPORT_OK = ();

# ====================================================================
# organize_xml_log
# This reorganizes the XML log file by month and period for a more
# suitable format for CHREM
# ====================================================================

sub organize_xml_log {
	my $house_name = shift; # House name
	my $sim_period = shift; # Simulation period hash reference
	my $zone_name_num = shift; # Zone names and numbers hash reference
	my $coordinates = shift; # House coordinate information for error reporting

	my $file = $house_name . '.xml'; # Create a complete filename with extension
	my $XML = XMLin($file); # Readin the XML data
	my $parameters = $XML->{'parameter'}; # Create a reference to the XML parameters

	my @month_names = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec); # Short month names
	my ($month_num, $num_month, $month_days); # Declare some month information hash refs
	@{$month_num}{@month_names} = (1..12); # Key = month name, value = month number [1..12]
	$num_month = {reverse(%{$month_num})}; # Key = month number [1..12], value = month name
	@{$month_days}{@month_names} = qw(31 28 31 30 31 30 31 31 30 31 30 31); # Key = month name, value = days in month
	
	my $month_num_begin = $month_num->{$sim_period->{'begin'}->{'month'}};
	my $month_num_end = $month_num->{$sim_period->{'end'}->{'month'}};


	# Cycle over the parameters and reorder the summaries for ease of use
	foreach my $key (keys %{$parameters}) {
		my ($unit) = ($parameters->{$key}->{'units'} =~ /\((.+)\)/); # Strip the units value of brackets and store it as 'normal' units
		$parameters->{$key}->{'units'} = {'normal' => $unit}; # Set units equal to this as the nominal unit type for non-integrated values
		
		# Cycle over the binned_data (by month and annual) and relocate the data up the tree
		foreach my $element (@{$parameters->{$key}->{'binned_data'}}) {
			my $period; # Define a period variable
			if ($element->{'type'} eq 'annual') { # If the type is annual
				$period = 'P00_Period'; # Store the period name
				delete $element->{'type'}; # Delete the redundant information
				# Cycle over the begin and end and set the month and day equal to the simulation period
# 				foreach my $begin_end (qw(begin end)) {
# 					@{$element->{$begin_end}}{qw(month day)} = @{$sim_period->{$begin_end}}{qw(month day)}; # Hash slice
# 				};
			}
			elsif ($element->{'type'} eq 'monthly') { # Elsif the type is monthly
				my $month = $num_month->{$element->{'index'} + $month_num_begin}; # Store the period by month name.
				$period = sprintf("P%02u_%s", $month_num->{$month}, $month); # Store the period by mm_mmm
				delete @{$element}{'type', 'index'}; # Delete the redundant information
				# Cycle over the begin and end and set the month and determine the days
# 				foreach my $begin_end (qw(begin end)) {
# 					$element->{$begin_end}->{'month'} = $period; # Month will alway be equal to the period
# 					if ($period eq $sim_period->{$begin_end}->{'month'}) {$element->{$begin_end}->{'day'} = $sim_period->{$begin_end}->{'day'};} # If the month is equal to the begin or end month then use the days specified for either the beginnig or end of simulation
# 					else {$element->{$begin_end}->{'day'} = {'begin' => '01', 'end' => $month_days->{$period}}->{$begin_end};}; # Otherwise if it is a beginning then set to 1 and if it is an end set to the number of days in the month
# 				};
			}
			else { # Report if the type is unknown
				&die_msg("Bad XML reporting binned data type in $file: should be 'annual' or 'monthly'", $element->{'type'}, $coordinates);
			};
			# Save the information up the tree by cloning the remainder of the element to that period
			$parameters->{$key}->{$period} = dclone($element);
		};
		# Delete the redundant information
		delete $parameters->{$key}->{'binned_data'};
		
		# Integrated data
		if (defined($parameters->{$key}->{'integrated_data'})) {
			# Cycle over the integrated data
			foreach my $element (@{$parameters->{$key}->{'integrated_data'}->{'bin'}}) {
				my $period; # Define a period variable
				if ($element->{'type'} eq 'annual') { # If the type is annual
					$period = 'P00_Period'; # Store the period
				}
				elsif ($element->{'type'} eq 'monthly') { # Elsif the type is monthly
					my $month = $num_month->{$element->{'index'} + $month_num_begin}; # Store the period by month name.
					$period = sprintf("P%02u_%s", $month_num->{$month}, $month); # Store the period by mm_mmm
				}
				else { # Report if the type is unknown
					&die_msg("Bad XML reporting integrated data bin type in $file: should be 'annual' or 'monthly'", $element->{'type'}, $coordinates);
				};
				# Save the information (integrated value) up the tree under a key of 'integrated'
				$parameters->{$key}->{$period}->{'integrated'} = $element->{'content'};
			};

			# Also store the integrated units type
			($parameters->{$key}->{'units'}->{'integrated'}) = $parameters->{$key}->{'integrated_data'}->{'units'};
			# Delete the redundant information
			delete $parameters->{$key}->{'integrated_data'};
		};
	};

	# Store the sim period and zone information
	$XML->{'sim_period'} = dclone($sim_period);
	$XML->{'zone_name_num'} = dclone($zone_name_num);

	# To access these sorted results at a later point, output them in XML format to a file
	open (my $XML_file, '>', $file) or die ("\n\nERROR: can't open $file to rewrite xml log in sorted form\n"); # Open a writeout file
	print $XML_file XMLout($XML);	# printout the XML data
	close $XML_file;
	
	return(1);
};


# ====================================================================
# energy_balance
# This constructs an energy balance from the xml log reporting
# ====================================================================

sub zone_energy_balance {
	my $house_name = shift;
	my $coordinates = shift;
	
	my $file = $house_name . '.xml';
# 	print "In xml reporting at $file\n";
	my $XML = XMLin($file);
	
	# Remove the 'parameter' field
	my $parameters = $XML->{'parameter'};
# 	print Dumper $parameters;
	my $zone_num_name = {reverse(%{$XML->{'zone_name_num'}})};

	# Create an energy results hash reference to store accumulated data
	my $en_results;
	# The data will be sorted into a columnar printout, so store the width of the first column based on its header
	$en_results->{'columns'}->{'variable'} = length('Energy (kWh)');
	
	# Cycle over the entire summary hash and summarize the control volume energy results
	foreach my $key (keys %{$parameters}) {
		# Only summarize for energy balance based on zone information and a power type
		if ($key =~ /^CHREM\/zone_0(\d)\/Power\/(.+)$/) {
			my $zone_name2 = $zone_num_name->{$1}; # Store the zone name
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
			if ($parameters->{$key}->{'units'}->{'integrated'} eq 'GJ') {
				$en_results->{$type}->{$variable}->{$zone_name2} = sprintf("%+.0f", $parameters->{$key}->{'P00_Period'}->{'integrated'} * 277.78);
			}
			else {&die_msg("Bad integrated data units for energy balance: should be 'GJ'", $parameters->{$key}->{'units'}->{'integrated'}, $coordinates);};

			# NOTE: Because interior convection with reference to the node is opposite our control volume, it needs a sign reversal
# 				if ($variable =~ /^CV/) {
# 					$en_results->{$type}->{$variable}->{$zone_name2} = sprintf("%+.0f", -$en_results->{$type}->{$variable}->{$zone_name2});
# 				};

			# Compare the length of this value to the column size and modify if necessary
			if ((length($en_results->{$type}->{$variable}->{$zone_name2}) + 2) > $en_results->{'columns'}->{$zone_name2}) {
				$en_results->{'columns'}->{$zone_name2} = length($en_results->{$type}->{$variable}->{$zone_name2}) + 2;
			};
		}

		elsif ($key =~ /^CHREM\/zone_0(\d)\/Temp\/Airpoint$/) {
			my $zone_name2 = $zone_num_name->{$1}; # Store the zone name

			# Check to see if a column has been generated for this zone. If not then set it equal to the zone name length + 2 for spacing
			unless (defined($en_results->{'columns'}->{$zone_name2})) {
				$en_results->{'columns'}->{$zone_name2} = length($zone_name2) + 2;
			};

			my $type = 'temperature';

			unless ($parameters->{$key}->{'units'}->{'normal'} eq 'C') {&die_msg("Bad normal data units for temperature: should be 'C'", $parameters->{$key}->{'units'}->{'normal'}, $coordinates);};

			# Store the resulting information
			foreach my $rep (qw(min max avg)) {
				my $variable = 'Temp_' . $rep;
				my $rep2 = $rep;
				if ($rep2 eq 'avg') {$rep2 = 'total_average';};
				
				# Check the length of the variable and if it is longer, set the column to that width
				if (length($variable) > $en_results->{'columns'}->{'variable'}) {
					$en_results->{'columns'}->{'variable'} = length($variable);
				};

				$en_results->{$type}->{$variable}->{$zone_name2} = sprintf("%+.1f", $parameters->{$key}->{'P00_Period'}->{$rep2});

				# Compare the length of this value to the column size and modify if necessary
				if ((length($en_results->{$type}->{$variable}->{$zone_name2}) + 2) > $en_results->{'columns'}->{$zone_name2}) {
					$en_results->{'columns'}->{$zone_name2} = length($en_results->{$type}->{$variable}->{$zone_name2}) + 2;
				};

			};
		};
	};
	
#	print Dumper $en_results;
	
	$file = $house_name . '.energy_balance';
	# Create a results file
	open (my $PERIOD, '>', $file);
	
	print $PERIOD "Simulation period: $XML->{'sim_period'}->{'begin'}->{'month'} $XML->{'sim_period'}->{'begin'}->{'day'} to $XML->{'sim_period'}->{'end'}->{'month'} $XML->{'sim_period'}->{'end'}->{'day'}\n\n";
	# Print the first column name of the header row, using the width specifified and a format involving a vertical bar afterwards
	printf $PERIOD ("%-$en_results->{'columns'}->{'variable'}s |", 'Energy (kWh)');
	
	# Select the printout orders
	my $print->{'zones'} = &order($en_results->{'columns'}, [qw(main bsmt crawl attic roof)], ['']); # Only print desired zones
	$print->{'type'} = [qw(opaque transparent), 'air point', qw(storage), qw(temperature)]; # Print the following energy types
	# The following three lines control the types of fluxes to be output
	$print->{'opaque'} = &order($en_results->{'opaque'}, [qw(CD SW LW)], ['']); # CD CV SW LW
	$print->{'transparent'} = &order($en_results->{'transparent'}, [qw(CD SW LW)], ['']); # CD CV SW LW
	$print->{'air point'} = &order($en_results->{'air point'}, [qw(AV GN)], ['']); #AV GN
	$print->{'storage'} = &order($en_results->{'storage'}, [qw(SH LH)], []); # SH LH
	$print->{'temperature'} = &order($en_results->{'temperature'}, [qw(Temp_avg Temp_min Temp_max)], []); # Temp_avg Temp_min Temp_max
	
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
		
		unless ($type eq 'temperature') {
			# Print the sum for this type of energy flux (e.g. opaque)
			printf $PERIOD ("%-$en_results->{'columns'}->{'variable'}s |", '++SUM++');
			# Cycle over the zones and print the sum
			foreach my $zone (@{$print->{'zones'}}) {
				printf $PERIOD ("%$en_results->{'columns'}->{$zone}s", $sum->{$zone}->{$type});
			};
		};
	};
	# Close up the file
	close $PERIOD;
	
# 	print Dumper $parameters;
	return($parameters);
};


# Final return value of one to indicate that the perl module is successful
1;
