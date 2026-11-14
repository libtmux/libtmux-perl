use v5.44;
use FindBin;
use lib "$FindBin::Bin/../local/lib/perl5";
use PPI 1.291;
use Scalar::Util qw(refaddr);
use Pod::Simple::SimpleTree;
use JSON::PP       ();
use Digest::SHA    qw(sha256_hex);
use Getopt::Long   qw(GetOptions);
use File::Find     ();
use File::Path     qw(make_path);
use File::Basename qw(dirname);
use Cwd            qw(getcwd);
use Encode         qw(encode FB_CROAK);
chdir "$FindBin::Bin/.." or die $!;
my ($output, $revision, $exporter_revision, $allow_dirty) =
    ('docs/_build/api.json', 'HEAD', 'HEAD', false);
GetOptions(
    'output=s'            => \$output,
    'revision=s'          => \$revision,
    'exporter-revision=s' => \$exporter_revision,
    'allow-dirty'         => \$allow_dirty
) or die 'invalid exporter options';

sub git (@args) {
    open my $in, '-|', 'git', @args or die $!;
    binmode $in;
    my $bytes = do { local $/; <$in> };
    close $in or die 'git command failed';
    return $bytes;
}
chomp($revision          = git('rev-parse', $revision));
chomp($exporter_revision = git('rev-parse', $exporter_revision));
my %native_scan;
my %internal = map { $_ => true } qw(LibTmux::Codec LibTmux::Platform::Linux);
my (
    @symbols,          @files,       @packages,
    %modules,          %method_docs, %module_docs,
    %module_summaries, %sections,    %parents
);

