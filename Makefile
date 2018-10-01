# Installation commands
.PHONY: npm build-ganache build-remix-ide docker-build build docker-start docker-stop init develop

# Commands to use remix
.PHONY: start-remixd open-remix-ide remix

# Test commands
.PHONY: test coverage

# Linting commands
.PHONY: test-lint lint

# ganache options
GANACHE=ganache/docker-compose.yml
ACCOUNTS=ganache/accounts.txt

yarn:
	@yarn install

build-ganache:
	@ACCOUNTS="" docker-compose -f $(GANACHE) build

docker-build: build-ganache

build: yarn docker-build

start-ganache:
	@ACCOUNTS=`cat $(ACCOUNTS)` docker-compose -f $(GANACHE) up -d

stop-ganache:
	@ACCOUNTS="" docker-compose -f $(GANACHE) stop

init: build start-ganache

develop: start-ganache

stop-develop: stop-ganache
	
test:
	@yarn run contract:test

run-coverage:
	@yarn run contract:test:coverage

coverage: run-coverage
	@xdg-open coverage/index.html

test-lint:
	@yarn run lint:all

lint:
	@yarn run lint:all:fix
