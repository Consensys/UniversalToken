# Installation commands
.PHONY: yarn build-ganache build-remix-ide docker-build build docker-start docker-stop init develop

# Commands to use remix
.PHONY: start-remixd open-remix-ide remix

# Test commands
.PHONY: test coverage

# Linting commands
.PHONY: test-lint lint

# Executables
NODE_MODULES=./node_modules
BIN=$(NODE_MODULES)/.bin
TRUFFLE=$(BIN)/truffle

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

start-remixd:
	@yarn run remixd

stop-develop: stop-ganache stop-remix-ide

open-remix-ide:
	@xdg-open http://localhost:8080

remix:
	@yarn run remix

test:
	@$(TRUFFLE) test --network development

run-coverage:
	@yarn run coverage

coverage: run-coverage
	@xdg-open coverage/index.html

test-lint:
	@yarn run lint:all

lint:
	@yarn run lint:all:fix
