#!/usr/bin/perl
# 
#====================================================================
# Secondary_sys-type.pl
# Author:    Rasoul Asaee
# Date:      November 2013
# Copyright: Dalhousie University
#
#
# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"] [fuel type that used for space heating seperated by "/"; 0 means all] 
#
# DESCRIPTION:
# This script simply organize houses based on secondary system type for space heating and 
# put it in a file. These data can be used to make a decision about novel secondary system 
# to be added to the CHREM.
#===================================================================

#--------------------------------------------------------------------
# Declare modules which are used
#--------------------------------------------------------------------
use warnings;
use strict;
use CSV;		#CSV-2 (for CSV split and join, this works best)
use Switch;
use Data::Dumper;

use lib qw(./modules);
use General;

#--------------------------------------------------------------------
# Declare the global variables
#--------------------------------------------------------------------
my @hse_types;					# declare an array to store the desired house types
my %hse_names = (1, "1-SD", 2, "2-DR");		# declare a hash with the house type names

my @regions;					#Regions to generate
my %region_names = (1, "1-AT", 2, "2-QC", 3, "3-OT", 4, "4-PR", 5, "5-BC");


my @fuels;					# Fuel source type for space heating
my %fuel_names = (1, "Electricity", 2, "Natural Gas", 3, "Oil", 4, "Propane", 5, "Mixed wood", 6, "Hardwood", 7, "Softwood", 8, "Wood Pellets");

