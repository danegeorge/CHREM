This line is log
* Building
Zone control description line
#NUM_FUNCTIONS number of functions
2
#
#
#CTL_TAG
* Control function
#SENSOR_DATA four values - zero for in zone, first digit is zone num if sense in one zone only
0 0 0 0
#ACTUATOR_DATA three values - zero for in zone
0 0 0
#NUM_YEAR_PERIODS number of periods in year
5
#
#VALID_DAYS day # to day #
1 91
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (basic control), start @ hr
0 1 0
#NUM_DATA_ITEMS Number of data items
7
#DATA_LINE1 space seperated
100000 0 100000 0 21 100 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?
#
#VALID_DAYS day # to day #
92 154
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (free floating), start @ hr
0 2 0
#NUM_DATA_ITEMS Number of data items
0
#
#VALID_DAYS day # to day #
155 259
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (basic control), start @ hr
0 1 0
#NUM_DATA_ITEMS Number of data items
7
#DATA_LINE1 space seperated
100000 0 100000 0 10 25 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?
#
#VALID_DAYS day # to day #
260 280
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (free floating), start @ hr
0 2 0
#NUM_DATA_ITEMS Number of data items
0
#VALID_DAYS day # to day #
281 365
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (basic control), start @ hr
0 1 0
#NUM_DATA_ITEMS Number of data items
7
#DATA_LINE1 space seperated
100000 0 100000 0 21 100 0 # heat_max_W heat_min_W cool_max_W cool_min_W heat_setpoint_C cool_setpoint_C relative_humidity?
#
#
#CTL_TAG
* Control function
#SENSOR_DATA four values - zero for in zone, first digit is zone num if sense in one zone only
0 0 0 0
#ACTUATOR_DATA three values - zero for in zone
0 0 0
#NUM_YEAR_PERIODS number of periods in year
1
#
#VALID_DAYS day # to day #
1 365
#NUM_DAY_PERIODS
1
#CTL_TYPE ctl type, law (free floating), start @ hr
0 2 0
#NUM_DATA_ITEMS Number of data items
0
#
#ZONE_LINKS, comma seperate each zone (in order) and list the loop number the zone corresponds too (attc = 0)
1 1 2