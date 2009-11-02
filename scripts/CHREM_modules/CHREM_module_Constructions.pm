# ====================================================================
# CHREM_module_Constructions.pm
# Author: Lukas Swan
# Date: Oct 2009
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# con_layers: push the appropriate layers onto the construction array
# con_reverse: copies and reverse the layers of a construction (e.g. reversing main ceiling to be attic floor)
# con_10_dig: develops the layers for the 10 digit codes
# con_5_dig: develops the layers for the 5 digit codes
# con_6_dig: develops the layers for the 6 digit codes
# ====================================================================

# Declare the package name of this perl module
package CHREM_module_Constructions;

# Declare packages used by this perl module
use strict;
# use CSV;	# CSV-2 (for CSV split and join, this works best)
use Data::Dumper;
# use List::Util ('shuffle');
use Switch;

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('con_layers', 'con_reverse', 'con_10_dig', 'con_5_dig', 'con_6_dig');


# ====================================================================
# con_layers
# This subroutine recieves the code and component and places the appropriate layers
# on the construction array. The intent is to reuse the lookup thicknesses and types
# for multiple construction types.
# ====================================================================

sub con_layers {

	my $comp = shift; # the component to add
	my $code = shift; # reference to the code hash
	my $con = shift; # reference to the construction array

	my $thickness; # scalar of the thickness so we do not require repeated 'my' on single line (see anonymous hash and 'or' below)

	switch ($comp) {

		# siding
		case (/^siding$/) {
			# This presently covers the following siding:
			# 0 = None
			# 1 = Wood (lapped), assume 12 mm thick
			# 2 = Hollow metal/vinyl, assume Vinyl and 3 mm thick
			# 3 = Insul metal/vinyl, assume Vinyl and 8 mm thick
			# 4 = Brick, assume 100 mm thick
			# 5 = Mortar, assume Concrete and 25 mm thick
			# 6 = Stucco, assume Concrete and 25 mm thick
			# 7 = Stone, assume 25 mm thick
			
			switch ($code->{$comp}) {
				case (0) {} # none
				case (1) {push (@{$con->{'layers'}}, {'mat' => 'SPF', 'thickness_mm' => 25, 'component' => $comp});}	# wood
				case (2) {push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 3, 'component' => $comp});}	# metal/vinyl
				case (3) {push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 8, 'component' => $comp});}	# insulated metal/vinyl
				case (4) {push (@{$con->{'layers'}}, {'mat' => 'Brick', 'thickness_mm' => 100, 'component' => $comp});}	# brick
				case [5, 6] {push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => 25, 'component' => $comp});}	# mortar and stucco
				case (7) {push (@{$con->{'layers'}}, {'mat' => 'Stone', 'thickness_mm' => 25, 'component' => $comp});}	# stone
				else {push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 3, 'component' => $comp});};	# assume vinyl
			};
		}
		
		# sheathing
		case (/^sheathing$/) {
			# This presently covers the following sheathing:
			# 0 = None
			# 1-3 = Waferboard/OSB (mm 9.5, 11.1, 15.9)
			# 4-7 = Plywood (mm 9.5, 12.7, 15.5, 18.5)
			# 8-9 = Fibreboard (mm 9.5, 11.1)
			# A-B = Gypsum sheathing, assume Drywall (mm 9.5, 12.7)
			# C = Concrete slab (mm 50.8)
		
			switch ($code->{$comp}) {
				# these thicknesses correspond to the types in mm
				$thickness = {1 => 9.5, 2 => 11.1, 3 => 15.9, 4 => 9.5, 5 => 12.7, 6 => 15.5, 7 => 18.5, 8 => 9.5, 9 => 11.1, 'A' => 9.5, 'B' => 12.7, 'C' => 50.8}->{$code->{$comp}} or $thickness = 11.1;
				case (0) {} # none
				case [1..3] {push (@{$con->{'layers'}}, {'mat' => 'OSB', 'thickness_mm' => $thickness, 'component' => $comp});}	# Oriented strand board @ thickness
				case [4..7] {push (@{$con->{'layers'}}, {'mat' => 'Plywood', 'thickness_mm' => $thickness, 'component' => $comp});}	# plywood @ thickness
				case [8..9] {push (@{$con->{'layers'}}, {'mat' => 'MDF', 'thickness_mm' => $thickness, 'component' => $comp});}	# MDF @ thickness
				case (/A|B/) {push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp});}	# Drywall @ thickness
				case (/C/) {push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => $thickness, 'component' => $comp});}	# Concrete @ thickness
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
			# 9 = Same as Insul 1, call insulation_1 again and then rename the component to insulation_2
			# A = EPS II (mm 50)
			# B = XTPS IV, treat as EPS (mm 25)
			# C = EPS II (mm 25)
				
			switch ($code->{$comp}) {
				# these thicknesses correspond to the types in mm
				$thickness = {1 => 50, 2 => 38, 3 => 76, 4 => 19, 5 => 38, 6 => 64, 7 => 25, 8 => 19, 'A' => 50, 'B' => 25, 'C' => 25}->{$code->{$comp}} or $thickness = 19;
				case (0) {} # none
				case [1..8] {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});}	# EPS @ thickness
				case (9) {
					$con = con_layers('insulation_1', $code, $con);	# same as insulation_1 by calling insulation_1
					# because the preceding will add a second 'insulation_1' layer, we want to rename the component to 'insulation_2'
					$con->{'layers'}->[$#{$con->{'layers'}}]->{'component'} = $comp;
				}
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
					$con = con_layers('insulation_1', $code, $con);
				}
				case (5) {	# insulating concrete block
					push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => 30, 'component' => $comp . '_2'});
					$con = con_layers('insulation_1', $code, $con);
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
					$con = con_layers('insulation_1', $code, $con);
				}
				case (/E/) {
					push (@{$con->{'layers'}}, {'mat' => 'SPF', 'thickness_mm' => 102, 'component' => $comp});	# Plank logs @ thickness
					$con = con_layers('insulation_1', $code, $con);
				}
				case (/F/) {
					push (@{$con->{'layers'}}, {'mat' => 'Brick', 'thickness_mm' => 200, 'component' => $comp});	# Brick @ thickness
					$con = con_layers('insulation_1', $code, $con);
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
			$con = con_layers('insulation_1', $code, $con);
		}

		# insulation_fndn_slab - the layer above the foundation slab
		case (/^insulation_fndn_slab$/) {
		
			switch ($code->{$comp}) {
				# This presently covers the following insulations:
				# 0 = None
				# 1-5 = Fibreglass batt (RSI 1.4, 2.1, 3.5, 3.9, 4.9)
				# 6 = EPS I (mm 50)
				# 7-8 = EPS II (mm 38, 76)
				# 9, A-B = XTPS IV, treat as EPS (mm 19, 38, 64)
				# C = Semi-rigid, treat as EPS (mm 25)
				# D = Isocyanurate, treat as EPS (mm 19)
				# E = Rigid glass fibre, treat as Fibreglass batt (mm 50)
				# F = EPS II (mm 50)
				
				# determine the thickness for the specified insulation types
				$thickness = {1 => 56, 2 => 84, 3 => 140, 4 => 156, 5 => 196, 6 => 50, 7 => 38, 8 => 76, 9 => 19, 'A' => 38, 'B' => 64, 'C' => 25, 'D' => 19, 'E' => 50, 'F' => 50}->{$code->{$comp}} or $thickness = 89;
				
				# in the case where no insulating layer exists, put in a very small EPS layer to adjust the RSI
				case (0) {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => 0.1, 'component' => $comp});} # none
				case [1..5] {push (@{$con->{'layers'}}, {'mat' => 'Fbrglas_Batt', 'thickness_mm' => $thickness, 'component' => $comp});}	# Batt @ thickness
				case (/[6-9]|[A-D]|E/) {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => $thickness, 'component' => $comp});}	# EPS @ thickness
				case (/F/) {push (@{$con->{'layers'}}, {'mat' => 'Fibre_18.6', 'thickness_mm' => $thickness, 'component' => $comp});}	# Batt @ thickness
				else {push (@{$con->{'layers'}}, {'mat' => 'Fbrglas_Batt', 'thickness_mm' => $thickness, 'component' => $comp});};	# assume batt
			};
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
					
					if ($code->{'name'} =~ /^M_wall$|^B_pony$/) {
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
			# This presently covers the following sheathing:
			# 0 = None
			# 1 = Gypsum, treat as Drywall (mm 12)
			# 2 = Gypsum + non insul strapping, treat as Drywall (estimate mm 12)
			# 3 = Gypsum + insul strapping RSI 1.4, treat as Drywall (estimate mm 12)
			# 4 = Tile/Linoleum, treat as Vinyl (estimate mm 3)
			# 5 = Gypsum + Tile/Linoleum, treat as Drywall (est. 12 mm) and Vinyl (est. mm 3)
			# 6 = Wood (est. 12 mm)
			# 7 = Gypsum + Wood, treat as Drywall + wood (est. 12 mm each)
			# 8 = Carpet & underpad, treat as EPS 4 mm thick
			# 9 = Lath and plaster, treat as Drywall (est. 12 mm)
				
			switch ($code->{$comp}) {
				$thickness = 12;
				case (0) {} # none
				case [1..3, 9] {push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp});}	# Drywall and lath/plaster
				case (4) {push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 3, 'component' => $comp});}	# linoleum
				case (5) {
					push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp . '_2'});	# drywall
					push (@{$con->{'layers'}}, {'mat' => 'Vinyl', 'thickness_mm' => 3, 'component' => $comp . '_1'});	# linoleum
				}
				case (6) {push (@{$con->{'layers'}}, {'mat' => 'SPF', 'thickness_mm' => $thickness, 'component' => $comp});}	# wood
				case (7) {
					push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp . '_2'});	# drywall
					push (@{$con->{'layers'}}, {'mat' => 'SPF', 'thickness_mm' => $thickness, 'component' => $comp . '_1'});	# wood
				}
				case (8) {push (@{$con->{'layers'}}, {'mat' => 'EPS', 'thickness_mm' => 4, 'component' => $comp});}	# Carpet + underpad
				else {push (@{$con->{'layers'}}, {'mat' => 'Drywall', 'thickness_mm' => $thickness, 'component' => $comp});};	# assume Drywall
			};
		}
		
		
		else {die "Bad Call to sub construction' - there is no component: $comp\n"};
	};
	
	return ($con);
};



