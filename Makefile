DOKKU_VERSION ?= latest
HATEST_HOST_DIR ?= $(CURDIR)/tmp/hatest-host

# Optional path or filename relative to /plugin-src/tests passed to bats, e.g.
# `make unit-tests UNIT_TESTS=http_auth_enable.bats`. Defaults to the whole
# tests directory.
UNIT_TESTS ?= .
# Optional regex passed to bats --filter to scope down to a single test name.
UNIT_TESTS_FILTER ?=
BATS_FLAGS := --timing --print-output-on-failure
ifneq ($(UNIT_TESTS_FILTER),)
BATS_FLAGS += --filter '$(UNIT_TESTS_FILTER)'
endif

COMPOSE := DOKKU_VERSION=$(DOKKU_VERSION) HATEST_HOST_DIR=$(HATEST_HOST_DIR) docker compose -f tests/docker-compose.yml
COMPOSE_COMPOSE_MODE := $(COMPOSE) --profile compose-mode
COMPOSE_EXEC_DOKKU := $(COMPOSE) exec -T dokku

PLUGIN_BASH_FILES := command-functions commands help-functions install internal-functions \
	nginx-pre-reload post-app-clone-setup post-app-rename-setup post-delete report \
	$(wildcard subcommands/*) \
	tests/setup.sh tests/setup-native.sh tests/test_helper.bash

.PHONY: setup build-stack wait-stack install-plugin test lint unit-tests clean logs \
	setup-native unit-tests-native clean-native

setup: build-stack wait-stack install-plugin

build-stack:
	mkdir -p $(HATEST_HOST_DIR)
	$(COMPOSE_COMPOSE_MODE) build
	$(COMPOSE_COMPOSE_MODE) up -d

wait-stack:
	$(COMPOSE_COMPOSE_MODE) up -d --wait

install-plugin:
	$(COMPOSE_EXEC_DOKKU) bash /plugin-src/tests/setup.sh

lint:
	$(COMPOSE_EXEC_DOKKU) shellcheck $(addprefix /plugin-src/, $(PLUGIN_BASH_FILES))

unit-tests:
	$(COMPOSE_EXEC_DOKKU) bats $(BATS_FLAGS) /plugin-src/tests/$(UNIT_TESTS)

test: lint unit-tests

logs:
	$(COMPOSE) logs --no-color --tail=200

clean:
	$(COMPOSE_COMPOSE_MODE) down -v --remove-orphans
	# The host-side state dir contains files owned by root inside the
	# dokku container, which the host user cannot rm without elevation.
	rm -rf $(HATEST_HOST_DIR) 2>/dev/null || sudo rm -rf $(HATEST_HOST_DIR)

# --- Native mode: dokku installed on the host. http-auth needs no supporting services. ---

setup-native:
	bash tests/setup-native.sh

unit-tests-native:
	SUDO=sudo bats $(BATS_FLAGS) tests/$(UNIT_TESTS)

clean-native:
	@echo "http-auth needs no supporting compose services; nothing to tear down"
