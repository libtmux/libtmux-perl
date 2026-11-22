PERL ?= perl
PACKAGES := core async workspace
LOCAL_LIB := $(CURDIR)/local/lib/perl5
LIBS := -I"$(LOCAL_LIB)" $(foreach package,$(PACKAGES),-Ipackages/$(package)/lib)
TIDY := $(PERL) -I"$(LOCAL_LIB)" "$(CURDIR)/local/bin/perltidy"
PERL_FILES := cpanfile $(foreach package,$(PACKAGES),packages/$(package)/Makefile.PL packages/$(package)/cpanfile)
CLEAN_ENV := env -u TMUX -u TMUX_PANE -u LIBTMUX_SOCKET -u LIBTMUX_SOCKET_PATH

.PHONY: benchmark check-async-wakeup check-supervisor-wakeup check-snippets check check-metadata check-format format check-generated check-pod unit integration examples artifacts compatibility

check: check-metadata check-format check-generated check-pod check-snippets unit

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
	@$(CLEAN_ENV) prove $(LIBS) -Iscripts/lib scripts/t/*.t scripts/*/tests/*.t packages/core/t/unit/*.t packages/async/t/unit/*.t packages/workspace/t/unit/*.t

integration:
	@set -eu; for suite in packages/core/t/integration/*.t packages/async/t/integration/*.t packages/workspace/t/integration/*.t; do \
		$(CLEAN_ENV) $(PERL) scripts/with-subreaper/with-subreaper.pl $(PERL) $(LIBS) -Iscripts/lib "$$suite"; \
	done

check-async-wakeup:
	@$(PERL) scripts/check-wakeup/check-wakeup.pl async

check-supervisor-wakeup:
	@$(PERL) scripts/check-wakeup/check-wakeup.pl supervisor

examples:
	@$(PERL) scripts/run-examples.pl

artifacts:
	@$(PERL) scripts/check-artifacts.pl

compatibility:
	@$(PERL) scripts/compatibility/compatibility.pl $(TMUX)

check-snippets:
	@$(PERL) scripts/check-snippets.pl

benchmark:
	@$(PERL) scripts/with-subreaper/with-subreaper.pl $(PERL) $(LIBS) -Iscripts/lib scripts/benchmark.pl
