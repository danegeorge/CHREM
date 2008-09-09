#!/usr/bin/perl -w

@orig_files = <../climate/2008-06_climate/*>;
@new_files = <../climate/2008-07_linux_climate/*>;

foreach $file (0..$#orig_files) {
	my $original = $orig_files[$file];
	$original =~ s/..\/climate\/2008-06_climate\///;
	my $new = $new_files[$file];
	$new =~ s/..\/climate\/2008-07_linux_climate\///;
#	print "original $original, new $new\n";
	if ($original ne $new) {die "Bad  name: $original\n"}
}
