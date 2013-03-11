# ====================================================================
# Control.pm
# Author: Lukas Swan
# Date: Nov 2009
# Copyright: Dalhousie University
# ====================================================================
# The following subroutines are included in the perl module:
# basic_5_season: applies the basic controller with 5 season types to control heat/cool use
# slave: slave controller for zones that key off the central thermostat in basic_5_season
# free_float: a free floating controller
# ====================================================================

# Declare the package name of this perl module
package Control;

# Declare packages used by this perl module
use strict;
use CSV;	# CSV-2 (for CSV split and join, this works best)
use Data::Dumper;


# Set the package up to export the subroutines for local use within the calling perl script
require Exporter;
our @ISA = qw(Exporter);

# Place the routines that are to be automatically exported here
our @EXPORT = qw(basic_5_season slave free_float);
# Place the routines that must be requested as a list following use in the calling script
our @EXPORT_OK = ();

# ====================================================================
# basic_5_season
# This fills out the basic control type with 5 season types
# to control the use of heating and cooling throughout the year
# ====================================================================

sub basic_5_season {
	my $zone_num = shift; # zone number
	my $heat_W = shift; # maximum heating system watts
	my $cool_W = shift; # maximum cooling system watts
	my $vol_ratio = shift; # volume ratio of the zone to all conditioned zones
	
	# Apply the zone volume ratio to the heating and cooling capacities so they are for this zone only
	$heat_W = sprintf("%.0f", $heat_W * $vol_ratio);
	$cool_W = sprintf("%.0f", $cool_W * $vol_ratio);
	
	# Declare heating and cooling setpoints
	my $heat_T = 21;
	my $cool_T = 25;
	
	# Develop the control information lines in an array
	my @control = 
		('#',
		'#',
		"#CTL_TAG - THIS IS A MASTER OR DISTRIBUTED CONTROLLER FOR ZONE $zone_num",
		'* Control function',
		'#SENSOR_DATA four values - zero for in zone, first digit is zone num if sense in one zone only',
		"$zone_num 0 0 0",
		'#ACTUATOR_DATA three values - zero for in zone',
		"$zone_num 0 0",
		'#NUM_YEAR_PERIODS number of periods in year',
		'5 # To represent the seasonal use of the thermostat for heating and cooling',
		'#',
		'#VALID_DAYS day # to day #; THIS IS WINTER HEATING',
		'1 91',
		'#NUM_DAY_PERIODS',
		'1',
		'#CTL_TYPE ctl type, law (basic control), start @ hr',
		'0 1 0',
		'#NUM_DATA_ITEMS Number of data items',
		'7',
		'#DATA_LINE1 space seperated',
		"$heat_W 0 $cool_W 0 $heat_T 100 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?",
		'#',
		'#VALID_DAYS day # to day #; THIS IS SPRING WITH BOTH HEAT AND COOL',
		'92 154',
		'#NUM_DAY_PERIODS',
		'1',
		'#CTL_TYPE ctl type, law (basic control), start @ hr',
		'0 1 0',
		'#NUM_DATA_ITEMS Number of data items',
		'7',
		'#DATA_LINE1 space seperated',
		"$heat_W 0 $cool_W 0 $heat_T $cool_T 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?",
		'#',
		'#VALID_DAYS day # to day #; THIS IS SUMMER COOLING',
		'155 259',
		'#NUM_DAY_PERIODS',
		'1',
		'#CTL_TYPE ctl type, law (basic control), start @ hr',
		'0 1 0',
		'#NUM_DATA_ITEMS Number of data items',
		'7',
		'#DATA_LINE1 space seperated',
		"$heat_W 0 $cool_W 0 0 $cool_T 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?",
		'#',
		'#VALID_DAYS day # to day #; THIS IS FALL WITH BOTH HEAT AND COOL',
		'260 280',
		'#NUM_DAY_PERIODS',
		'1',
		'#CTL_TYPE ctl type, law (basic control), start @ hr',
		'0 1 0',
		'#NUM_DATA_ITEMS Number of data items',
		'7',
		'#DATA_LINE1 space seperated',
		"$heat_W 0 $cool_W 0 $heat_T $cool_T 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?",
		'#',
		'#VALID_DAYS day # to day #; THIS IS WINTER HEATING',
		'281 365',
		'#NUM_DAY_PERIODS',
		'1',
		'#CTL_TYPE ctl type, law (basic control), start @ hr',
		'0 1 0',
		'#NUM_DATA_ITEMS Number of data items',
		'7',
		'#DATA_LINE1 space seperated',
		"$heat_W 0 $cool_W 0 $heat_T 100 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?");
	
	# Declare a string to store the concatenated control lines
	my $string = '';
	
	# Cycle over the array and concatenate the lines with an end of line character
	foreach my $line (@control) {
		$string = $string . $line . "\n";
	};
	
	# Return the string
	return ($string);
};


