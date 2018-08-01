.PHONY: all clean

all: visible invisible
	@echo "version compiled with --libs-visible works:"
	-./visible
	@echo ""
	@echo "version compiled without --libs-visible fails (in eval):"
	-./invisible

visible: main.ss german.ss
	swish-build -o $@ main.ss --libs-visible

invisible: main.ss german.ss
	swish-build -o $@ main.ss

test:
	@echo "Please test the 'libs-visible' example manually."

clean:
	rm -f invisible visible german.so german.wpo
