# ====================================================================
# Upgrade.pm
# Author: Sara Nikoofard
# Date: May 2011
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# upgrade_name: a subroutine that return the name of upgrade that is needed
# input_upgrade: it reads the input data for each upgrade from a csv file
# eligible_houses_pent: it select houses randomly from the eligible houses by using penetration level
# data_read_up:similar to one_data_line without *header
# data_read_one_up:similar to data_read_up without Fileout
# cross_ref_ups: cross referncing files and store in hash reference
# ====================================================================

# Declare the package name of this perl module
package Upgrade;

# Declare packages used by this perl module
use strict;
use CSV;	# CSV-2 (for CSV split and join, this works best)
use Switch;
use File::Path;
use Data::Dumper;
use XML::Simple; # to parse the XML results files
use XML::Dumper;
use Storable  qw(dclone);

# use lib qw(./modules);
use General;
use Cross_reference;
use Results;

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = qw(Exporter);

# Place the routines that are to be automatically exported here
our @EXPORT = qw(upgrade_name input_upgrade eligible_houses_pent data_read_up data_read_one_up cross_ref_ups up_house_side Economic_analysis print_results_out_difference_ECO GHG_conversion_difference_perc random_house_dist houses_selected_random);
# Place the routines that must be requested as a list following use in the calling script
our @EXPORT_OK = ();

# ====================================================================
# upgrade_name
# This subroutine recieves the user specified upgarde type. It interprets the appropriate Upgrade Types
# (e.g. 1 => SDHW) and outputs these back to the calling script. It asks for not more than 3 upgrades. 
# It will also issue warnings if the input is malformed.
# ====================================================================

sub upgrade_name {
	my $upgrade_num = shift; # upgrade number
	my $name_up;
	my $count = 0;
	my @list_up;
	my $flag_blind = 0;
	my $flag = 0;
	
	UP_LOOP: while ($upgrade_num =~ /^[1-9]?$/ && $upgrade_num =~ /\S/) {
		$list_up[$count] = $upgrade_num;
		$count++;
		if ($count == 3 ) {last UP_LOOP;} 
		$upgrade_num = <STDIN>;
		chomp ($upgrade_num);
	}
	foreach my $up (@list_up){
		if ($up == 1 || $up == 8 || $up == 9) {$flag++};
		if ($up == 4 || $up == 7) {$flag_blind++};
	}
	if ($flag > 1) { die "One of SDHW, PV and BIPVT should be selected \n";}
	if ($flag_blind > 1 ) {die "One of FVB or CVB should be selected \n";}
	foreach my $up (@list_up){
		switch ($up) {
			case (1) {$name_up->{$up} ='SDHW';}	# solar domestic hot water
			case (2) {$name_up->{$up} ='WAM';}	# changing window area
			case (3) {$name_up->{$up} ='WTM';}	# changing window type
			case (4) {$name_up->{$up} ='FVB';}	# fixed venetian blind
			case (5) {$name_up->{$up} ='FOH';}	# fixed overhang
			case (6) {$name_up->{$up} ='PCM';}	# phase change material
			case (7) {$name_up->{$up} ='CVB';}	# controlable venetian blind
			case (8) {$name_up->{$up} ='PV';}	# photovoltaic
			case (9) {$name_up->{$up} ='BIPVT';}	# building integrated photovoltaic / thermal
		}
	};
      return ($name_up);
	
};

