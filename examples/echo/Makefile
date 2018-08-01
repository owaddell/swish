.PHONY: all clean

all: script linked stand-alone
	@echo "running echo.ss as a script:"
	./script 1 2 3
	@echo "running echo.ss as a linked application:"
	./linked 1 2 3
	@echo "running echo.ss as a stand-alone application:"
	./stand-alone 1 2 3

script: echo.ss
	echo "#!/usr/bin/env swish" > script
	cat echo.ss >> script
	chmod +x script

linked: echo.ss
	swish-build -o $@ $<

stand-alone: echo.ss
	swish-build -b petite -o $@ $<

test: script linked stand-alone
	swish-test echo.ms

clean:
	rm -f script linked stand-alone stand-alone.boot
	rm -f *.ms.mo *.sop
