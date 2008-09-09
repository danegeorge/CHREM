#!/usr/bin/perl
use strict;

my $hse_file = [(1, 2, 3, 4, 5)];
my $line = 2;
my $beyond = 1;
my $replace = "here";

print "@{$hse_file}\n";

splice (@{$hse_file}, $line+$beyond, 1, "$replace");

print "@{$hse_file}\n";