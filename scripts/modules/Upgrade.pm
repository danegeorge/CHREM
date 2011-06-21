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
our @EXPORT = qw(upgrade_name eligible_houses_pent data_read_up data_read_one_up);
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
	
	
	foreach my $up (keys (%{$list})) {
		open (my $COUNT, '<', '../Eligible_houses/Count.csv') or die("Can't open ../Eligible_houses/Count.csv \n");
		my $count_up;
		my $new_data;
		while (<$COUNT>) {
			($new_data) = &data_read_one_up ($_, $new_data); 
			if (($new_data->{'hse_type'} eq $hse_type) && ($new_data->{'region'} eq $region) && ($new_data->{'upgrade'} eq $list->{$up})) {
				$count_up = $new_data->{'eligible'};
				last;
			}
		}
		
		open (my $FILEIN, '<', '../Eligible_houses/Eligible_Houses_Upgarde_'.$list->{$up}.'_'.$hse_type.'_subset_'.$region.'.csv') or die ('Cannot open data file:  ../Eligible_houses/Eligible_Houses_Upgarde_'.$list->{$up}.'_'.$hse_type.'_subset_'.$region.'.csv'); 
		my @file_names;
		my $i = 0;
		while (<$FILEIN>){
			($new_data) = &data_read_one_up ($_, $new_data);
			if (defined ($new_data->{'file_name'})){
				$file_names[$i] = $new_data->{'file_name'};
				$i++;
			}
		}
		my $count_up_pent = $count_up * $pent / 100;
		my @houses_selected;
		my $k;
		$count_up_pent = sprintf ("%.0f", $count_up_pent);
		print "$count_up_pent \n";
		for ($k = 0; $k < $count_up_pent; $k++) {
			my $random = int (rand ($count_up));
			$houses_selected[$k] = $file_names[$random];
		}
		$houses->{$up} = [@houses_selected];
		close $FILEIN;
		close $COUNT;
	}
	
	return ($houses);
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
# Final return value of one to indicate that the perl module is successful
1;
