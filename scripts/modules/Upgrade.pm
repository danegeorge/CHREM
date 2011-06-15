# ====================================================================
# Upgrade.pm
# Author: Sara Nikoofard
# Date: May 2011
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# upgrade_name: a subroutine that return the name of upgrade that is needed
# ====================================================================

# Declare the package name of this perl module
package Upgrade;

# Declare packages used by this perl module
use strict;
use CSV;	# CSV-2 (for CSV split and join, this works best)
use Switch;
use Data::Dumper;

use lib qw(./modules);
use General;

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = qw(Exporter);

# Place the routines that are to be automatically exported here
our @EXPORT = qw(upgrade_name eligible_houses);
# Place the routines that must be requested as a list following use in the calling script
our @EXPORT_OK = ();

# ====================================================================
# upgrade_name
# This subroutine recieves the user specified upgarde type. It interprets the appropriate Upgrade Types
# (e.g. 1 => SDHW) and outputs these back to the calling script. 
# It will also issue warnings if the input is malformed.
# ====================================================================

sub upgrade_name {
	my $upgrade_num = shift; # upgrade number
	my $name_up;
	my $count = 0;
	my @list_up;
	
	while ($upgrade_num =~ /^[1-9]?$/ && $upgrade_num =~ /\S/) {
		$list_up[$count] = $upgrade_num;
		$count++;
		$upgrade_num = <STDIN>;
		chomp ($upgrade_num);
	}
	foreach my $up (@list_up){
		switch ($up) {
			case (1) {$name_up->{$up} ='SDHW';}	# solar domestic hot water
			case (2) {$name_up->{$up} ='WAM';}	# changing window area
			case (3) {$name_up->{$up} ='WTM';}	# changing window type
			case (4) {$name_up->{$up} ='FVB';}	# fixed venetian blind
			case (5) {$name_up->{$up} ='FOH';}	# fixed overhang
			case (6) {$name_up->{$up} ='PMC';}	# phase change material
			case (7) {$name_up->{$up} ='CVB';}	# controlable venetian blind
			case (8) {$name_up->{$up} ='PV';}	# photovoltaic
			case (9) {$name_up->{$up} ='BIPVT';}	# building integrated photovoltaic / thermal
		}
	};

      return ($name_up);
	
        
	
};

