control for 2508A00065_NB  # overall descr 
* Building
building cntl fn model  # bld descr
   3  # No. of functions
* Control Function # 1[Main] 
# senses dry bulb temperature in Main
    1    0    0    0    0  # sensor data
# actuates air point of the current zone
    0    0    0    0  # actuator data
    5 # No. day types
# ++++++ Day Type: 1 +++++
    1  91  # valid Thu  1 Jan - Wed  1 Apr
     1  # No. of periods in day
#    >>>>Day Type: 1 - Period: 1<<<<
    0     1  0.000  # ctl type, law (basic control), start @
7  # No. of data items
14350.000 0.000 0.000 0.000 21.000 100.000 0.000   # MaxHCap/MinHCap/MaxCCap/MinCCap/HStPt/CStPt/ClTRng
# ++++++ Day Type: 2 +++++
    92  154  # valid Thu  2 Apr - Wed  3 Jun
     1  # No. of periods in day
#    >>>>Day Type: 2 - Period: 1<<<<
    0     2  0.000  # ctl type, law (free floating), start @
0  # No. of data items
# ++++++ Day Type: 3 +++++
    155  259  # valid Thu  4 Jun - Wed 16 Sep
     1  # No. of periods in day
#    >>>>Day Type: 3 - Period: 1<<<<
    0     1  0.000  # ctl type, law (basic control), start @
7  # No. of data items
0.000 0.000 3447.807 0.000 10.000 25.000 0.000   # MaxHCap/MinHCap/MaxCCap/MinCCap/HStPt/CStPt/ClTRng
# ++++++ Day Type: 4 +++++
    260  280  # valid Thu 17 Sep - Wed  7 Oct
     1  # No. of periods in day
#    >>>>Day Type: 4 - Period: 1<<<<
    0     2  0.000  # ctl type, law (free floating), start @
0  # No. of data items
# ++++++ Day Type: 5 +++++
    281  365  # valid Thu  8 Oct - Thu 31 Dec
     1  # No. of periods in day
#    >>>>Day Type: 5 - Period: 1<<<<
    0     1  0.000  # ctl type, law (basic control), start @
7  # No. of data items
14350.000 0.000 0.000 0.000 21.000 100.000 0.000   # MaxHCap/MinHCap/MaxCCap/MinCCap/HStPt/CStPt/ClTRng
# END  Control Function   # 1
* Control Function # 2[Foundation-1] 
# senses dry bulb temperature in Main
    1    0    0    0    0  # sensor data
# actuates the air point in zone Foundation-1
    3    0    0    0  # actuator data
    1 # No. day types
# ++++++ Day Type: 1 +++++
    1  365  # valid Thu  1 Jan - Thu 31 Dec
     1  # No. of periods in day
#    >>>>Day Type: 1 - Period: 1<<<<
    0    21  0.000  # ctl type, law (slave law), start @
3  # No. of data items
1.000 6150.000 0.000   # MasterCtlFnc/MaxHCap/MaxCCap
# END  Control Function   # 2
* Control Function # 3[Ceiling01] 
# senses the temperature of the current zone.
    0    0    0    0    0  # sensor data
# actuates air point of the current zone
    0    0    0    0  # actuator data
    1 # No. day types
# ++++++ Day Type: 1 +++++
    1  365  # valid Thu  1 Jan - Thu 31 Dec
     1  # No. of periods in day
#    >>>>Day Type: 1 - Period: 1<<<<
    0     2  0.000  # ctl type, law (free floating), start @
0  # No. of data items
# END  Control Function   # 3
# Function:Zone links
1 3 2 
