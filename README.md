# Rx Compiler Template

## Getting Started

Welcome to the Rx Compiler course! This repository provides a template from which you can build your own compiler for the Rx programming language. It includes official testcases, a test scaffold, and the G4 representation of Rx to get you started.

We strongly recommend that you **fork this repository** instead of downloading zips, in case we need to update the official testcases. After forking your copy, clone it to your local machine.

## Overview

In this course you can use **any language** to implement your compiler. Contact the TA if your language is not mainstream so that we can provide support for it on the Online Judge. For this reason, the template we provide here is **language-agnostic**. You will find:

- Testcases under `tests/`. Official testcases reside under `tests/official` and is a git submodule. You may add your own testcases under `tests/custom`.
- A test runner. The `Makefile` runs testcases using the compiler configured in `config.mk`. By default it points to your system rustc so running `make test` on a fresh clone should pass all testcases. **Replace the commands in `config.mk` with your own compiler commands** to setup testing for your compiler. See [Running and testing](#running-and-testing) for details.
- G4 grammar for Rx under `grammar/`. You may use it to generate the lexer and parser for your compiler.

## Setting up the Makefile

The Makefile is our unified entrypoint in accessing your compiler. You are expected to edit [`config.mk`](config.mk) and hook in your compiler commands. In practice, specify in these fields:

| Command Name | Purpose |
| --- | --- |
| `BUILD` | The command to build your compiler, can be empty. Must exit 0. |
| `SEMANTIC` | Check a complete program through semantic analysis. Exit 0 to accept or 1 to reject. |
| `CODEGEN` | Compile successfully and write the artifact to `{output}`. |
| `RUN` | The command to run the compiled artifact `{output}`. |

For example, if your compiler supports `--stage` and `-o`:

```make
BUILD = cargo build --release
SEMANTIC = ./target/release/compiler --stage semantic {source}
CODEGEN = ./target/release/compiler --stage codegen {source} -o {output}
RUN = {output}
```

## Testcases

Tests reside in `tests/`, and are organized into subdirectories. We recommend you follow the "namespace:test-suite:testcase" pattern. For instance, `official:semantic:arrays` is the `arrays` testcase in the `semantic` test suite of the `official` namespace.

Each testcase can have one or more source files, optional input and output files and a compulsory `manifest.json` file which defines the format of the testcase. See [the official schema](tests/official/manifest.schema.json) for details. The manifest's `stage` argument chooses the compiler command to run in the Makefile.

You are encouraged to add your own testcases under `tests/custom`. The runner will find them automatically.

Requirements for each kind of testcase:

| Testcase Type | Requirements |
| --- | --- |
| Semantic | The compiler must exit 0 or 1 to match `compilation_success`. Other exit codes, signals, and timeouts fail the case. |
| Codegen | Compilation must exit 0 and create `{output}`. Each `io` pair runs the artifact and the output must match the expected file. |
| Optimization | Same as Codegen. |

Testcases with type `lex` and `parse` will be skipped since we already provide the G4 grammar. Extend the Makefile if you want to DIY these stages.

## Running tests

Run from the project root:

```sh
make test
make test FILTER=official:semantic
make test FILTER=official:codegen:arrays,official:optimization
make test FILTER=custom
make test FILTER=official:optimization COMPILE_TIMEOUT=60 RUN_TIMEOUT=30
```

Supported environment variables include:

- `FILTER`, which selects directories under `tests`, using `:` between folder names and `,` between selections. Omit `FILTER` or leave it empty to run all supported tests.
- `COMPILE_TIMEOUT` and `RUN_TIMEOUT`, which override the default timeouts for compilation and execution.
