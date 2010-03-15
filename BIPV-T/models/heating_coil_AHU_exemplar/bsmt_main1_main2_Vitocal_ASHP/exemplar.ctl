no overall control description supplied
* Building
no zone control description supplied
   3  # No. of functions
* Control function    1
# senses dry bulb temperature in main_1.
    1    0    0    0  # sensor data
# actuates the air point in main_1.
    1    0    0  # actuator data
    1 # No. day types
    1  365  # valid Sat-01-Jan - Sun-31-Dec
     1  # No. of periods in day: weekdays    
    0    6   0.000  # ctl type, law (flux zone/plant), start @
      7.  # No. of data items
  9.000 1.000 5.000 99000.000 99000.000 10.000 1.000
* Control function    2
# senses dry bulb temperature in main_2.
    2    0    0    0  # sensor data
# actuates the air point in main_2.
    2    0    0  # actuator data
    1 # No. day types
    1  365  # valid Sat-01-Jan - Sun-31-Dec
     1  # No. of periods in day: weekdays    
    0    6   0.000  # ctl type, law (flux zone/plant), start @
      7.  # No. of data items
  12.000 1.000 5.000 99000.000 99000.000 13.000 1.000
* Control function    3
# senses dry bulb temperature in bsmt.
    3    0    0    0  # sensor data
# actuates the air point in bsmt.
    3    0    0  # actuator data
    1 # No. day types
    1  365  # valid Sat-01-Jan - Sun-31-Dec
     1  # No. of periods in day: weekdays    
    0    6   0.000  # ctl type, law (flux zone/plant), start @
      7.  # No. of data items
  19.000 1.000 5.000 99000.000 99000.000 20.000 1.000
# Function:Zone links
 1,2,3,0,0,0,0,0,0
* Plant
no plant control description supplied
   5  # No. of loops
* Control loops    1
# senses var in compt.  5:tank @ node no.  1
   -1    5    1    0    0  # sensor 
# plant component   4:fan_ROOF @ node no.  1
   -1    4    1    0  # actuator 
    1 # No. day types
    1  365  # valid Sat-01-Jan - Sun-31-Dec
     3  # No. of periods in day: weekdays    
   12    8   0.000  # ctl type, law (On-Off control.), start @
      7.  # No. of data items
  -1.00000 35.00000 36.00000 0.00000 1.11000 0.00000 0.00000
   12    8   6.000  # ctl type, law (On-Off control.), start @
      7.  # No. of data items
  -1.00000 35.00000 50.00000 0.00000 1.11000 0.00000 0.00000
   12    0  24.000  # ctl type, law (period off), start @
      0.  # No. of data items
* Control loops    2
# senses var in compt.  4:fan_ROOF @ node no.  1
   -1    4    1    0    0  # sensor 
# plant component   1:pump_HP @ node no.  1
   -1    1    1    0  # actuator 
    1 # No. day types
    1  365  # valid Sat-01-Jan - Sun-31-Dec
     1  # No. of periods in day: weekdays    
    5    8   0.000  # ctl type, law (On-Off control.), start @
      7.  # No. of data items
  -1.00000 0.10000 0.20000 0.00038 0.00000 0.00000 0.00000
* Control loops    3
# senses dry bulb temperature in main_1.
    1    0    0    0    0  # sensor 
# plant component   2:pump_supp @ node no.  1
   -1    2    1    0  # actuator 
    1 # No. day types
    1  365  # valid Sat-01-Jan - Sun-31-Dec
     1  # No. of periods in day: weekdays    
   12    8   0.000  # ctl type, law (On-Off control.), start @
      7.  # No. of data items
  -1.00000 20.00000 22.00000 0.00000 0.00020 0.00000 0.00000
* Control loops    4
# senses dry bulb temperature in main_1.
    1    0    0    0    0  # sensor 
# plant component   8:fan_AHU @ node no.  1
   -1    8    1    0  # actuator 
    1 # No. day types
    1  365  # valid Sat-01-Jan - Sun-31-Dec
     1  # No. of periods in day: weekdays    
   12    8   0.000  # ctl type, law (On-Off control.), start @
      7.  # No. of data items
  -1.00000 20.00000 22.00000 0.00000 1.00000 0.00000 0.00000
* Control loops    5
# senses dry bulb temperature in main_1.
    1    0    0    0    0  # sensor 
# plant component  17:bup_inline_htr @ node no.  1
   -1   17    1    0  # actuator 
    1 # No. day types
    1  365  # valid Sat-01-Jan - Sun-31-Dec
     1  # No. of periods in day: weekdays    
   12    8   0.000  # ctl type, law (On-Off control.), start @
      7.  # No. of data items
  -1.00000 18.00000 20.00000 0.00000 10000.00000 0.00000 0.00000
* Mass Flow
no flow control description supplied
   1  # No. of controls
* Control mass    1
# senses connection (  6) bipvt5 - outlet
   -4    6    0    1  # sensor data
# actuates flow component:   3 damper_vent
   -4    3    1  # actuator data
    1 # No. day types
    1  365  # valid Sat-01-Jan - Sun-31-Dec
     1  # No. of periods in day: weekdays    
    5    0   0.000  # ctl type (1st phase > flow), law (on/off setpoint 0.75 inverse action ON fraction 0.000.), starting @
      3.  # No. of data items
  0.75000 -1.00000 0.00000
bipvt5        outlet        damper_vent   bipvt5        outlet      
