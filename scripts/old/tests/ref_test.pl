#!/usr/bin/perl
use strict;
&sub1;
sub sub1 {
	my @try1 = (1,2,3,4,5,6);
	my $try2 = [(1,2,3,4,5,6)];
	print "try1a- @try1;	try2a- @{$try2}\n";
	&sub2 ([@try1], $try2);
	print "try1b- @try1;	try2b- @{$try2}\n";
}

sub sub2 {
	my $try3 = $_[0];
	my $try4 = $_[1];
	print "try3a- @{$try3};	try4a- @{$try3}\n";
	shift (@{$try3});
	shift (@{$try4});
	print "try3b- @{$try3};	try4b- @{$try3}\n";
	
}
print "second part\n";
