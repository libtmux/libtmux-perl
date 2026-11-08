# ADR 0002: Reversible native option and environment values

## Status

Accepted, 2026-11-08. This resolves the typed-getter framing correction in
[ADR 0001](0001-core-async-workspace-architecture.md#frame-bytes-before-decoding-fields).

## Context

On tmux 3.4, 3.5 and 3.5a, `show-options -v` and ordinary `show-environment`
can print byte `FF` and literal `\377` identically. Decoding that output cannot
recover the stored value. The problem precedes Perl text decoding: these APIs
return octets. Native command and buffer output have different contracts.

## Decision

Read options with `show-options` without `-v`. Its
[`cmd_show_options_print`](https://github.com/tmux/tmux/blob/3.3a/cmd-show-options.c#L148)
encodes string values through
[`args_escape`](https://github.com/tmux/tmux/blob/3.3a/arguments.c#L526).
Decode that one argument token without interpreting it as executable code.
Key and numeric values retain native spelling, and command-valued options retain
native command syntax. String values containing spaces are quoted; command
values start with a verb and unquoted argument separator.

The key options `backspace`, `prefix` and `prefix2` use
[`options_value_to_string`](https://github.com/tmux/tmux/blob/3.8/options.c#L201),
which can print a bare quote or backslash. Preserve that spelling using the
resolved option name in the response, including when the request abbreviates
the name. These are the complete `OPTIONS_TABLE_KEY` names in every supported
release; string token validation does not apply to them.

Preserve native scope flags, target selection and `-A` inheritance. Iterate
array records in their native order and join decoded values with newlines,
matching the existing scalar return. An empty array remains an empty string.
The bracket grammar follows
[`options_parse`](https://github.com/tmux/tmux/blob/3.8/options.c#L755): tmux 3.8
also accepts string keys, including keys containing spaces and newlines.
Native missing-option failures still propagate; a built-in option without a
local override can return empty output. User-option names can contain spaces,
newlines or print escapes, so their value is the final complete argument token,
not the second whitespace-separated word.

Read environment values with `show-environment -s`.
[`cmd_show_environment_escape`](https://github.com/tmux/tmux/blob/3.3a/cmd-show-environment.c#L51)
doubles literal backslashes and escapes shell metacharacters. Parse the fixed
assignment/export envelope and decode the enclosed value. Never run the text
through a shell or Perl `eval`. Preserve global versus session selection,
captured-target checks, empty values, and errors for absent or removed values.

Both encoders protect literal backslashes before older print paths add their
escapes. The tmux 3.4
[`server_client_print`](https://github.com/tmux/tmux/blob/3.4/server-client.c#L3274)
also adds a slash before a dollar followed by a letter, underscore or opening
brace. Each native encoder already escapes that dollar. An even slash run
therefore identifies the added layer; remove exactly one slash before decoding
the native escapes. This rule derives from the encoded data, not a potentially
stale client-version cache. Require one complete quoted token and a matching
environment envelope; invalid quoting and escapes raise a codec error.

All calls retain the UTF-8 client flag without changing the server environment.
The shared operation parser serves synchronous and asynchronous callers.

## Alternatives and costs

- Raw output plus a decoder cannot recover distinctions already lost upstream.
- Generic format lookup changes option inheritance and environment selection;
  it does not replace these scoped getters.
- A shell parser or shell execution is unnecessary for the fixed native output.
- These private parsers add compatibility code but no runtime dependency,
  subprocess, execution mode or mutable server state.

Raw `cmd`, `execute`, pane capture, hook listings and direct buffers retain
their native output. Array values joined with newlines remain a scalar API,
not a lossless representation of array element boundaries. Reconsider that
separate contract only when a caller needs indexed array records.

## Verification and reconsideration

[Getter integration tests](../../../packages/core/t/integration/getters.t)
exercise actual native encoders under a C locale: non-NUL byte values, literal
escapes, quoting, names containing delimiters, sparse arrays, inheritance,
key and command options, scoped environments and removed variables. The
[async integration](../../../packages/async/t/integration/tmux.t) exercises
the same parser with opaque bytes. These suites run in the required tmux matrix;
[codec units](../../../packages/core/t/unit/codec.t) reject malformed output.

Revisit the private representation if tmux changes these encoders, adds a
portable structured getter, or a caller needs a richer option-array API.
Qualify changes against the oldest supported release and the full matrix.
