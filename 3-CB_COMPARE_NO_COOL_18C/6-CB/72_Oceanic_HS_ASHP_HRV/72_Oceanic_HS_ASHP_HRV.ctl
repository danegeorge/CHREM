This line is control log
* Building
Zone control description line
#NUM_FUNCTIONS number of functions
3
#
#
#FUNCTION_DATA
#
#
#CTL_TAG - THIS IS A MASTER OR DISTRIBUTED CONTROLLER FOR ZONE 1
* Control function
#SENSOR_DATA four values - zero for in zone, first digit is zone num if sense in one zone only
1 0 0 0
#ACTUATOR_DATA three values - zero for in zone
1 0 0
#NUM_YEAR_PERIODS number of periods in year
5 # To represent the seasonal use of the thermostat for heating and cooling
#
#VALID_DAYS day # to day #; THIS IS WINTER HEATING
1 91
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (basic control), start @ hr
0 1 0
#NUM_DATA_ITEMS Number of data items
7
#DATA_LINE1 space seperated
12591 0 0 0 18 100 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?
#
#VALID_DAYS day # to day #; THIS IS SPRING WITH BOTH HEAT AND COOL
92 154
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (basic control), start @ hr
0 1 0
#NUM_DATA_ITEMS Number of data items
7
#DATA_LINE1 space seperated
12591 0 0 0 18 25 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?
#
#VALID_DAYS day # to day #; THIS IS SUMMER COOLING
155 259
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (basic control), start @ hr
0 1 0
#NUM_DATA_ITEMS Number of data items
7
#DATA_LINE1 space seperated
12591 0 0 0 0 25 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?
#
#VALID_DAYS day # to day #; THIS IS FALL WITH BOTH HEAT AND COOL
260 280
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (basic control), start @ hr
0 1 0
#NUM_DATA_ITEMS Number of data items
7
#DATA_LINE1 space seperated
12591 0 0 0 18 25 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?
#
#VALID_DAYS day # to day #; THIS IS WINTER HEATING
281 365
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (basic control), start @ hr
0 1 0
#NUM_DATA_ITEMS Number of data items
7
#DATA_LINE1 space seperated
12591 0 0 0 18 100 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?
#
#
#CTL_TAG - THIS IS THE SLAVE CONTROLLER FOR ZONE NUMBER 2
* Control function
#SENSOR_DATA four values - master controller zone number followed by zeroes
1 0 0 0
#ACTUATOR_DATA three values - actuator zone number followed by zeroes
2 0 0
#NUM_YEAR_PERIODS number of periods in year
1
#
#VALID_DAYS day # to day #
1 365
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (SLAVE), start @ hr
0 21 0
#NUM_DATA_ITEMS Number of data items
3
#DATA_LINE1 space seperated: master controller number, heat capacity (W), cool capacity (W)
1 14209 0
#
#
#CTL_TAG - THIS IS A FREE-FLOAT CONTROLLER
* Control function
#SENSOR_DATA four values - zero for in present zone followed by zeroes
0 0 0 0
#ACTUATOR_DATA three values - zero for in present zone followed by zeroes
0 0 0
#NUM_YEAR_PERIODS number of periods in year
1
#
#VALID_DAYS day # to day #
1 365
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (FREE FLOATING), start @ hr
0 2 0
#NUM_DATA_ITEMS Number of data items
0
#END_FUNCTION_DATA
#
#
#ZONE_LINKS, each zone (in order) and list the loop number the zone corresponds too (e.g main = 1, if none the equal 0 [bad idea])
1 2 3