# ====================================================================
# con_reverse
# This subroutine recieves the facing zone's surface characteristics
# and reverses them for the present zone's surface.
# For example, the attic/roof floor is the reverse of the of main_highest
# ceiling.
# ====================================================================

sub con_reverse {

	my $con = shift; # the construction hash reference for the particular zone and surface
	my $record_indc = shift; # reference to the record indicator
	my $facing = shift; # reference to the facing surface and conditions for this zone's surface

	# copy the other zones facing surface because it was generated first
	%{$con} = %{$record_indc->{$facing->{'zone_name'}}->{'surfaces'}->{$facing->{'surface_name'}}->{'construction'}};
	
	# reverse the name by the surrounding '->'
# 	print "orig name $con->{'name'}\n";
	$con->{'name'} =~ s/(\w+)->(\w+)/$2->$1/;
# 	print "rev name $con->{'name'}\n";
	
	# reverse the layer order
	@{$con->{'layers'}} = reverse (@{$con->{'layers'}});
	
	# state it is copy/reversed
	$con->{'from'} = 'REVERSE';

	return (1);
};




# ====================================================================
# con_10_dig
# This subroutine develops the layers for the common 10 digit code
# This code shows up for main walls, exposed ceilings and floors, pony walls, etc.
# ====================================================================

