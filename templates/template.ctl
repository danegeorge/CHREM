This line is log
* Building
Zone control description line
1 # No. of functions
* Control function
# senses the temperature of the current zone.
0 0 0 0 # SENSOR_DATA
# actuates air point of the current zone
0 0 0 # ACTUATOR_DATA
1 # No. day types
1 365 # valid Mon-01-Jan - Mon-31-Dec
1 # No. of periods in day
0 1 0.000 # ctl type, law (basic control), start @
7 # No. of data items
1000.000 0.000 1000.000 0.000 20.000 24.000 0.000 # DATA_LINE1
#ZONE_LINKS, comma seperate each zone (in order) and list the loop number the zone corresponds too (attc = 0)
1