# ====================================================================
# slave
# This fills out the slave control type which relies on links to the 
# master zone for the sensor and the master controller for on/off
# ====================================================================

sub slave {
	my $zone_num = shift; # zone number
	my $heat_W = shift; # maximum heating system watts
	my $cool_W = shift; # maximum cooling system watts
	my $vol_ratio = shift; # volume ratio of the zone to all conditioned zones
	my $master_num = shift; # the master zone controller number which is equal to the main_1 zone number
	
	# Apply the zone volume ratio to the heating and cooling capacities so they are for this zone only
	$heat_W = sprintf("%.0f", $heat_W * $vol_ratio);
	$cool_W = sprintf("%.0f", $cool_W * $vol_ratio);
	
	# Develop the control information lines in an array
	my @control = 
		('#',
		'#',
		"#CTL_TAG - THIS IS THE SLAVE CONTROLLER FOR ZONE NUMBER $zone_num",
		'* Control function',
		'#SENSOR_DATA four values - master controller zone number followed by zeroes',
		"$master_num 0 0 0",
		'#ACTUATOR_DATA three values - actuator zone number followed by zeroes',
		"$zone_num 0 0",
		'#NUM_YEAR_PERIODS number of periods in year',
		'1',
		'#',
		'#VALID_DAYS day # to day #',
		'1 365',
		'#NUM_DAY_PERIODS',
		'1',
		'#CTL_TYPE ctl type, law (SLAVE), start @ hr',
		'0 21 0',
		'#NUM_DATA_ITEMS Number of data items',
		'3',
		'#DATA_LINE1 space seperated: master controller number, heat capacity (W), cool capacity (W)',
		"$master_num $heat_W $cool_W");

	# Declare a string to store the concatenated control lines
	my $string = '';
	
	# Cycle over the array and concatenate the lines with an end of line character
	foreach my $line (@control) {
		$string = $string . $line . "\n";
	};
	
	# Return the string
	return ($string);
};



sub free_float {

	# Construct an array of the required control lines
	my @control =
		('#',
		'#',
		'#CTL_TAG - THIS IS A FREE-FLOAT CONTROLLER',
		'* Control function',
		'#SENSOR_DATA four values - zero for in present zone followed by zeroes',
		'0 0 0 0',
		'#ACTUATOR_DATA three values - zero for in present zone followed by zeroes',
		'0 0 0',
		'#NUM_YEAR_PERIODS number of periods in year',
		'1',
		'#',
		'#VALID_DAYS day # to day #',
		'1 365',
		'#NUM_DAY_PERIODS',
		'1',
		'#CTL_TYPE ctl type, law (FREE FLOATING), start @ hr',
		'0 2 0',
		'#NUM_DATA_ITEMS Number of data items',
		'0');

	# Declare a string to store the concatenated control lines
	my $string = '';
	
	# Cycle over the array and concatenate the lines with an end of line character
	foreach my $line (@control) {
		$string = $string . $line . "\n";
	};
	
	# Return the string
	return ($string);
};

# Final return value of one to indicate that the perl module is successful
1;
