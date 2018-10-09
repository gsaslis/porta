run: ## Runs command $(CMD) without starting any containers.
run:
	bash -c "script/docker.sh && source script/proxy_env.sh && echo \"$(CMD)\" && $(CMD)"


test: ## Runs tests inside container build environment
test: CMD = $(SCRIPT_TEST)
test: info
	@echo
	@echo "======= Tests ======="
	@echo
	$(MAKE) test-run --keep-going

test-no-deps: ## Runs only tests (without dependency installation) inside container build environment
test-no-deps: CMD = script/jenkins.sh
test-no-deps: info
	@echo
	@echo "======= Tests ======="
	@echo
	$(MAKE) test-run --keep-going

test-run: ## Runs tests
test-run: clean-tmp cache
	$(CMD)

