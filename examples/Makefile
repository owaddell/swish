.PHONY: clean test

define walk
for d in $$(git ls-files '*/Makefile'); do make -sC "$$(dirname "$$d")" $(1); done
endef

test:
	@$(call walk, $@) 2>&1 | tee .post
	@grep "Please.*manually" .post
	@echo "Please test the 'echo-server' example manually."

clean:
	$(call walk, $@)
	rm -f .post