#--------------------------------------------------------------------
# Read the command line input arguments
#--------------------------------------------------------------------
COMMAND_LINE: {
	if ($#ARGV != 2) {die "Three arguments are required: house_types regions fuel_type\n";};
	
	if ($ARGV[0] eq "0") {@hse_types = (1, 2);}	# check if both house types are desired
	else {
		@hse_types = split (/\//,$ARGV[0]);	# House types to generate
		foreach my $type (@hse_types) {
			unless (defined ($hse_names{$type})) {
				my @keys = sort {$a cmp $b} keys (%hse_names);
				die "House type argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
			};
		};
	};
	
	if ($ARGV[1] eq "0") {@regions = (1, 2, 3, 4, 5);}
	else {
		@regions = split (/\//,$ARGV[1]);	# House regions to generate
		foreach my $region (@regions) {
			unless (defined ($region_names{$region})) {
				my @keys = sort {$a cmp $b} keys (%region_names);
				die "Region argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
			};
		};
	};

	if ($ARGV[2] eq "0") {@fuels = (1, 2, 3, 4, 5, 6, 7, 8);}
	else {
		@fuels = split (/\//, $ARGV[2]);	# upgrade types to generate
		foreach my $fuel (@fuels) {
			unless (defined ($fuel_names{$fuel})) {
				my @keys = sort {$a cmp $b} keys (%fuel_names);
				die "Fuel argument must be one or more of the following numeric values seperated by a \"/\": 0 @keys\n";
			}
		}
	}
};

#--------------------------------------------------------------------
# Main program
#--------------------------------------------------------------------
my $FILEIN;
my $count;
my $COUNT;
open ($COUNT, '>', '../Secondary_system/Count.csv') or die ('../Secondary_system/Count.csv');
my @header = ('*header', 'hse_type', 'region', 'fuel', 'system_type', 'count', 'total', 'percent');
print $COUNT CSVjoin (@header) . "\n";
foreach my $hse_type (@hse_types) {
	foreach my $region (@regions) {
		open (my $COUNT_REGN, '>', '../Secondary_system/Count_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv') or die ('../Secondary_system/Count_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv');
		my @header = ('*header', 'hse_type', 'region', 'fuel', 'system_type', 'count', 'total', 'percent');
		print $COUNT_REGN CSVjoin (@header) . "\n";
		foreach my $fuel (@fuels) {
			my @line;
			my $new_data;	# create an crosslisting hash reference
			switch ($fuel) {
				case (1) { # eligible houses for Electricity

					my %sys_types = (1, "Baseboard/Hydronic/Plenum(duct) htrs.", 2, "Forced air furnace", 3, "Radiant floor panels", 4, "Radiant ceiling panels",
							 5, "Air-source   HP w/Electric backup", 6, "Air-source   HP w/78 % Gas backup", 7, "Water-source HP w/Electric backup");
					foreach my $sys_type (sort {$a<=>$b} (keys (%sys_types))) {
						@line = ('*data', $hse_names{$hse_type}, $region_names{$region}, $fuel_names{$fuel}, $sys_types{$sys_type});
						my $file = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_names{$hse_type} . '_subset_' . $region_names{$region};
						my $ext = '.csv';
						open ($FILEIN, '<', $file . $ext) or die ("Can't open datafile: $file$ext");	# open readable file
						open (my $FILEOUT, '>', '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv') or die ('../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'); 	# open writable file
						my $count_Electricity = 0;
						my @houses_Electricity;
						my $count_total= 0;
						while (<$FILEIN>){
							($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
							if ($_ =~ /^\*data,/) { $count_total++;}

							if (defined($new_data->{'heating_energy_src'} && $new_data->{'heating_equip_type'}) && $new_data->{'heating_energy_src'} == $fuel && $new_data->{'heating_equip_type'} == $sys_type){

								$houses_Electricity[$count_Electricity] = $new_data->{'file_name'};
								$count_Electricity++;
								print $FILEOUT "$_ \n";
							}
						}
						close $FILEIN;
						close $FILEOUT;
						if ($count_Electricity == 0){
							unlink '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'
						}
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}} = $count_Electricity;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'} = $count_total;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'} = sprintf("%.2f", $count_Electricity/$count_total *100.0);
						push (@line, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'});
						print $COUNT CSVjoin (@line) . "\n";
						print $COUNT_REGN CSVjoin (@line) . "\n";
					}
				}

				case (2) { # eligible houses for Natural Gas

					my %sys_types = (1, "Furnace with continuous pilot", 2, "Boiler  with continuous pilot", 3, "Furnace with spark ignition", 4, "Boiler  with spark ignition",
							 5, "Furnace with spark ignit.,vent dmpr", 6, "Boiler  with spark ignit.,vent dmpr", 7, "Induced draft fan furnace", 
							 8, "Induced draft fan boiler", 9, "Condensing furnace", 10, "Condensing boiler");
					foreach my $sys_type (sort {$a<=>$b} (keys (%sys_types))) {
						@line = ('*data', $hse_names{$hse_type}, $region_names{$region}, $fuel_names{$fuel}, $sys_types{$sys_type});
						my $file = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_names{$hse_type} . '_subset_' . $region_names{$region};
						my $ext = '.csv';
						open ($FILEIN, '<', $file . $ext) or die ("Can't open datafile: $file$ext");	# open readable file
						open (my $FILEOUT, '>', '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv') or die ('../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'); 	# open writable file
						my $count_Electricity = 0;
						my @houses_Electricity;
						my $count_total= 0;
						while (<$FILEIN>){
							($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
							if ($_ =~ /^\*data,/) { $count_total++;}

							if (defined($new_data->{'heating_energy_src'} && $new_data->{'heating_equip_type'}) && $new_data->{'heating_energy_src'} == $fuel && $new_data->{'heating_equip_type'} == $sys_type){

								$houses_Electricity[$count_Electricity] = $new_data->{'file_name'};
								$count_Electricity++;
								print $FILEOUT "$_ \n";
							}
						}
						close $FILEIN;
						close $FILEOUT;
						if ($count_Electricity == 0){
							unlink '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'
						}
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}} = $count_Electricity;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'} = $count_total;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'} = sprintf("%.2f", $count_Electricity/$count_total *100.0);
						push (@line, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'});
						print $COUNT CSVjoin (@line) . "\n";
						print $COUNT_REGN CSVjoin (@line) . "\n";
					}
				}

				case (3) { # eligible houses for oil

					my %sys_types = (1, "Furnace", 2, "Boiler", 3, "Furnace with flue vent damper", 4, "Boiler  with flue vent damper",
							 5, "Furnace with flame retention head", 6, "Boiler  with flame retention head", 7, "Mid-efficiency furnace (no dil. air)", 
							 8, "Mid-efficiency boiler  (no dil. air)", 9, "Condensing furnace (no chimney)", 10, "Condensing boiler  (no chimney)",
							 11, "Direct vent, non-condensing furnace");
					foreach my $sys_type (sort {$a<=>$b} (keys (%sys_types))) {
						@line = ('*data', $hse_names{$hse_type}, $region_names{$region}, $fuel_names{$fuel}, $sys_types{$sys_type});
						my $file = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_names{$hse_type} . '_subset_' . $region_names{$region};
						my $ext = '.csv';
						open ($FILEIN, '<', $file . $ext) or die ("Can't open datafile: $file$ext");	# open readable file
						open (my $FILEOUT, '>', '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv') or die ('../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'); 	# open writable file
						my $count_Electricity = 0;
						my @houses_Electricity;
						my $count_total= 0;
						while (<$FILEIN>){
							($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
							if ($_ =~ /^\*data,/) { $count_total++;}

							if (defined($new_data->{'heating_energy_src'} && $new_data->{'heating_equip_type'}) && $new_data->{'heating_energy_src'} == $fuel && $new_data->{'heating_equip_type'} == $sys_type){

								$houses_Electricity[$count_Electricity] = $new_data->{'file_name'};
								$count_Electricity++;
								print $FILEOUT "$_ \n";
							}
						}
						close $FILEIN;
						close $FILEOUT;
						if ($count_Electricity == 0){
							unlink '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'
						}
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}} = $count_Electricity;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'} = $count_total;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'} = sprintf("%.2f", $count_Electricity/$count_total *100.0);
						push (@line, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'});
						print $COUNT CSVjoin (@line) . "\n";
						print $COUNT_REGN CSVjoin (@line) . "\n";
					}
				}

				case (4) { # eligible houses for propane

					my %sys_types = (1, "Furnace with continuous pilot", 2, "Boiler  with continuous pilot", 3, "Furnace with spark ignition", 4, "Boiler  with spark ignition",
							 5, "Furnace with spark ignit.,vent dmpr", 6, "Boiler  with spark ignit.,vent dmpr", 7, "Induced draft fan furnace", 
							 8, "Induced draft fan boiler", 9, "Condensing furnace", 10, "Condensing boiler");
					foreach my $sys_type (sort {$a<=>$b} (keys (%sys_types))) {
						@line = ('*data', $hse_names{$hse_type}, $region_names{$region}, $fuel_names{$fuel}, $sys_types{$sys_type});
						my $file = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_names{$hse_type} . '_subset_' . $region_names{$region};
						my $ext = '.csv';
						open ($FILEIN, '<', $file . $ext) or die ("Can't open datafile: $file$ext");	# open readable file
						open (my $FILEOUT, '>', '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv') or die ('../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'); 	# open writable file
						my $count_Electricity = 0;
						my @houses_Electricity;
						my $count_total= 0;
						while (<$FILEIN>){
							($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
							if ($_ =~ /^\*data,/) { $count_total++;}

							if (defined($new_data->{'heating_energy_src'} && $new_data->{'heating_equip_type'}) && $new_data->{'heating_energy_src'} == $fuel && $new_data->{'heating_equip_type'} == $sys_type){

								$houses_Electricity[$count_Electricity] = $new_data->{'file_name'};
								$count_Electricity++;
								print $FILEOUT "$_ \n";
							}
						}
						close $FILEIN;
						close $FILEOUT;
						if ($count_Electricity == 0){
							unlink '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'
						}
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}} = $count_Electricity;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'} = $count_total;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'} = sprintf("%.2f", $count_Electricity/$count_total *100.0);
						push (@line, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'});
						print $COUNT CSVjoin (@line) . "\n";
						print $COUNT_REGN CSVjoin (@line) . "\n";
					}
				}

				case (5) { # eligible houses for Mixed wood

					my %sys_types = (1, "Advanced airtight wood stove", 2, "Adv. airtight wood stove + cat. conv.", 3, "Conventional furnace", 4, "Conventional boiler",
							 5, "Conventional stove", 6, "Pellet stove", 7, "Masonry heater", 8, "Conventional fireplace", 9, "Fireplace (EPA/CSA)", 10, "Fireplace insert (EPA/CSA)");
					foreach my $sys_type (sort {$a<=>$b} (keys (%sys_types))) {
						@line = ('*data', $hse_names{$hse_type}, $region_names{$region}, $fuel_names{$fuel}, $sys_types{$sys_type});
						my $file = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_names{$hse_type} . '_subset_' . $region_names{$region};
						my $ext = '.csv';
						open ($FILEIN, '<', $file . $ext) or die ("Can't open datafile: $file$ext");	# open readable file
						open (my $FILEOUT, '>', '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv') or die ('../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'); 	# open writable file
						my $count_Electricity = 0;
						my @houses_Electricity;
						my $count_total= 0;
						while (<$FILEIN>){
							($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
							if ($_ =~ /^\*data,/) { $count_total++;}

							if (defined($new_data->{'heating_energy_src'} && $new_data->{'heating_equip_type'}) && $new_data->{'heating_energy_src'} == $fuel && $new_data->{'heating_equip_type'} == $sys_type){

								$houses_Electricity[$count_Electricity] = $new_data->{'file_name'};
								$count_Electricity++;
								print $FILEOUT "$_ \n";
							}
						}
						close $FILEIN;
						close $FILEOUT;
						if ($count_Electricity == 0){
							unlink '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'
						}
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}} = $count_Electricity;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'} = $count_total;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'} = sprintf("%.2f", $count_Electricity/$count_total *100.0);
						push (@line, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'});
						print $COUNT CSVjoin (@line) . "\n";
						print $COUNT_REGN CSVjoin (@line) . "\n";
					}
				}

				case (6) { # eligible houses for Hardwood

					my %sys_types = (1, "Advanced airtight wood stove", 2, "Adv. airtight wood stove + cat. conv.", 3, "Conventional furnace", 4, "Conventional boiler",
							 5, "Conventional stove", 6, "Pellet stove", 7, "Masonry heater", 8, "Conventional fireplace", 9, "Fireplace (EPA/CSA)", 10, "Fireplace insert (EPA/CSA)");
					foreach my $sys_type (sort {$a<=>$b} (keys (%sys_types))) {
						@line = ('*data', $hse_names{$hse_type}, $region_names{$region}, $fuel_names{$fuel}, $sys_types{$sys_type});
						my $file = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_names{$hse_type} . '_subset_' . $region_names{$region};
						my $ext = '.csv';
						open ($FILEIN, '<', $file . $ext) or die ("Can't open datafile: $file$ext");	# open readable file
						open (my $FILEOUT, '>', '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv') or die ('../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'); 	# open writable file
						my $count_Electricity = 0;
						my @houses_Electricity;
						my $count_total= 0;
						while (<$FILEIN>){
							($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
							if ($_ =~ /^\*data,/) { $count_total++;}

							if (defined($new_data->{'heating_energy_src'} && $new_data->{'heating_equip_type'}) && $new_data->{'heating_energy_src'} == $fuel && $new_data->{'heating_equip_type'} == $sys_type){

								$houses_Electricity[$count_Electricity] = $new_data->{'file_name'};
								$count_Electricity++;
								print $FILEOUT "$_ \n";
							}
						}
						close $FILEIN;
						close $FILEOUT;
						if ($count_Electricity == 0){
							unlink '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'
						}
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}} = $count_Electricity;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'} = $count_total;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'} = sprintf("%.2f", $count_Electricity/$count_total *100.0);
						push (@line, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'});
						print $COUNT CSVjoin (@line) . "\n";
						print $COUNT_REGN CSVjoin (@line) . "\n";
					}
				}
				case (7) { # eligible houses for Softwood

					my %sys_types = (1, "Advanced airtight wood stove", 2, "Adv. airtight wood stove + cat. conv.", 3, "Conventional furnace", 4, "Conventional boiler",
							 5, "Conventional stove", 6, "Pellet stove", 7, "Masonry heater", 8, "Conventional fireplace", 9, "Fireplace (EPA/CSA)", 10, "Fireplace insert (EPA/CSA)");
					foreach my $sys_type (sort {$a<=>$b} (keys (%sys_types))) {
						@line = ('*data', $hse_names{$hse_type}, $region_names{$region}, $fuel_names{$fuel}, $sys_types{$sys_type});
						my $file = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_names{$hse_type} . '_subset_' . $region_names{$region};
						my $ext = '.csv';
						open ($FILEIN, '<', $file . $ext) or die ("Can't open datafile: $file$ext");	# open readable file
						open (my $FILEOUT, '>', '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv') or die ('../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'); 	# open writable file
						my $count_Electricity = 0;
						my @houses_Electricity;
						my $count_total= 0;
						while (<$FILEIN>){
							($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
							if ($_ =~ /^\*data,/) { $count_total++;}

							if (defined($new_data->{'heating_energy_src'} && $new_data->{'heating_equip_type'}) && $new_data->{'heating_energy_src'} == $fuel && $new_data->{'heating_equip_type'} == $sys_type){

								$houses_Electricity[$count_Electricity] = $new_data->{'file_name'};
								$count_Electricity++;
								print $FILEOUT "$_ \n";
							}
						}
						close $FILEIN;
						close $FILEOUT;
						if ($count_Electricity == 0){
							unlink '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'
						}
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}} = $count_Electricity;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'} = $count_total;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'} = sprintf("%.2f", $count_Electricity/$count_total *100.0);
						push (@line, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'});
						print $COUNT CSVjoin (@line) . "\n";
						print $COUNT_REGN CSVjoin (@line) . "\n";
					}
				}
				case (8) { # eligible houses for Wood Pellets

					my %sys_types = (1, "Advanced airtight wood stove", 2, "Adv. airtight wood stove + cat. conv.", 3, "Conventional furnace", 4, "Conventional boiler",
							 5, "Conventional stove", 6, "Pellet stove", 7, "Masonry heater", 8, "Conventional fireplace", 9, "Fireplace (EPA/CSA)", 10, "Fireplace insert (EPA/CSA)");
					foreach my $sys_type (sort {$a<=>$b} (keys (%sys_types))) {
						@line = ('*data', $hse_names{$hse_type}, $region_names{$region}, $fuel_names{$fuel}, $sys_types{$sys_type});
						my $file = '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_names{$hse_type} . '_subset_' . $region_names{$region};
						my $ext = '.csv';
						open ($FILEIN, '<', $file . $ext) or die ("Can't open datafile: $file$ext");	# open readable file
						open (my $FILEOUT, '>', '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv') or die ('../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'); 	# open writable file
						my $count_Electricity = 0;
						my @houses_Electricity;
						my $count_total= 0;
						while (<$FILEIN>){
							($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
							if ($_ =~ /^\*data,/) { $count_total++;}

							if (defined($new_data->{'heating_energy_src'} && $new_data->{'heating_equip_type'}) && $new_data->{'heating_energy_src'} == $fuel && $new_data->{'heating_equip_type'} == $sys_type){

								$houses_Electricity[$count_Electricity] = $new_data->{'file_name'};
								$count_Electricity++;
								print $FILEOUT "$_ \n";
							}
						}
						close $FILEIN;
						close $FILEOUT;
						if ($count_Electricity == 0){
							unlink '../Secondary_system/Houses_Heating_fuel_'.$fuel_names{$fuel}.'_system-type_'.$sys_type.'_'.$hse_names{$hse_type}.'_subset_'.$region_names{$region}.'.csv'
						}
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}} = $count_Electricity;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'} = $count_total;
						$count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'} = sprintf("%.2f", $count_Electricity/$count_total *100.0);
						push (@line, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{$fuel_names{$fuel}.$sys_types{$sys_type}}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'total'}, $count->{$hse_names{$hse_type}}->{$region_names{$region}}->{'percent'});
						print $COUNT CSVjoin (@line) . "\n";
						print $COUNT_REGN CSVjoin (@line) . "\n";
					}
				}

			}
		};
		close $COUNT_REGN;
	};
};
close $COUNT;