sub con_10_dig {
	# STORE THE PASSED INFORMATION 
	my $field_name = shift; # the construction name that we are looking for: e.g. main_wall or bsmt_slab_insul
	my $con = shift; # reference to the construction
	my $CSDDRD = shift; # reference to the CSDDRD

	# CHECK THE CODE FOR VALIDITY
	# The code should be 10 alphanumeric characters, note that a whitespace trim is applied and we check that it is not all zeroes
	if ($CSDDRD->{$field_name . '_code'} =~ s/^\s*(\w{10})\s*$/$1/ && $CSDDRD->{$field_name . '_code'} !~ /0{10}/) {
		
		# DECLARE A HASH REFERENCE AND STORE THE CODE NAME AS THE CONSTRUCTION NAME
		my $code = {'name' => $con->{'name'}};

		# STORE THE BROKEN UP CODE
		# Declare fields for each digit of the code
		my @fields = ('index', 'type', 'framing', 'spacing', 'insulation_1', 'insulation_2', 'interior', 'sheathing', 'siding', 'other');
		
		# split the code up by each digit and store it based on component (hash slice)
		@{$code}{@fields} = split (//, $CSDDRD->{$field_name . '_code'});
		

		# WORK FROM THE OUTSIDE TO THE INSIDE MAKING LAYERS (SIDING, SHEATHING, INSULATION_2)
		$con = con_layers('siding', $code, $con);
		$con = con_layers('sheathing', $code, $con);
		$con = con_layers('insulation_2', $code, $con);
		
		# CHECK THE CONSTRUCTION TYPE TO DETERMINE THE NEXT SET OF LAYERS
		# first declare a hash reference that keys the type value to a type string
		my $type = {6 => 'solid', 7 => 'panel'};
		
		# check to see if the type is valid and if so build those layers (e.g. solid or panel)
		if (defined ($type->{$code->{'type'}})) {
			$con = con_layers($type->{$code->{'type'}}, $code, $con);
		}

		# all other types are framed, so treat as insulation for now
		else {
			$con = con_layers('framed', $code, $con);
		};

		# INTERIOR
		$con = con_layers('interior', $code, $con);
		
		# SUCCESSFUL LAYERING, SO RETURN TRUE
		return (1);
	};
	
	# IF THE LAYERING WAS NOT SUCCESSFUL, RETURN FALSE
	return (0);

};

# ====================================================================
# con_5_dig
# This subroutine develops the layers for the common 5 digit code
# This code shows up for interior insulated foundation floors
# ====================================================================

sub con_5_dig {
	# STORE THE PASSED INFORMATION 
	my $field_name = shift; # the construction name that we are looking for: e.g. main_wall or bsmt_slab_insul
	my $con = shift; # reference to the construction
	my $CSDDRD = shift; # reference to the CSDDRD

	# CHECK THE CODE FOR VALIDITY
	# The code should be 5 alphanumeric characters, note that a whitespace trim is applied and we check that it is not all zeroes
	if ($CSDDRD->{$field_name . 'code'} =~ s/^\s*(\w{5})\s*$/$1/ && $CSDDRD->{$field_name . 'code'} !~ /0{5}/) {
		
		# DECLARE A HASH REFERENCE AND STORE THE CODE NAME AS THE CONSTRUCTION NAME
		my $code = {'name' => $con->{'name'}};

		# STORE THE BROKEN UP CODE
		# Declare fields for each digit of the code
		my @fields = ('framing', 'spacing', 'insulation_fndn_slab', 'interior', 'sheathing');
		
		# split the code up by each digit and store it based on component (hash slice)
		@{$code}{@fields} = split (//, $CSDDRD->{$field_name . '_code'});
		

		# WORK FROM THE OUTSIDE TO THE INSIDE MAKING LAYERS (SIDING, SHEATHING, INSULATION_2)
		# push the concrete slab
		push (@{$con->{'layers'}}, {'mat' => 'Concrete', 'thickness_mm' => 76, 'component' => 'slab'});	# Concrete @ thickness
		
		# sheathing
		$con = con_layers('sheathing', $code, $con);
		
		# insulation_fndn_slab
		$con = con_layers('insulation_fndn_slab', $code, $con);

		# INTERIOR
		$con = con_layers('interior', $code, $con);
		
		# SUCCESSFUL LAYERING, SO RETURN TRUE
		return (1);
	};
	
	# IF THE LAYERING WAS NOT SUCCESSFUL, RETURN FALSE
	return (0);

};


# ====================================================================
# con_6_dig
# This subroutine develops the layers for the common 6 digit code
# This code shows up for interior insulated foundation walls
# ====================================================================

sub con_6_dig {
	# STORE THE PASSED INFORMATION 
	my $field_name = shift; # the construction name that we are looking for: e.g. main_wall or bsmt_slab_insul
	my $con = shift; # reference to the construction
	my $CSDDRD = shift; # reference to the CSDDRD

	# CHECK THE CODE FOR VALIDITY
	# The code should be 6 alphanumeric characters, note that a whitespace trim is applied and we check that it is not all zeroes
	if ($CSDDRD->{$field_name . 'code'} =~ s/^\s*(\w{6})\s*$/$1/ && $CSDDRD->{$field_name . 'code'} !~ /0{6}/) {
		
		# DECLARE A HASH REFERENCE AND STORE THE CODE NAME AS THE CONSTRUCTION NAME
		my $code = {'name' => $con->{'name'}};

		# STORE THE BROKEN UP CODE
		# Declare fields for each digit of the code
		my @fields = ('framing', 'spacing', 'studs', 'insulation_1', 'insulation_fndn_slab', 'interior');
		
		# split the code up by each digit and store it based on component (hash slice)
		@{$code}{@fields} = split (//, $CSDDRD->{$field_name . '_code'});
		

		# WORK FROM THE OUTSIDE TO THE INSIDE MAKING LAYERS (insulation_fndn_slab, insulation_1, interior)
		
		# insulation_fndn_slab
		$con = con_layers('insulation_fndn_slab', $code, $con);
		
		# insulation_1
		$con = con_layers('insulation_1', $code, $con);

		# INTERIOR
		$con = con_layers('interior', $code, $con);
		
		# SUCCESSFUL LAYERING, SO RETURN TRUE
		return (1);
	};
	
	# IF THE LAYERING WAS NOT SUCCESSFUL, RETURN FALSE
	return (0);

};


# Final return value of one to indicate that the perl module is successful
1;
