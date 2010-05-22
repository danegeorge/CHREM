#!/usr/bin/perl

use warnings;
use strict;

my @FOLDERS = @ARGV;

my @types = qw(Files Folders Links);
my $symbol;
@{$symbol}{@types} = qw(- d l);

foreach my $type (@types) {
	print "$type: ";
	system("ls -lR @FOLDERS | grep ^$symbol->{$type} | wc -l");
};