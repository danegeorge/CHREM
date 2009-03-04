#!/usr/bin/perl
# 
#====================================================================
# fsim.pl
# Author:    Lukas Swan
# Date:      Mar 2009
# Copyright: Dalhousie University
#
# DESCRIPTION:
# This script performs an in directory ish and bps

#===================================================================

use warnings;
use strict;

$ARGV[0] =~ /(^.*).$/;
my $folder_name = $1;

open (CFG, '<', "./$folder_name.cfg") or die ("can't open ./$folder_name.cfg");	#open the cfg file to check for isi
SEARCH: while (<CFG>) {
	if ($_ =~ /^\*isi/) {
		system ("ish -mode text -file ./$folder_name.cfg -zone main -act update_silent");	# call the ish shading and insolation analyzer
		last SEARCH;
	};
};
close CFG;

system ("bps -mode text -file ./$folder_name.cfg -p default silent");	#call the bps simulator with arguements to automate it
# rename the xml output files with the house name
