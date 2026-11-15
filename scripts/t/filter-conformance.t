use v5.44;
use Test2::V1;
use FindBin;
use JSON::PP ();
use LibTmux::Filter;
use LibTmux::Schema;

# Run every libtmux.where/v1 case through the Perl filter. A case expects
# either the ids of the matching records or the name of the error class.
open my $in, '<:raw', "$FindBin::Bin/../../conformance/where-v1.json"
    or die "conformance/where-v1.json: $!";
my $data = JSON::PP->new->utf8->core_bools->decode(do { local $/; <$in> });

sub record ($kind, $input) {
    my $fields = LibTmux::Schema->entity($kind)->{fields};
    my %wire   = map { $fields->{$_}{wire} => $_ } keys %$fields;
    my %out;
    for my $name (keys %$input) {
        my $key   = $wire{$name} // die "bad fixture record key $name";
        my $field = $fields->{$key};
        my $value = $input->{$name};
        if ($field->{type} eq 'relation' && defined $value) {
            $value =
                $field->{many}
                ? [map { record($field->{entity}, $_) } @$value]
                : record($field->{entity}, $value);
        }
        $out{$key} = $value;
    }
    return \%out;
}

sub outcome ($case) {
    try {
        my $filter = LibTmux::Filter->from_data(
            {
                schema => 'libtmux.where/v1',
                entity => $case->{entity},
                where  => $case->{where}
            }
        );
        my @records = map  { record($case->{entity}, $_) } $case->{records}->@*;
        my @matched = grep { $filter->matches($_) } @records;
        return {ids => [map { $_->{id} } @matched]};
    }
    catch ($error) {
        (my $type = ref($error)) =~ s/^LibTmux::X:://;
        return {error => $type || "$error"};
    }
}

T2->ok($data->{cases}->@*, 'the fixture file holds cases');
for my $case ($data->{cases}->@*) {
    my $expected =
        exists $case->{error}
        ? {error => $case->{error}}
        : {ids   => $case->{ids}};
    T2->is(outcome($case), $expected, $case->{key});
}
T2->done_testing;
