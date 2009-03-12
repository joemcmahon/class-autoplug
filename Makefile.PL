use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Class::AutoPlug',
    AUTHOR              => 'Joe McMahon <mcmahon@ibiblio.org>',
    VERSION_FROM        => 'lib/Class/AutoPlug/Pluggable.pm',
#   ABSTRACT_FROM       => 'lib/Class/AutoPlug/Pluggable.pm',
    PL_FILES            => {},
    PREREQ_PM => {
		'Carp' => 0,
        'Test::More' => 0,
		'Devel::Peek' => 0,
		'Sub::Installer' => 0,
		'Test::Exception' => 0,
		'Smart::Comments' => 0,
		'Module::Pluggable' => 0,
		'Attribute::Handlers' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Class-AutoPlug-*' },
);
