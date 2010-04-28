# ====================================================================
# Results.pm
# Author: Lukas Swan
# Date: Apr 2010
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# 
# ====================================================================

# Declare the package name of this perl module
package Results;

# Declare packages used by this perl module
use strict;
use CSV;	# CSV-2 (for CSV split and join, this works best)
use Data::Dumper;
use XML::Simple;
use General;
use Storable  qw(dclone);
# use File::Copy;	# (to copy the xml file)

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = qw(Exporter);

# Place the routines that are to be automatically exported here
our @EXPORT = qw(check_add_house_result results_headers print_results_out);
# Place the routines that must be requested as a list following use in the calling script
our @EXPORT_OK = ();

# ====================================================================
# check_add_house_result
# Checks and adds a house result to the results accumulation
# ====================================================================

sub check_add_house_result {
	my $hse_name = shift; # House name
	my $key = shift; # XML results key name
	my $param = shift; # Important part of the XML results key name
	my $val_type = shift; # e.g. integrated, minimum, maximum
	my $units = shift; # Units formats
	my $results_hse = shift; # The XML results for this house
	my $results_all = shift; # The results storage for all houses

	# Check to see if the value is defined
	if (defined($results_hse->{'parameter'}->{$key}->{'P00_Period'}->{$val_type})) {
		# Determine the units
		my $unit;
		if ($val_type eq 'integrated') {$unit = $results_hse->{'parameter'}->{$key}->{'units'}->{'integrated'};} # If integrated type
		else {$unit = $results_hse->{'parameter'}->{$key}->{'units'}->{'normal'};}; # All other types are normal

		# Check to see if we have already defined this parameter. If not, then set it equal to the units. Later the parameter list will be used as a key to print everything out and provide info on the units
		unless (defined($results_all->{'parameter'}->{$param . '/' . $val_type})) {
			$results_all->{'parameter'}->{$param . '/' . $val_type} = $unit;
		};

		# Store the resultant house data that is formatted for units
		$results_all->{'house_results'}->{$hse_name}->{$param . '/' . $val_type} = sprintf($units->{$unit}, $results_hse->{'parameter'}->{$key}->{'P00_Period'}->{$val_type});
	};

	return(1);
};


# ====================================================================
# results_headers
# Determines the results file header information such as groups, src, use, etc.
# ====================================================================

