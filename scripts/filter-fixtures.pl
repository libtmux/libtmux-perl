use v5.44;
use FindBin;
use lib "$FindBin::Bin/../packages/core/lib";
use JSON::PP ();
use LibTmux::Filter;
use LibTmux::Schema;
open my $in, '<:raw', "$FindBin::Bin/../conformance/where-v1.json" or die $!;
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
my @results;
for my $case ($data->{cases}->@*) {
    my $row = {key => $case->{key}};
    try {
        my $filter = LibTmux::Filter->from_data(
            {
                schema => 'libtmux.where/v1',
                entity => $case->{entity},
                where  => $case->{where}
            }
        );
        my @records = map { record($case->{entity}, $_) } $case->{records}->@*;
        $row->{ids} = [map { $_->{id} } grep { $filter->matches($_) } @records];
    }
    catch ($error) {
        (my $type = ref($error)) =~ s/^LibTmux::X:://;
        $row->{error} = $type || "$error";
    }
    push @results, $row;
}
print JSON::PP->new->utf8->canonical->encode(\@results);
