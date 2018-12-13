# Installation commands
.PHONY: yarn docker-start docker-stop init develop

# Commands to use remix
.PHONY: remix

# Test commands
.PHONY: test coverage

# Linting commands
.PHONY: test-lint lint

# Executables
NODE_MODULES=./node_modules
BIN=$(NODE_MODULES)/.bin
TRUFFLE=$(BIN)/truffle

yarn:
	@yarn install

start-ganache:
	docker run -p 7545:8545 --name ganache-cli --rm -d trufflesuite/ganache-cli:latest -d -e 1000 -g 0xfffffffffff

stop-ganache:
	docker stop ganache-cli

init: yarn start-ganache

develop: start-ganache

stop-develop: stop-ganache

start-remixd:
	@yarn run remixd

open-remix-ide:
	@open http://localhost:8080

remix:
	@yarn run remix

test:
	@$(TRUFFLE) test --network development

run-coverage:
	@yarn run coverage

coverage: run-coverage
	@python -mwebbrowser coverage/index.html

test-lint:
	@yarn run lint:all

lint:
	@yarn run lint:all:fix
