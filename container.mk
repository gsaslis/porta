run: ## Runs command $(CMD) without starting any containers.
run:
	$(CMD)

info: jenkins-env # Prints relevant environment info

test: ## Runs tests inside container build environment
test: CMD = $(SCRIPT_TEST)
test: test-with-info

test-no-deps: ## Runs only tests (without dependency installation) inside container build environment
test-no-deps: CMD = script/jenkins.sh
test-no-deps: test-with-info

test-run: ## Runs tests
test-run: clean-tmp cache
	$(CMD)

test-with-info: info
	@echo
	@echo "======= Tests ======="
	@echo
	$(MAKE) test-run --keep-going