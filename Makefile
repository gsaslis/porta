MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
PROJECT_PATH := $(patsubst %/,%,$(dir $(MKFILE_PATH)))
PROJECT = $(subst @,,$(notdir $(subst /workspace,,$(PROJECT_PATH))))

export PROJECT

BUNDLE_GEMFILE ?= Gemfile

TMP = tmp/capybara tmp/junit tmp/codeclimate coverage log/test.searchd.log tmp/jspm

DB ?= mysql

JENKINS_ENV = JENKINS_URL BUILD_TAG BUILD_NUMBER BUILD_URL
JENKINS_ENV += GIT_BRANCH GIT_COMMIT GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_EMAIL GIT_COMMITTER_NAME PERCY_ENABLE
JENKINS_ENV += BUNDLE_GEMFILE BUNDLE_GEMS__CONTRIBSYS__COM
JENKINS_ENV += PARALLEL_TEST_PROCESSORS
JENKINS_ENV += CIRCLE_BUILD_NUM \
			   CIRCLE_BUILD_URL \
			   CIRCLE_COMPARE_URL \
			   CIRCLE_INTERNAL_CONFIG \
			   CIRCLE_INTERNAL_SCRATCH \
			   CIRCLE_INTERNAL_TASK_DATA \
			   CIRCLE_JOB \
			   CIRCLE_JOB \
			   CIRCLE_NODE_INDEX \
			   CIRCLE_NODE_TOTAL \
			   CIRCLE_PR_NUMBER \
			   CIRCLE_PREVIOUS_BUILD_NUM \
			   CIRCLE_PROJECT_REPONAME \
			   CIRCLE_PROJECT_USERNAME \
			   CIRCLE_REPOSITORY_URL \
			   CIRCLE_SHA1 \
			   CIRCLE_SHELL_ENV \
			   CIRCLE_STAGE \
			   CIRCLE_STAGE \
			   CIRCLE_USERNAME \
			   CIRCLE_WORKFLOW_ID \
			   CIRCLE_WORKFLOW_JOB_ID \
			   CIRCLE_WORKFLOW_WORKSPACE_ID \
			   CIRCLE_WORKING_DIRECTORY \
			   CIRCLECI \
			   CIRCLECI_PKG_DIR

JENKINS_ENV += MULTIJOB_KIND PERCY_ENABLE PERCY_TOKEN COVERAGE PROXY_ENABLED
JENKINS_ENV += DB

RUBY_ENV += RUBY_GC_HEAP_INIT_SLOTS=479708
RUBY_ENV += RUBY_GC_HEAP_FREE_SLOTS=47431584
RUBY_ENV += RUBY_GC_HEAP_GROWTH_FACTOR=1.03
RUBY_ENV += RUBY_GC_HEAP_GROWTH_MAX_SLOTS=472324
RUBY_ENV += RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=1.2
RUBY_ENV += RUBY_GC_MALLOC_LIMIT=40265318
RUBY_ENV += RUBY_GC_MALLOC_LIMIT_MAX=72477572
RUBY_ENV += RUBY_GC_MALLOC_LIMIT_GROWTH_FACTOR=1.32
RUBY_ENV += RUBY_GC_OLDMALLOC_LIMIT=40125988
RUBY_ENV += RUBY_GC_OLDMALLOC_LIMIT_MAX=72226778
RUBY_ENV += RUBY_GC_OLDMALLOC_LIMIT_GROWTH_FACTOR=1.2

ifeq ($(CI),true)
DOCKER_ENV = CI=true
else
DOCKER_ENV = CI=jenkins
endif

DOCKER_ENV += $(foreach env,$(JENKINS_ENV),$(env)=$(value $(env)))
DOCKER_ENV += GIT_TIMESTAMP=$(shell git log -1 --pretty=format:%ct)
DOCKER_ENV += PERCY_PROJECT=3scale/porta PERCY_BRANCH=$(subst origin/,,$(GIT_BRANCH)) PERCY_COMMIT=$(GIT_COMMIT)
DOCKER_ENV += $(RUBY_ENV)
DOCKER_ENV += BUNDLE_GEMFILE=$(BUNDLE_GEMFILE)

DOCKER_ENV := $(addprefix -e ,$(DOCKER_ENV))
DOCKER_ENV += -e GIT_COMMIT_MESSAGE='$(subst ','\'',$(shell git log -1 --pretty=format:%B))'
DOCKER_ENV += -e GIT_COMMITTED_DATE="$(shell git log -1 --pretty=format:%ai)"

