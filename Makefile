PERL ?= perl
PACKAGES := core workspace
LOCAL_LIB := $(CURDIR)/local/lib/perl5
TIDY := $(PERL) -I"$(LOCAL_LIB)" "$(CURDIR)/local/bin/perltidy"
PERL_FILES := cpanfile $(foreach package,$(PACKAGES),packages/$(package)/Makefile.PL packages/$(package)/cpanfile)

.PHONY: check check-metadata check-format format

check: check-metadata check-format

check-metadata:
	@set -eu; for package in $(PACKAGES); do \
		(cd "packages/$$package" && \
			$(PERL) -I"$(LOCAL_LIB)" -c Makefile.PL && \
			$(PERL) -I"$(LOCAL_LIB)" Makefile.PL && \
			$(PERL) -MCPAN::Meta -e 'CPAN::Meta->load_file("MYMETA.json", {lazy_validation => 0})' && \
			cmp "$(CURDIR)/LICENSE" LICENSE); \
	done

check-format:
	@mkdir -p .cache/tidy/root
	@$(TIDY) --assert-tidy --profile=.perltidyrc --output-path=.cache/tidy/root --standard-error-output cpanfile
	@set -eu; for package in $(PACKAGES); do \
		mkdir -p ".cache/tidy/$$package"; \
		$(TIDY) --assert-tidy --profile=.perltidyrc --output-path=".cache/tidy/$$package" --standard-error-output \
			"packages/$$package/Makefile.PL" "packages/$$package/cpanfile"; \
	done

format:
	@$(TIDY) --profile=.perltidyrc -b -bext=/ $(PERL_FILES)
