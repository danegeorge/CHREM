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
	my @parameters = @_; # The passed parameters to evaluate

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

	# Determine the parameter (e.g. GHG, energy, quantity)
	$line = 'parameter';
	@{$header_lines->{$line}} = grep(s/^.+\/(\w+)\/\w+$/$1/, @{dclone([@parameters])});

	# Determine the field (e.g. integrated, min, max)
	$line = 'field';
	@{$header_lines->{$line}} = grep(s/^.+\/(\w+)$/$1/, @{dclone([@parameters])});

	return($header_lines);
};


# Final return value of one to indicate that the perl module is successful
1;
