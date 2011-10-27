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
use Data::Dumper;

use lib qw(./modules);
use General;
use Cross_reference;

# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = qw(Exporter);

# Place the routines that are to be automatically exported here
our @EXPORT = qw(upgrade_name input_upgrade eligible_houses_pent data_read_up data_read_one_up cross_ref_ups up_house_side Economic_analysis);
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
	return();
};


# Final return value of one to indicate that the perl module is successful
1;
