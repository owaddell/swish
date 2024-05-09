ifeq (Windows_NT,${OS})
EXESUFFIX:= .exe
else
EXESUFFIX:=
endif

TARGETS:=apt-archive${EXESUFFIX} apt-archive.boot
DEPS:=proxy.ss git.revision

.PHONY: it
it: $(TARGETS)

define gen_rule
$(1): $(DEPS)
	swish-build -o apt-archive proxy.ss -b petite --rtlib swish --libs-visible
endef

$(foreach target,$(TARGETS),$(eval $(call gen_rule,$(target))))

proxy.ss: | prepare-source

# force evaluation, but use a different target from the output that
# proxy.ss depends on so we don't rebuild needlessly
.PHONY: prepare-source
prepare-source:
ifeq ($(wildcard ../../.git),)
	@cp ../git.revision git.revision.tmp
else
	@git describe --always --exclude='*' --abbrev=40 --dirty > git.revision.tmp
endif
	@if cmp --quiet git.revision git.revision.tmp; then \
	  rm git.revision.tmp; \
	else \
	  mv git.revision.tmp git.revision; echo "git.revision changed"; \
	fi

test:
	@echo "Please test the 'apt-archive' example manually."

clean:
	rm -f git.revision
	rm -f apt-archive${EXESUFFIX} apt-archive.boot
	rm -f *.{so,wpo}
	rm -rf data