# ====================================================================
# input_upgrade
# This subroutine recieves the user specified upgarde type.It asks for the required input and 
# store them to be used later.
# ====================================================================
sub input_upgrade {
	my $list = shift;
	my $input; # declare a hash that store inputs for all upgrades

	foreach my $up (keys (%{$list})) {
		if ($list->{$up} eq 'SDHW') {
		}
		elsif ($list->{$up} eq 'WAM') {
			$input->{$list->{$up}}= &cross_ref_up('../Input_upgrade/Input_'.$list->{$up}.'.csv');	# create an input reference crosslisting hash
			my %side_name = ("S", "South", "N", "North", "E", "East", "W", "West");

			# check if the window_wall_ratio is between 0 and 1
			if ($input->{$list->{$up}}->{'Wndw_Wall_Ratio'} < 0 || $input->{$list->{$up}}->{'Wndw_Wall_Ratio'} > 1) {
				die "window/wall area ratio should be a number between 0 and 1! \n";
			}
			
			# Check for the number of sides
			my $flag_num = 0;
			my $side_num;
			if ($input->{$list->{$up}}->{'Num'} =~ /[1..4]/) {
					$flag_num = 1;
					$side_num = $input->{$list->{$up}}->{'Num'};
			}
			if ($flag_num == 0) {die "side number is not in the range! \n";}

			# Check for the sides
			my @side= keys %side_name;
			my $flag_sid = 0;
			for (my $num = 1; $num <= $side_num; $num ++) {
				foreach my $sid (@side) {
					if ($input->{$list->{$up}}->{'Side_'.$num} =~ /$sid|$side_name{$sid}/) {
					$flag_sid = $flag_sid+1;
					$input->{$list->{$up}}->{'Side_'.$num} = $side_name{$sid};
					}
				}
			}
			if ($flag_sid < $side_num) {die "Side type is missing! \n";}
		}

		#-----------------------------------------------------------------------------
		# Window Type Modification Inputs (WTM)
		#-----------------------------------------------------------------------------
		# The required input for the window type modification is asked from the user. The inputs are :
		# 1- Window type, it needs three digits corresponding to glazing type, coating type and gas filled/width (exp. 203 double_glazed, clear glass, 13 mmm argon filled)
		# 2- Frame type, which is one of the following: {0 => 'FRM_Al', 1 => 'FRM_Al_brk', 2 => 'FRM_wood', 3 => 'FRM_wood_Al', 4 => 'FRM_Vnl', 5 => 'FRM_Vnl', 6 => 'FRM_Fbgls'}
		# 3- the number of sides that we want the windows are upgraded (1: ones side ...4:  all sides)
		# 4- The location of window which we want to be upgraded, (exp. if one side :south, if two sides: east and south)

		elsif ($list->{$up} eq 'WTM') {
			$input->{$list->{$up}}= &cross_ref_up('../Input_upgrade/Input_'.$list->{$up}.'.csv');	# create an input reference crosslisting hash
			my %window_name = (100, "SG clear", 200, "DG clear Air/13", 201, "DG clear Air/9", 202, "DG clear Air/6", 203, "DG clear Argon/13", 210, "DG low_e(0.04) Air/13", 213, "DG low_e(0.04) Argon/13", 220,"DG low_e(0.1) Air/13", 223, "DG low_e(0.1) Argon/13" , 224, "DG low_e(0.1) Argon/9", 230,"DG low_e(0.2) Air/13", 231, "DG low_e(0.2) Air/9", 233, "DG low_e(0.2) Argon/13", 234, "DG low_e(0.2) Argon/9", 240,"DG low_e(0.4) Air/13", 243, "DG low_e(0.4) Argon/13", 244, "DG low_e(0.4) Argon/9", 300, "TG clear Air/13", 301, "TG clear Air/9", 320,"TG low_e(0.1) Air/13", 323, "TG low_e(0.1) Argon/13", 330, "TG low_e(0.2) Air/13", 331, "TG low_e(0.2) Air/9", 333, "TG low_e(0.2) Argon/13", 334, "TG low_e(0.2) Argon/9");

			my %frame_name = (0, "FRM_Al", 1, "FRM_Al_brk", 2, "FRM_wood", 3, "FRM_wood_Al", 4, "FRM_Vnl", 5, "FRM_Vnl", 6, "FRM_Fbgls");

			my %side_name = ("S", "South", "N", "North", "E", "East", "W", "West");
			
			# Check window type
			my @window= keys %window_name;
			my $flag_win = 0;
			foreach my $win (@window) {
				if ($input->{$list->{$up}}->{'Wndw_type'} =~ /$win/) {
					$flag_win = 1;
				}
			}
			if ($flag_win == 0) {die "Window type is not listed!";}
			
			# Check frame type
			my @frame= keys %frame_name;
			my $flag_frm = 0;
			foreach my $frm (@frame) {
				if ($input->{$list->{$up}}->{'Frame_type'} =~ /$frm/) {
					$flag_frm = 1;
				}
			}
			if ($flag_frm == 0) {die "Frame type is not listed!";}
			
			# Check for the number of sides
			my $flag_num = 0;
			my $side_num;
			if ($input->{$list->{$up}}->{'Num'} =~ /[1..4]/) {
					$flag_num = 1;
					$side_num = $input->{$list->{$up}}->{'Num'};
			}
			if ($flag_num == 0) {die "side number is not in the range!";}

			# Check for the sides
			my @side= keys %side_name;
			my $flag_sid = 0;
			for (my $num = 1; $num <= $side_num; $num ++) {
				foreach my $sid (@side) {
					if ($input->{$list->{$up}}->{'Side_'.$num} =~ /$sid|$side_name{$sid}/) {
					$flag_sid = $flag_sid+1;
					$input->{$list->{$up}}->{'Side_'.$num} = $side_name{$sid};
					}
				}
			}
			if ($flag_sid < $side_num) {die "Side type is missing!";}
		}
		elsif ($list->{$up} eq 'FVB') {
		}
		elsif ($list->{$up} eq 'FOH') {
		}
		elsif ($list->{$up} eq 'PCM') {
		}
		elsif ($list->{$up} eq 'CVB') {
		}
		elsif ($list->{$up} eq 'PV') {
		}
		elsif ($list->{$up} eq 'BIPVT') {
		}
	}
	return ($input);
};

