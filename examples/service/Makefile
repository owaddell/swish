.PHONEY: build clean install-user uninstall-user install-system uninstall-system

ifeq (Linux,$(shell uname -s))
else ifeq (Windows_NT,${OS})
EXE := .exe
endif

build: swish-service-example${EXE} swish-service-example.boot

swish-service-example${EXE} swish-service-example.boot: $(wildcard *.ss)
	swish-build -o swish-service-example${EXE} -b petite main.ss --rtlib swish

test:
	@echo "Please test the 'service' example manually."

clean:
	rm -f swish-service-example${EXE} swish-service-example.boot
