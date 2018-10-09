MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))

DOCKER_COMPOSE_VERSION := 1.21.0
DOCKER_COMPOSE := $(BIN_PATH)/docker-compose
DOCKER_COMPOSE_BIN := $(DOCKER_COMPOSE)-$(DOCKER_COMPOSE_VERSION)

ifndef COMPOSE_PROJECT_NAME
$(error missing COMPOSE_PROJECT_NAME)
endif

ifndef COMPOSE_FILE
$(error missing COMPOSE_FILE)
endif

export COMPOSE_PROJECT_NAME
export COMPOSE_FILE

$(DOCKER_COMPOSE): $(DOCKER_COMPOSE_BIN)
	@ln -sf $(realpath $(DOCKER_COMPOSE_BIN)) $(DOCKER_COMPOSE)

$(DOCKER_COMPOSE_BIN): $(BIN_PATH) | wget
	@wget --no-verbose https://github.com/docker/compose/releases/download/$(DOCKER_COMPOSE_VERSION)/docker-compose-`uname -s`-`uname -m` -O $(DOCKER_COMPOSE_BIN)
	@chmod +x $(DOCKER_COMPOSE_BIN)
	@touch $(DOCKER_COMPOSE_BIN)

compose: $(DOCKER_COMPOSE)
	@$(MAKE) $(DOCKER_COMPOSE) > /dev/null
	@echo $(DOCKER_COMPOSE) --file $(COMPOSE_FILE) --project-name $(COMPOSE_PROJECT_NAME)



build: ## Build the container image using one of the docker-compose file set by $(COMPOSE_FILE) env var
build: COMPOSE_FILE = $(COMPOSE_TEST_FILE)
build: $(DOCKER_COMPOSE)
	$(DOCKER_COMPOSE) build

cache: ## Starts only cache service from docker-compose file
cache: COMPOSE_FILE = $(COMPOSE_TEST_FILE)
cache: $(DOCKER_COMPOSE)
	$(DOCKER_COMPOSE) up --remove-orphans -d cache || $(MAKE) clean-cache $@


clean: ## Cleaning docker-compose services
clean: SERVICES ?= database build
ifeq ($(CACHE),false)
clean: clean-cache
endif
clean: COMPOSE_FILE = $(COMPOSE_TEST_FILE)
clean: $(DOCKER_COMPOSE)
	- $(DOCKER_COMPOSE) stop $(SERVICES)
	- $(DOCKER_COMPOSE) rm --force -v $(SERVICES)
	- docker rm --force --volumes $(PROJECT)-build $(PROJECT)-build-run 2> /dev/null
	- $(foreach service,$(SERVICES),docker rm --force --volumes $(PROJECT)-$(service) 2> /dev/null;)

clean-cache: ## Only clean up the cache container
clean-cache: export SERVICES = cache
clean-cache: export CACHE = true
clean-cache:
	$(MAKE) clean

oracle-database: ## Starts Oracle database container
oracle-database: ORACLE_DATA_DIR ?= $(HOME)
oracle-database:
	[ "$(shell docker inspect -f '{{.State.Running}}' oracle-database 2>/dev/null)" = "true" ] || docker start oracle-database || docker run \
		--shm-size=6gb \
		-p 1521:1521 -p 5500:5500 \
		--name oracle-database \
		-e ORACLE_PDB=systempdb \
		-e ORACLE_SID=threescale \
		-e ORACLE_PWD=threescalepass \
		-e ORACLE_CHARACTERSET=AL32UTF8 \
		-v $(ORACLE_DATA_DIR)/oracle-database:/opt/oracle/oradata \
		-v $(PWD)/script/oracle:/opt/oracle/scripts/setup \
		quay.io/3scale/oracle:12.2.0.1-ee


run: ## Starts containers and runs command $(CMD) inside the container in a non-interactive shell
run: COMPOSE_FILE = $(COMPOSE_TEST_FILE)
run: $(DOCKER_COMPOSE)
	@echo
	@echo "======= Run ======="
	@echo
	$(DOCKER_COMPOSE) run --rm --name $(PROJECT)-build-run $(DOCKER_ENV) build bash -c "script/docker.sh && source script/proxy_env.sh && echo \"$(CMD)\" && $(CMD)"

test: ## Runs tests inside container build environment
test: COMPOSE_FILE = $(COMPOSE_TEST_FILE)
test: CMD = $(SCRIPT_TEST)
test: $(DOCKER_COMPOSE) info
	@echo
	@echo "======= Tests ======="
	@echo
	$(MAKE) test-run tmp-export --keep-going

test-no-deps: ## Runs only tests (without dependency installation) inside container build environment
test-no-deps: COMPOSE_FILE = $(COMPOSE_TEST_FILE)
test-no-deps: CMD = script/jenkins.sh
test-no-deps: $(DOCKER_COMPOSE) info
	@echo
	@echo "======= Tests ======="
	@echo
	$(MAKE) test-run tmp-export --keep-going

test-run: ## Runs test inside container
test-run: COMPOSE_FILE = $(COMPOSE_TEST_FILE)
test-run: $(DOCKER_COMPOSE) clean-tmp cache
	$(DOCKER_COMPOSE) run --name $(PROJECT)-build $(DOCKER_ENV) build $(CMD)


tmp-export: ## Copies files from inside docker container to local tmp folder.
tmp-export: IMAGE ?= $(PROJECT)-build
tmp-export: clean-tmp
	-@ $(foreach dir,$(TMP),docker cp $(IMAGE):/opt/system/$(dir) $(dir) 2>/dev/null;)

