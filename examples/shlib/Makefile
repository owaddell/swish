.PHONY: all clean

ifeq (Windows_NT,${OS})
DLL=.dll
else
DLL=.so
endif

all: .config script linked stand-alone
	@echo "--- without .config files ---"
	rm -f script.config linked.config stand-alone.config
	@echo "running main.ss as a script:"
	-./script 2 3 4 other
	@echo "running main.ss as a linked application:"
	-./linked 2 3 4 other
	@echo "running main.ss as a stand-alone application:"
	-./stand-alone 2 3 4 other
	@echo "--- with minimal .config files ---"
	cp .config script.config
	cp .config linked.config
	cp .config stand-alone.config
	@echo "running main.ss as a script:"
	-./script 2 3 4 other
	@echo "running main.ss as a linked application:"
	-./linked 2 3 4 other
	@echo "running main.ss as a stand-alone application:"
	-./stand-alone 2 3 4 other
	@echo "--- with bad hash .config files ---"
	sed -i '/"file"/i"SHA1" : "BADHASH",' .config
	cp .config script.config
	cp .config linked.config
	cp .config stand-alone.config
	@echo "running main.ss as a script:"
	-./script 2 3 4 other
	@echo "running main.ss as a linked application:"
	-./linked 2 3 4 other
	@echo "running main.ss as a stand-alone application:"
	-./stand-alone 2 3 4 other
	@echo "--- with good hash .config files ---"
	sed -i s_BADHASH_$$(sha1sum -b ../../src/swish/shlibtest${DLL}|cut -c-40)_ .config
	cp .config script.config
	cp .config linked.config
	cp .config stand-alone.config
	@echo "running main.ss as a script:"
	-./script 2 3 4 other
	@echo "running main.ss as a linked application:"
	-./linked 2 3 4 other
	@echo "running main.ss as a stand-alone application:"
	-./stand-alone 2 3 4 other
	rm .config

SRC:=$(wildcard *.ss)

.config: ../../src/swish/shlibtest${DLL}
	echo \
	 '(begin' \
	 '  (provide-shared-library "shlibtest" "$<")' \
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

clean:
	rm -f script linked stand-alone stand-alone.boot stand-alone.wpo
	rm -f .config script.config linked.config stand-alone.config
	rm -f foreign.so foreign.wpo
	rm -f main.so main.wpo
	rm -f shared-library.so shared-library.wpo
