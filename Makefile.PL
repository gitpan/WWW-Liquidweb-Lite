use ExtUtils::MakeMaker;
WriteMakefile(
	NAME         => 'WWW::Liquidweb::Lite',
	VERSION_FROM => 'lib/WWW/Liquidweb/Lite.pm',
	AUTHOR       => 'Shane Utt (shaneutt@linux.com)',
	ABSTRACT     => 'A module to interface with the Liquidweb API',
	PREREQ_PM    => {
		'Devel::StackTrace' => 1.31,
		'JSON'              => 2.53,
		'LWP::UserAgent'    => 6.05,
		'Test::Simple'      => 0.44,
		'Want'              => 0.23,
	},
);
