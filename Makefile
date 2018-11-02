# Installation commands
.PHONY: npm build-ganache build-remix-ide docker-build build docker-start docker-stop init develop

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

# remix-ide options
REMIX_IDE=remix-ide/docker-compose.yml

npm:
	@npm install

build-ganache:
	@ACCOUNTS="" docker-compose -f $(GANACHE) build

build-remix-ide:
	@docker-compose -f $(REMIX_IDE) build

docker-build: build-ganache build-remix-ide

build: npm docker-build

start-ganache:
	@ACCOUNTS=`cat $(ACCOUNTS)` docker-compose -f $(GANACHE) up -d

stop-ganache:
	@ACCOUNTS="" docker-compose -f $(GANACHE) stop

init: build start-ganache

develop: start-ganache

start-remix-ide:
	@docker-compose -f $(REMIX_IDE) up -d

stop-remix-ide:
	@docker-compose -f $(REMIX_IDE) stop

start-remixd:
	@npm run remixd

stop-develop: stop-ganache stop-remix-ide

open-remix-ide:
	@xdg-open http://localhost:9999

remix: start-remix-ide open-remix-ide start-remixd

test:
	@$(TRUFFLE) test --network development

run-coverage:
	@npm run coverage

coverage: run-coverage
	@xdg-open coverage/index.html

test-lint:
	@npm run lint:all

lint:
	@npm run lint:all:fix