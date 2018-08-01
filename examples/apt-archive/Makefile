ifeq (Windows_NT,${OS})
EXESUFFIX:= .exe
else
EXESUFFIX:=
endif

apt-archive${EXESUFFIX}:: | prepare-source
apt-archive${EXESUFFIX}:: git.revision proxy.ss
	swish-build -o $@ proxy.ss -b petite --rtlib swish --libs-visible

# force evaluation, but use a different target from the output that
# proxy.ss depends on so we don't rebuild needlessly
.PHONY: prepare-source
prepare-source:
	@git describe --always --exclude='*' --abbrev=40 --dirty > git.revision.tmp
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
