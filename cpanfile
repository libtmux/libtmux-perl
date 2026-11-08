# Bare versions are supported minimums; newer releases remain eligible.
requires 'perl', '5.044000';

on 'configure' => sub {
    requires 'ExtUtils::MakeMaker',           '7.78';
    requires 'ExtUtils::MakeMaker::CPANfile', '0.11';
    requires 'Module::CPANfile',              '1.1004';
};

on 'develop' => sub {

    # Exact author-tool versions stabilize formatting and API extraction.
    requires 'PPI',                '== 1.291';
    requires 'Perl::Tidy',         '== 20260826';
    requires 'Test2::V1',          '1.302226';
    requires 'Test::Pod',          '1.52';
    requires 'Future',             '0.54';
    requires 'IO::Async',          '0.805';
    requires 'Future::AsyncAwait', '0.71';
};
