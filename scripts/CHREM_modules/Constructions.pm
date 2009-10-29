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
		
		
		# insulation_1 - the layer within the framing
		case (/^insulation_1$/) {
			switch ($code->{$comp}) {
				# determine the thickness for the specified insulation types
				$thickness = {1 => 56, 2 => 84, 3 => 140, 4 => 156, 5 => 196, 'G' => 66, 'H' => 105, 'J' => 280, 'K' => 68, 'L' => 224, 'R' => 25, 'S' => 25, 'T' => 25}->{$code->{$comp}} or $thickness = 89;
				
				# in the case where no insulating layer exists, put in a very small EPS layer to adjust the RSI
				case (0) {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => 0.1, 'component' => $comp});} # none
				case (/[1-5]|[J-L]/) {push (@{$con->{'layers'}}, {'mat' => 'Fbrglas_Batt', 'thickness_mm' => $thickness, 'component' => $comp});}	# Batt @ thickness
				case (/[G-H]|[R-T]/) {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});}	# EPS and Icynene @ thickness
				
				# the following insulation types do not have a specified thickness, so determine the framing thickness and use this as the thickness
				case (/9|A|[E-F]|[M-Q]/) {
					# these insulations require the framing thickness as they fill it
					
					if ($code->{'name'} eq 'M_wall') {
						if ($code->{'type'} == 2) {	# wood frame, determine framing thickness
							$thickness = {0 => 89, 1 => 140, 2 => 184, 3 => 235, 4 => 286, 5 => 102}->{$code->{'framing'}} or $thickness = 89;
						}
						elsif ($code->{'type'} == 3) {	# metal frame, determine framing thickness
							$thickness = {0 => 92, 1 => 152}->{$code->{'framing'}} or $thickness = 92;
						}
						else {$thickness = 89};	# assume equal to 2x4 width
					}
					else {die "The construction type is not present to determine the framing thickness: $code->{'construction'}\n"};
					
					
					# now cycle back through the insulation types and apply this thickness to the appropriate insulation
					switch ($code->{$comp}) {
						case (9) {push (@{$con->{'layers'}}, {'mat' => 'Cellulose_23.7', 'thickness_mm' => $thickness, 'component' => $comp});}
						case (/A/) {push (@{$con->{'layers'}}, {'mat' => 'Cellulose_25.3', 'thickness_mm' => $thickness, 'component' => $comp});}
						case (/E/) {push (@{$con->{'layers'}}, {'mat' => 'Fibre_18.6', 'thickness_mm' => $thickness, 'component' => $comp});}
						case (/F/) {push (@{$con->{'layers'}}, {'mat' => 'Icynene_25.0', 'thickness_mm' => $thickness, 'component' => $comp});}
						case (/M|O/) {push (@{$con->{'layers'}}, {'mat' => 'Woodshavings', 'thickness_mm' => $thickness, 'component' => $comp});}
						case (/N/) {push (@{$con->{'layers'}}, {'mat' => 'Newspaper', 'thickness_mm' => $thickness, 'component' => $comp});}
						case (/P/) {push (@{$con->{'layers'}}, {'mat' => 'Vermiculite', 'thickness_mm' => $thickness, 'component' => $comp});}
						case (/Q/) {push (@{$con->{'layers'}}, {'mat' => 'Straw', 'thickness_mm' => $thickness, 'component' => $comp});}
						else {push (@{$con->{'layers'}}, {'mat' => 'Fbrglas_Batt', 'thickness_mm' => $thickness, 'component' => $comp});} # assume batt
					};
				}
				
				else {push (@{$con->{'layers'}}, {'mat' => 'Fbrglas_Batt', 'thickness_mm' => $thickness, 'component' => $comp});};	# assume batt
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
