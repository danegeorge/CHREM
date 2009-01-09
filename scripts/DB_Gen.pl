#!/usr/bin/perl
#  
#====================================================================
# DB_Gen.pl
# Author: Lukas Swan
# Date: Jan 2009
# Copyright: Dalhousie University
#
#
# INPUT USE:
#
#
#
# DESCRIPTION:
# This script generates the esp-r database files to facilitate opening 
# CSDDRD houses within prj. This script reads the material and 
# composite construction XML databases and generates the appropriate 
# ASCII columnar delimited format files required by ESP-r.
#
#
#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;
#use CSV;	# CSV-2 (for CSV split and join, this works best)
#use Array::Compare;	#A rray-Compare-1.15
#use threads;	# threads-1.71 (to multithread the program)
#use File::Path;	# File-Path-2.04 (to create directory trees)
#use File::Copy;	#(to copy the input.xml file)
use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen

#--------------------------------------------------------------------
# Generate the esp-r databases
#--------------------------------------------------------------------

my $mat_data;	# declare repository for material_db.xml readin
my @mat_list;	# declare an array to store (at index = material number) material name and description for use in developing the construction database
my $con_data;	# declare repository for constr_db.xml readin

MATERIALS: {
	my $mat_xml = new XML::Simple;	# create a XML simple
	$mat_data = $mat_xml->XMLin("../databases/mat_db.xml");	# readin the XML data

	LEGACY_FORMAT: {	# the columnar format
		open (MAT_DB, '>', "../databases/mat_db_xml.a") or die ("can't open  ../databases/mat_db_xml.a");	# open a writeout file

		print MAT_DB "# materials database (columnar format) constructed from mat_db.xml by DB_Gen.pl\n#\n";
		printf MAT_DB ("%5u%s", $#{$mat_data->{'class'}} + 1," # total number of classes\n#\n");	# print the number of classes
		print MAT_DB "# for each class list the: class #, # of materials in the class, and the class name.\n";
		print MAT_DB "#\t followed by for each material in the class:\n";
		print MAT_DB "#\t\t material number (20 * 'class number' + 'material position within class') and material name\n";
		print MAT_DB "#\t\t conductivity W/(m-K), density (kg/m**3), specific heat (J/(kg-K), emissivity, absorbitivity, vapor resistance\n";

		foreach my $class (0..$#{$mat_data->{'class'}}) {	# iterate over each class
			print MAT_DB "#\n#\n# CLASS\n";
			printf MAT_DB ("%5u%5u%s", 	# print the class information
				$class + 1,
				$#{$mat_data->{'class'}->[$class]->{'material'}} + 1,
				"   $mat_data->{'class'}->[$class]->{'class_name'}\n"
			);
			print MAT_DB ("# $mat_data->{'class'}->[$class]->{'description'}\n");	# print the class description
			print MAT_DB "#\n# MATERIALS\n";

			foreach my $material (0..$#{$mat_data->{'class'}->[$class]->{'material'}}) {
				printf MAT_DB ("%5u%s",	# print the material number and name
					$class * 20 + $material + 1,
					"   $mat_data->{'class'}->[$class]->{'material'}->[$material]->{'mat_name'}\n"
				);
				print MAT_DB ("# $mat_data->{'class'}->[$class]->{'material'}->[$material]->{'description'}\n");	# print the material description
				# print the material properties with consideration to columnar format and comma delimits
				printf MAT_DB ("%13.3f,%10.3f,%10.3f,%7.3f,%7.3f,%11.3f%s",
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'conductivity'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'density'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'spec_heat'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'emissivity_out'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'absorbtivity_out'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'vapor_resist'},
					"\n"
				);
			};
		};
		close MAT_DB;
	};

	NEW_FORMAT: {	# the tagged format version 1.1
		open (MAT_DB, '>', "../databases/mat_db_xml_1.1.a") or die ("can't open  ../databases/mat_db_xml_1.1.a");	# open a writeout file
		open (MAT_LIST, '>', "../databases/mat_db_xml_list") or die ("can't open  ../databases/mat_db_xml_list");	# open a list file that will simply list the materials and the numbers for use as a reference when making composite constructions

		print MAT_DB "*Materials 1.1\n";
		my $time = localtime();
		printf MAT_DB "*date,$time\n";
		print MAT_DB "*doc,Materials database (tagged format) constructed from mat_db.xml by DB_Gen.pl\n#\n";
		print MAT_LIST "Materials database constructed from material_db.xml by DB_Gen.pl\n\n";
		printf MAT_DB ("%u%s", $#{$mat_data->{'class'}} + 1," # total number of classes\n#\n");	# print the number of classes
		my $format = "# Material classes are listed as follows:
#	*class, 'class number'(2 digits),'number of materials in class','class name'
#	'class description
#
# Materials within each class are listed as follows:
#	*item,'material name','material number'(20 * 'class number' + 'material position within class'; 3 digits),'class number'(2 digits),'material description'
# The material tag is followed by the following material attributes:
#	conductivity (W/(m-K), density (kg/m**3), specific heat (J/(kg-K),
#	emissivity out (-), emissivity in (-), absorptivity out, (-) absorptivity in (-),
#	diffusion resistance (?), default thickness (mm),
#	flag [-] legacy [o] opaque [t] transparent [g] gas data+T cor [h] gas data at 4T
#
#	transparent material include additional attributes:
#		longwave tran (-), solar direct tran (-), solar reflec out (-), solar refled in (-),
#		visable tran (-), visable reflec out (-), visable reflec in (-), colour rendering (-)";
		print MAT_DB "$format\n";

		foreach my $class (0..$#{$mat_data->{'class'}}) {	# iterate over each class
			print MAT_DB "#\n#\n# CLASS\n";
			printf MAT_DB ("%s%2u%s%2u%s", "*class,", $class + 1, ",", $#{$mat_data->{'class'}->[$class]->{'material'}} + 1, ",$mat_data->{'class'}->[$class]->{'class_name'}\n");	# print the class information
			print MAT_LIST "$mat_data->{'class'}->[$class]->{'class_name'}\n";	# print the class name to the list
			print MAT_DB "$mat_data->{'class'}->[$class]->{'description'}\n";
			print MAT_DB "#\n# MATERIALS\n";
			foreach my $material (0..$#{$mat_data->{'class'}->[$class]->{'material'}}) {
				# print the material title line
				printf MAT_DB ("%s,%s,%3u,%2u,%s",
					"*item",
					"$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'mat_name'}",
					 $class * 20 + $material + 1,
					$class + 1,
					"$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'description'}\n"
				);
				# store the material name and description in an array for use with construction db
				$mat_list[ $class * 20 + $material + 1] = [$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'mat_name'}, $mat_data->{'class'}->[$class]->{'material'}->[$material]->{'description'}];
				printf MAT_LIST ("\t%3u\t%s",	# print material number, name, and description to the list
					$class * 20 + $material + 1,
					"$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'mat_name'} : $mat_data->{'class'}->[$class]->{'material'}->[$material]->{'description'}\n"
				);

				# print the first part of the material data line
				printf MAT_DB ("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.1f",
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'conductivity'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'density'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'spec_heat'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'emissivity_out'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'emissivity_in'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'absorbtivity_out'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'absorbtivity_in'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'vapor_resist'},
					$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'default_thickness'}
				);
				if ($mat_data->{'class'}->[$class]->{'material'}->[$material]->{'type'} eq "OPAQ") {print MAT_DB ",o\n";}
				elsif ($mat_data->{'class'}->[$class]->{'material'}->[$material]->{'type'} eq "TRAN") {
					print MAT_DB ",t,";
					printf MAT_DB ("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f\n",
						$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'optic_props'}{'trans_long'},
						$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'optic_props'}{'trans_solar'},
						$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'optic_props'}{'trans_vis'},
						$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'optic_props'}{'ref_solar_out'},
						$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'optic_props'}{'ref_solar_in'},
						$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'optic_props'}{'ref_vis_out'},
						$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'optic_props'}{'ref_vis_in'},
						$mat_data->{'class'}->[$class]->{'material'}->[$material]->{'optic_props'}{'clr_render'}
					);
				};
			};
		};
		close MAT_DB;
	};
};