# 
# ====================================================================
# Subroutines:
# data_read_up
# This subroutine is similar to one_data_line subroutine in General.pm.
# It just doesn't remove *header and *data tag.
# ====================================================================

sub data_read_up {
	my $line = shift;
	# shift the existing data which may include the array of header info at $existing_data->{'header'}
	my $old_data = shift;
	my $file = shift;

	my $present_data;	# create an crosslisting hash reference

	$line = &rm_EOL_and_trim($line);
	if (defined ($old_data->{'header'})) {
		$present_data->{'header'} = $old_data->{'header'};
	}
		
	# Check to see if header has not yet been encountered. This will fill out $new_data once and in subsequent calls to this subroutine with the same file the header will be set above.
	if ($line =~ /^\*header,/) {	
		$present_data->{'header'} = [CSVsplit($line)];  # split the header into an array
		print $file "$line \n";
	}
		
	# Check for the existance of the data tag, and if so store the data and return to the calling program.
	elsif ($line =~ /^\*data,/) {	
		# create a hash slice that uses the header and data
		# although this is a complex structure it simply creates a hash with an array of keys and array of values
		# @{$hash_ref}{@keys} = @values
		@{$present_data}{@{$present_data->{'header'}}} = CSVsplit($line);
	}
	# We have successfully identified a line of data, so return this to the calling program, complete with the header information to be passed back to this routine
	return ($present_data, $line);

};

