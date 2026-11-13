use v5.44;
use Test2::V1;
use File::Temp qw(tempdir);
use LWP::UserAgent;
use LWP::Protocol::https;
use HTTP::Response;
use LibTmuxRelease;

my $root  = tempdir('libtmux-perl-upload-test-XXXX', TMPDIR => 1, CLEANUP => 1);
my $bytes = "archive\0\xff\r\n";
my @items;
for my $name (qw(LibTmux LibTmux-Workspace LibTmux-Async)) {
    my $file = "$name-0.002.tar.gz";
    open my $out, '>:raw', "$root/$file" or die $!;
    print {$out} $bytes;
    close $out or die $!;
    push @items, {file => $file, path => "$root/$file"};
}
my $plan  = {order => \@items};
my $token = 'EXAMPLE:' . ('a' x 32) . ':' . ('b' x 64);
my (@requests, @agents);
my $response = HTTP::Response->new(
    200, 'OK',
    ['Content-Type' => 'application/json'],
    '{"result":"Upload succeeded"}'
);
my $failure;
my $attempts = 0;
my $capture  = sub ($agent, $request) {
    ++$attempts;
    push @requests, $request;
    push @agents,   $agent;
    die "private $token" if $failure && $attempts == 2;
    return $response;
};
{
    no warnings 'redefine';
    local *LWP::UserAgent::request = $capture;
    my ($receipt, $error);
    try { $receipt = LibTmuxRelease->upload($plan, token => $token) }
    catch ($caught) { $error = $caught }
    T2->is($error, undef,
        'bearer-token upload succeeds without an account password');
    T2->is(
        $receipt,
        {accepted => [map { $_->{file} } @items], indexed => false},
        'accepted files preserve dependency order without claiming indexing'
    );
    T2->is(scalar @requests, 3, 'submit each archive exactly once');

    if (@requests) {
        T2->is($requests[0]->method, 'POST', 'upload uses POST');
        T2->is(
            "" . $requests[0]->uri,
            'https://pause.perl.org/api/upload',
            'token goes only to the fixed PAUSE API endpoint'
        );
        T2->is(
            $requests[0]->header('Authorization'),
            "Bearer $token",
            'entire token is used as bearer authentication'
        );
        T2->like(
            $requests[0]->content,
            qr/name="file"; filename="LibTmux-0\.002\.tar\.gz"/,
            'multipart field names the exact native archive'
        );
        T2->ok(
            index($requests[0]->content, $bytes) >= 0,
            'multipart encoding preserves archive octets'
        );
        T2->is($agents[0]->max_redirect,
            0, 'redirects cannot forward credentials');
        T2->is($agents[0]->ssl_opts('verify_hostname'),
            1, 'TLS verifies the PAUSE hostname');
        T2->is($agents[0]->ssl_opts('SSL_verify_mode'),
            1, 'TLS verifies the certificate chain');
        T2->is($agents[0]->timeout, 30, 'upload HTTP inactivity is bounded');
    }
    @requests = ();
    $attempts = 0;
    $failure  = true;
    my $partial;
    try { LibTmuxRelease->upload($plan, token => $token) }
    catch ($caught) { $partial = $caught }
    T2->like(
        $partial // '',
qr/outcome is uncertain.*LibTmux-Workspace.*accepted earlier: LibTmux-0\.002/s,
        'partial failure retains confirmed and uncertain upload identities'
    );
    T2->unlike($partial // '',
        qr/\Q$token\E/, 'transport diagnostics never expose the token');
    T2->is($attempts, 2,
        'an uncertain upload is neither retried nor followed by another file');
    $failure = false;

    for my $case (
        [302, '{"result":"Upload succeeded"}', 'redirect'],
        [500, '{"error":"Not accepted"}',      'server error'],
        [200, '{"error":"Not accepted"}',      'JSON error'],
        [200, '<html>login</html>',            'non-JSON response'],
        )
    {
        $response =
            HTTP::Response->new($case->[0], 'fixture',
            ['Content-Type' => 'application/json'],
            $case->[1]);
        $attempts = 0;
        my $rejected;
        try { LibTmuxRelease->upload($plan, token => $token) }
        catch ($caught) { $rejected = $caught }
        T2->like(
            $rejected // '',
            qr/outcome is uncertain/,
            "$case->[2] is not acceptance"
        );
        T2->is($attempts, 1, "$case->[2] stops without retrying");
    }
    $attempts = 0;
    my $bad;
    try { LibTmuxRelease->upload($plan, token => "$token\r\nX-Test: injected") }
    catch ($caught) { $bad = $caught }
    T2->like($bad // '', qr/PAUSE_TOKEN/,
        'malformed token fails before HTTP dispatch');
    T2->is($attempts, 0, 'invalid credentials cannot submit a request');
}
T2->done_testing;
