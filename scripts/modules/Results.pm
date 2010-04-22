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
# use CSV;	# CSV-2 (for CSV split and join, this works best)
use Data::Dumper;
# use XML::Simple;
# use General;
use Storable  qw(dclone);
# use File::Copy;	# (to copy the xml file)

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = qw(Exporter);

# Place the routines that are to be automatically exported here
our @EXPORT = qw(check_add_house_result results_headers);
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

# A simple subroutine to captitalize the first letter of a  string

sub capitalize_first_letter {
	my $string = shift; # The string

	$string =~ /^(.)/; # Determine the first letter

	my $character = uc($1); # Captilize this letter

	$string =~ s/^(.)/$character/; # Replace the letter with the capitalized one

	return ($string); # Return the string
}



# Final return value of one to indicate that the perl module is successful
1;
