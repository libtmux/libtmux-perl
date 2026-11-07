requires 'perl', '5.044000';

on 'configure' => sub {
    requires 'ExtUtils::MakeMaker',           '7.78';
    requires 'ExtUtils::MakeMaker::CPANfile', '0.11';
    requires 'Module::CPANfile',              '1.1004';
};

on 'develop' => sub {
    requires 'Perl::Tidy', '== 20260826';
};
