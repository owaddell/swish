.PHONY: all clean

all: script linked stand-alone
	@echo "running hello.ss as a script:"
	./script
	@echo "running hello.ss as a linked application:"
	./linked
	@echo "running hello.ss as a stand-alone application:"
	./stand-alone

script: hello.ss
	echo "#!/usr/bin/env swish" > script
	cat hello.ss >> script
	chmod +x script

linked: hello.ss
	swish-build -o $@ $<

stand-alone: hello.ss
	swish-build -b petite -o $@ $<

test:
	@echo "Please test the 'hello' example manually."

clean:
	rm -f script linked stand-alone stand-alone.boot
