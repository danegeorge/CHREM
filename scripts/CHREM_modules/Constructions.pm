# ====================================================================
# CHREM_modules::Constructions.pl
# Author: Lukas Swan
# Date: Oct 2009
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# construction: push the appropriate layers onto the construction array
# ====================================================================

# Declare the package name of this perl module
package CHREM_modules::Constructions;

# Declare packages used by this perl module
use strict;
# use CSV;	# CSV-2 (for CSV split and join, this works best)
use Data::Dumper;
# use List::Util ('shuffle');
use Switch;

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('construction');


# ====================================================================
# construction
# This subroutine recieves the code and component and places the appropriate layers
# on the construction array. The intent is to reuse the lookup thicknesses and types
# for multiple construction types.
# ====================================================================

sub construction {

	my $comp = shift; # the component to add
	my $code = shift; # reference to the code hash
	my $con = shift; # reference to the construction array

	my $thickness; # scalar of the thickness so we do not require repeated 'my' on single line (see anonymous hash and 'or' below)

	switch ($comp) {

		# siding
		case (/^siding$/) {
			switch ($code->{$comp}) {
				case (0) {} # none
				case (1) {push (@{$con->{'layers'}}, {'mat' => 'SPF', 'thickness_mm' => 25, 'component' => $comp});}	# wood
				case (2) {push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 3, 'component' => $comp});}	# metal/vinyl
				case (3) {push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 8, 'component' => $comp});}	# insulated metal/vinyl
				case [4, 7] {push (@{$con->{'layers'}}, {'mat' => 'Brick', 'thickness_mm' => 100, 'component' => $comp});}	# brick or stone
				case [5, 6] {push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => 25, 'component' => $comp});}	# mortar and stucco
				else {push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 3, 'component' => $comp});};	# assume vinyl
			};
		}
		
		# sheathing
		case (/^sheathing$/) {
			switch ($code->{$comp}) {
				# these thicknesses correspond to the types in mm
				$thickness = {1 => 9.5, 2 => 11.1, 3 => 15.9, 4 => 9.5, 5 => 12.7, 6 => 15.5, 7 => 18.5, 8 => 9.5, 9 => 11.1, 'A' => 9.5, 'B' => 12.7}->{$code->{$comp}} or $thickness = 11.1;
				case (0) {} # none
				case [1..3] {push (@{$con->{'layers'}}, {'mat' => 'OSB', 'thickness_mm' => $thickness, 'component' => $comp});}	# Oriented strand board @ thickness
				case [4..7] {push (@{$con->{'layers'}}, {'mat' => 'Plywood', 'thickness_mm' => $thickness, 'component' => $comp});}	# plywood @ thickness
				case [8, 9] {push (@{$con->{'layers'}}, {'mat' => 'MDF', 'thickness_mm' => $thickness, 'component' => $comp});}	# MDF @ thickness
				case (/A|B/) {push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp});}	# Drywall @ thickness
				else {push (@{$con->{'layers'}}, {'mat' => 'OSB', 'thickness_mm' => $thickness, 'component' => $comp});};	# assume OSB
			};
		}

		# insulation_2 - the layer outside the framing
		case (/^insulation_2$/) {
			switch ($code->{$comp}) {
				# these thicknesses correspond to the types in mm
				$thickness = {1 => 50, 2 => 38, 3 => 76, 4 => 19, 5 => 38, 6 => 64, 7 => 25, 8 => 19, 'A' => 50, 'B' => 25, 'C' => 25}->{$code->{$comp}} or $thickness = 19;
				case (0) {} # none
				case [1..8] {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});}	# EPS @ thickness
				case 9 {push (@{$con->{'layers'}}, {'mat' => 'Fbrglas_Batt', 'thickness_mm' => 100, 'component' => $comp});}	# assume that insulation_1 is most common
				case (/A|B|C/) {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});}	# EPS @ thickness
				else {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});};	# assume EPS
			};
		}
		
		# interior
		case (/^interior$/) {
			switch ($code->{$comp}) {
				$thickness = 12;
				case (0) {} # none
				case [1..3, 9] {push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp});}	# Drywall and lath/plaster
				case 4 {push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 3, 'component' => $comp});}	# linoleum
				case 5 {
					push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp . '_2'});	# drywall
					push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 3, 'component' => $comp . '_1'});	# linoleum
				}
				case 6 {push (@{$con->{'layers'}}, {'mat' => 'SPF', 'thickness_mm' => $thickness, 'component' => $comp});}	# wood
				case 7 {
					push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp . '_2'});	# drywall
					push (@{$con->{'layers'}}, {'mat' => 'SPF', 'thickness_mm' => $thickness, 'component' => $comp . '_1'});	# wood
				}
				case 8 {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => 4, 'component' => $comp});}	# Carpet + underpad
				else {push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp});};	# assume Drywall
			};
		}
		
		
		else {die "Bad Call to sub construction' - there is no component: $comp\n"};
	};
	
	return ($con);
};



# Final return value of one to indicate that the perl module is successful
1;
