#!/usr/bin/perl

# ====================================================================
# NN_sensitivity.pl
# Author: Lukas Swan
# Date: Dec 2009
# Copyright: Dalhousie University

# INPUT USE:
# filename.pl [house type numbers seperated by "/"] [region numbers seperated by "/"; 0 means all] [simulation timestep in minutes]

# DESCRIPTION:
# This script 

# ===================================================================

# --------------------------------------------------------------------
# Declare modules which are used
# --------------------------------------------------------------------

use warnings;
use strict;

use CSV;	# CSV-2 (for CSV split and join, this works best)
# use Array::Compare;	# Array-Compare-1.15
use threads;	# threads-1.71 (to multithread the program)
use File::Path;	# File-Path-2.04 (to create directory trees)
use File::Copy;	# (to copy the input.xml file)
use XML::Simple;	# to parse the XML databases for esp-r and for Hse_Gen
use Data::Dumper;	# to dump info to the terminal for debugging purposes
use Switch;
use Storable  qw(dclone);
use Hash::Merge qw(merge);

use lib qw(./modules);
use General;
use Cross_reference;
use Database;
use Constructions;

$Data::Dumper::Sortkeys = \&order;

Hash::Merge::specify_behavior(
	{
		'SCALAR' => {
			'SCALAR' => sub {$_[0] + $_[1]},
			'ARRAY'  => sub {[$_[0], @{$_[1]}]},
			'HASH'   => sub {$_[1]->{$_[0]} = undef},
		},
		'ARRAY' => {
			'SCALAR' => sub {[@{$_[0]}, $_[1]]},
			'ARRAY'  => sub {[@{$_[0]}, @{$_[1]}]},
			'HASH'   => sub {[@{$_[0]}, $_[1]]},
		},
		'HASH' => {
			'SCALAR' => sub {$_[0]->{$_[1]} = undef},
			'ARRAY'  => sub {[@{$_[1]}, $_[0]]},
			'HASH'   => sub {Hash::Merge::_merge_hashes($_[0], $_[1])},
		},
	}, 
	'Merge where scalars are added, and items are (pre)|(ap)pended to arrays', 
);

# --------------------------------------------------------------------
# Declare the global variables
# --------------------------------------------------------------------

foreach my $NN qw(ALC DHW) {
	my $path = '../NN/NN_model/';
	my $file = $NN . '_Sensitivity_Input';
	my $ext = '.csv';
	my $FILE;

	open ($FILE, '<', $path . $file . $ext) or die ("Can't open datafile: $path$file$ext");	# open readable file

	# declare a storage variable
	my $input = {};

	# go through the lines and store everything
	$input = &one_data_line_keyed($FILE, $input);

	close $FILE;

# 	print Dumper $input;

	$file = $NN . '-Inputs-V2';
	open ($FILE, '>', $path . $file . $ext) or die ("Can't open datafile: $path$file$ext");	# open writeable file

	foreach my $tag (@{$input->{'order'}}) {
		if (ref($input->{$tag}) eq 'HASH') {
			print $FILE CSVjoin('*' .$tag, @{$input->{$tag}}{@{$input->{'header'}}}) . "\n";
		}
		elsif (ref($input->{$tag}) eq 'ARRAY') {
			print $FILE CSVjoin('*' .$tag, @{$input->{$tag}}) . "\n";
		}
		else {
			die "The tag \"$tag\" is not a HASH or ARRAY reference\n";
		};
	};
	
	my $File_name = $input->{'data'}->{'File_name'};
	$input->{'data'}->{'File_name'} = 'base_base_0';
	print $FILE CSVjoin('*data', @{$input->{'data'}}{@{$input->{'header'}}}) . "\n";
	$input->{'data'}->{'File_name'} = $File_name;
	
	foreach my $field (@{$input->{'header'}}[1..$#{$input->{'header'}}]) {
		
		my $variation = $input->{'min'}->{$field};
		
		VARIATIONS: while ($variation <= $input->{'max'}->{$field}) {
			my $data;
			%{$data} = %{$input->{'data'}};
			$data->{$field} = $variation;
			$data->{'File_name'} = $data->{'File_name'} . '_' . $field . '_' . $variation;
			
			print $FILE CSVjoin('*data', @{$data}{@{$input->{'header'}}}) . "\n";
			
			if ($variation == $input->{'max'}->{$field}) {
				last VARIATIONS;
			};
			
			$variation = $variation + $input->{'var'}->{$field};
			
			if ($variation > $input->{'max'}->{$field}) {
				$variation = $input->{'max'}->{$field};
			};
			
		};
	};

	close $FILE;
	$input = {};
	
	system "./NN_Model.pl $NN";
	
	$file = $NN . '-Results';
	open ($FILE, '<', $path . $file . $ext) or die ("Can't open datafile: $path$file$ext");	# open readable file
	
	# declare a storage variable
	my $results = {};

	my $prev = 0;
	# go through the lines and store everything
	while ($input = &one_data_line_keyed($FILE, $input)) {
		$input->{'data'}->{'Filename'} =~ /^base_(\w+)_(\d+$|\d+\.\d+$)/;
		$results->{'data'}->{$1}->{$2} = sprintf("%u", $input->{'data'}->{'GJ'});
		if ($1 ne $prev) {
			push(@{$results->{'order'}},$1);
			$prev = $1;
		};
	};
	
# 	print Dumper $results;
	
	close $FILE;
	
	$file = $NN . '-Results_Summary';
	open ($FILE, '>', $path . $file . $ext) or die ("Can't open datafile: $path$file$ext");	# open writeable file
	
	print $FILE "The following lines show the sensitivity of the $NN NN to the input variables\n";
	print $FILE "A Base case house was generated and then the variations were applied to see the change\n";
	print $FILE "The first column is the altered variable; it is followed by the input values; the next line contains the whole GJ consumption for these input values\n";
	
	foreach my $field (@{$results->{'order'}}) {
		my @keys = &array_order(keys %{$results->{'data'}->{$field}});
		print $FILE CSVjoin($field . '_Input', @keys) . "\n";
		print $FILE CSVjoin($field . '_GJ', @{$results->{'data'}->{$field}}{@keys}) . "\n";
	};
	
	close $FILE;
	
};
	
	
