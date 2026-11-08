# Architecture decisions

These records explain the package boundaries, execution model, and public
contracts that guide changes to libtmux for Perl. They record decisions and
their costs; the [architecture guide](../../architecture.md) and reader guides
describe how to use the library.

| Record | Status | Subject |
| --- | --- | --- |
| [ADR 0001](0001-core-async-workspace-architecture.md) | Accepted; corrections open | Shared operations, captured graphs, and execution adapters. |
| [ADR 0002](0002-reversible-native-getters.md) | Accepted | Reversible native option and environment values. |

An accepted record describes the implementation baseline. It does not certify
a release, an operating system, or a deployed documentation site. A change to
an accepted contract needs a reasoned amendment or a superseding record,
affected caller examples, and the relevant qualification checks.
