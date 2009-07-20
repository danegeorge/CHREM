# ====================================================================
# CHREM_modules::Database.pl
# Author: Lukas Swan
# Date: July 2009
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# database_XML: this file reads the XML files and generates ESP-r database and passes the info back to the calling program
# ====================================================================

# Declare the package name of this perl module
package CHREM_modules::Database;

# Declare packages used by this perl module
use strict;
use XML::Simple;	# to parse the XML databases

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('database_XML');

# ====================================================================
# database_XML
# This subroutine generates the esp-r database files to facilitate opening 
# CSDDRD houses within prj. This script reads the material and 
# composite construction XML databases and generates the appropriate 
# ASCII columnar delimited format files required by ESP-r. It then passes
# back the XML information in hash format to the calling program for use
# ====================================================================

sub database_XML {
	my $mat_name;	# declare an array ref to store (at index = material number) a reference to that material in the mat_db.xml
	my $con_name;	# declare a hash ref to store (at key = construction name) a reference to that construction in the con_db.xml
	my $optic_data;	# declare a hash ref to store the optical data from optic_db.xml

	my $mat_data;	# declare repository for mat_db.xml readin
	my $con_data;	# declare repository for con_db.xml readin
# 		my $optic_data;	# declare repository for optic_db.xml readin

	MATERIALS: {
		$mat_data = XMLin("../databases/mat_db.xml", ForceArray => 1);	# readin the XML data, note that any hash with properties will recieve an array index even if there is only one of that hash
		open (MAT_DB_XML, '>', "../databases/mat_db_regen.xml") or die ("can't open  ../databases/mat_db_regen.xml");	# open a writeout file
		print MAT_DB_XML XMLout($mat_data);	# printout the XML data
		close MAT_DB_XML;

		NEW_FORMAT: {	# the tagged format version 1.1
			open (MAT_DB, '>', "../databases/mat_db_xml_1.1.a") or die ("can't open  ../databases/mat_db_xml_1.1.a");	# open a writeout file
			open (MAT_LIST, '>', "../databases/mat_db_xml_list") or die ("can't open  ../databases/mat_db_xml_list");	# open a list file that will simply list the materials for use as a reference when making composite constructions

			print MAT_DB "*Materials 1.1\n";	# print the head tag line
			my $time = localtime();	# determine the time
			printf MAT_DB ("%s,%s\n", "*date", $time);	# print the time
			print MAT_DB "*doc,Materials database (tagged format) constructed from mat_db.xml by DB_Gen.pl\n#\n";	# print the documentation tag line

			printf MAT_DB ("%d%s", $#{$mat_data->{'class'}}," # total number of classes\n#\n");	# print the number of classes

			# specification of file format
			printf MAT_DB ("%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n",
				"# Material classes are listed as follows:",
				"#	*class, 'class number'(2 digits),'number of materials in class','class name'",
				"#	'class description",
				"#",
				"# Materials within each class are listed as follows:",
				"#	*item,'material name','material number'(20 * 'class number' + 'material position within class'; 3 digits),'class number'(2 digits),'material description'",
				"# The material tag is followed by the following material attributes:",
				"#	conductivity (W/(m-K), density (kg/m**3), specific heat (J/(kg-K),",
				"#	emissivity out (-), emissivity in (-), absorptivity out, (-) absorptivity in (-),",
				"#	diffusion resistance (?), default thickness (mm),",
				"#	flag [-] legacy [o] opaque [t] transparent [g] gas data+T cor [h] gas data at 4T",
				"#",
				"#	transparent material include additional attributes:",
				"#		longwave tran (-), solar direct tran (-), solar reflec out (-), solar refled in (-),",
				"#		visable tran (-), visable reflec out (-), visable reflec in (-), colour rendering (-)"
			);

			print MAT_LIST "Materials database constructed from material_db.xml by DB_Gen.pl\n\n";

			foreach my $class_num (0..$#{$mat_data->{'class'}}) {	# iterate over each class
				my $class = $mat_data->{'class'}->[$class_num];	# simplify the class reference to a simple scalar for use

				if ($class->{'class_name'} eq 'gap') {$class->{'class_name'} = 'Gap';};
				print MAT_LIST "\n$class->{'class_name'} : $class->{'description'}\n";	# print the class name and description to the list

				unless ($class->{'class_name'} eq 'Gap') {	# do not print out for Gap
					print MAT_DB "#\n#\n# CLASS\n";	# print a common identifier

					printf MAT_DB ("%s,%2d,%2d,%s\n",	# print the class information
						"*class",	# class tag
						$class_num,	# class number
						$#{$class->{'material'}} + 1,	# number of materials in the class
						"$class->{'class_name'}"	# class name
					);
					print MAT_DB "$class->{'description'}\n";	# print the class description

					print MAT_DB "#\n# MATERIALS\n";	# print a common identifier
				};

				foreach my $mat_num (0..$#{$class->{'material'}}) {	# iterate over each material within the class
					my $mat = $class->{'material'}->[$mat_num];
					$mat_name->{$mat->{'mat_name'}} = $mat;	# set mat_name equal to a reference to the material
					if ($class->{'class_name'} eq 'Gap') {$mat->{'mat_num'} = 0;}	# material is Gap so set equal to mat_num 0
					else {$mat->{'mat_num'} = ($class_num - 1) * 20 + $mat_num + 1;};	# add a key in the material equal to the ESP-r material number

					print MAT_LIST "\t$mat->{'mat_name'} : $mat->{'description'}\n";	# material name and description

					unless ($class->{'class_name'} eq 'Gap') {	# do not print out for Gap
						printf MAT_DB ("%s,%s,%3d,%2d,%s",	# print the material title line
							"*item",	# material tag
							"$mat->{'mat_name'}",	# material name
							$mat->{'mat_num'},	# material number (groups of 20)
							$class_num,
							"$mat->{'description'}\n"	# material description
						);

						# print the first part of the material data line
						foreach my $property ('conductivity_W_mK', 'density_kg_m3', 'spec_heat_J_kgK', 'emissivity_out', 'emissivity_in', 'absorptivity_out', 'absorptivity_in', 'vapor_resist') {
							printf MAT_DB ("%.3f,", $mat->{$property});
						};
						printf MAT_DB ("%.1f", $mat->{'default_thickness_mm'});	# this property has a different format but is on the same line

						if ($mat->{'type'} eq "OPAQ") {print MAT_DB ",o\n";} # opaque material so print last digit of line
						elsif ($mat->{'type'} eq "TRAN") {	# translucent material so print t and additional data
							print MAT_DB ",t,";	# print TRAN identifier
							# print the translucent properties
							foreach my $property ('trans_long', 'trans_solar', 'trans_vis', 'refl_solar_out', 'refl_solar_in', 'refl_vis_out', 'refl_vis_in') {
								printf MAT_DB ("%.3f,", $mat->{'optic_mat_props'}->[0]->{$property});
							};
							printf MAT_DB ("%.3f\n", $mat->{'optic_mat_props'}->[0]->{'clr_render'});	# print the last part of translucent properties line
						};
					};
				};
			};
			print MAT_DB "*end\n";	# print the end tag
			close MAT_DB;
			close MAT_LIST;
		};
	};


	OPTICS: {
		$optic_data = XMLin("../databases/optic_db.xml", ForceArray => 1);	# readin the XML data, note that any hash with properties will recieve an array index even if there is only one of that hash
		open (OPTIC_DB_XML, '>', "../databases/optics_db_regen.xml") or die ("can't open  ../databases/optics_db_regen.xml");	# open a writeout file
		print OPTIC_DB_XML XMLout($optic_data);	# printout the XML data
		close OPTIC_DB_XML;

		open (OPTIC_DB, '>', "../databases/optic_db_xml.a") or die ("can't open  ../databases/optic_db_xml.a");	# open a writeout file for the optics database
		open (OPTIC_LIST, '>', "../databases/optic_db_xml_list") or die ("can't open  ../databases/optic_db_xml_list");	# open a list file that will simply list the optic name and description 

		# provide the header lines and instructions to the optics database
		print OPTIC_DB "# optics database (columnar format) constructed from con_db.xml by DB_Gen.pl based on mat_db.xml\n#\n";

		# print the file format
		foreach my $statement (
			"# optical properties db for default windows and most of the information",
			"# required to automatically build transparent constructions & tmc files.",
			"#",
			"# 1st line of each item is column sensitive and holds:",
			"# an identifier (12 char) followed by a description",
			"# 2nd line holds:",
			"# a) the number of default (always 1?) and tmc layers (equal to construction)",
			"# b) visable trans ",
			"# c) solar reflectance (outside)",
			"# d) overall solar absorbed",
			"# e) U value (for reporting purposes only)",
			"# 3rd line holds:",
			"# a) direct solar tran at 0deg 40deg 55deg 70deg 80deg from normal",
			"# b) total heat gain at the same angles (for reporting purposes only)",
			"# then for each layer there is a line containing",
			"# a) refractive index",
			"# b) solar absorption at 0deg 40deg 55deg 70deg 80deg from normal",
			"#",
			"#"
			) {printf OPTIC_DB ("%s\n", $statement);
			};

		my @optics = sort {$a cmp $b} keys (%{$optic_data});	# sort optic types to order the printout


		foreach my $optic (@optics) {

			my $opt = $optic_data->{$optic}->[0];	# shorten the name for subsequent use

			# fill out the optics database (TMC)
			printf OPTIC_DB ("%-14s%s\n",
				$optic,	# print the optics name
				": $opt->{'description'}"	# print the optics description
			);

			printf OPTIC_LIST ("%-14s%s\n",
				$optic,	# print the optics name
				": $opt->{'description'}"	# print the optics description
			);

			print OPTIC_DB "# $opt->{'optic_con_props'}->[0]->{'optical_description'}\n";	# print additional optical description

			# print the one time optical information
			printf OPTIC_DB ("%s%4d%7.3f%7.3f%7.3f%7.3f\n",
				"  1",
				$#{$opt->{'layer'}} + 1,
				$opt->{'optic_con_props'}->[0]->{'trans_vis'},
				$opt->{'optic_con_props'}->[0]->{'refl_solar_doc_only'},
				$opt->{'optic_con_props'}->[0]->{'abs_solar_doc_only'},
				$opt->{'optic_con_props'}->[0]->{'U_val_W_m2K_doc_only'}
			);

			# print the transmission and heat gain values at different angles for the construction type
			printf OPTIC_DB ("  %s %s\n",
				$opt->{'optic_con_props'}->[0]->{'trans_solar'},
				$opt->{'optic_con_props'}->[0]->{'heat_gain_doc_only'}
			);

			print OPTIC_DB "# layers\n";	# print a common identifier
			# print the refractive index and abs values at different angles for each layer of the transluscent construction type
			foreach my $layer (@{$opt->{'layer'}}) {	# iterate over construction layers
				printf OPTIC_DB ("  %4.3f %s\n",
					$layer->{'refr_index'},
					$layer->{'absorption'}
				);
			};
		};

		close OPTIC_DB;
		close OPTIC_LIST;
	};

	CONSTRUCTIONS: {
		$con_data = XMLin("../databases/con_db.xml", ForceArray => 1);	# readin the XML data, note that any hash with properties will recieve an array index even if there is only one of that hash
		open (CON_DB_XML, '>', "../databases/con_db_regen.xml") or die ("can't open  ../databases/con_db_regen.xml");	# open a writeout file
		print CON_DB_XML XMLout($con_data);	# printout the XML data
		close CON_DB_XML;

		open (CON_DB, '>', "../databases/con_db_xml.a") or die ("can't open  ../databases/con_db_xml.a");	# open a writeout file for the constructions
		open (CON_LIST, '>', "../databases/con_db_xml_list") or die ("can't open  ../databases/con_db_xml_list");	# open a list file that will simply list the materials 

		print CON_DB "# composite constructions database (columnar format) constructed from con_db.xml by DB_Gen.pl based on mat_db.xml\n#\n";	# heading intro line
		print CON_LIST "# composite constructions database (columnar format) constructed from con_db.xml by DB_Gen.pl based on mat_db.xml\n#\n";	# heading intro line

		printf CON_DB ("%5d%s\n", $#{$con_data->{'construction'}} + 1," # total number of constructions\n#");	# print the number of constructions

		printf CON_DB ("%s\n%s\n%s\n",	# format instructions for the construction database
			"# for each construction list the: # of layers, construction name, type (OPAQ or TRAN), Optics name (or OPAQUE), symmetry.",
			"#\t followed by for each material of the construction:",
			"#\t\t material number, thickness (m), material name, and if 'Gap' then RSI at vert horiz and sloped"
		);

		foreach my $con (@{$con_data->{'construction'}}) {	# iterate over each construction
			print CON_DB "#\n#\n# CONSTRUCTION\n";	# print a common identifier

			print CON_LIST "\n$con->{'con_name'} : $con->{'type'} : $con->{'symmetry'} : $con->{'description'}\n";	# print the construction name and description to the list

			printf CON_DB ("%5d    %-14s%-6s", 	# print the construction information
				$#{$con->{'layer'}} + 1,	# number of layers in the construction
				$con->{'con_name'},	# construction name
				$con->{'type'}	# type of construction (OPAQ or TRAN)
			);
			$con_name->{$con->{'con_name'}} = $con;

			if ($con->{'type'} eq "OPAQ") {printf CON_DB ("%-14s", "OPAQUE");}	# opaque so no line to optics database
			elsif ($con->{'type'} eq "TRAN") {printf CON_DB ("%-14s", $con->{'optic_name'});};	# transluscent construction so link to the optics database


			printf CON_DB ("%-14s\n", $con->{'symmetry'});	# print symetrical or not

			print CON_DB "# $con->{'description'}\n";	# print the construction description
			print CON_DB "#\n# MATERIALS\n";	# print a common identifier

			foreach my $layer (@{$con->{'layer'}}) {	# iterate over construction layers
				# check if the material is Gap
				if ($layer->{'mat_name'} eq 'gap') {	# check spelling of Gap and fix if necessary
					$layer->{'mat_name'} = "Gap";
				};

				printf CON_DB ("%5d%10.4f",	# print the layers number and name
					$mat_name->{$layer->{'mat_name'}}->{'mat_num'},	# material number
					$layer->{'thickness_mm'} / 1000	# material thickness in (m)
				);

				if ($layer->{'mat_name'} eq 'Gap') {	# it is Gap based on material number zero
					# print the RSI properties of Gap for the three positions that the construction may be placed in
					printf CON_DB ("%s%4.3f %4.3f %4.3f\n",
						"  Gap  ",
						$layer->{'gap_RSI'}->[0]->{'vert'},
						$layer->{'gap_RSI'}->[0]->{'horiz'},
						$layer->{'gap_RSI'}->[0]->{'slope'}
					);
				}
				else {	# not Gap so simply report the name and descriptions
					print CON_DB "  $layer->{'mat_name'} : $mat_name->{$layer->{'mat_name'}}->{'description'}\n";	# material name and description from the list
				};

				print CON_LIST "\t$layer->{'mat_name'} : $layer->{'thickness_mm'} (mm) : $mat_name->{$layer->{'mat_name'}}->{'description'}\n";	# material name and description
			};
		};
		close CON_DB;
		close CON_LIST;
	};

	return ($mat_name, $con_name, $optic_data);
};


# Final return value of one to indicate that the perl module is successful
1;
