#!/usr/bin/perl -w
# $Id: test_main.t,v 1.9 2001/08/19 02:00:15 christopher Exp $
###
# Automated test script for CSV.pm
###
use CSV;
use strict;

###
# Assign filenames.
#
my($TEST_FOLDER)="t";
#
my($CSVIP)="$TEST_FOLDER/test_ip.csv";
my($SSVIP)="$TEST_FOLDER/test_ip.ssv";
#
my($CSVOP)="$TEST_FOLDER/test_op.csv";
my($SSVOP)="$TEST_FOLDER/test_op.ssv";
#
my($CSVTMP)="tmp_csv.op";
my($SSVTMP)="tmp_ssv.op";

###
# Declare number of tests.
#
print "1..2\n";

###
# Open files.
#
open CSVIP_F, "$CSVIP" or die "not ok 1\n";
open CSVTMP_F, ">$CSVTMP" or die "not ok 1\n";

open SSVIP_F, "$SSVIP" or die "not ok 2\n";
open SSVTMP_F, ">$SSVTMP" or die "not ok 2\n";

###
# Run Test 1.
#
while (<CSVIP_F>) {
    print CSVTMP_F join(":", CSVsplit($_)), "\n";
}

close(CSVTMP_F); # to ensure the diff command sees the output.

if (system("diff","$CSVOP","$CSVTMP")) {
    print "not ok 1\n";
} else {
    print "ok 1\n";
}

###
# Run Test 2.
#
local $CSV::Delimiters = ";";
while (<SSVIP_F>) {
    print SSVTMP_F join(":", CSVsplit($_)), "\n";
}

close(SSVTMP_F); # to ensure the diff command sees the output.

if (system("diff","$SSVOP","$SSVTMP")) {
    print "not ok 2\n";
} else {
    print "ok 2\n";
}

###
# Clean up.
#
unlink "$CSVTMP";
unlink "$SSVTMP";

###
# end of test script.
###