# ====================================================================
# eligible_houses_pent
# This subroutine recieves the user specified upgarde type and according the provided criteria 
# select eligible houses that can recieve upgrades for the specified house type and region.
# ====================================================================
sub eligible_houses_pent {

	my $hse_type = shift;
	my $region = shift;
	my $list = shift;
	my $pent = shift;
	my $houses;
	my @houses_selected;
	my @file_names;
	my $up_count = 0;
	
	foreach my $up (keys (%{$list})) {
		$up_count++;
		
		open (my $FILEIN, '<', '../Eligible_houses/Eligible_Houses_Upgarde_'.$list->{$up}.'_'.$hse_type.'_subset_'.$region.'.csv') or die ('Cannot open data file:  ../Eligible_houses/Eligible_Houses_Upgarde_'.$list->{$up}.'_'.$hse_type.'_subset_'.$region.'.csv'); 
		
		my $i = 0;
		my $new_data;
		while (<$FILEIN>){
			($new_data) = &data_read_one_up ($_, $new_data);
			if (defined ($new_data->{'file_name'})){
				$houses->{$up}->[$i] = $new_data->{'file_name'};
				$i++;
			}
		}
		close $FILEIN;
	}
	my $flag_up = 0;
	my %houses_count;
	my @array1;
	my @array2;
	my @array3;

	# Find the same houses in the different upgrade eligibile houses for a combination of upgrade

	foreach my $up (keys (%{$list})){
		@array1 = @{$houses->{$up}};
		$flag_up++;
		if ($up_count == 1) { 
			@houses_selected = @{$houses->{$up}};
		}
		elsif ( $up_count == 2) { 
			if ($flag_up == 1) {
				@array2 = @array1;
			}
			elsif ($flag_up == 2) {
				map $houses_count{$_}++ , @array1, @array2;
				@houses_selected = grep $houses_count{$_} == 2, @array1;
			}
		}
		else {
			if ($flag_up == 1) {
				@array3 = @array1;
			}
			elsif ($flag_up == 2) {
				@array2 = @array1;
			}
			else {
				map $houses_count{$_}++ , @array1, @array2, @array3;
				@houses_selected = grep $houses_count{$_} == 3, @array1;
			}
		}
	}

	my $count_up = $#houses_selected + 1;
	my $count_up_pent =  $count_up  * $pent / 100;
	my @houses_selected_pent;
	my $k;
	$count_up_pent = sprintf ("%.0f", $count_up_pent);
	print "selected houses are $count_up_pent  out of  $count_up . \n";
	for ($k = 0; $k < $count_up_pent; $k++) {
		my $random = int (rand ($count_up));
		$houses_selected_pent[$k] = $houses_selected[$random];
	}
	my $upgrade = '';
	foreach my $up (keys (%{$list})){
		$upgrade = $upgrade . $list->{$up}.'_';
	}
	# make a directory to hold the houses selected for the specific penetration level and upgrade(s)
	mkpath ("../Desired_houses");

	# remove any existing file
	foreach my $file (<../Desired_houses/*>) {
		my $check = 'selected_houses_'.$upgrade.'_'.$hse_type.'_subset_'.$region.'_'.'pent_'.$pent;
		if ($file =~ /$check/) {unlink ($file);};
	};

	# add the list of houses that are going to be modeled for this penetration level and upgrade(s)
	my $file = '../Desired_houses/selected_houses_'.$upgrade.'_'.$hse_type.'_subset_'.$region.'_'.'pent_'.$pent;
	my $ext = '.csv';
	open (my $FILEOUT, '>', $file.$ext) or die ("Can't open datafile: $file$ext");
	print $FILEOUT CSVjoin (@houses_selected_pent);

	return (@houses_selected_pent);
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

# ====================================================================
# data_read_one_up
# This subroutine is similar to data_read_up subroutine , it just don't
# accept the file out.
# ====================================================================

sub data_read_one_up {
	my $line = shift;
	# shift the existing data which may include the array of header info at $existing_data->{'header'}
	my $old_data = shift;

	my $present_data;	# create an crosslisting hash reference

	$line = &rm_EOL_and_trim($line);
	if (defined ($old_data->{'header'})) {
		$present_data->{'header'} = $old_data->{'header'};
	}
		
	# Check to see if header has not yet been encountered. This will fill out $new_data once and in subsequent calls to this subroutine with the same file the header will be set above.
	if ($line =~ /^\*header,/) {	
		$present_data->{'header'} = [CSVsplit($line)];  # split the header into an array
	}
		
	# Check for the existance of the data tag, and if so store the data and return to the calling program.
	elsif ($line =~ /^\*data,/) {	
		# create a hash slice that uses the header and data
		# although this is a complex structure it simply creates a hash with an array of keys and array of values
		# @{$hash_ref}{@keys} = @values
		@{$present_data}{@{$present_data->{'header'}}} = CSVsplit($line);
	}
	# We have successfully identified a line of data, so return this to the calling program, complete with the header information to be passed back to this routine
	return ($present_data);

};

# ====================================================================
# cross_ref_up
# This routines reads in cross referencing file that are tagged with 
# *header and *data information. It stores the information as hash references.
# It then returns this reference to the calling script.
# ====================================================================

sub cross_ref_up {
	# shift the passed file path
	my $file = shift;
	# show the user that we are working on this file. Note that the system call is used due to timing which can lead to a print statment not showing up until the readin is complete
	system ("printf \"Reading $file\"");

	# Open and read the crosslisting, note that the file handle below is a variable so that it simply goes out of scope
	open (my $FILE, '<', $file) or die ("can't open datafile: $file");

	my $cross_ref_up;	# create an crosslisting hash reference

	while (<$FILE>) {
		$_ = rm_EOL_and_trim($_);
		
		if ($_ =~ s/^\*header,//) {	# header row has *header tag, so remove this portion, and the key (first header value) leaving the CSV information
			$cross_ref_up->{'header'} = [CSVsplit($_)];	# split the header into an array
		}
			
		elsif ($_ =~ s/^\*data,//) {	# data lines will begin with the *data tag, so remove this portion, leaving the CSV information
			@_ = CSVsplit($_);	# split the data onto the @_ array
			
			# create a hash slice that uses the header and data array
			# although this is a complex structure it simply creates a hash with an array of keys and array of values
			# @{$hash_ref}{@keys} = @values
			@{$cross_ref_up}{@{$cross_ref_up->{'header'}}} = @_;
		};
	};
	
	# notify the user we are complete and start a new line
	print " - Complete\n";
	
	# Return the hash reference that includes all of the header and data
	return ($cross_ref_up);
};

# ====================================================================
# up_house_side
# This routines reads th efront orientation of the house and give all 
# house sides in 4 cardinal directions (e.g. front->south, back->north)
# ====================================================================

sub up_house_side {
	# shift the passed file path
	my $front = shift;
	my $house_sides;
	
	if ($front == 1 || $front == 2 || $front == 8) {
		$house_sides->{'front'} = "South";
		$house_sides->{'back'} = "North";
		$house_sides->{'right'} = "East";
		$house_sides->{'left'} = "West";
	}
	elsif ($front == 4 || $front == 5 || $front == 6) {
		$house_sides->{'front'} = "North";
		$house_sides->{'back'} = "South";
		$house_sides->{'right'} = "West";
		$house_sides->{'left'} = "East";
	}
	elsif ($front == 3) {
		$house_sides->{'front'} = "East";
		$house_sides->{'back'} = "West";
		$house_sides->{'right'} = "North";
		$house_sides->{'left'} = "South";
	}
	elsif ($front == 7) {
		$house_sides->{'front'} = "West";
		$house_sides->{'back'} = "East";
		$house_sides->{'right'} = "South";
		$house_sides->{'left'} = "North";
	}
	
	# Return the hash reference that includes all of the header and data
	return ($house_sides);
};

# ====================================================================
# Economic_analysis
# This routin computes the capital cost at the current year for each upgrade  
# regarding the interest rate and fuel escalation rate
# ====================================================================

sub Economic_analysis {
	my $results_all = shift;
	my $payback = shift;	#pay back period
	my $interest = shift;	#interst_rate
	my $escal_mode = shift;	#fuel escalation rate
	my $price_file;
	my $esc_file;
	
	# read the prices for different fules and regions
	if (-e '../../../keys/price_key.xml') {$price_file = '../../../keys/price_key.xml'}
	elsif (-e '../keys/price_key.xml') {$price_file = '../keys/price_key.xml'}
	my $price = XMLin($price_file);

	# Remove the 'en_src' field
	my $en_srcs = $price->{'en_src'};

	if (-e '../../../keys/escalation_key.xml') {$esc_file = '../../../keys/escalation_key.xml'}
	elsif (-e '../keys/escalation_key.xml') {$esc_file = '../keys/escalation_key.xml'}
	my $esc = XMLin($esc_file);

	# Remove the 'es_mode' field
	my $es_mode = $esc->{'es_mode'};

	# Cycle over the difference file and calculate the price
	foreach my $region (keys(%{$results_all->{'difference'}->{'house_names'}})) { # By region
		foreach my $province (keys(%{$results_all->{'difference'}->{'house_names'}->{$region}})) { # By province
			foreach my $hse_type (keys(%{$results_all->{'difference'}->{'house_names'}->{$region}->{$province}})) { # By house type
				foreach my $house (@{$results_all->{'difference'}->{'house_names'}->{$region}->{$province}->{$hse_type}}) { # Cycle over each listed house
					
					my $present_worth;	#present worth  of money
					my $site_price;
					# Create a shortcut
					my $house_result = $results_all->{'difference'}->{'house_results'}->{$house};
# 					my $house_elec_result = $results_all->{'difference'}->{'house_results_electricity'}->{$house};
				
					# Cycle over the results for this house and do the comparison
					foreach my $key (keys(%{$house_result})) {

						if ($key =~ /^src\/(\w+)\/quantity\/integrated$/) {
							my $src = $1;
							unless ($src =~ /mixed_wood/) {

							# saving price calculation (negative means saving)
								 $house_result->{"src/$src/price/integrated"} = $house_result->{$key} * $en_srcs->{$src}->{'province'}->{$province}->{'price'} / 100;
								 $results_all->{'difference'}->{'parameter'}->{"src/$src/price/integrated"} = 'CAN$';
		
							# nominal escalation rate and present worth of money for each fuel calculation
								 if ( $house_result->{"src/$src/price/integrated"} < 0) {
									my $nom_escal = $interest + $es_mode->{$escal_mode}->{'en_src'}->{$src}->{'rate'};
									if ($interest != $nom_escal) {
										$present_worth->{$src} =  $house_result->{"src/$src/price/integrated"} * ((1-(((1+$nom_escal/100)**($payback))*((1+$interest/100)**(-1*$payback))))/($interest/100-$nom_escal/100));
									}
									elsif ($interest == $nom_escal) { #this never happens but in case
										$present_worth->{$src} =  $house_result->{"src/$src/price/integrated"} * $payback * ((1+$interest/100)**(-1));
									}
									$house_result->{"src/$src/present_worth/integrated"} = -$present_worth->{$src}; # this should be positive because it shows capital cost
									$results_all->{'difference'}->{'parameter'}->{"src/$src/present_worth/integrated"} = 'CAN$';
								}
								else {
								      $house_result->{"src/$src/present_worth/integrated"} = 0;
								      $results_all->{'difference'}->{'parameter'}->{"src/$src/present_worth/integrated"} = 'CAN$';
								}
								 $site_price +=  $house_result->{"src/$src/price/integrated"};
								 $present_worth->{'total'} += $house_result->{"src/$src/present_worth/integrated"};
								 
							}
							else { #mixed_wood
								$house_result->{"src/$src/price/integrated"} = $house_result->{$key} * $en_srcs->{$src}->{'province'}->{$province}->{'price'};
								$results_all->{'difference'}->{'parameter'}->{"src/$src/price/integrated"} = 'CAN$';
								
								# nominal escalation rate and present worth of money for each fuel calculation
								 if ( $house_result->{"src/$src/price/integrated"} < 0) {
									my $nom_escal = $interest + $es_mode->{$escal_mode}->{'en_src'}->{$src}->{'rate'};
									if ($interest != $nom_escal) {
										$present_worth->{$src} =  $house_result->{"src/$src/price/integrated"} * ((1-(((1+$nom_escal/100)**($payback))*((1+$interest/100)**(-1*$payback))))/($interest/100-$nom_escal/100));
									}
									elsif ($interest == $nom_escal) { #this never happens but in case
										$present_worth->{$src} =  $house_result->{"src/$src/price/integrated"} * $payback * ((1+$interest/100)**(-1));
									}
									$house_result->{"src/$src/present_worth/integrated"} = -$present_worth->{$src}; # this should be positive because it shows capital cost
									$results_all->{'difference'}->{'parameter'}->{"src/$src/present_worth/integrated"} = 'CAN$';
								}
								else {
								      $house_result->{"src/$src/present_worth/integrated"} = 0;
								      $results_all->{'difference'}->{'parameter'}->{"src/$src/present_worth/integrated"} = 'CAN$';
								}
								 $site_price +=  $house_result->{"src/$src/price/integrated"};
								 $present_worth->{'total'} += $house_result->{"src/$src/present_worth/integrated"};
							}
								
						}
						

					};
					$house_result->{"site/PRICE/integrated"} = $site_price;
					$results_all->{'difference'}->{'parameter'}->{"site/PRICE/integrated"} = 'CAN$';
					$house_result->{"site/CAPITAL_COST/integrated"} = $present_worth->{'total'};
					$results_all->{'difference'}->{'parameter'}->{"site/CAPITAL_COST/integrated"} = 'CAN$';
					
				};
			};
		};
	};

# 	print Dumper $parameters;
	return(1);
};

# ====================================================================
# GHG_conversion_difference_perc
# This writes converts utility energy to GHG from the xml log reporting
# ====================================================================

sub GHG_conversion_difference_perc {
	my $results_all = shift;

	my $ghg_file;
	if (-e '../../../keys/GHG_key.xml') {$ghg_file = '../../../keys/GHG_key.xml'}
	elsif (-e '../keys/GHG_key.xml') {$ghg_file = '../keys/GHG_key.xml'}
	my $GHG = XMLin($ghg_file);

	# Remove the 'en_src' field
	my $en_srcs = $GHG->{'en_src'};

	# Cycle over the Difference file and calculate the GHG difference
	foreach my $region (keys(%{$results_all->{'difference'}->{'house_names'}})) { # By region
		foreach my $province (keys(%{$results_all->{'difference'}->{'house_names'}->{$region}})) { # By province
			foreach my $hse_type (keys(%{$results_all->{'difference'}->{'house_names'}->{$region}->{$province}})) { # By house type
				foreach my $house (@{$results_all->{'difference'}->{'house_names'}->{$region}->{$province}->{$hse_type}}) { # Cycle over each listed house
				
					my $site_ghg;
					my $use_ghg;
					
					# Create a shortcut
					my $house_result = $results_all->{'difference'}->{'house_results'}->{$house};
					my $house_elec_result = $results_all->{'difference'}->{'house_results_electricity'}->{$house};
				      
					# Cycle over the results for this house and do the comparison
					foreach my $key (keys(%{$house_result})) {

						if ($key =~ /^src\/(\w+)\/quantity\/integrated$/) {
							my $src = $1;
							unless ($src =~ /electricity/) {
								$house_result->{"src/$src/GHG/integrated"} = $house_result->{$key} * $en_srcs->{$src}->{'GHGIF'} / 1000;
								unless ($src =~ /mixed_wood/) {
									$house_result->{"src/$src/GHG_perc/integrated"} = $house_result->{"src/$src/GHG/integrated"} / ($results_all->{'orig'}->{'house_results'}->{$house}->{$key} * $en_srcs->{$src}->{'GHGIF'} / 1000) * 100;
								}
							}
							else { # electricity
								my $per_sum = 0;
								my $per_sum_orig = 0;
								foreach my $period (@{&order($house_elec_result->{$key})}) {
									my $mult;
									if (defined($en_srcs->{$src}->{'province'}->{$province}->{'period'}->{$period}->{'GHGIFmarginal'})) {
										$mult = $en_srcs->{$src}->{'province'}->{$province}->{'period'}->{$period}->{'GHGIFmarginal'};
									}
									else {
										$mult = $en_srcs->{$src}->{'province'}->{$province}->{'period'}->{'P00_Period'}->{'GHGIFmarginal'};
									};

									$per_sum += $house_elec_result->{$key}->{$period} / (1 - $en_srcs->{$src}->{'province'}->{$province}->{'trans_dist_loss'}) * $mult / 1000;
									$per_sum_orig += $results_all->{'orig'}->{'house_results_electricity'}->{$house}{$key}->{$period} / (1 - $en_srcs->{$src}->{'province'}->{$province}->{'trans_dist_loss'});
								};
								$house_result->{"src/$src/GHG/integrated"} = $per_sum;
								$house_result->{"src/$src/GHG_perc/integrated"} = $house_result->{"src/$src/GHG/integrated"} / ($per_sum_orig * $en_srcs->{$src}->{'province'}->{$province}->{'period'}->{'P00_Period'}->{'GHGIFavg'} / 1000) * 100;
							};
							$site_ghg += $house_result->{"src/$src/GHG/integrated"};
							$results_all->{'difference'}->{'parameter'}->{"src/$src/GHG/integrated"} = 'kg';
							$results_all->{'difference'}->{'parameter'}->{"src/$src/GHG_perc/integrated"} = '%';
						}

						elsif ($key =~ /^use\/(\w+)\/src\/(\w+)\/quantity\/integrated$/) {
							my $use = $1;
							my $src = $2;
							unless ($src =~ /electricity/) {
								$house_result->{"use/$use/src/$src/GHG/integrated"} = $house_result->{$key} * $en_srcs->{$src}->{'GHGIF'} / 1000;
							}
							else { # electricity
								my $per_sum = 0;
								foreach my $period (@{&order($house_elec_result->{$key})}) {
									my $mult;
									if (defined($en_srcs->{$src}->{'province'}->{$province}->{'period'}->{$period}->{'GHGIFmarginal'})) {
										$mult = $en_srcs->{$src}->{'province'}->{$province}->{'period'}->{$period}->{'GHGIFmarginal'};
									}
									else {
										$mult = $en_srcs->{$src}->{'province'}->{$province}->{'period'}->{'P00_Period'}->{'GHGIFmarginal'};
									};

									$per_sum += $house_elec_result->{$key}->{$period} / (1 - $en_srcs->{$src}->{'province'}->{$province}->{'trans_dist_loss'}) * $mult / 1000;
								};
								$house_result->{"use/$use/src/$src/GHG/integrated"} = $per_sum;
							};
							$use_ghg->{$use} += $house_result->{"use/$use/src/$src/GHG/integrated"};
							$results_all->{'difference'}->{'parameter'}->{"use/$use/src/$src/GHG/integrated"} = 'kg';
						}

					};
					
					$house_result->{"site/GHG/integrated"} = $site_ghg;
					$results_all->{'difference'}->{'parameter'}->{"site/GHG/integrated"} = 'kg';
					$house_result->{"site/GHG_perc/integrated"} = $site_ghg /  $results_all->{'orig'}->{'house_results'}->{$house}->{'site/GHG/integrated'} *100 ;
					$results_all->{'difference'}->{'parameter'}->{"site/GHG_perc/integrated"} = '%';
					
					foreach my $use (keys(%{$use_ghg})) {
						$house_result->{"use/$use/GHG/integrated"} = $use_ghg->{$use};
						$results_all->{'difference'}->{'parameter'}->{"use/$use/GHG/integrated"} = 'kg';
					};
				};
			};
		};
	};

# 	print Dumper $parameters;
	return(1);
};


#--------------------------------------------------------------------
# Subroutine to print out the Results
#--------------------------------------------------------------------
sub print_results_out_difference_ECO {
	my $results_multi_set = shift;
	my $set_name = shift;

	# We only want to focus on the difference
	# NOTE that we pass all the sets to get the correct multipliers
	my $results_all = $results_multi_set->{'difference'};

	# List the provinces in the preferred order
	my @provinces = ('NEWFOUNDLAND', 'NOVA SCOTIA' ,'PRINCE EDWARD ISLAND', 'NEW BRUNSWICK', 'QUEBEC', 'ONTARIO', 'MANITOBA', 'SASKATCHEWAN' ,'ALBERTA' ,'BRITISH COLUMBIA');
	my $prov_acronym;
	@{$prov_acronym}{@provinces} = qw(NF NS PE NB QC OT MB SK AB BC);

	# Declare and fill out a set out formats for values with particular units
	my $units = {};
	@{$units}{qw(GJ W kg kWh l m3 tonne COP CAN$)} = qw(%.1f %.0f %.0f %.0f %.0f %.0f %.3f %.2f %.1f);

	my $SHEU03_houses = {}; # Declare a variable to store the total number of desired houses based on SHEU-1993

	# Fill out the number of desired houses for each province. These values are a combination of SHEU-2003 (being the baseline and providing the regional values) and CENSUS 2006 (to distribute the regional values by province)
	@{$SHEU03_houses->{'1-SD'}}{@provinces} = qw(148879 259392 38980 215084 1513497 2724438 305111 285601 790508 910051);
	@{$SHEU03_houses->{'2-DR'}}{@provinces} = qw(26098 38778 6014 23260 469193 707777 34609 29494 182745 203449);


	if (defined($results_all->{'parameter'}) && defined($results_all->{'house_names'})) {
		# Order the results that we want to printout for each house
# 		my @result_params = @{&order($results_all->{'parameter'}, [qw(site src use)])};

		# Also create a totalizer of integrated units that will sum up for each province and house type individually
		my @result_total = grep(/^site\/\w+\/integrated$/, @{&order($results_all->{'parameter'}, [qw(site src use)])}); # Only store site consumptions
		push(@result_total, grep(/^src\/\w+\/\w+\/integrated$/, @{&order($results_all->{'parameter'}, [qw(site src use)])})); # Append src total consumptions
		push(@result_total, grep(/^use\/\w+\/\w+\/integrated$/, @{&order($results_all->{'parameter'}, [qw(site src use)])})); # Append end use total consumptions
		push(@result_total, @{&order($results_all->{'parameter'}, [qw(Zone_heat Heating_Sys Zone_cool Cooling_Sys)], [''])}); # Append zone and system heating/cooling info
# 		print Dumper $results_all->{'parameter'};
# 		print "\n@result_total\n";
		# Create a file to print out the house results to
		my $filename = "../summary_files/Results$set_name" . '_Houses.csv';
		open (my $FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

		# Setup the header lines for printing by passing refs to the variables and units
# 		my $header_lines = &results_headers([@result_params], [@{$results_all->{'parameter'}}{@result_params}]);
		my $header_lines = &results_headers([@result_total], [@{$results_all->{'parameter'}}{@result_total}]);

		# We have a few extra fields to put in place so make some spaces for other header lines
		my @space = ('', '', '', '', '');

		# Print out the header lines to the file. Note the space usage
		print $FILE CSVjoin(qw(*group), @space, @{$header_lines->{'group'}}) . "\n";
		print $FILE CSVjoin(qw(*src), @space, @{$header_lines->{'src'}}) . "\n";
		print $FILE CSVjoin(qw(*use), @space, @{$header_lines->{'use'}}) . "\n";
		print $FILE CSVjoin(qw(*variable), @space, @{$header_lines->{'variable'}}) . "\n";
		print $FILE CSVjoin(qw(*descriptor), @space, @{$header_lines->{'descriptor'}}) . "\n";
		print $FILE CSVjoin(qw(*units), @space, @{$header_lines->{'units'}}) . "\n";
		print $FILE CSVjoin(qw(*field house_name region province hse_type required_multiplier), @{$header_lines->{'field'}}) . "\n";


		# Declare a variable to store the total results by province and house type
		my $results_tot;

		# Cycle over each region, province and house type to store and accumulate the results
		foreach my $region (@{&order($results_all->{'house_names'})}) {
			foreach my $province (@{&order($results_all->{'house_names'}->{$region}, [@provinces])}) {
				foreach my $hse_type (@{&order($results_all->{'house_names'}->{$region}->{$province})}) {
					
					my ($region_short) = ($region =~ /\d-(\w{2})/);
					my ($hse_type_short) = ($hse_type =~ /\d-(\w{2})/);
					my $prov_short = $prov_acronym->{$province};
					
					# To determine the multiplier for the house type for a province, we must first determine the total desirable houses
					my $total_houses;
					# If it is defined in SHEU then use the number (this is to account for test cases like 3-CB)
					if (defined($SHEU03_houses->{$hse_type}->{$province})) {$total_houses = $SHEU03_houses->{$hse_type}->{$province};}
					# Otherwise set it equal to the number of present houses so the multiplier is 1
					else {$total_houses = @{$results_all->{'house_names'}->{$region}->{$province}->{$hse_type}};};
					
					# Calculate the house multiplier and format -NOTE USE THE ORIGINAL NUMBER OF HOUSES TO SCALE CORRECTLY
					# If we scale based the difference, the multiplier would be large as it would be to scale the upgraded only houses up to national.
					# Instead use the multipliers from the original set
					my $multiplier = sprintf("%.1f", $total_houses / @{$results_multi_set->{'orig'}->{'house_names'}->{$region}->{$province}->{$hse_type}});
					# Store the multiplier in the totalizer where it will be used later to scale the total results
					$results_tot->{$region}->{$province}->{$hse_type}->{'multiplier'} = $multiplier;

					# Cycle over each house with results and print out the results
					foreach my $hse_name (@{&order($results_all->{'house_names'}->{$region}->{$province}->{$hse_type})}) {
						# Print out the desirable fields and hten printout all the results for this house
# 						print $FILE CSVjoin('*data', $hse_name, $region_short, $prov_short, $hse_type_short, $multiplier, @{$results_all->{'house_results'}->{$hse_name}}{@result_params}) . "\n";
						print $FILE CSVjoin('*data', $hse_name, $region_short, $prov_short, $hse_type_short, $multiplier, @{$results_all->{'house_results'}->{$hse_name}}{@result_total}) . "\n";
						
						# Accumulate the results for this house into the provincial and house type total
						# Only cycle over the desirable fields (integrated only)
						foreach my $res_tot (@result_total) {
							# If the field exists for this house, then add it to the accumulator
							if (defined($results_all->{'house_results'}->{$hse_name}->{$res_tot})) {
								# To account for ventilation fans, CHREM incorporated these into CHREM_AL. With the exception for space_cooling. As such the fan power for heating fans was set to zero, but the fan power for cooling fans was not. Therefore, any consumption for ventilation is actually associated with space cooling. Rather than have an extra consumption end-use associated with ventilation, this incorporates such consumption into the space_cooling
								my $var = $res_tot; # Declare a variable the same as res_total to support changing the name without affecting the original
								$var =~ s/ventilation/space_cooling/; # Check for 'ventilation' and replace with 'space cooling'
								
								# If this is the first time encountered then set equal to zero. Use '$var'
								unless (defined($results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$var})) {
									$results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$var} = 0;
								};

								# Note the use of 'simulated'. This is so we can have a 'scaled' and 'per house' later
								# Note the use of $var for the totalizer and the use of $res_tot for the individual house results
								$results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$var} = $results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$var} + $results_all->{'house_results'}->{$hse_name}->{$res_tot};
							};
						};
					};
				};
			};
		};

		close $FILE; # The individual house data file is complete

		# Create a file to print the total scaled provincial results to
		$filename = "../summary_files/Results$set_name" . '_Total.csv';
		open ($FILE, '>', $filename) or die ("\n\nERROR: can't open $filename\n");

		# Declare and fill out a set of unit conversions for totalizing
		my @unit_base = qw(GJ kg kWh l m3 tonne COP CAN$);
		my $unit_conv = {};
		# These units have been adjusted to represent just the upgrades (so the units are less than PJ and Mt)
		@{$unit_conv->{'unit'}}{@unit_base} = qw(TJ kt GWh kl km3 kt BOGUS MCAN$);
		@{$unit_conv->{'mult'}}{@unit_base} = qw(1e-3 1e-6 1e-6 1e-3 1e-9 1e-3 0 1e-6);
		@{$unit_conv->{'format'}}{@unit_base} = qw(%.1f %.2f %.1f %.1f %.3f %.2f %.0f %.2f);

		# Determine the appropriate units for the totalized values
		my @converted_units = @{$unit_conv->{'unit'}}{@{$results_all->{'parameter'}}{@result_total}};

		# Setup the header lines for printing by passing refs to the variables and units
		$header_lines = &results_headers([@result_total], [@converted_units]);


		# We have a few extra fields to put in place so make some spaces for other header lines
		@space = ('', '', '', '', '');

		# Print out the header lines to the file. Note the space usage
		print $FILE CSVjoin(qw(*group), @space, @{$header_lines->{'group'}}) . "\n";
		print $FILE CSVjoin(qw(*src), @space, @{$header_lines->{'src'}}) . "\n";
		print $FILE CSVjoin(qw(*use), @space, @{$header_lines->{'use'}}) . "\n";
		print $FILE CSVjoin(qw(*variable), @space, @{$header_lines->{'variable'}}) . "\n";
		print $FILE CSVjoin(qw(*descriptor), @space, @{$header_lines->{'descriptor'}}) . "\n";
		print $FILE CSVjoin(qw(*units), @space, @{$header_lines->{'units'}}) . "\n";
		print $FILE CSVjoin(qw(*field source region province hse_type multiplier_used), @{$header_lines->{'field'}}) . "\n";

		my $results_Canada = {};

		# Cycle over the provinces and house types
		foreach my $region (@{&order($results_tot)}) {
			foreach my $province (@{&order($results_tot->{$region}, [@provinces])}) {
				foreach my $hse_type (@{&order($results_tot->{$region}->{$province})}) {
				
					my ($region_short) = ($region =~ /\d-(\w{2})/);
					my ($hse_type_short) = ($hse_type =~ /\d-(\w{2})/);
					my $prov_short = $prov_acronym->{$province};
				
					# Cycle over the desired accumulated results and scale them to national values using the previously calculated house representation multiplier
					foreach my $res_tot (@result_total) {
						if (defined($results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot})) {
							my $unit_orig = $results_all->{'parameter'}->{$res_tot};
							my $conversion = $unit_conv->{'mult'}->{$unit_orig};
							my $format = $unit_conv->{'format'}->{$unit_orig};
							# Note these are placed at 'scaled' so as not to corrupt the 'simulated' results, so that they may be used at a later point
							$results_tot->{$region}->{$province}->{$hse_type}->{'scaled'}->{$res_tot} = sprintf($format, $results_tot->{$region}->{$province}->{$hse_type}->{'simulated'}->{$res_tot} * $results_tot->{$region}->{$province}->{$hse_type}->{'multiplier'} * $conversion);
							# Add it to the national total
							unless (defined($results_Canada->{$hse_type_short}->{$res_tot})) {
								$results_Canada->{$hse_type_short}->{$res_tot} = 0
							};
							$results_Canada->{$hse_type_short}->{$res_tot} = sprintf($format, $results_Canada->{$hse_type_short}->{$res_tot} + $results_tot->{$region}->{$province}->{$hse_type}->{'scaled'}->{$res_tot});
						};
						
					};
					# Print out the national total results
					print $FILE CSVjoin('*data', 'CHREM', $region_short, $prov_short, $hse_type_short, $results_tot->{$region}->{$province}->{$hse_type}->{'multiplier'}, @{$results_tot->{$region}->{$province}->{$hse_type}->{'scaled'}}{@result_total}) . "\n";
				};
			};
		};
		
		foreach my $hse_type (@{&order($results_Canada, [qw(SD DR)])}) {
			print $FILE CSVjoin('*data', 'CHREM', 'Canada', '', $hse_type, 1, @{$results_Canada->{$hse_type}}{@result_total}) . "\n";
		};
		

		close $FILE; # The national scaled totals are now complete

	};
	return();
};

# ====================================================================
# random_house_dist
# This subroutine recieves the user specified amount of house that is 
# going to be selected randomly from CSDDRD and calculate the distribution  
# in different region and for different house types.
# ====================================================================
sub random_house_dist {

	my $hse_types = shift;
	my $regions = shift;
	my $num_hses = shift;
	
	
	my %SD_hse_num = ("1-AT", 1271,"2-QC", 2882, "3-OT", 5404, "4-PR", 2703, "5-BC", 1770);	# number of SD houses in each region
	my %DR_hse_num = ("1-AT", 137,"2-QC", 798, "3-OT", 1231, "4-PR", 441, "5-BC", 315);	# number of DR houses in each region

	my $tot_hses = 0;
	foreach my $hse_type (&array_order(values %{$hse_types})) {	# return for each house type
		foreach my $region (&array_order(values %{$regions})) {	# return for each region type
			if ($hse_type =~ /^1-SD$/) {
				$tot_hses +=  $SD_hse_num{$region};
			}
			else {
				$tot_hses += $DR_hse_num{$region};
			}
		}
	}
	my $hse_dist;
	my $hse_check = 0;
	foreach my $hse_type (&array_order(values %{$hse_types})) {	# return for each house type
		foreach my $region (&array_order(values %{$regions})) {	# return for each region type
			if ($hse_type =~ /^1-SD$/) {
				$hse_dist->{$hse_type}->{$region} =  sprintf("%.0f",($SD_hse_num{$region} / $tot_hses * $num_hses));
			}
			else {
				$hse_dist->{$hse_type}->{$region} =  sprintf("%.0f",($DR_hse_num{$region} / $tot_hses * $num_hses)); 
			}
			$hse_check += $hse_dist->{$hse_type}->{$region};
		}
	}
	if ($hse_check != $num_hses) { print "Due to rounding the number of houses are $hse_check! \n";}
		  
	  
	return ($hse_dist);
};

# ====================================================================
# houses_selected_random
# This subroutine select the desired houses for specified 
# number of houses for each house type and region.
# ====================================================================
sub houses_selected_random {

	my $hse_type = shift;
	my $region = shift;
	my $hse_dist = shift;
	my @houses;
	my @houses_selected;

	open (my $FILEIN, '<', '../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_type . '_subset_' . $region.'.csv') or die ('Cannot open data file: ../CSDDRD/2007-10-31_EGHD-HOT2XP_dupl-chk_A-files_region_qual_pref_' . $hse_type . '_subset_' . $region.'.csv');
	
	my $count;
	my $new_data;
	while (<$FILEIN>){
		($new_data) = &data_read_one_up ($_, $new_data);
			if (defined ($new_data->{'file_name'})){
				 $houses[$count] = $new_data->{'file_name'};
				 $count ++;
			}
	}
	close $FILEIN;
	my $k;
	for ($k = 0; $k < $hse_dist->{$hse_type}->{$region}; $k++) {
		my $random = int (rand ($#houses));
		$houses_selected[$k] = $houses[$random];
	}

	  # make a directory to hold the houses selected for the specific penetration level and upgrade(s)
	mkpath ("../Random_houses");

	# remove any existing file
	foreach my $file (<../Random_houses/*>) {
		my $check = 'random_selected_houses_'.$hse_type.'_subset_'.$region;
		if ($file =~ /$check/) {unlink ($file);};
	};

	# add the list of houses that are going to be modeled for this penetration level and upgrade(s)
	my $file = '../Random_houses/random_selected_houses_'.$hse_type.'_subset_'.$region;
	my $ext = '.csv';
	open (my $FILEOUT, '>', $file.$ext) or die ("Can't open datafile: $file$ext");
	print $FILEOUT CSVjoin (@houses_selected);
	
	return (@houses_selected);
};

# Final return value of one to indicate that the perl module is successful
1;
