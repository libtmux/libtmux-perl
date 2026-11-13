PERL ?= perl
PACKAGES := core async workspace
LOCAL_LIB := $(CURDIR)/local/lib/perl5
LIBS := -I"$(LOCAL_LIB)" $(foreach package,$(PACKAGES),-Ipackages/$(package)/lib)
TIDY := $(PERL) -I"$(LOCAL_LIB)" "$(CURDIR)/local/bin/perltidy"
PERL_FILES := cpanfile $(foreach package,$(PACKAGES),packages/$(package)/Makefile.PL packages/$(package)/cpanfile)

.PHONY: benchmark check-async-wakeup check-supervisor-wakeup check-inventory conformance check-snippets check check-metadata check-format format check-generated check-pod unit integration examples artifacts compatibility

check: check-metadata check-format check-generated check-pod check-snippets check-inventory unit conformance

check-metadata:
	@set -eu; for package in $(PACKAGES); do \
		(cd "packages/$$package" && \
			$(PERL) -I"$(LOCAL_LIB)" -c Makefile.PL && \
			$(PERL) -I"$(LOCAL_LIB)" Makefile.PL && \
			$(PERL) -MCPAN::Meta -e 'CPAN::Meta->load_file("MYMETA.json", {lazy_validation => 0})' && \
			cmp "$(CURDIR)/LICENSE" LICENSE); \
	done

check-format:
	@$(PERL) scripts/format.pl --check

format:
	@$(PERL) scripts/format.pl --write

check-generated:
	@$(PERL) scripts/generate.pl --check

check-pod:
	@$(PERL) scripts/check-pod.pl

unit:
	@prove $(LIBS) -Iscripts/lib scripts/t/*.t packages/core/t/unit/*.t packages/async/t/unit/*.t packages/workspace/t/unit/*.t

integration:
	@set -eu; for suite in packages/core/t/integration/*.t packages/async/t/integration/*.t packages/workspace/t/integration/*.t; do \
		python3 scripts/with-subreaper.py $(PERL) $(LIBS) -Iscripts/lib "$$suite"; \
	done

check-async-wakeup:
	@python3 scripts/check-async-wakeup.py

check-supervisor-wakeup:
	@python3 scripts/check-supervisor-wakeup.py

examples:
	@$(PERL) scripts/run-examples.pl

artifacts:
	@$(PERL) scripts/check-artifacts.pl

compatibility:
	@python3 scripts/compatibility.py --check

check-snippets:
	@$(PERL) scripts/check-snippets.pl

conformance:
	@python3 scripts/conformance.py

benchmark:
	@python3 scripts/with-subreaper.py $(PERL) $(LIBS) -Iscripts/lib scripts/benchmark.pl

check-inventory:
	@python3 scripts/inventory.py --check