SCRIPT_BUNDLER = bundle check --path=vendor/bundle --gemfile=Gemfile || ${PROXY_ENV} bundle install --deployment --retry=5 --gemfile=Gemfile && bundle config
SCRIPT_NPM = yarn --version && yarn global dir && ${PROXY_ENV} yarn install --frozen-lockfile --link-duplicates && jspm -v && ${PROXY_ENV} jspm dl-loader && ${PROXY_ENV} jspm install --lock || ${PROXY_ENV} jspm install --force
SCRIPT_APICAST_DEPENDENCIES = cd vendor/docker-gateway && ls -al && ${PROXY_ENV} make dependencies && cd ../../
SCRIPT_PRECOMPILE_ASSETS = bundle config && bundle exec rake assets:precompile RAILS_GROUPS=assets RAILS_ENV=production WEBPACKER_PRECOMPILE=false && bundle exec rake assets:precompile RAILS_GROUPS=assets RAILS_ENV=test WEBPACKER_PRECOMPILE=false
SCRIPT_ALL_DEPS = $(SCRIPT_BUNDLER) && $(SCRIPT_NPM) && $(SCRIPT_APICAST_DEPENDENCIES) && $(SCRIPT_PRECOMPILE_ASSETS)
SCRIPT_BASH = $(SCRIPT_ALL_DEPS) && bundle exec rake db:create db:test:load && bundle exec bash
SCRIPT_TEST = $(SCRIPT_ALL_DEPS) && script/jenkins.sh

default: all

COMPOSE_PROJECT_NAME := $(PROJECT)
COMPOSE_FILE := docker-compose.yml
COMPOSE_TEST_FILE := docker-compose.test-$(DB).yml

## This image is private and cannot be accessed by another third party than redhat.com employees
## You will need to build your own image as instructed in https://github.com/oracle/docker-images/tree/master/OracleDatabase/SingleInstance
ORACLE_DB_IMAGE := quay.io/3scale/oracle:12.2.0.1-ee

include wget.mk
ifndef RUNNING_IN_DOCKER
	include docker-compose.mk
else
	include container.mk
endif
include openshift.mk
include dependencies.mk

.PHONY: default all clean build test info jenkins-env docker test-run tmp-export run test-bash clean-cache clean-tmp compose help bundle-in-container apicast-dependencies-in-container npm-install-in-container test-no-deps
.DEFAULT_GOAL := help

# From here on, only phony targets to manage docker compose
all: clean clean-tmp build test ## Cleans environment, builds docker image and runs tests

info: docker jenkins-env # Prints relevant environment info

jenkins-env: ## Prints env vars
	@echo
	@echo "======= Jenkins environment ======="
	@echo
	@env
	@echo

docker: ## Prints docker version and info
	@echo
	@echo "======= Docker ======="
	@echo
	@docker version
	@echo
	@docker info
	@echo

precompile-assets-info:
	@echo
	@echo "======= Assets Precompile ======="
	@echo
precompile-assets: ## Precompiles static assets
precompile-assets: CMD = $(SCRIPT_PRECOMPILE_ASSETS)
precompile-assets: precompile-assets-info run

clean-tmp: ## Removes temporary files
	-@ $(foreach dir,$(TMP),rm -rf $(dir);)

bash: ## Opens up shell to environment where tests can be ran
bash: CMD = $(SCRIPT_BASH)
bash: run

bundle: ## Installs dependencies using bundler. Run this after you make some changes to Gemfile.
bundle: Gemfile.prod Gemfile
	bundle install --gemfile=Gemfile.prod
	cp Gemfile.prod.lock Gemfile.lock
	bundle install --gemfile=Gemfile

oracle-db-setup: ## Creates databases in Oracle
oracle-db-setup: oracle-database
	MASTER_PASSWORD=p USER_PASSWORD=p ORACLE_SYSTEM_PASSWORD=threescalepass NLS_LANG='AMERICAN_AMERICA.UTF8' DISABLE_SPRING=true DB=oracle bundle exec rake db:drop db:create db:setup

schema: ## Runs db schema migrations. Run this when you have changes to your database schema that you have added as new migrations.
	bundle exec rake db:migrate db:schema:dump
	MASTER_PASSWORD=p USER_PASSWORD=p ORACLE_SYSTEM_PASSWORD=threescalepass NLS_LANG='AMERICAN_AMERICA.UTF8' DISABLE_SPRING=true DB=oracle bundle exec rake db:migrate db:schema:dump

# Check http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

