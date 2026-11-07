use v5.44;

use Module::CPANfile;
use ExtUtils::MakeMaker::CPANfile 0.11;

my $prereqs = Module::CPANfile->load('cpanfile')->prereqs;

WriteMakefile(
    NAME             => 'LibTmux',
    VERSION          => '0.001_001',
    ABSTRACT         => 'Perl library for tmux (scaffold)',
    AUTHOR           => 'libtmux contributors',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => $prereqs->requirements_for('runtime', 'requires')
        ->requirements_for_module('perl'),
    META_MERGE => {
        'meta-spec'    => {version => 2},
        dynamic_config => 0,
        release_status => 'testing',
        prereqs        => $prereqs->as_string_hash,
        provides       => {},
        resources      => {
            bugtracker => {
                web => 'https://github.com/libtmux/libtmux-perl/issues',
            },
            homepage   => 'https://github.com/libtmux/libtmux-perl',
            repository => {
                type => 'git',
                url  => 'https://github.com/libtmux/libtmux-perl.git',
                web  =>
'https://github.com/libtmux/libtmux-perl/tree/master/packages/core',
            },
        },
    },
);
