November 2007- Lukas Swan, PhD Student, Dalhousie University; lswan@dal.ca
----
This folder includes 2 forms of models which utilize the Neural Network 
results from Merih Aydinalp's PhD thesis (2002, Dalhousie University).

Model 1: Excel
A Space Heating (SH) model was created in MS Excel. It incorporates the inputs, 
hidden layers, and outputs. Calculations include the weighting, bias, and 
activation functions.
The model is titled: SH-Excel-model-of-MA-thesis_V2.xls
Column C allows for the input of parameters associated with the dwelling to be 
modelled.
Column Y and Z are the resultant annual energy consumption in GJ and kWh, respectively.
All remaining columns are either descriptive, calculations, or values.


Model 2: PERL
This is a flexible script which performs the calculations to determine energy 
consumption of the input dwelling by calling the appropriate text file (*.csv) 
for input weights, bias, and activation functions.
The script may be run from any Linux terminal which has PERL installed.
see www.perl.com

Description of input files:
***-Inputs-V1.csv: A text file where each row (except for header) is a dwelling and each column 
	contains parameter values. This file can have an unlimited number (within 
	your computer RAM space) of dwelling rows
***-Input-min-max-bias.csv: A text file which lists the minimum and maximum value 
	and any bias associated with the input. It also includes the output scaling 
	values in column A. The min/max values are used to properly scale the inputs 
	for the NN values
***-Layer-X.csv: A text file which lists the node number, their bias, and the 
	appropriate weighting. "X" corresponds to the total number of hidden and output layers.
***-NN.csv: A text file which lists the total number of hidden and output layers and the 
	scaling function scale values (low and high)

Description of script:
2007-11-06a.pl: This PERL script operates on the proper energy model as defined on 
	line 10 under the variable "$model". Place the acronym "ALC" for "appliance
	lighting and cooling", "DHW" for "domestic hot water", or "SH" for "space 
	heating". This is the only user input.
	The script opens the appropriate files and determines the range values
	It then reads in the input dwelling parameters and scales and biases them.
	It then reads in the node weights and performs the appropriate calculations, 
	ending with the summation of the node and the bias as well as the activation function.
	This is repeated for all layers including the output.
	It then rescales the output and writes the output file.

Description of output files:
***-Results.csv: A text file which is generating after running the script.
	It includes the sequence and dwelling name and annual energy requirement 
	gigajoules (column C) and kilowatt-hours (column D)
