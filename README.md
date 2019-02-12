# Boilerplate-Solidity

This project is an empty Solidity Smart-Contract project bringing useful features for helping developers create a new project.
This project aims to facilitate developpers life when writing Solidity Smart Contracts.

Particularly it comes with

## Main Development Features

- **[Truffle](https://github.com/ConsenSys/truffle)* integrated as Ethereum development environment
- **CI** integrated on GitLab-CI
- **remix-ide** started locally with ``remixd`` exposing local contracts
- **coverage** configured using ``solidity-coverage``
- **linting** configured using ``solium``

## Setting up development environment

## Requirements

It is highly recommended to use this project on Unix distribution.

- **Git**, having the latest version of ``git`` installed locally
- **Node**, having ``node`` and ``npm`` installed locally
- **Docker**, having ``docker`` and ``docker-compose`` installed locally

## First time setup

- Clone project locally

- Create development environment

    ```
    $ make init
    ```
  
  This command will build ``docker`` images for ``ganache`` and ``remix-ide``. After building images, it starts to run a service for ``ganache`` and for ``testrpc-sc``.

## Starting/Stopping development environment

Each time you need to develop again on this project run

```
$ make develop
```

It starts ``ganache`` and ``testrpc-sc``.

When you stop developing you can run

```
$ make stop-develop
```

It stops every ``docker`` services

## Using Remix-IDE

If you like to use ``Remix-IDE`` when developping on this project, please run

```
$ make remix
```

It will start a  ``docker`` service for ``Remix-IDE``

``Remix-IDE`` will then be available at ``http://localhost:9999``

#### Note: Remixd

It will also start a ``remixd`` server that exposes your local contracts scripts to ``Remix-IDE``.
Please refer to [Remix-IDE](https://remix.readthedocs.io/en/latest/tutorial_remixd_filesystem/) doc for security guidelines and access your local contracts from ``Remix-IDE``.

## Testing

### Running tests

Run test suite in by running

```
$ make test
```

### Running coverage

Please ensure that all the lines of source code you are writing are covered in your test suite.
To generate the coverage report, please run

```
$ make coverage
```

### Testing linting

To test if your project is compliant with linting rules run

```
$ make test-lint
```

To automatically correct linting errors run

```
$ make lint
```