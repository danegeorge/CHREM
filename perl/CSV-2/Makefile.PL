require 5.000;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	   => 'CSV',
    'VERSION_FROM' => 'lib/CSV.pm', # finds $VERSION
    'PREREQ_PM'    => {	
	                 'Exporter' => 1.00
		      },
    'AUTHOR'	   => 'Christopher Rath <Christopher@Rath.ca> and Mark Mielke <Mark@Mielke.cc>',
    dist           => { COMPRESS => 'gzip --best', SUFFIX => 'gz', },
);
