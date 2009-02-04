November 2007- Lukas Swan, PhD Student, Dalhousie University; lswan@dal.ca
----
This folder includes the normalization of 5 minute Appliance and Load profiles gathered
from the IEA ANNEX 42. The data range is averaged to allow for different time intervals.
It then uses the previously determined annual Appliance and Lighting
(no cooling) energy load from the NN values calculation and multiplies this value
by the normalized values over the time intervals to achieve a load profile in Watts.
Two PERL scripts are used to accomplish this task: the first normalizes the profiles
to the desired time interval and the second applies the annual energy consumption to the
normalized profile to determine a final AL power profile in Watts.


2007-11-14a_AL-profile-normalize.pl
	This PERL script calls all 9 load profiles can_gen_c"X"-y"Z".fcl and normalizes
	their Watts (5 minute interval) by the annual energy consumption (kWh) of the profile.
	"X" corresponds to low, med, and high energy consumption ranges as defined by ANNEX 42.
	"Y" corresponds to the profile year as defined by ANNEX 42.
	It then reaverages the profile as a function of desired time variable "$minutes" on line 10
	which is the only user input. The resultant array consists of Watts per units time normalized
	by annual energy consumption in kWh.
	The script outputs 9 normalized load profiles 2007-11-14_AL-consumption"X"-year"Z"-minutes"$minutes"-normalized.csv

2007-11-14a_AL-NN-profile.pl
	This PERL script calls the 9 prior developed normalized profiles as defined by the 
	variable "$minutes" over which the resultant average Watts are desired.
	The script then call the ALC-Results.csv file developed in the NN_annual_energy_calc folder.
	The script matches the dwellings ALC energy consumption to the appropriate consumption profile
	and randomly assigns a yearly profile. It then multiplies each time interval value by the annual energy 
	consumption (kWh) to obtain average Watts over the give time interval.
	Its output is a text file 2007-11-22_AL-profile-minutes"$minutes".csv which contains the dwellings'
	yearly Watts profile in rows. The number of columns corresponds to the number of time intervals
	within a year plus 5 preceding columns with dwelling information.
