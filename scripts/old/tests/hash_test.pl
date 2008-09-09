#!/usr/bin/perl
use strict;

# my %hash = ("aim", 1, "bsm", 2, "cfg", 3, "cnn", 4, "con", 5, "ctl", 6, "geo", 7, "opr", 8, "tmc", 9);
# foreach my $test (@hash{"bsm", "cnn", "ctl"}) {print "$test\n"};
# print "done\n";
# my @array=keys(%hash);
# print "$#(keys(%hash))\n";
# $hash {"test"} = 10;
# print %hash;
# print "\n";
# delete @hash{"aim", "bsm"};
# print %hash;
# print "\n";
# print "\n";

# my $try="".keys(%hash)."";
# #$try={"hash",1};
# print "$try";
# #print ("$try->{"hash"}");

my $hash_ref;
$hash_ref->{"hash1"} = 1;
$hash_ref->{"hash2", "hash3"} = (2, 3);
# $hash_ref = {"hash3", 3, "hash4", 4};
# $hash_ref = {"hash5" => 5, "hash6" => 6};
my @count = keys (%$hash_ref);
print "$hash_ref->{'hash2'}\n";
print "@count\n";