# provision-consumer

Installs the pinned runtime modules into a temporary prefix outside the
checkout, so installed-archive checks run against a consumer that has only the
published runtime dependencies. It runs `cpm`, which CI downloads and verifies
into `.cache/cpm` first.

The `native-artifacts` job runs it before `make artifacts`, and the release
guide runs it before a release check. `check-artifacts.pl` reads the prefix
from `.cache/consumer-prefix`. A later run reuses the recorded prefix while it
exists:

```console
$ perl scripts/provision-consumer/provision-consumer.pl
```

`--cpm PATH` selects another `cpm`, and `--cache DIR` moves the record.

Test it against a fake `cpm`:

```console
$ prove -Iscripts/lib scripts/provision-consumer/tests
```
