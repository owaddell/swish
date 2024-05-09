.PHONY: clean test

ifeq ($(wildcard ../.git),)
MAKEFILES=$(wildcard */Makefile)
else
MAKEFILES=$(shell git ls-files '*/Makefile')
endif

define walk
for d in $(MAKEFILES); do make -sC "$$(dirname "$$d")" $(1); done
endef

test:
	@$(call walk, $@) 2>&1 | tee .post | grep -v "^Please.*manually"
	@grep "^Please.*manually" .post

clean:
	$(call walk, $@)
	rm -f .post