sub results_headers {
	my @parameters = @{shift()}; # The passed parameters to evaluate
	my @units = @{shift()}; # The passed units

	my $header_lines = {}; # Storage variable for the header lines
	my $line; # Temporarily holds the line type

	# Determine the group (site, src, use)
	$line = 'group';
	@{$header_lines->{$line}} = grep(s/^(\w+)\/.+$/$1/, @{dclone([@parameters])});

	# Determine the src (e.g. electricity, natural_gas)
	$line = 'src';
	foreach my $param (@parameters) {
		if ($param =~ /^src\/(\w+)\//) {push(@{$header_lines->{$line}}, $1);} # If 
		elsif ($param =~ /^use\/\w+\/src\/(\w+)\//) {push(@{$header_lines->{$line}}, $1);}
		else {push(@{$header_lines->{$line}}, 'all');};
	};

	# Determine the use (e.g. space-heating, CHREM_AL)
	$line = 'use';
	foreach my $param (@parameters) {
		if ($param =~ /^use\/(\w+)\//) {push(@{$header_lines->{$line}}, $1);}
		else {push(@{$header_lines->{$line}}, 'all');};
	};

	# Determine the variable (e.g. GHG, energy, quantity)
	$line = 'variable';
	@{$header_lines->{$line}} = grep(s/^.+\/(\w+)\/\w+$/$1/, @{dclone([@parameters])});

	# Determine the descriptor (e.g. integrated, min, max)
	$line = 'descriptor';
	@{$header_lines->{$line}} = grep(s/^.+\/(\w+)$/$1/, @{dclone([@parameters])});

	# Determine the units (e.g. GJ, W)
	$line = 'units';
	@{$header_lines->{$line}} = @units;
	
	
	# Now construct a field name that is useful for displaying in tables
	$line = 'field';
	# Cycle over each element of the arrays. We use element number to keep track
	foreach my $element (0..$#parameters) {
		# If it is at the site level, then call it Total
		if ($header_lines->{'group'}->[$element] eq 'site') {
			# If it is integrated we don't need to say that
			if ($header_lines->{'descriptor'}->[$element] eq 'integrated') {
				push(@{$header_lines->{$line}}, 'Total ' . $header_lines->{'variable'}->[$element] . ' (' . $header_lines->{'units'}->[$element] . ')');
			}
			# If it is not integrated then it is a power type so call it power instead of energy and provide the min/max etc.
			else {
				push(@{$header_lines->{$line}}, 'Total power ' . $header_lines->{'descriptor'}->[$element] . ' (' . $header_lines->{'units'}->[$element] . ')');
			};
		}
		# Different energy src types
		elsif ($header_lines->{'group'}->[$element] eq 'src') {
			if ($header_lines->{'descriptor'}->[$element] eq 'integrated') {
				push(@{$header_lines->{$line}}, $header_lines->{'src'}->[$element] . ' ' . $header_lines->{'variable'}->[$element] . ' (' . $header_lines->{'units'}->[$element] . ')');
			}
			else {
				push(@{$header_lines->{$line}}, $header_lines->{'src'}->[$element] . ' power ' . $header_lines->{'descriptor'}->[$element] . ' (' . $header_lines->{'units'}->[$element] . ')');
			}; 
		}
		# Different end use groups
		elsif ($header_lines->{'group'}->[$element] eq 'use') {
			# Check to see if it is the total for the group or if it is by energy src
			if ($header_lines->{'src'}->[$element] eq 'all') {
				if ($header_lines->{'descriptor'}->[$element] eq 'integrated') {
					push(@{$header_lines->{$line}}, $header_lines->{'use'}->[$element] . ' ' . $header_lines->{'variable'}->[$element] . ' (' . $header_lines->{'units'}->[$element] . ')');
				}
				else {
					push(@{$header_lines->{$line}}, $header_lines->{'use'}->[$element] . ' power ' . $header_lines->{'descriptor'}->[$element] . ' (' . $header_lines->{'units'}->[$element] . ')');
				};
			}
			# This is by energy src
			else {
				if ($header_lines->{'descriptor'}->[$element] eq 'integrated') {
					push(@{$header_lines->{$line}}, $header_lines->{'use'}->[$element] . ' ' . $header_lines->{'src'}->[$element] . ' ' . $header_lines->{'variable'}->[$element] . ' (' . $header_lines->{'units'}->[$element] . ')');
				}
				else {
					push(@{$header_lines->{$line}}, $header_lines->{'use'}->[$element] . ' ' . $header_lines->{'src'}->[$element] . ' power ' . $header_lines->{'descriptor'}->[$element] . ' (' . $header_lines->{'units'}->[$element] . ')');
				};
			};
		}
		# Otherwise simply output the full name and units because we don't know what to do
		else {
			push(@{$header_lines->{$line}}, $parameters[$element] . ' (' . $header_lines->{'units'}->[$element] . ')');
		};
		# Finally capitalize the first digit to make it look better
		push(@{$header_lines->{$line}}, &capitalize_first_letter(pop(@{$header_lines->{$line}})));
	};

	return($header_lines);
};



#--------------------------------------------------------------------
# Subroutine to print out the Results
#--------------------------------------------------------------------
sub print_results_out {
	my $results_all = shift;
	my $set_name = shift;

	# List the provinces in the preferred order
	my @provinces = ('NEWFOUNDLAND', 'NOVA SCOTIA' ,'PRINCE EDWARD ISLAND', 'NEW BRUNSWICK', 'QUEBEC', 'ONTARIO', 'MANITOBA', 'SASKATCHEWAN' ,'ALBERTA' ,'BRITISH COLUMBIA');
	my $prov_acronym;
	@{$prov_acronym}{@provinces} = qw(NF NS PE NB QC OT MB SK AB BC);

	# If there is BAD HOUSE data then print it
	if (defined($results_all->{'bad_houses'})) {
		# Create a file to print out the bad houses
		my $filename = "../summary_files/Results$set_name" . '_Bad.csv';
		open (my $FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

		# Print the header information
		print $FILE CSVjoin(qw(*header region province hse_type hse_name issue)) . "\n";

		# Cycle over each region, ,province and house type to print the bad house issue
		foreach my $region (@{&order($results_all->{'bad_houses'})}) {
			foreach my $province (@{&order($results_all->{'bad_houses'}->{$region}, [@provinces])}) {
				foreach my $hse_type (@{&order($results_all->{'bad_houses'}->{$region}->{$province})}) {
					# Cycle over each house with results and print out the issue
					foreach my $hse_name (@{&order($results_all->{'bad_houses'}->{$region}->{$province}->{$hse_type})}) {
						my ($region_short) = ($region =~ /\d-(\w{2})/);
						my ($hse_type_short) = ($hse_type =~ /\d-(\w{2})/);
						my $prov_short = $prov_acronym->{$province};
						print $FILE CSVjoin('*data', $region_short, $prov_short, $hse_type_short, $hse_name, $results_all->{'bad_houses'}->{$region}->{$province}->{$hse_type}->{$hse_name}) . "\n";
					};
				};
			};
		};
		close $FILE; # The Bas house data file is complete
	};



	# Declare and fill out a set out formats for values with particular units
	my $units = {};
	@{$units}{qw(GJ W kg kWh l m3 tonne)} = qw(%.1f %.0f %.0f %.0f %.0f %.0f %.3f);

	my $SHEU03_houses = {}; # Declare a variable to store the total number of desired houses based on SHEU-1993

	# Fill out the number of desired houses for each province. These values are a combination of SHEU-2003 (being the baseline and providing the regional values) and CENSUS 2006 (to distribute the regional values by province)
	@{$SHEU03_houses->{'1-SD'}}{@provinces} = qw(148879 259392 38980 215084 1513497 2724438 305111 285601 790508 910051);
	@{$SHEU03_houses->{'2-DR'}}{@provinces} = qw(26098 38778 6014 23260 469193 707777 34609 29494 182745 203449);


	if (defined($results_all->{'parameter'}) && defined($results_all->{'house_names'})) {
		# Order the results that we want to printout for each house
		my @result_params = @{&order($results_all->{'parameter'}, [qw(site src use)])};

		# Also create a totalizer of integrated units that will sum up for each province and house type individually
		my @result_total = grep(/^site\/\w+\/integrated$/, @{&order($results_all->{'parameter'}, [qw(site src use)])}); # Only store site consumptions
		push(@result_total, grep(/^src\/\w+\/\w+\/integrated$/, @{&order($results_all->{'parameter'}, [qw(site src use)])})); # Append src total consumptions
		push(@result_total, grep(/^use\/\w+\/\w+\/integrated$/, @{&order($results_all->{'parameter'}, [qw(site src use)])})); # Append end use total consumptions

		# Create a file to print out the house results to
		my $filename = "../summary_files/Results$set_name" . '_Houses.csv';
		open (my $FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

		# Setup the header lines for printing by passing refs to the variables and units
		my $header_lines = &results_headers([@result_params], [@{$results_all->{'parameter'}}{@result_params}]);

		# We have a few extra fields to put in place so make some spaces for other header lines
		my @space = ('', '', '', '', '');

		# Print out the header lines to the file. Note the space usage
		print $FILE CSVjoin(qw(*group), @space, @{$header_lines->{'group'}}) . "\n";
		print $FILE CSVjoin(qw(*src), @space, @{$header_lines->{'src'}}) . "\n";
		print $FILE CSVjoin(qw(*use), @space, @{$header_lines->{'use'}}) . "\n";
		print $FILE CSVjoin(qw(*variable), @space, @{$header_lines->{'variable'}}) . "\n";
		print $FILE CSVjoin(qw(*descriptor), @space, @{$header_lines->{'descriptor'}}) . "\n";
		print $FILE CSVjoin(qw(*units), @space, @{$header_lines->{'units'}}) . "\n";
		print $FILE CSVjoin(qw(*field house_name region province hse_type required_multiplier), @{$header_lines->{'field'}}) . "\n";


		# Declare a variable to store the total results by province and house type
		my $results_tot;

		# Cycle over each region, ,province and house type to store and accumulate the results
		foreach my $region (@{&order($results_all->{'house_names'})}) {
			foreach my $province (@{&order($results_all->{'house_names'}->{$region}, [@provinces])}) {
				foreach my $hse_type (@{&order($results_all->{'house_names'}->{$region}->{$province})}) {
					
					my ($region_short) = ($region =~ /\d-(\w{2})/);
					my ($hse_type_short) = ($hse_type =~ /\d-(\w{2})/);
					my $prov_short = $prov_acronym->{$province};
					
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
						print $FILE CSVjoin('*data', $hse_name, $region_short, $prov_short, $hse_type_short, $multiplier, @{$results_all->{'house_results'}->{$hse_name}}{@result_params}) . "\n";
						
						# Accumulate the results for this house into the provincial and house type total
						# Only cycle over the desirable fields (integrated only)
						foreach my $res_tot (@result_total) {
							# If the field exists for this house, then add it to the accumulator
							if (defined($results_all->{'house_results'}->{$hse_name}->{$res_tot})) {

								# If this is the first time encountered then set equal to zero
								unless (defined($results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot})) {
									$results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} = 0;
								};

								# Note the use of 'simulated'. This is so we can have a 'scaled' and 'per house' later
								$results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} = $results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} + $results_all->{'house_results'}->{$hse_name}->{$res_tot};
							};
						};
					};
				};
			};
		};

		close $FILE; # The individual house data file is complete



		# Create a file to print the total scaled provincial results to
		$filename = "../summary_files/Results$set_name" . '_Total.csv';
		open ($FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

		# Declare and fill out a set of unit conversions for totalizing
		my @unit_base = qw(GJ kg kWh l m3 tonne);
		my $unit_conv = {};
		@{$unit_conv->{'unit'}}{@unit_base} = qw(PJ Mt TWh Ml km3 Mt);
		@{$unit_conv->{'mult'}}{@unit_base} = qw(1e-6 1e-9 1e-9 1e-6 1e-9 1e-6);
		@{$unit_conv->{'format'}}{@unit_base} = qw(%.1f %.2f %.1f %.1f %.3f %.2f);

		# Determine the appropriate units for the totalized values
		my @converted_units = @{$unit_conv->{'unit'}}{@{$results_all->{'parameter'}}{@result_total}};

		# Setup the header lines for printing by passing refs to the variables and units
		$header_lines = &results_headers([@result_total], [@converted_units]);


		# We have a few extra fields to put in place so make some spaces for other header lines
		@space = ('', '', '', '', '');

		# Print out the header lines to the file. Note the space usage
		print $FILE CSVjoin(qw(*group), @space, @{$header_lines->{'group'}}) . "\n";
		print $FILE CSVjoin(qw(*src), @space, @{$header_lines->{'src'}}) . "\n";
		print $FILE CSVjoin(qw(*use), @space, @{$header_lines->{'use'}}) . "\n";
		print $FILE CSVjoin(qw(*variable), @space, @{$header_lines->{'variable'}}) . "\n";
		print $FILE CSVjoin(qw(*descriptor), @space, @{$header_lines->{'descriptor'}}) . "\n";
		print $FILE CSVjoin(qw(*units), @space, @{$header_lines->{'units'}}) . "\n";
		print $FILE CSVjoin(qw(*field source region province hse_type multiplier_used), @{$header_lines->{'field'}}) . "\n";

		my $results_Canada = {};

		# Cycle over the provinces and house types
		foreach my $region (@{&order($results_tot)}) {
			foreach my $province (@{&order($results_tot->{$region}, [@provinces])}) {
				foreach my $hse_type (@{&order($results_tot->{$region}->{$province})}) {
				
					my ($region_short) = ($region =~ /\d-(\w{2})/);
					my ($hse_type_short) = ($hse_type =~ /\d-(\w{2})/);
					my $prov_short = $prov_acronym->{$province};
				
					# Cycle over the desired accumulated results and scale them to national values using the previously calculated house representation multiplier
					foreach my $res_tot (@result_total) {
						if (defined($results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot})) {
							my $unit_orig = $results_all->{'parameter'}->{$res_tot};
							my $conversion = $unit_conv->{'mult'}->{$unit_orig};
							my $format = $unit_conv->{'format'}->{$unit_orig};
							# Note these are placed at 'scaled' so as not to corrupt the 'simulated' results, so that they may be used at a later point
							$results_tot->{$region}->{$province}->{$hse_type}->{'scaled'}->{$res_tot} = sprintf($format, $results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} * $results_tot->{$region}->{$province}->{$hse_type}->{'multiplier'} * $conversion);
							# Add it to the national total
							unless (defined($results_Canada->{$hse_type_short}->{$res_tot})) {
								$results_Canada->{$hse_type_short}->{$res_tot} = 0
							};
							$results_Canada->{$hse_type_short}->{$res_tot} = sprintf($format, $results_Canada->{$hse_type_short}->{$res_tot} + $results_tot->{$region}->{$province}->{$hse_type}->{'scaled'}->{$res_tot});
						};
						
					};
					# Print out the national total results
					print $FILE CSVjoin('*data', 'CHREM', $region_short, $prov_short, $hse_type_short, $results_tot->{$region}->{$province}->{$hse_type}->{'multiplier'}, @{$results_tot->{$region}->{$province}->{$hse_type}->{'scaled'}}{@result_total}) . "\n";
				};
			};
		};
		
		foreach my $hse_type (@{&order($results_Canada, [qw(SD DR)])}) {
			print $FILE CSVjoin('*data', 'CHREM', 'Canada', '', $hse_type, 1, @{$results_Canada->{$hse_type}}{@result_total}) . "\n";
		};
		
		$filename = "../keys/SHEU_03_results.xml";
		my $SHEU_03_results = XMLin($filename, ContentKey => '-value');
# 		print Dumper XMLout($SHEU_03_results);
		foreach my $region (@{&order($SHEU_03_results->{'region'}, [qw(AT QC OT PR BC Canada)])}) {
			foreach my $hse_type (@{&order($SHEU_03_results->{'region'}->{$region}->{'house_type'}, [qw(SD DR)])}) {
				# Print out the national total results
				print $FILE CSVjoin('*data', 'SHEU-03', $region, '', $hse_type, 1, @{$SHEU_03_results->{'region'}->{$region}->{'house_type'}->{$hse_type}->{'var'}}{@result_total}) . "\n";
			};
		};
		
		$filename = "../keys/REUM_00_04_results.xml";
		my $REUM_00_04_results = XMLin($filename);
# 		print Dumper ($REUM_00_04_results);
		foreach my $hse_type (@{&order($REUM_00_04_results->{'house_type'}, [qw(SD DR)])}) {
			foreach my $var(@{&order($REUM_00_04_results->{'house_type'}->{$hse_type}->{'var'})}) {
				my $short = $REUM_00_04_results->{'house_type'}->{$hse_type}->{'var'}->{$var};
				$REUM_00_04_results->{'house_type'}->{$hse_type}->{'var'}->{$var} = sprintf("%.1f", $short->{'value'} * $short->{'multiplier'});
			};
			# Print out the national total results
			print $FILE CSVjoin('*data', 'REUM-00-04', 'Canada', '', $hse_type, 1, @{$REUM_00_04_results->{'house_type'}->{$hse_type}->{'var'}}{@result_total}) . "\n";
		};
		

		close $FILE; # The national scaled totals are now complete


		# Create a file to print the total scaled provincial results to
		$filename = "../summary_files/Results$set_name" . '_Average.csv';
		open ($FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

		# Determine the header lines. Because this is per house the base units will stay
		$header_lines = &results_headers([@result_total], [@{$results_all->{'parameter'}}{@result_total}]);

		# We have a few extra fields to put in place so make some spaces for other header lines
		@space = ('', '', '', '');

		# Print out the header lines to the file. Note the space usage
		print $FILE CSVjoin(qw(*group), @space, @{$header_lines->{'group'}}) . "\n";
		print $FILE CSVjoin(qw(*src), @space, @{$header_lines->{'src'}}) . "\n";
		print $FILE CSVjoin(qw(*use), @space, @{$header_lines->{'use'}}) . "\n";
		print $FILE CSVjoin(qw(*variable), @space, @{$header_lines->{'variable'}}) . "\n";
		print $FILE CSVjoin(qw(*descriptor), @space, @{$header_lines->{'descriptor'}}) . "\n";
		print $FILE CSVjoin(qw(*units), @space, @{$header_lines->{'units'}}) . "\n";
		print $FILE CSVjoin(qw(*field region province hse_type multiplier_used), @{$header_lines->{'field'}}) . "\n";

		# Cycle over the provinces and house types. NOTE we also cycle over region so we can pick up the total number of houses to divide by
		foreach my $region (@{&order($results_tot)}) {
			foreach my $province (@{&order($results_tot->{$region}, [@provinces])}) {
				foreach my $hse_type (@{&order($results_tot->{$region}->{$province})}) {
				
					my ($region_short) = ($region =~ /\d-(\w{2})/);
					my ($hse_type_short) = ($hse_type =~ /\d-(\w{2})/);
					my $prov_short = $prov_acronym->{$province};
				
					# Cycle over the desired accumulated results and divide them down to the avg house using the total number of simulated houses
					foreach my $res_tot (@result_total) {

						if (defined($results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot})) {
					
							# Note these are placed at 'avg' so as not to corrupt the 'simulated' results, so that they may be used at a later point
							$results_tot->{$region}->{$province}->{$hse_type}->{'avg'}->{$res_tot} = sprintf($units->{$results_all->{'parameter'}->{$res_tot}}, $results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} / @{$results_all->{'house_names'}->{$region}->{$province}->{$hse_type}});
						};
					};
					print $FILE CSVjoin('*data', $region_short, $prov_short, $hse_type_short, 'avg per house', @{$results_tot->{$region}->{$province}->{$hse_type}->{'avg'}}{@result_total}) . "\n";
				};
			};
		};

		close $FILE;
	};
	return();
};


# Final return value of one to indicate that the perl module is successful
1;
