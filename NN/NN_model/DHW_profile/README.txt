November 2007- Lukas Swan, PhD Student, Dalhousie University; lswan@dal.ca
----
This folder includes the normalization of 1 minute Domestic Hot Water DHW Load profiles gathered
from the IEA ANNEX 42. The data range is averaged to allow for different time intervals.
It then uses the previously determined annual DHW annual energy consumption from the NN values calculation and multiplies this value
by the normalized values over the time intervals to achieve a load profile in Watts.
Two PERL scripts are used to accomplish this task: the first normalizes the profiles
to the desired time interval and the second applies the annual energy consumption to the
normalized profile to determine a final DHW power profile in Watts.


2007-11-14a_DHW-profile-normalize.pl
	This PERL script calls 3 load profiles DHW_minute"X"-litre"Y"00.txt and normalizes
	their litres by the annual energy consumption (litres) of the profile.
	"X" corresponds to the number of average minutes per datapoint as defined by ANNEX 42.
	It was found that the 1 minute version was the most detailed.
	"Y" corresponds to the average daily DHW load in litres/100 as defined by ANNEX 42.
	It then reaverages the profile as a function of desired time variable "$minutes_desired" on line 11.
	Please verify that the variable "$minutes_data" is set to the number of minutes per data point
	of the original data. The resultant array consists of a value that is to be multiplied by the annual NN DHW 
	calculated energy consumption to result in average Watts over the defined time step.
	The script outputs 3 normalized load profiles 2007-11-14_DHW-minute"$minutes_desired"-litre"Y"-normalized.csv

2007-11-14a_DHW-NN-profile.pl
	This PERL script calls the 3 prior developed normalized profiles as defined by the 
	variable "$minutes_desired" over which the resultant average Watts are desired.
	The script then call the DHW-Results.csv file developed in the NN_annual_energy_calc folder.
	The script matches the dwellings DHW energy consumption to the appropriate consumption profile based on 
	average daily DHW consumption. This was calculated by dividing the annual DHW energy consumption by 365 and
	further dividing by the Cp and a temperature difference of 50C to obtain the mass. The SG was taken as 1.
	It then multiplies each time interval value by the annual energy 
	consumption (kWh) to obtain average Watts over the give time interval.
	Its output is a text file 2007-11-22_DHW-profile-minutes"$minutes_desired".csv which contains the dwellings'
	yearly Watts profile in rows. The number of columns corresponds to the number of time intervals
	within a year plus 5 preceding columns with dwelling information.
