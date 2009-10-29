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
		
			# This presently covers the following insulations:
			# 0 = None
			# 1 = EPS I (mm 50)
			# 2-3 = EPS II (mm 38, 76)
			# 4-6 = XTPS, treat as EPS (mm 19, 38, 64)
			# 7 = Semi-rigid, treat as EPS (mm 25)
			# 8 = Isocyanurate, treat as EPS (mm 19)
			# 9 = Same as Insul 1, assume Fiberglass Batt of 89 mm
			# A = EPS II (mm 50)
			# B = XTPS IV, treat as EPS (mm 25)
			# C = EPS II (mm 25)
				
			switch ($code->{$comp}) {
				# these thicknesses correspond to the types in mm
				$thickness = {1 => 50, 2 => 38, 3 => 76, 4 => 19, 5 => 38, 6 => 64, 7 => 25, 8 => 19, 'A' => 50, 'B' => 25, 'C' => 25}->{$code->{$comp}} or $thickness = 19;
				case (0) {} # none
				case [1..8] {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});}	# EPS @ thickness
				case 9 {push (@{$con->{'layers'}}, {'mat' => 'Fbrglas_Batt', 'thickness_mm' => 89, 'component' => $comp});}	# assume that insulation_1 is most common
				case (/A|B|C/) {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});}	# EPS @ thickness
				else {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});};	# assume EPS
			};
		}

		# solid - solid type construction (e.g. concrete, wood logs)
		case (/^solid$/) {
		
			# This presently covers the following:
			# 0-2 = Concrete (mm 76, 203, 305)
			# 3-4 = Concrete block, treat as concrete sides (mm 203, 305)
			# 5 = Insulating concrete block, treat as 30 mm concrete on each side of insulation_1
			# 6 = Concrete + 2 layers XTPS IV, treat as EPS (203 mm for concrete and 30 mm EPS)
			# 7-8 = Concrete + 2 layers EPS II (140, 159 mm for concrete and 30 mm EPS)
			# 9, A-C = Logs, mutiple types treated as SPF (mm 305, 150, 254, 406)
			# D = Stone (mm 610)
			# E = Logs, plank treat as SPF (mm 102)
			# F = Double brick (estimate 200 mm)

		
			# because we used 'solid' to get here, we have to link it to 'framing' value
			$code->{$comp} = $code->{'framing'};
			$con->{'description'} = 'CUSTOM: Solid construction type (concrete or wood logs)';
			# this is solid construction type - so apply the solid but then put a small amount of insulatin inside to adjust the RSI
			switch ($code->{$comp}) {
				# these thicknesses correspond to the types in mm
				$thickness = {0 => 76, 1 => 203, 2 => 305, 3 => 60, 4 => 80, 6 => 203, 7 => 140, 8 => 159, 9 => 305, 'A' => 150, 'B' => 254, 'C' => 406}->{$code->{$comp}} or $thickness = 0.1;
				case [0..4] {	# solid concrete
					push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => $thickness, 'component' => $comp});	# Concrete @ thickness
					$con = construction('insulation_1', $code, $con);
				}
				case 5 {	# insulating concrete block
					push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => 30, 'component' => $comp . '_2'});
					$con = construction('insulation_1', $code, $con);
					push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => 30, 'component' => $comp . '_1'});
				}
				case [6..8] {	# Concrete and EPS insulation
					push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => $thickness, 'component' => $comp});
					push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => 30, 'component' => 'insulation_1'});
				}
				case (/9|[A-C]/) {
					push (@{$con->{'layers'}}, {'mat' => 'SPF', 'thickness_mm' => $thickness, 'component' => $comp});	# Wood logs @ thickness
					# this type does not go to the insulation_1, so force on a little bit of EPS for RSI adjustment
					push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => 0.1, 'component' => 'insulation_1'});	# EPS to adjust RSI
				}
				case (/D/) {
					push (@{$con->{'layers'}}, {'mat' => 'Stone', 'thickness_mm' => 610, 'component' => $comp});	# Stone @ thickness
					$con = construction('insulation_1', $code, $con);
				}
				case (/E/) {
					push (@{$con->{'layers'}}, {'mat' => 'SPF', 'thickness_mm' => 102, 'component' => $comp});	# Plank logs @ thickness
					$con = construction('insulation_1', $code, $con);
				}
				case (/F/) {
					push (@{$con->{'layers'}}, {'mat' => 'Brick', 'thickness_mm' => 200, 'component' => $comp});	# Brick @ thickness
					$con = construction('insulation_1', $code, $con);
				}
				# we don't know what it is, so just push a little EPS to adjust RSI
				else {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => 'insulation_1'});};	# Fallback to small EPS to adjust RSI
			};
		}


		# panel - the layers surrounding the insulation
		case (/^panel$/) {
			# because we used 'panel' to get here, we have to link it to 'framing' value
			$code->{$comp} = $code->{'framing'};
			$con->{'description'} = 'CUSTOM: Panel construction type (sheet_metal/insulation/sheet_metal)';
			$thickness = {0 => 140, 1 => 140, 2 => 82, 3 => 108, 4 => 159, 5 => 89, 6 => 140}->{$code->{$comp}} or $thickness = 140;
			push (@{$con->{'layers'}}, {'mat' => 'Sheet_Metal', 'thickness_mm' => 2, 'component' => $comp . '_2'});	# Sheet metal
			# this does not check for insulation_1, so assume the panel is filled with fibreglass batt
			push (@{$con->{'layers'}}, {'mat' => 'Fbrglas_Batt', 'thickness_mm' => $thickness, 'component' => 'insulation_1'});	# Insul adjust RSI
			push (@{$con->{'layers'}}, {'mat' => 'Sheet_Metal', 'thickness_mm' => 2, 'component' => $comp . '_1'});	# Sheet metal
		}
		
		# framed - typical wood or metal framing construction
		case (/^framed$/) {
			$con->{'description'} = 'CUSTOM: Framed with wood or metal';
			# insulation_1 - the layer within the framing
			$con = construction('insulation_1', $code, $con);
		}
		
		# insulation_1 - the layer within the framing
		case (/^insulation_1$/) {
			switch ($code->{$comp}) {
			
				# This presently covers the following insulations:
				# 0 = None
				# 1-5 = Fibreglass batt (RSI 1.4, 2.1, 3.5, 3.9, 4.9)
				# 6-8 = Blown cellulose (RSI 3.5, 4.9, 9.0)
				# 9 = Blown cellulose (RSI/m 23.7, fit to framing)
				# A = Blown cellulose (RSI/m 25.3, fit to framing)
				# B-D = Mineral fibre (RSI 3.5, 4.9, 9.0)
				# E = Mineral fibre (RSI/m 18.6, fit to framing)
				# F = Icynene (RSI/m 25.0, fit to framing)
				# G-I = Icynene, (RSI 2.2, 3.5, 4.4)
				# J-L = Fibreglass batt (RSI 7.0, 1.7, 5.6)
				# M = Woodshavings (fit to framing)
				# N = Newspaper (fit to framing)
				# O = Wood pieces, treat as Woodshavings (fit to framing)
				# P = Vermiculite (fit to framing)
				# Q = Straw (fit to framing)
				# R = EPS I (estimate 17 mm)
				# S = EPS II (estimate 17 mm)
				# T = XTPS IV, treat as EPS (estimate 17 mm)
				
			
				# determine the thickness for the specified insulation types
				$thickness = {1 => 56, 2 => 84, 3 => 140, 4 => 156, 5 => 196, 6 => 148, 7 => 207, 8 => 380, 'B' => 188, 'C' => 263, 'D' => 484, 'G' => 88, 'H' => 140, 'I' => 176, 'J' => 280, 'K' => 68, 'L' => 224, 'R' => 25, 'S' => 25, 'T' => 25}->{$code->{$comp}} or $thickness = 89;
				
				# in the case where no insulating layer exists, put in a very small EPS layer to adjust the RSI
				case (0) {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => 0.1, 'component' => $comp});} # none
				case (/[1-5]|[J-L]/) {push (@{$con->{'layers'}}, {'mat' => 'Fbrglas_Batt', 'thickness_mm' => $thickness, 'component' => $comp});}	# Batt @ thickness
				case [6..8] {push (@{$con->{'layers'}}, {'mat' => 'Cellulose_23.7', 'thickness_mm' => $thickness, 'component' => $comp});}	# Cellulose @ thickness
				case (/[B-D]/) {push (@{$con->{'layers'}}, {'mat' => 'Fibre_18.6', 'thickness_mm' => $thickness, 'component' => $comp});}	# Batt @ thickness
				case (/[G-I]/) {push (@{$con->{'layers'}}, {'mat' => 'Icynene_25.0', 'thickness_mm' => $thickness, 'component' => $comp});}	# Icynene @ thickness
				case (/[R-T]/) {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});}	# EPS and Icynene @ thickness
				
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