CONSTRUCTIONS: {
	my $con_xml = new XML::Simple;	# create a XML simple
	$con_data = $con_xml->XMLin("../databases/con_db.xml");	# readin the XML data

	open (CON_DB, '>', "../databases/con_db_xml.a") or die ("can't open  ../databases/con_db_xml.a");	# open a writeout file
	open (TMC_DB, '>', "../databases/tmc_db_xml.a") or die ("can't open  ../databases/tmc_db_xml.a");	# open a writeout file

	print CON_DB "# composite constructions database (columnar format) constructed from con_db.xml by DB_Gen.pl based on mat_db.xml\n#\n";
	printf CON_DB ("%5u%s", $#{$con_data->{'construction'}} + 1," # total number of constructions\n#\n");	# print the number of constructions
	print CON_DB "# for each construction list the: # of layers, construction name, type (OPAQ or TRAN), Optics name (or OPAQUE), symmetry.\n";
	print CON_DB "#\t followed by for each material of the construction:\n";
	print CON_DB "#\t\t material number, thickness (m), material name, and if 'air' then RSI at vert horiz and sloped\n";

	foreach my $construction (0..$#{$con_data->{'construction'}}) {	# iterate over each construction
		print CON_DB "#\n#\n# CONSTRUCTION\n";

		if (ref ($con_data->{'construction'}->[$construction]->{'layer'}) eq 'HASH') {
			$con_data->{'construction'}->[$construction]->{'layer'} = [$con_data->{'construction'}->[$construction]->{'layer'}];
		};

		printf CON_DB ("%5u    %-14s%-6s", 	# print the construction information
			$#{$con_data->{'construction'}->[$construction]->{'layer'}} + 1,
			$con_data->{'construction'}->[$construction]->{'con_name'},
			$con_data->{'construction'}->[$construction]->{'type'}
		);

		if ($con_data->{'construction'}->[$construction]->{'type'} eq "OPAQ") {printf CON_DB ("%-14s", "OPAQUE");}
		elsif ($con_data->{'construction'}->[$construction]->{'type'} eq "TRAN") {
			printf CON_DB ("%-14s", $con_data->{'construction'}->[$construction]->{'optics'});
			print TMC_DB "#\n#\n";
			printf TMC_DB ("%-14s%s",
				$con_data->{'construction'}->[$construction]->{'optics'},
				": $con_data->{'construction'}->[$construction]->{'description'}\n"
			);
			print TMC_DB "# $con_data->{'construction'}->[$construction]->{'optic_props'}{'optical_description'}\n";
			printf TMC_DB ("%s%4u%7.3f%7.3f%7.3f%7.3f\n",
				"  1",
				$#{$con_data->{'construction'}->[$construction]->{'layer'}} + 1,
				$con_data->{'construction'}->[$construction]->{'optic_props'}{'trans_vis'},
				$con_data->{'construction'}->[$construction]->{'optic_props'}{'ref_solar'},
				$con_data->{'construction'}->[$construction]->{'optic_props'}{'abs_solar'},
				$con_data->{'construction'}->[$construction]->{'optic_props'}{'U_val'}
			);
			printf TMC_DB ("  %s %s\n",
				$con_data->{'construction'}->[$construction]->{'optic_props'}{'trans_dir'},
				$con_data->{'construction'}->[$construction]->{'optic_props'}{'heat_gain'}
			);
			print TMC_DB "# layers\n";
			foreach my $layer (0..$#{$con_data->{'construction'}->[$construction]->{'layer'}}) {
				printf TMC_DB ("  %4.3f %s\n",
					$con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'refr_index'},
					$con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'absorption'}
				);
			};
		};

		printf CON_DB ("%-14s\n", $con_data->{'construction'}->[$construction]->{'symmetry'});

		print CON_DB "# $con_data->{'construction'}->[$construction]->{'description'}\n";
		print CON_DB "#\n# MATERIALS\n";

		foreach my $layer (0..$#{$con_data->{'construction'}->[$construction]->{'layer'}}) {
			printf CON_DB ("%5u%10.4f",	# print the layers number and name
				$con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'material'},
				$con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'thickness'}
			);
			if ($con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'material'} == 0) {
				printf CON_DB ("%s%4.3f %4.3f %4.3f\n",
					"  air  ",
					$con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'air_RSI'}{'vert'},
					$con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'air_RSI'}{'horiz'},
					$con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'air_RSI'}{'slope'}
				);
			}
			else {
				print CON_DB "  $mat_list[$con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'material'}][0] : $mat_list[$con_data->{'construction'}->[$construction]->{'layer'}->[$layer]->{'material'}][1]\n";
			};
		};
	};
	close CON_DB;
};
