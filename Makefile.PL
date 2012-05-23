use strict;
use ExtUtils::MakeMaker 6.30;

my %WriteMakefileArgs = (
    'AUTHOR' => 'Graham Knop <haarg@haarg.org>',
    'BUILD_REQUIRES' => {
        'Test::More' => 0.94,
        'Capture::Tiny' => 0.12,
        'File::Spec' => 0,
        'File::Basename' => 0,
        'Try::Tiny' => 0,
    },
    'CONFIGURE_REQUIRES' => {
        'ExtUtils::MakeMaker' => '6.30'
    },
    'DISTNAME' => 'Win32-ShellQuote',
    'EXE_FILES' => [],
    'LICENSE' => 'perl',
    'NAME' => 'Win32-ShellQuote',
    'ABSTRACT_FROM' => 'lib/Win32/ShellQuote.pm',
    'VERSION_FROM' => 'lib/Win32/ShellQuote.pm',
    'PREREQ_PM' => {
        'strict' => 0,
        'warnings' => 0,
        'Exporter' => 0,
        'Carp' => 0,
    },
    'META_ADD' => {
        'dynamic_config' => 0,
    },
);

unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
    my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
    my $pp = $WriteMakefileArgs{PREREQ_PM};
    for my $mod ( keys %$br ) {
        if ( exists $pp->{$mod} ) {
            $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
        }
        else {
            $pp->{$mod} = $br->{$mod};
        }
    }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
    unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);

