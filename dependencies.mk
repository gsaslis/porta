bash-interactive: ## Opens up interactive shell in development environment inside container.
bash-interactive: COMMAND = /bin/bash
bash-interactive: bash-run

bash-run: ## Runs arbitrary ${COMMAND} in development environment inside container.
bash-run: COMPOSE_FILE = $(COMPOSE_TEST_FILE)
bash-run: $(DOCKER_COMPOSE)
	@echo
	@echo "======= Run Command ======="
	@echo
	$(DOCKER_COMPOSE) run --rm --name $(PROJECT)-build-run $(DOCKER_ENV) build "$(COMMAND)"


bundle-info:
	@echo
	@echo "======= Bundler ======="
	@echo

bundle-in-container: ## Installs dependencies using bundler, inside the build container. Run this after you make some changes to Gemfile.
bundle-in-container: Gemfile
bundle-in-container: CMD = $(SCRIPT_BUNDLER)
bundle-in-container: bundle-info run


apicast-dependencies-info:
	@echo
	@echo "======= APIcast ======="
	@echo

apicast-dependencies-in-container: ## Fetches APICast dependencies by invoking `dependencies` target on apicast submodule.
apicast-dependencies-in-container: CMD = $(SCRIPT_APICAST_DEPENDENCIES)
apicast-dependencies-in-container: apicast-dependencies-info run

npm-install-info:
	@echo
	@echo "======= NPM ======="
	@echo

npm-install-in-container: ## Installs NPM & JSPM dependencies in development environment inside container.
npm-install-in-container: CMD = $(SCRIPT_NPM)
npm-install-in-container: npm-install-info run




