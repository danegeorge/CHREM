#!/usr/bin/perl

my $string = "this is a test";
my @try = split (/\W/,$string);
foreach my $element (@try) {print "start.$element.end\n";};