# ====================================================================
# eligible_houses
# This subroutine recieves the user specified upgarde type and according the provided criteria 
# select eligible houses that can recieve upgrades for the specified house type and region.
# ====================================================================
sub eligible_houses {

	my $file1 = shift;
	my $ext1 = shift;
	my $list = shift;
	my $FILEIN;
	my $FILEOUT;
	my $new_data;	# create an crosslisting hash reference
	my @houses;
	my $count;
	# Open the data source files from the CSDDRD - path to the correct CSDDRD type and region file
	

	foreach my $up (keys(%{$list})) {
		open ($FILEIN, '<', $file1 . $ext1) or die ("Can't open datafile: $file1$ext1");	# open readable file
		switch ($up) {
			case (1) { # eligible houses for SDHW
				open ($FILEOUT, '>', "../Eligible_Houses_".$list->{$up}.".csv") or die ("Can't open datafile: Eligible_Houses_$list->{$up}"); 	# open writable file
				my $count_SDHW = 0;
				my @houses_SDHW;
				while (<$FILEIN>){
					($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
					my $width;
					my @zones = qw (bsmt crawl main_1 main_2 main_3);
					my $last_zone;
					# calculation width of all zones
					if (defined($new_data->{'exterior_width'} && $new_data->{'exterior_depth'})){
						my $w_d_ratio = sprintf ("%.2f", $new_data->{'exterior_width'}/ $new_data->{'exterior_depth'});
						my $depth = sprintf("%6.2f", ($new_data->{'main_floor_area_1'} / $w_d_ratio) ** 0.5);
						foreach my $zone (@zones) {
							if ($zone =~ /^bsmt$|^crawl$/) {
								# Because bsmt walls are thicker, the bsmt or crawl floor area is typically a little less than the main_1 level. However, it is really not appropriate to expose main_1 floor area for this small difference.
								# Thus, if the difference between the main_1 and foundation floor area is less than 10% of them main_1 floor area, resize the foundation area to be equal to the main_1 floor area
								if ($new_data->{'main_floor_area_1'} - $new_data->{$zone . '_floor_area'} < 0.1 * $new_data->{'main_floor_area_1'}) {
									$new_data->{$zone . '_floor_area'} = $new_data->{'main_floor_area_1'};
								}
								$width->{$zone} = $new_data->{$zone . '_floor_area'} / $depth;	# determine width of zone based upon main_1 depth
							}
							elsif ($zone =~ /^main_(\d)$/) {
								# determine x from floor area and y
								$width->{$zone} = $new_data->{"main_floor_area_$1"} / $depth;	# determine width of zone based upon main_1 depth
							}
							$last_zone = $zone;
						};
						# examine the existance of attic and if the DR house is middle row attachment
						if ($new_data->{'ceiling_flat_type'} == 2 || $new_data->{'attachment_type'} == 4) {
							# next criteria is existance of the basement with height more than 2m
							if ($new_data->{'bsmt_wall_height'} >= 2){
								# if the front orientation of the house is south, south-east or south-west to have a ridgeline running west-east the width which is always front of the house should be more than depth
								if ($new_data->{'front_orientation'} == 3 || $new_data->{'front_orientation'} == 7) {
									if ($new_data->{'exterior_width'} < $new_data->{'exterior_depth'}) {
										$houses_SDHW[$count_SDHW] = $new_data->{'file_name'};
										$count_SDHW++;
										print $FILEOUT "$_ \n";
									}
								}
								else {
									if ($new_data->{'exterior_width'} > $new_data->{'exterior_depth'}) {
										$houses_SDHW[$count_SDHW] = $new_data->{'file_name'};
										$count_SDHW++;
										print $FILEOUT "$_ \n";
									}
								}
							}
						}
						elsif ($new_data->{'ceiling_flat_type'} == 3) {
							if ($new_data->{'attachment_type'} == 2 || $new_data->{'attachment_type'} == 3) { # DR - left/right end house type
								if (($width->{$last_zone} * 2 / 3) >= 4 && ($new_data->{'bsmt_wall_height'} >= 2)){
									$houses_SDHW[$count_SDHW] = $new_data->{'file_name'};
									$count_SDHW++;
									print $FILEOUT "$_ \n";
								  }
							}
						}
					}
					
				}
# 				print "$count_SDHW \n";
				close $FILEOUT;
				$count->{$list->{$up}} = $count_SDHW;
				push (@houses, @houses_SDHW);
			}
			case (2) { # eligible houses for WAM 
				open ($FILEOUT, '>', "../Eligible_Houses_".$list->{$up}.".csv") or die ("Can't open datafile: Eligible_Houses_$list->{$up}"); 	# open writable file
				my $count_WAM = 0;
				my @houses_WAM;
				while (<$FILEIN>){
					($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
					my $width;
					my $height;
					my $total_area;
					my @zones = qw (bsmt crawl main_1 main_2 main_3);
					my @sides = qw (front back right left);
					# calculation of area for all surfaces
					if (defined($new_data->{'exterior_width'} && $new_data->{'exterior_depth'})){
						my $w_d_ratio = sprintf ("%.2f", $new_data->{'exterior_width'}/ $new_data->{'exterior_depth'});
						my $depth = sprintf("%6.2f", ($new_data->{'main_floor_area_1'} / $w_d_ratio) ** 0.5);
						foreach my $zone (@zones) {
						
							if ($zone =~ /^bsmt$|^crawl$/) {
						
								# Because bsmt walls are thicker, the bsmt or crawl floor area is typically a little less than the main_1 level. However, it is really not appropriate to expose main_1 floor area for this small difference.
								# Thus, if the difference between the main_1 and foundation floor area is less than 10% of them main_1 floor area, resize the foundation area to be equal to the main_1 floor area
								if ($new_data->{'main_floor_area_1'} - $new_data->{$zone . '_floor_area'} < 0.1 * $new_data->{'main_floor_area_1'}) {
									$new_data->{$zone . '_floor_area'} = $new_data->{'main_floor_area_1'};
								}
								$width->{$zone} = $new_data->{$zone . '_floor_area'} / $depth;	# determine width of zone based upon main_1 depth

								$height->{$zone} = $new_data->{$zone . '_wall_height'};
								$total_area-> {$zone} = &total_surface_area ($width->{$zone}, $depth, $height->{$zone});
							}

							elsif ($zone =~ /^main_(\d)$/) {
								# determine x from floor area and y
								$width->{$zone} = $new_data->{"main_floor_area_$1"} / $depth;	# determine width of zone based upon main_1 depth
								$height->{$zone} = $new_data->{"main_wall_height_$1"};	# determine height of zone
								$total_area->{$zone} = &total_surface_area ($width->{$zone}, $depth, $height->{$zone});
							}
							foreach my $surface (@sides){
								$total_area->{'total'}->{$surface} = $total_area-> {$zone}->{$surface} + $total_area->{'total'}->{$surface};
							}
						};
					}
					# presence of window on the south, south-west and south-east side
					switch ($new_data->{'wndw_count_front'}){
						case(1) {
							if ($new_data->{'wndw_count_front'} > 0) {
								# check the window area/wall area ratio (it should be less than 50%)
								if (($new_data->{'wndw_area_front'} / $total_area->{'total'}->{'front'}) <= 0.5 ) {
									$houses_WAM[$count_WAM] = $new_data->{'file_name'};
									$count_WAM++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						case(2) {
							if ($new_data->{'wndw_count_front'} > 0) {
								# check the window area/wall area ratio (it should be less than 50%)
								if (($new_data->{'wndw_area_front'} / $total_area->{'total'}->{'front'}) <= 0.5 ) {
									$houses_WAM[$count_WAM] = $new_data->{'file_name'};
									$count_WAM++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						case(3) {
							if ($new_data->{'wndw_count_left'} > 0 ) {
								# check the window area/wall area ratio (it should be less than 50%)
								if (($new_data->{'wndw_area_left'} / $total_area->{'total'}->{'left'}) <= 0.5 ) {
									$houses_WAM[$count_WAM] = $new_data->{'file_name'};
									$count_WAM++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						case(4) {
							if ($new_data->{'wndw_count_back'} > 0) {
								# check the window area/wall area ratio (it should be less than 50%)
								if (($new_data->{'wndw_area_back'} / $total_area->{'total'}->{'back'}) <= 0.5 ) {
									$houses_WAM[$count_WAM] = $new_data->{'file_name'};
									$count_WAM++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						case(5) {
							if ($new_data->{'wndw_count_back'} > 0) {
								# check the window area/wall area ratio (it should be less than 50%)
								if (($new_data->{'wndw_area_back'} / $total_area->{'total'}->{'back'}) <= 0.5 ) {
									$houses_WAM[$count_WAM] = $new_data->{'file_name'};
									$count_WAM++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						case(6) {
							if ($new_data->{'wndw_count_back'} > 0) {
								# check the window area/wall area ratio (it should be less than 50%)
								if (($new_data->{'wndw_area_back'} / $total_area->{'total'}->{'back'}) <= 0.5 ) {
									$houses_WAM[$count_WAM] = $new_data->{'file_name'};
									$count_WAM++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						case(7) {
							if ($new_data->{'wndw_count_right'} > 0) {
								# check the window area/wall area ratio (it should be less than 50%)
								if (($new_data->{'wndw_area_right'} / $total_area->{'total'}->{'right'}) <= 0.5 ) {
									$houses_WAM[$count_WAM] = $new_data->{'file_name'};
									$count_WAM++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						case(8) {
							if ($new_data->{'wndw_count_front'} > 0) {
								# check the window area/wall area ratio (it should be less than 50%)
								if (($new_data->{'wndw_area_front'} / $total_area->{'total'}->{'front'}) <= 0.5 ) {
									$houses_WAM[$count_WAM] = $new_data->{'file_name'};
									$count_WAM++;
									print $FILEOUT "$_ \n";
								}
							}
						}  
					}
				}
# 				print "$count_WAM \n";
				close $FILEOUT;
				$count->{$list->{$up}} = $count_WAM;
				push (@houses, @houses_WAM);
			}
			case (3) { # eligible houses for WTM
				open ($FILEOUT, '>', "../Eligible_Houses_".$list->{$up}.".csv") or die ("Can't open datafile: Eligible_Houses_$list->{$up}"); 	# open writable file
				my $count_WTM = 0;
				my @houses_WTM;
				my @sides = qw (front back right left);
				RECORD: while (<$FILEIN>){
					($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
					foreach my $surface (@sides) {
						if ($new_data->{'wndw_count_'.$surface} > 0) {
							my $wndw_count = $new_data->{'wndw_count_'.$surface};
							for (my $i = 1; $i <= $wndw_count; $i++) {
								my $index = sprintf ("%02u", $i);
								$new_data->{'wndw_z_'.$surface.'_code_'.$index} =~ /(\d{3})\d{3}/;
								my $wndw_code = $1;
								$wndw_code =~ /(\d)(\d)\d/;
# 								windows that are not triple glazed or clear triple_glazed are eligible for upgrade
								if (($1 != 3) || ($2 == 0)) {
									$houses_WTM[$count_WTM] = $new_data->{'file_name'};
									$count_WTM++;
									print $FILEOUT "$_ \n";
									next RECORD;
								}
									
							}
						}
					}

				}
# 				print "$count_WTM \n";
				close $FILEOUT;
				$count->{$list->{$up}} = $count_WTM;
				push (@houses, @houses_WTM);
			}
			case (4) { # eligible houses for FVB 
			  open ($FILEOUT, '>', "../Eligible_Houses_".$list->{$up}.".csv") or die ("Can't open datafile: Eligible_Houses_$list->{$up}"); 	# open writable file
				my $count_FVB = 0;
				my @houses_FVB;
				while (<$FILEIN>){
					($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);

					# examine the existance of cooling system
					if ($new_data->{'cooling_equip_type'} != 4) {
						# presence of window on the west, south-west, east and south-east side
						switch ($new_data->{'wndw_count_front'}){
							case(1) {
								if ($new_data->{'wndw_count_right'} > 0 || $new_data->{'wndw_count_left'} >0) {
									$houses_FVB[$count_FVB] = $new_data->{'file_name'};
									$count_FVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(2) {
								if ($new_data->{'wndw_count_front'} > 0 || $new_data->{'wndw_count_left'} >0) {
									$houses_FVB[$count_FVB] = $new_data->{'file_name'};
									$count_FVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(3) {
								if ($new_data->{'wndw_count_front'} > 0 || $new_data->{'wndw_count_back'} >0) {
									$houses_FVB[$count_FVB] = $new_data->{'file_name'};
									$count_FVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(4) {
								if ($new_data->{'wndw_count_left'} > 0 || $new_data->{'wndw_count_back'} >0) {
									$houses_FVB[$count_FVB] = $new_data->{'file_name'};
									$count_FVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(5) {
								if ($new_data->{'wndw_count_right'} > 0 || $new_data->{'wndw_count_left'} >0) {
									$houses_FVB[$count_FVB] = $new_data->{'file_name'};
									$count_FVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(6) {
								if ($new_data->{'wndw_count_right'} > 0 || $new_data->{'wndw_count_back'} >0) {
									$houses_FVB[$count_FVB] = $new_data->{'file_name'};
									$count_FVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(7) {
								if ($new_data->{'wndw_count_front'} > 0 || $new_data->{'wndw_count_back'} >0) {
									$houses_FVB[$count_FVB] = $new_data->{'file_name'};
									$count_FVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(8) {
								if ($new_data->{'wndw_count_front'} > 0 || $new_data->{'wndw_count_right'} >0) {
									$houses_FVB[$count_FVB] = $new_data->{'file_name'};
									$count_FVB++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						  
					}
				}
# 				print "$count_FVB \n";
				close $FILEOUT;
				$count->{$list->{$up}} = $count_FVB;
				push (@houses, @houses_FVB);
			}
			case (5) { # eligible houses for FOH
				open ($FILEOUT, '>', "../Eligible_Houses_".$list->{$up}.".csv") or die ("Can't open datafile: Eligible_Houses_$list->{$up}"); 	# open writable file
				my $count_FOH = 0;
				my @houses_FOH;
				while (<$FILEIN>){
					($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);

					# examine the existance of cooling system
					if ($new_data->{'cooling_equip_type'} != 4) {
						# presence of window on the south, south-west and south-east side
						switch ($new_data->{'wndw_count_front'}){
							case(1) {
								if ($new_data->{'wndw_count_front'} > 0) {
									$houses_FOH[$count_FOH] = $new_data->{'file_name'};
									$count_FOH++;
									print $FILEOUT "$_ \n";
								}
							}
							case(2) {
								if ($new_data->{'wndw_count_front'} > 0) {
									$houses_FOH[$count_FOH] = $new_data->{'file_name'};
									$count_FOH++;
									print $FILEOUT "$_ \n";
								}
							}
							case(3) {
								if ($new_data->{'wndw_count_left'} > 0 ) {
									$houses_FOH[$count_FOH] = $new_data->{'file_name'};
									$count_FOH++;
									print $FILEOUT "$_ \n";
								}
							}
							case(4) {
								if ($new_data->{'wndw_count_back'} > 0) {
									$houses_FOH[$count_FOH] = $new_data->{'file_name'};
									$count_FOH++;
									print $FILEOUT "$_ \n";
								}
							}
							case(5) {
								if ($new_data->{'wndw_count_back'} > 0) {
									$houses_FOH[$count_FOH] = $new_data->{'file_name'};
									$count_FOH++;
									print $FILEOUT "$_ \n";
								}
							}
							case(6) {
								if ($new_data->{'wndw_count_back'} > 0) {
									$houses_FOH[$count_FOH] = $new_data->{'file_name'};
									$count_FOH++;
									print $FILEOUT "$_ \n";
								}
							}
							case(7) {
								if ($new_data->{'wndw_count_right'} > 0) {
									$houses_FOH[$count_FOH] = $new_data->{'file_name'};
									$count_FOH++;
									print $FILEOUT "$_ \n";
								}
							}
							case(8) {
								if ($new_data->{'wndw_count_front'} > 0) {
									$houses_FOH[$count_FOH] = $new_data->{'file_name'};
									$count_FOH++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						  
					}
				}
# 				print "$count_FOH \n";
				close $FILEOUT;
				$count->{$list->{$up}} = $count_FOH;
				push (@houses, @houses_FOH);
			}
			case (6) { # eligible houses for PCM 
				open ($FILEOUT, '>', "../Eligible_Houses_".$list->{$up}.".csv") or die ("Can't open datafile: Eligible_Houses_$list->{$up}"); 	# open writable file
				my $count_PCM = 0;
				my @houses_PCM;
				while (<$FILEIN>){
					($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);

					# presence of window on the south, south-west and south-east side
					switch ($new_data->{'wndw_count_front'}){
						case(1) {
							if ($new_data->{'wndw_count_front'} > 0) {
								$houses_PCM[$count_PCM] = $new_data->{'file_name'};
								$count_PCM++;
								print $FILEOUT "$_ \n";
							}
						}
						case(2) {
							if ($new_data->{'wndw_count_front'} > 0) {
								$houses_PCM[$count_PCM] = $new_data->{'file_name'};
								$count_PCM++;
								print $FILEOUT "$_ \n";
							}
						}
						case(3) {
							if ($new_data->{'wndw_count_left'} > 0 ) {
								$houses_PCM[$count_PCM] = $new_data->{'file_name'};
								$count_PCM++;
								print $FILEOUT "$_ \n";
							}
						}
						case(4) {
							if ($new_data->{'wndw_count_back'} > 0) {
								$houses_PCM[$count_PCM] = $new_data->{'file_name'};
								$count_PCM++;
								print $FILEOUT "$_ \n";
							}
						}
						case(5) {
							if ($new_data->{'wndw_count_back'} > 0) {
								$houses_PCM[$count_PCM] = $new_data->{'file_name'};
								$count_PCM++;
								print $FILEOUT "$_ \n";
							}
						}
						case(6) {
							if ($new_data->{'wndw_count_back'} > 0) {
								$houses_PCM[$count_PCM] = $new_data->{'file_name'};
								$count_PCM++;
								print $FILEOUT "$_ \n";
							}
						}
						case(7) {
							if ($new_data->{'wndw_count_right'} > 0) {
								$houses_PCM[$count_PCM] = $new_data->{'file_name'};
								$count_PCM++;
								print $FILEOUT "$_ \n";
							}
						}
						case(8) {
							if ($new_data->{'wndw_count_front'} > 0) {
								$houses_PCM[$count_PCM] = $new_data->{'file_name'};
								$count_PCM++;
								print $FILEOUT "$_ \n";
							}
						}  
					}
				}
# 				print "$count_PCM \n";
				close $FILEOUT;
				$count->{$list->{$up}} = $count_PCM;
				push (@houses, @houses_PCM);
			}
			case (7) { # eligible houses for CVB
				open ($FILEOUT, '>', "../Eligible_Houses_".$list->{$up}.".csv") or die ("Can't open datafile: Eligible_Houses_$list->{$up}"); 	# open writable file
				my $count_CVB = 0;
				my @houses_CVB;
				while (<$FILEIN>){
					($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);

					# examine the existance of cooling system
					if ($new_data->{'cooling_equip_type'} != 4) {
						# presence of window on the west, south, south-west, east and south-east side
						switch ($new_data->{'wndw_count_front'}){
							case(1) {
								if ($new_data->{'wndw_count_right'} > 0 || $new_data->{'wndw_count_left'} > 0 || $new_data->{'wndw_count_front'} > 0) {
									$houses_CVB[$count_CVB] = $new_data->{'file_name'};
									$count_CVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(2) {
								if ($new_data->{'wndw_count_front'} > 0 || $new_data->{'wndw_count_left'} > 0) {
									$houses_CVB[$count_CVB] = $new_data->{'file_name'};
									$count_CVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(3) {
								if ($new_data->{'wndw_count_front'} > 0 || $new_data->{'wndw_count_back'} > 0 || $new_data->{'wndw_count_left'} > 0) {
									$houses_CVB[$count_CVB] = $new_data->{'file_name'};
									$count_CVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(4) {
								if ($new_data->{'wndw_count_left'} > 0 || $new_data->{'wndw_count_back'} > 0) {
									$houses_CVB[$count_CVB] = $new_data->{'file_name'};
									$count_CVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(5) {
								if ($new_data->{'wndw_count_right'} > 0 || $new_data->{'wndw_count_left'} > 0 || $new_data->{'wndw_count_back'} > 0) {
									$houses_CVB[$count_CVB] = $new_data->{'file_name'};
									$count_CVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(6) {
								if ($new_data->{'wndw_count_right'} > 0 || $new_data->{'wndw_count_back'} > 0) {
									$houses_CVB[$count_CVB] = $new_data->{'file_name'};
									$count_CVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(7) {
								if ($new_data->{'wndw_count_front'} > 0 || $new_data->{'wndw_count_back'} > 0 || $new_data->{'wndw_count_right'} > 0) {
									$houses_CVB[$count_CVB] = $new_data->{'file_name'};
									$count_CVB++;
									print $FILEOUT "$_ \n";
								}
							}
							case(8) {
								if ($new_data->{'wndw_count_front'} > 0 || $new_data->{'wndw_count_right'} > 0) {
									$houses_CVB[$count_CVB] = $new_data->{'file_name'};
									$count_CVB++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						  
					}
				}
# 				print "$count_CVB \n";
				close $FILEOUT;
				$count->{$list->{$up}} = $count_CVB;
				push (@houses, @houses_CVB);
			}
			case (8) { # eligible houses for PV 
				open ($FILEOUT, '>', "../Eligible_Houses_".$list->{$up}.".csv") or die ("Can't open datafile: Eligible_Houses_$list->{$up}"); 	# open writable file
				my $count_PV = 0;
				my @houses_PV;
				while (<$FILEIN>){
					($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
					my $width;
					my @zones = qw (bsmt crawl main_1 main_2 main_3);
					my $last_zone;
					# calculation width of all zones
					if (defined($new_data->{'exterior_width'} && $new_data->{'exterior_depth'})){
						my $w_d_ratio = sprintf ("%.2f", $new_data->{'exterior_width'}/ $new_data->{'exterior_depth'});
						my $depth = sprintf("%6.2f", ($new_data->{'main_floor_area_1'} / $w_d_ratio) ** 0.5);
						foreach my $zone (@zones) {
							if ($zone =~ /^bsmt$|^crawl$/) {
								# Because bsmt walls are thicker, the bsmt or crawl floor area is typically a little less than the main_1 level. However, it is really not appropriate to expose main_1 floor area for this small difference.
								# Thus, if the difference between the main_1 and foundation floor area is less than 10% of them main_1 floor area, resize the foundation area to be equal to the main_1 floor area
								if ($new_data->{'main_floor_area_1'} - $new_data->{$zone . '_floor_area'} < 0.1 * $new_data->{'main_floor_area_1'}) {
									$new_data->{$zone . '_floor_area'} = $new_data->{'main_floor_area_1'};
								}
								$width->{$zone} = $new_data->{$zone . '_floor_area'} / $depth;	# determine width of zone based upon main_1 depth
							}
							elsif ($zone =~ /^main_(\d)$/) {
								# determine x from floor area and y
								$width->{$zone} = $new_data->{"main_floor_area_$1"} / $depth;	# determine width of zone based upon main_1 depth
							}
							$last_zone = $zone;
						};
						# examine the existance of attic and if the DR house is middle row attachment
						if ($new_data->{'ceiling_flat_type'} == 2 || $new_data->{'attachment_type'} == 4) {
							# if the front orientation of the house is south, south-east or south-west to have a ridgeline running west-east the width which is always front of the house should be more than depth
							if ($new_data->{'front_orientation'} == 3 || $new_data->{'front_orientation'} == 7) {
								if ($new_data->{'exterior_width'} < $new_data->{'exterior_depth'}) {
									$houses_PV[$count_PV] = $new_data->{'file_name'};
									$count_PV++;
									print $FILEOUT "$_ \n";
								}
							}
							else {
								if ($new_data->{'exterior_width'} > $new_data->{'exterior_depth'}) {
									$houses_PV[$count_PV] = $new_data->{'file_name'};
									$count_PV++;
									print $FILEOUT "$_ \n";
								}
							}
						}
						elsif ($new_data->{'ceiling_flat_type'} == 3) {
							if ($new_data->{'attachment_type'} == 2 || $new_data->{'attachment_type'} == 3) { # DR - left/right end house type
								if (($width->{$last_zone} * 2 / 3) >= 4){
									$houses_PV[$count_PV] = $new_data->{'file_name'};
									$count_PV++;
									print $FILEOUT "$_ \n";
								  }
							}
						}
					}
				}
# 				print "$count_PV \n";
				close $FILEOUT;
				$count->{$list->{$up}} = $count_PV;
				push (@houses, @houses_PV);
			}
			case (9) {  # eligible houses for BIPV/T
				open ($FILEOUT, '>', "../Eligible_Houses_".$list->{$up}.".csv") or die ("Can't open datafile: Eligible_Houses_$list->{$up}"); 	# open writable file
				my $count_BIPVT = 0;
				my @houses_BIPVT;
				while (<$FILEIN>){
					($new_data, $_) = &data_read_up ($_, $new_data, $FILEOUT);
					my $width;
					my @zones = qw (bsmt crawl main_1 main_2 main_3);
					my $last_zone;
					# calculation width of all zones
					if (defined($new_data->{'exterior_width'} && $new_data->{'exterior_depth'})){
						my $w_d_ratio = sprintf ("%.2f", $new_data->{'exterior_width'}/ $new_data->{'exterior_depth'});
						my $depth = sprintf("%6.2f", ($new_data->{'main_floor_area_1'} / $w_d_ratio) ** 0.5);
						foreach my $zone (@zones) {
							if ($zone =~ /^bsmt$|^crawl$/) {
								# Because bsmt walls are thicker, the bsmt or crawl floor area is typically a little less than the main_1 level. However, it is really not appropriate to expose main_1 floor area for this small difference.
								# Thus, if the difference between the main_1 and foundation floor area is less than 10% of them main_1 floor area, resize the foundation area to be equal to the main_1 floor area
								if ($new_data->{'main_floor_area_1'} - $new_data->{$zone . '_floor_area'} < 0.1 * $new_data->{'main_floor_area_1'}) {
									$new_data->{$zone . '_floor_area'} = $new_data->{'main_floor_area_1'};
								}
								$width->{$zone} = $new_data->{$zone . '_floor_area'} / $depth;	# determine width of zone based upon main_1 depth
							}
							elsif ($zone =~ /^main_(\d)$/) {
								# determine x from floor area and y
								$width->{$zone} = $new_data->{"main_floor_area_$1"} / $depth;	# determine width of zone based upon main_1 depth
							}
							$last_zone = $zone;
						};
						# examine the existance of attic and if the DR house is middle row attachment
						if ($new_data->{'ceiling_flat_type'} == 2 || $new_data->{'attachment_type'} == 4) {
							# next criteria is existance of the basement with height more than 2m
							if ($new_data->{'bsmt_wall_height'} >= 2){
# 								if the front orientation of the house is south, south-east or south-west to have a ridgeline running west-east the width which is always front of the house should be more than depth
								if ($new_data->{'front_orientation'} == 3 || $new_data->{'front_orientation'} == 7) {
									if ($new_data->{'exterior_width'} < $new_data->{'exterior_depth'}) {
										$houses_BIPVT[$count_BIPVT] = $new_data->{'file_name'};
										$count_BIPVT++;
										print $FILEOUT "$_ \n";
									}
								}
								else {
									if ($new_data->{'exterior_width'} > $new_data->{'exterior_depth'}) {
										$houses_BIPVT[$count_BIPVT] = $new_data->{'file_name'};
										$count_BIPVT++;
										print $FILEOUT "$_ \n";
									}
								}
							}
						}
						elsif ($new_data->{'ceiling_flat_type'} == 3) {
							if ($new_data->{'attachment_type'} == 2 || $new_data->{'attachment_type'} == 3) { # DR - left/right end house type
								if (($width->{$last_zone} * 2 / 3) >= 4 && ($new_data->{'bsmt_wall_height'} >= 2)){
									$houses_BIPVT[$count_BIPVT] = $new_data->{'file_name'};
									$count_BIPVT++;
									print $FILEOUT "$_ \n";
								  }
							}
						}
					}
					
				}
# 				print "$count_BIPVT \n";
				close $FILEOUT;
				$count->{$list->{$up}} = $count_BIPVT;
				push (@houses, @houses_BIPVT);
			}
		}
		close $FILEIN;
# 		print "The number of $list->{$up} is = $count->{$list->{$up}} \n";
	}
	
	return (@houses);
};

# ====================================================================
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
		$present_data->{'header'} = [CSVsplit($_)];  # split the header into an array
		print $file "$line \n";
	}
		
	# Check for the existance of the data tag, and if so store the data and return to the calling program.
	elsif ($line =~ /^\*data,/) {	
		# create a hash slice that uses the header and data
		# although this is a complex structure it simply creates a hash with an array of keys and array of values
		# @{$hash_ref}{@keys} = @values
		@{$present_data}{@{$present_data->{'header'}}} = CSVsplit($_);
	}
	# We have successfully identified a line of data, so return this to the calling program, complete with the header information to be passed back to this routine
	return ($present_data, $line);

};


# ====================================================================
# total_surface_area
# This subroutine calculate area of each side.
# ====================================================================

sub total_surface_area {
	my $x = shift;
	my $y = shift;
	my $z = shift;
	my $area;

	my @sides = qw (front back right left);

	foreach my $surface (@sides) {
		if ($surface =~ /^front$|^back$/){
			$area->{$surface} = $x * $z + $area->{$surface};
		}
		else {
			$area->{$surface} = $y * $z + $area->{$surface};
		}
	}
	return ($area);

};


# Final return value of one to indicate that the perl module is successful
1;
