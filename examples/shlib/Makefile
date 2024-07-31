.PHONY: all clean without-config minimal-config bad-hash good-hash

SWISH_SRC?=../../src/swish

ifeq ($(wildcard $(SWISH_SRC)/Mf-config),)
$(error "Cannot find Swish's Mf-config. Please set SWISH_SRC appropriately.")
endif

include $(SWISH_SRC)/Mf-config

ifeq ($(wildcard $(SWISH_SRC)/shlibtest$(DLLSUFFIX)),)
$(error "Cannot find Swish's shlibtest$(DLLSUFFIX). Please make it in $(SWISH_SRC).")
endif

ifeq ($(shell uname -o),Darwin)
SED = sed -i ""
else
SED = sed -i""
endif

all: without-config minimal-config bad-hash good-hash

without-config: script linked stand-alone
	@echo "--- without .config files ---"
	@rm -f .config script.config linked.config stand-alone.config
	@echo "running main.ss as a script:"
	-./script 2 3 4 other
	@echo "running main.ss as a linked application:"
	-./linked 2 3 4 other
	@echo "running main.ss as a stand-alone application:"
	-./stand-alone 2 3 4 other
	@echo "[ expect errors complaining: Unknown shared object shlibtest ]"

minimal-config: script linked stand-alone
	@echo "--- with minimal .config files ---"
	$(MAKE) .config
	@cp .config script.config
	@cp .config linked.config
	@cp .config stand-alone.config
	@rm .config
	@echo "running main.ss as a script:"
	-./script 2 3 4 other
	@echo "running main.ss as a linked application:"
	-./linked 2 3 4 other
	@echo "running main.ss as a stand-alone application:"
	-./stand-alone 2 3 4 other
	@echo "[ expect it to work ]"

bad-hash: script linked stand-alone
	@echo "--- with bad hash .config files ---"
	$(MAKE) .config
	@printf '/"file"/i\\\n"SHA1" : "BADHASH",' > .sedscript
	@${SED} -f .sedscript .config
	@rm .sedscript
	@cp .config script.config
	@cp .config linked.config
	@cp .config stand-alone.config
	@rm .config
	@echo "running main.ss as a script:"
	-./script 2 3 4 other
	@echo "running main.ss as a linked application:"
	-./linked 2 3 4 other
	@echo "running main.ss as a stand-alone application:"
	-./stand-alone 2 3 4 other
	@echo "[ expect errors complaining: Cannot load shared object ]"

good-hash: script linked stand-alone
	@echo "--- with good hash .config files ---"
	$(MAKE) .config
	@printf '/"file"/i\\\n"SHA1" : "%s",' $$(sha1sum -b $(SWISH_SRC)/shlibtest${DLLSUFFIX}|cut -c-40) > .sedscript
	@${SED} -f .sedscript .config
	@rm .sedscript
	@cp .config script.config
	@cp .config linked.config
	@cp .config stand-alone.config
	@rm .config
	@echo "running main.ss as a script:"
	-./script 2 3 4 other
	@echo "running main.ss as a linked application:"
	-./linked 2 3 4 other
	@echo "running main.ss as a stand-alone application:"
	-./stand-alone 2 3 4 other
	@echo "[ expect it to work ]*"

SRC:=$(wildcard *.ss)

.config: $(SWISH_SRC)/shlibtest${DLLSUFFIX}
	@echo \
	 '(begin' \
	 '  (provide-shared-object (quote shlibtest) "$<")' \
	 '  (call-with-output-file ".config"' \
	 '    (lambda (op)' \
	 '      (json:write op (app:config) 0))))' \
	| swish -q

script: ${SRC}
	echo "#!/usr/bin/env swish" > script
	cat main.ss >> script
	chmod +x script

linked: ${SRC}
	swish-build -o $@ main.ss

stand-alone: ${SRC}
	swish-build -b petite -o $@ main.ss

test:
	@echo "Please test the 'shlib' example manually."

clean:
	rm -f script linked stand-alone stand-alone.boot stand-alone.wpo
	rm -f .config script.config linked.config stand-alone.config
	rm -f foreign.so foreign.wpo
	rm -f main.so main.wpo
	rm -f check-shared-object.so check-shared-object.wpo
