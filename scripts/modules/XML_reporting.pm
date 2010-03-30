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
	my $house_name = shift;
	my $sim_period = shift;
	my $zone_name_num = shift;
	my $coordinates = shift;
	
# 	print Dumper $sim_period;
	my $file = $house_name . '.xml';
	my $summary_XML = XMLin($file);
	my $summary = $summary_XML->{'parameter'};
	
	# Create a month index hash which uses the month index as keys and the month name as values
	my $index_month;
	@{$index_month}{1..12} = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec); # Hash slice
	my $month_index = {reverse(%{$index_month})};
# 	print Dumper $month_index;
	
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
				$period = $index_month->{$element->{'index'} + $month_index->{$sim_period->{'start_month'}}}; # Store the period by month index, but add in the start month index as it may not be January
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
				$period = $index_month->{$element->{'index'} + $month_index->{$sim_period->{'start_month'}}}; # Store the period by month index, but add in the start month index as it may not be January
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

	$summary_XML->{'sim_period'} = dclone($sim_period);
	$summary_XML->{'zone_name_num'} = dclone($zone_name_num);
# 	print Dumper $summary;

	# To access these sorted results at a later point, output them in XML format to a file
	open (my $XML, '>', $file) or die ("\n\nERROR: can't open $file to rewrite xml log in sorted form\n"); # Open a writeout file
	print $XML XMLout($summary_XML);	# printout the XML data
	close $XML;
	
	return($summary);
};


# ====================================================================
# energy_balance
# This constructs an energy balance from the xml log reporting
# ====================================================================

sub zone_energy_balance {
	my $house_name = shift;
	my $coordinates = shift;
	
	my $file = $house_name . '.xml';
	my $summary_XML = XMLin($file);
	
	# Remove the 'parameter' field
	my $summary = $summary_XML->{'parameter'};
	my $zone_num_name = {reverse(%{$summary_XML->{'zone_name_num'}})};

# Create an energy results hash reference to store accumulated data
	my $en_results;
	# The data will be sorted into a columnar printout, so store the width of the first column based on its header
	$en_results->{'columns'}->{'variable'} = length('Energy (kWh)');
	
	# Cycle over the entire summary hash and summarize the control volume energy results
	foreach my $key (keys %{$summary}) {
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
	
	$file = $house_name . '.energy_balance';
	# Create a results file
	open (my $PERIOD, '>', $file);
	
	print $PERIOD "Simulation period: $summary_XML->{'sim_period'}->{'start_month'} $summary_XML->{'sim_period'}->{'start_day'} to $summary_XML->{'sim_period'}->{'end_month'} $summary_XML->{'sim_period'}->{'end_day'}\n\n";
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
	
# 	print Dumper $summary;
	return($summary);
};


# Final return value of one to indicate that the perl module is successful
1;