sub text_of ($node) {
    return $node unless ref($node);
    join '', map { text_of($_) } @$node[2 .. $#$node];
}

sub inline ($node, $owner) {
    return $node unless ref $node;
    my ($tag, $attrs, @children) = @$node;
    my $body = join '', map { inline($_, $owner) } @children;
    return '`' . text_of($node) . '`' if $tag eq 'C' || $tag eq 'F';
    return '**' . $body . '**'        if $tag eq 'B';
    return '*' . $body . '*'          if $tag eq 'I';
    if ($tag eq 'L') {
        return '[' . $body . '](' . $attrs->{to} . ')'
            if ($attrs->{type} // '') eq 'url';
        my $module = exists($attrs->{to}) ? text_of($attrs->{to}) : $owner;
        my $section =
            exists($attrs->{section}) ? text_of($attrs->{section}) : undef;
        if (defined $section) {
            $section = encode('UTF-8', $section, FB_CROAK);
            $section =~ s/([^A-Za-z0-9_.~-])/sprintf '%%%02X', ord $1/eg;
        }
        return
              '['
            . $body
            . '](pod:'
            . $module
            . (defined($section) ? '/' . $section : '') . ')';
    }
    return $body;
}

sub docs ($file, $module) {
    my $parser = Pod::Simple::SimpleTree->new;
    $parser->parse_file($file);
    my ($heading, $method) = ('', '');
    my $general = '';
    my %methods;
    for my $node (@{$parser->root}[2 .. $#{$parser->root}]) {
        next unless ref $node;
        my ($tag, $attrs, @children) = @$node;
        if ($tag eq 'head1') {
            $heading = text_of($node);
            $method  = '';
            $general .= "\n## $heading\n\n"
                unless $heading eq 'NAME'
                || $heading eq 'METHODS'
                || $heading eq 'CORE OPERATIONS';
            next;
        }
        if ($tag eq 'head2') {
            $method = text_of($node);
            $sections{$module}{$method} = true;
            next;
        }
        if ($heading eq 'NAME' && $tag eq 'Para') {
            my $description = text_of($node);
            $description =~ s/\A\Q$module\E\s+-\s+//;
            $module_summaries{$module} = $description;
        }
        my $value =
            $tag eq 'Verbatim'
            ? "\n```perl\n" . text_of($node) . "\n```\n\n"
            : inline($node, $module) . "\n\n";
        if    (length $method) { $methods{$method} .= $value }
        elsif ($heading ne 'NAME'
            && $heading ne 'METHODS'
            && $heading ne 'CORE OPERATIONS')
        {
            $general .= $value;
        }
    }
    $module_docs{$module} = $general;
    $method_docs{$module} = \%methods;
}

sub source ($file, $line) {
    +{
        file              => $file,
        line              => $line,
        repo              => 'libtmux/libtmux-perl',
        revision          => $revision,
        extractedRevision => $revision
    };
}

sub block ($text) {
    $text //= '';
    $text =~ s/\A\s+|\s+\z//g;
    my ($summary, $body) = split /\n\s*\n/, $text, 2;
    return {summary => $summary // '', defined($body) ? (body => $body) : ()};
}

sub source_scan ($document, $bytes) {
    my (@functions, @types, %function_nodes);
    my $visit;
    $visit = sub ($node, $owner) {
        for my $child ($node->children) {
            if ($child->isa('PPI::Statement::Package')) {
                my $declared = $child->namespace;
                push @types,
                    {
                    name  => $declared,
                    start => $child->location->[0],
                    end   => scalar(split /\n/, $bytes)
                    };
                my $body = $child->find_first('PPI::Structure::Block');
                if ($body) { $visit->($body, $declared) }
                else       { $owner = $declared }
                next;
            }
            if ($child->isa('PPI::Statement::Sub') && defined($child->name)) {
                my $block = $child->block;
                next unless $block;
                $function_nodes{refaddr($child)} = scalar @functions;
                push @functions,
                    {
                    name     => $child->name,
                    owner    => $owner,
                    start    => $child->location->[0],
                    nameLine => $child->location->[0],
                    end      => $block->finish->location->[0],
                    kind     => 'function'
                    };
            }
            $visit->($child, $owner) if $child->isa('PPI::Node');
        }
    };
    $visit->($document, '');
    my @tokens;
    for my $token ($document->tokens) {
        next
            if $token->isa('PPI::Token::Whitespace')
            || $token->isa('PPI::Token::Comment')
            || $token->isa('PPI::Token::Pod');
        my $parent = $token->parent;
        $parent = $parent->parent
            while $parent && !exists($function_nodes{refaddr($parent)});
        next unless $parent;
        my @values;
        my $kind = 'sym';
        if ($token->isa('PPI::Token::QuoteLike::Words')) {
            @values = $token->literal;
            $kind   = 'str';
        }
        elsif ($token->isa('PPI::Token::Quote')) {
            next unless $token->can('string');
            my $value = $token->string;
            next
                if $token->isa('PPI::Token::Quote::Double')
                && $value =~ /[\$\@]/;
            @values = ($value);
            $kind   = 'str';
        }
        elsif ($token->isa('PPI::Token::QuoteLike')
            || $token->isa('PPI::Token::Regexp')
            || $token->isa('PPI::Token::HereDoc'))
        {
            next;
        }
        else {
            @values = ($token->content);
            $kind   = 'id' if $token->isa('PPI::Token::Word');
        }
        push @tokens, map {
            +{
                t        => $kind,
                v        => $_,
                line     => $token->location->[0],
                col      => $token->location->[1],
                function => $function_nodes{refaddr($parent)}
            }
        } @values;
    }
    return {
        sha256    => sha256_hex($bytes),
        functions => \@functions,
        types     => \@types,
        tokens    => \@tokens
    };
}

sub walk ($node, $owner, $file, $package, $product) {
    for my $child ($node->children) {
        if ($child->isa('PPI::Statement::Package')) {
            my $declared = $child->namespace;
            my $body     = $child->find_first('PPI::Structure::Block');
            if ($body) { walk($body, $declared, $file, $package, $product) }
            else       { $owner = $declared }
            next if $internal{$declared};
            $modules{$declared} = {
                id            => $declared,
                publicId      => $declared,
                qualifiedName => $declared,
                name          => ($declared =~ s/.*:://r),
                kind          => $declared =~ /::X::/ ? 'exception'
                : $declared eq 'LibTmux'
                    || $declared eq 'LibTmux::Async' ? 'module'
                : 'class',
                modifiers  => [],
                signatures =>
                    [{raw => 'package ' . $declared . ';', params => []}],
                package  => $package,
                product  => $product,
                apiScope => 'exported',
                source   => source($file, $child->location->[0])
            };
            next;
        }
        if ($child->isa('PPI::Statement::Include')
            && ($child->module // '') eq 'parent')
        {
            my $quotes = $child->find('PPI::Token::Quote::Single') || [];
            for my $quote (@$quotes) {
                my $parent = $quote->string;
                $parents{$owner} = $parent if $parent =~ /\ALibTmux/;
            }
        }
        if ($child->isa('PPI::Statement::Sub')) {
            my $name = $child->name;
            next unless defined($name) && $name !~ /\A_/ && !$internal{$owner};
            my $signature = $child->find_first('PPI::Structure::Signature');
            next unless $signature;
            my $raw = $signature->content;
            my @params;
            my $parameters = $raw =~ s/\A\(|\)\z//gr;
            for my $part (split /\s*,\s*/, $parameters) {
                next unless length $part;
                my ($sigil, $param, $default) = $part =~
/\A\s*([\$\@%])([A-Za-z_][A-Za-z_0-9]*)(?:\s*=\s*(.*))?\s*\z/;
                die "unsupported native signature: $owner.$name $raw"
                    unless defined $param;
                push @params,
                    {
                    name => $param,
                    defined($default) ? (default  => $default) : (),
                    $sigil eq '@'     ? (variadic => 'positional')
                    : $sigil eq '%'   ? (variadic => 'keyword')
                    :                   ()
                    };
            }
            my $receiver =
                @params
                && ($params[0]{name} eq 'self' || $params[0]{name} eq 'class')
                ? shift @params
                : undef;
            my $prefix = 'sub ' . $name;
            my @syntax =
                ({start => 4, end => 4 + length($name), kind => 'name'});
            my %indices = map { $params[$_]{name} => $_ } 0 .. $#params;
            my (%seen, $offset);
            $offset = length($prefix);
            for my $token ($signature->tokens) {
                my $content = $token->content;
                if (   $token->isa('PPI::Token::Symbol')
                    && $content =~ /\A[\$\@%]([A-Za-z_][A-Za-z_0-9]*)\z/
                    && exists($indices{$1})
                    && !$seen{$1}++)
                {
                    push @syntax,
                        {
                        start     => $offset,
                        end       => $offset + length($content),
                        kind      => 'parameter',
                        parameter => $indices{$1}
                        };
                }
                $offset += length $content;
            }

            push @symbols,
                {
                id            => $owner . '::' . $name,
                publicId      => $owner . '::' . $name,
                qualifiedName => $owner . '::' . $name,
                name          => $name,
                kind          => 'method',
                modifiers     => $package eq 'LibTmux-Async'
                    && $owner eq 'LibTmux::Async::Server'
                    && $name ne 'new' ? ['async'] : [],
                parent     => $owner,
                package    => $package,
                product    => $product,
                apiScope   => 'exported',
                signatures => [
                    {
                        raw          => 'sub ' . $name . $raw,
                        params       => \@params,
                        nativeSyntax => \@syntax,
                        defined($receiver) ? (receiver => $receiver) : (),
                        methodKind => $name eq 'new' ? 'constructor' : 'call'
                    }
                ],
                source => source($file, $child->location->[0])
                };
            next;
        }
        walk($child, $owner, $file, $package, $product)
            if $child->isa('PPI::Node');
    }
}
for my $distribution (qw(core async workspace)) {
    my $package =
          $distribution eq 'core'  ? 'LibTmux'
        : $distribution eq 'async' ? 'LibTmux-Async'
        :                            'LibTmux-Workspace';
    my $product = $distribution eq 'workspace' ? 'workspace' : 'core';
    push @packages, {name => $package, product => $product, version => '0.003'};
    my @inputs;
    File::Find::find(
        {
            no_chdir => 1,
            wanted   => sub {
                push @inputs, $File::Find::name if -f $_ && /\.(?:pm|json)\z/;
            }
        },
        "packages/$distribution/lib"
    );
    push @inputs,
        map { "packages/$distribution/$_" }
        qw(Makefile.PL cpanfile README.md LICENSE);
    for my $file (sort @inputs) {
        open my $in, '<:raw', $file or die $!;
        my $bytes = do { local $/; <$in> };
        close $in;
        if (!$allow_dirty) {
            die "source freshness mismatch: $file"
                unless git('show', "$revision:$file") eq $bytes;
        }
        push @files, {path => $file, sha256 => sha256_hex($bytes)};
        next unless $file =~ /\.pm\z/;
        my $doc = PPI::Document->new(\$bytes) or die "PPI failed: $file";
        my $package_node = $doc->find_first('PPI::Statement::Package');
        next unless $package_node;
        my $module = $package_node->namespace;
        $native_scan{$file} = source_scan($doc, $bytes);
        next if $internal{$module};
        docs($file, $module);
        walk($doc, $module, $file, $package, $product);
    }
}
my @public;
for my $symbol (@symbols) {
    my ($owner, $name) = @$symbol{qw(parent name)};
    my $documentation = $method_docs{$owner}{$name};
    if (!defined($documentation) && $owner =~ /\A(.+::X)::([^:]+)\z/) {
        $documentation = $method_docs{$1}{$name};
    }
    next unless defined $documentation;
    $symbol->{doc} = block($documentation);
    push @public, $symbol;
}
for my $name (sort keys %modules) {
    my $symbol = $modules{$name};
    if ($parents{$name}) { $symbol->{extends} = [$parents{$name}] }
    my $documentation = $module_docs{$name};
    if (!defined($documentation) && $name =~ /\A(.+::X)::([^:]+)\z/) {
        $documentation = $method_docs{$1}{$2};
    }
    $symbol->{doc} =
        exists($module_summaries{$name})
        ? {summary => $module_summaries{$name}, body => $documentation // ''}
        : block($documentation // $name);

    # Package prefixes are namespaces, not enclosing Perl declarations.
    # Inheritance remains explicit in extends; methods keep their package owner.
    push @public, $symbol;
}

# Preserve inherited API ownership instead of pretending Perl redeclares methods.
my %by_owner;
push $by_owner{$_->{parent}}->@*, $_
    for grep { $_->{kind} eq 'method' } @public;
for my $owner (sort keys %parents) {
    next unless $modules{$owner};
    for my $method (($by_owner{$parents{$owner}} // [])->@*) {
        next if grep { $_->{id} eq $owner . '::' . $method->{name} } @public;
        push @public,
            {
            %$method,
            id            => $owner . '::' . $method->{name},
            publicId      => $owner . '::' . $method->{name},
            qualifiedName => $owner . '::' . $method->{name},
            parent        => $owner,
            product       => $modules{$owner}{product},
            package       => $modules{$owner}{package},
            inheritedFrom => $parents{$owner}
            };
    }
}
my @examples;
for my $example (
    ['quickstart', 'LibTmux::Server'],
    ['selection',  'LibTmux::Selection'],
    ['workspace',  'LibTmux::Workspace::load'],
    ['async',      'LibTmux::Async::Server::snapshot'],
    ['await',      'LibTmux::Async::Server']
    )
{
    my ($name, $owner) = @$example;
    my $file = "examples/$name.pl";
    open my $in, '<:raw', $file or die $!;
    my $code = do { local $/; <$in> };
    close $in;
    die "example freshness mismatch: $file"
        if !$allow_dirty && git('show', "$revision:$file") ne $code;
    push @files, {path => $file, sha256 => sha256_hex($code)};
    push @examples, {owner => $owner, path => $file, code => $code};
}
open my $exporter_file, '<:raw', 'scripts/export-api.pl' or die $!;
my $exporter_code = do { local $/; <$exporter_file> };
close $exporter_file;
die 'exporter revision does not match executing bytes'
    if !$allow_dirty
    && git('show', "$exporter_revision:scripts/export-api.pl") ne
    $exporter_code;
my $artifact = {
    schema           => 'libtmux.perl-api/v1',
    port             => 'perl',
    repo             => 'libtmux/libtmux-perl',
    revision         => $revision,
    extractor        => 'Perl PPI 1.291 + Pod::Simple native POD v1',
    nativeProvenance => {
        files    => \@files,
        exporter => {
            repository   => 'libtmux/libtmux-perl',
            revision     => $exporter_revision,
            file         => 'scripts/export-api.pl',
            sha256       => sha256_hex($exporter_code),
            ppi          => "$PPI::VERSION",
            perl         => "$^V",
            working_tree => $allow_dirty ? true : false
        }
    },
    nativeScan => {
        schema   => 'libtmux.perl-source/v1',
        revision => $revision,
        files    => \%native_scan
    },
    examples => \@examples,
    sources  => [
        map {
            {
                package           => $_->{name},
                product           => $_->{product},
                version           => $_->{version},
                repo              => 'libtmux/libtmux-perl',
                revision          => $revision,
                extractedRevision => $revision
            }
        } @packages
    ],
    symbols => [sort { $a->{id} cmp $b->{id} } @public]
};
make_path(dirname($output));
open my $out, '>:raw', $output or die $!;
print {$out} JSON::PP->new->utf8->canonical->pretty->encode($artifact);
close $out;
print scalar(@public) . " public Perl declarations exported to $output\n";
