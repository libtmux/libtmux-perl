use v5.44;
use FindBin;
use File::Spec;
use JSON::PP    ();
use Time::HiRes qw(time);
use List::Util  qw(sum);
use IO::Async::Loop;
use Future;
use LibTmux::Async::Server;
use LibTmuxFixture;
my $count = 12;
my @samples;
my @counts;
LibTmuxFixture->run(
    sub ($base, $root) {
        my $session = $base->new_session(
            name    => 'benchmark',
            command => ['/bin/sleep', '120']
        );
        my $pane   = $session->window_links->one->window->panes->one;
        my $binary = $ENV{LIBTMUX_TEST_TMUX} // 'tmux';
        my $loop   = IO::Async::Loop->new;
        for my $instrumented (false, true) {
            for my $mode (qw(sync sync-batch async-concurrent async-batch)) {
                my %config = (
                    socket_path => "$root/s",
                    timeout     => 0.8,
                    executable  => $instrumented
                    ? "$FindBin::Bin/count-tmux-process.py"
                    : $binary
                );
                $config{env} = {
                    LIBTMUX_BENCH_MODE => $mode,
                    LIBTMUX_BENCH_TMUX => $binary,
                    LIBTMUX_BENCH_LOG  => "$root/processes"
                    }
                    if $instrumented;
                my $async = $mode =~ /^async/;
                my $server =
                    $async
                    ? LibTmux::Async::Server->new(
                    %config,
                    loop           => $loop,
                    max_concurrent => 4,
                    max_queue      => 32
                    )
                    : LibTmux::Server->new(%config);
                my @command =
                    ('display-message', '-p', '-t', $pane->id, '#{pane_id}');
                my $warm = $server->cmd(@command);
                if ($async) { $loop->await($warm); $warm->get }
                for (1 .. ($instrumented ? 1 : 3)) {
                    my $start = time();
                    my @values;
                    if ($mode =~ /batch/) {
                        my $value =
                            $server->batch([map { [@command] } 1 .. $count]);
                        if ($async) {
                            $loop->await($value);
                            $value = $value->get;
                        }
                        die 'batch effect attribution failed'
                            if grep { $_->{error} || !$_->{result}->success }
                            @$value;
                        @values = map { $_->{result}->stdout } @$value;
                    }
                    elsif ($async) {
                        my @futures =
                            map { $server->cmd(@command) } 1 .. $count;
                        $loop->await(Future->wait_all(@futures));
                        @values = map { $_->get->stdout } @futures;
                    }
                    else {
                        @values =
                            map { $server->cmd(@command)->stdout } 1 .. $count;
                    }
                    my $elapsed = time() - $start;
                    die 'mode changed workload results'
                        if @values != $count
                        || grep { $_ ne $pane->id . "\n" } @values;
                    push @samples,
                        {
                        mode     => $mode,
                        seconds  => $elapsed,
                        requests => $count
                        }
                        unless $instrumented;
                }
                my $query = $server->query_panes(
                    where    => {active => true},
                    pushdown => 'require'
                );
                if ($async) { $loop->await($query); $query = $query->get }
                die 'mode changed query identity'
                    unless $query->one->id eq $pane->id;
                $loop->await($server->close) if $async;
            }
        }
        open my $in, '<', "$root/processes" or die $!;
        my %processes;
        while (<$in>) {
            my $row = JSON::PP->new->decode($_);
            $processes{$row->{mode}}{commands}{$row->{command_pid}}       = 1;
            $processes{$row->{mode}}{supervisors}{$row->{supervisor_pid}} = 1;
        }
        for my $mode (sort keys %processes) {
            push @counts,
                {
                mode              => $mode,
                command_processes =>
                    scalar(keys $processes{$mode}{commands}->%*),
                supervisors => scalar(keys $processes{$mode}{supervisors}->%*)
                };
        }
        die 'unexpected attached client leak' if $base->clients->count;
    }
);
my @summary;
for my $mode (qw(sync sync-batch async-concurrent async-batch)) {
    my @times = sort { $a <=> $b }
        map { $_->{seconds} } grep { $_->{mode} eq $mode } @samples;
    my $mean     = sum(@times) / @times;
    my $variance = sum(map { ($_ - $mean)**2 } @times) / @times;
    push @summary,
        {
        mode                       => $mode,
        requests_per_sample        => $count,
        samples                    => scalar @times,
        median_seconds             => $times[1],
        min_seconds                => $times[0],
        max_seconds                => $times[-1],
        standard_deviation_seconds => sqrt($variance)
        };
}
my $report = {
    schema                 => 1,
    perl                   => "$^V",
    samples                => \@samples,
    summary                => \@summary,
    process_counts         => \@counts,
    attached_clients_after => 0,
    limits                 =>
'3 samples of 12 stable display-message requests, one pane; not a throughput promise. Native executable for wall times. Separate exec-wrapper process-count probe includes discovery, warmup and query; its overhead is excluded from wall timings. All modes preserve results and query identity.'
};
open my $out, '>:raw', "$FindBin::Bin/../.cache/modes.json" or die $!;
print {$out} JSON::PP->new->canonical->pretty->encode($report);
close $out;
print JSON::PP->new->canonical->encode(\@summary), "\n";
