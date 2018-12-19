.PHONY: all clean pristine
SRC := $(shell find src -type f -name '*.ss')

all: fail0 fail1 fail2 work
	mkdir -p deploy
	cp -frv src/pages deploy
	cp fail0 fail0.boot deploy
	cp fail1 fail1.boot deploy
	cp fail2 fail2.boot deploy
	cp work work.boot deploy

fail0: $(SRC)
	swish-build -b petite -o $@ src/server.ss

fail1: $(SRC)
	swish-build -b petite -o $@ src/server.ss --libs-visible

fail2: $(SRC)
	swish-build -b petite -o $@ src/server.ss --rtlib swish

work: $(SRC) web.lib
	swish-build -b petite -o $@ src/server.ss --rtlib swish --rtlib web.lib

web.lib: src/text-utils/describe.ss
	swish-build --library -o $@ src/text-utils/describe.ss

clean:
	rm -f fail0 fail0.boot fail1 fail1.boot fail2 fail2.boot work work.boot web.lib

pristine:
	git clean -dxf .
