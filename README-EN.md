# Rx Compiler Template

[English](README-EN.md) | [简体中文](README-ZH.md)

> Replace this with your own README when you start working on your compiler.

## Getting Started

Welcome to the Rx Compiler course! This repository provides a template from which you can build your own compiler for the Rx programming language. It includes official testcases, a test scaffold, and the G4 representation of Rx to get you started.

We strongly recommend that you **fork this repository** instead of downloading zips, in case we need to update the official testcases. After forking your copy, clone it to your local machine.

Initialize the testcases and [REIMU](https://github.com/wanoful/REIMU) submodules:

```sh
git submodule update --init --recursive
```

It requires Python 3, [xmake](https://xmake.io/), and a C++23 compiler to build REIMU. Build REIMU separately from the project root before running tests:

```sh
xmake f -y -P vendor/REIMU -m release -o target/reimu
xmake -y -P vendor/REIMU
```

Repeat these commands after updating the REIMU submodule. `make test` builds the reference runtime through `BUILD`. Codegen tests compile to RV32IM assembly and execute in REIMU, with testcase input and output connected to stdin and stdout.

## Overview

In this course you can use **any language** to implement your compiler. Contact the TA if your language is not mainstream so that we can provide support for it on the Online Judge. For this reason, the template we provide here is **language-agnostic**. You will find:

- Testcases under `tests/`. Official testcases reside under `tests/official` and is a git submodule. You may add your own testcases under `tests/custom`.
- A test runner. The `Makefile` runs testcases using the compiler configured in `config.mk`. By default it uses your system rustc with the `riscv32im-unknown-none-elf` target and executes generated assembly in REIMU. **Replace the compiler commands in `config.mk` with your own compiler commands** to set up testing for your compiler. See [Running tests](#running-tests) for details.
    - Some auxiliary files helps default rustc to output assembly file suitable for REIMU. It uses `scripts/reference.rs` for its bare-metal entry point, `Box`/`Vec` allocation, and panic handling. `crates/rx` implements integer I/O through REIMU's libc. The reference codegen command requests both assembly and a static library so rustc performs whole-program LTO and includes the runtime in the assembly. The extra `{output}.a` is a build artifact; `RUN` consumes `{output}` after `scripts/strip_asm_debug.py` removes debug metadata that REIMU cannot assemble. These helpers can be removed when you replace the Rust compiler commands.
- REIMU under `vendor/REIMU`, pinned as a git submodule. The `RUN` command in `config.mk` invokes it; the test runner does not depend on a particular simulator.
- G4 grammar for Rx under `grammar/`. You may use it to generate the lexer and parser for your compiler.

## Setting up the Makefile

The Makefile is our unified entrypoint in accessing your compiler. You are expected to edit [`config.mk`](config.mk) and hook in your compiler commands. In practice, specify in these fields:

| Command Name | Purpose |
| --- | --- |
| `BUILD` | The command to build your compiler, can be empty. Must exit 0. |
| `SEMANTIC` | Check a complete program through semantic analysis. Exit 0 to accept or 1 to reject. |
| `CODEGEN` | Compile codegen and optimization testcases and write RV32IM assembly to `{output}` for the default `RUN`. |
| `RUN` | Run `{output}`. Optional `{stdout}` and `{profile}` placeholders select per-execution output and profiling files. |

For example, if your compiler supports `--stage` and `-o` and emits RV32IM assembly:

```make
BUILD = cargo build --release
SEMANTIC = ./target/release/compiler --stage semantic {source}
CODEGEN = ./target/release/compiler --stage codegen {source} -o {output}
RUN = xmake run -P vendor/REIMU reimu -f {output} -o {stdout} -p {profile} 1>&2
```

REIMU starts at the assembly's global `main` symbol and provides its supported libc functions. `-o {stdout}` saves the program's output for comparison, `-p {profile}` saves its cycle profile, and `1>&2` sends simulator status messages to the stderr log. Do not add `--silent` when collecting cycles: REIMU suppresses profiles in silent mode. If your compiler needs additional runtime assembly, pass it with the program using `-f {output},path/to/runtime.s`.

## Testcases

Tests reside in `tests/`, and are organized into subdirectories. We recommend you follow the "namespace:test-suite:testcase" pattern. For instance, `official:semantic:arrays` is the `arrays` testcase in the `semantic` test suite of the `official` namespace.

Each testcase can have one or more source files, optional input and output files and a compulsory `manifest.json` file which defines the format of the testcase. See [the official schema](tests/official/manifest.schema.json) for details. The manifest's `stage` argument determines how the testcase runs: `semantic` uses `SEMANTIC`, while `codegen` and `optimization` use `CODEGEN` followed by `RUN`.

You are encouraged to add your own testcases under `tests/custom`. The runner will find them automatically.

Requirements for each kind of testcase:

| Testcase Type | Requirements |
| --- | --- |
| Semantic | The compiler must exit 0 or 1 to match `compilation_success`. Other exit codes, signals, and timeouts fail the case. |
| Codegen | Compilation must exit 0 and create `{output}`. Each `io` pair runs the artifact and the output must match the expected file. |
| Optimization | Same as Codegen, with cycle reporting when `RUN` provides `{profile}`. |

Testcases with type `lex` and `parse` will be skipped since we already provide the G4 grammar. Extend the Makefile if you want to DIY these stages.

## Running tests

Run from the project root:

```sh
make test
make test FILTER=official:semantic
make test FILTER=official:codegen:arrays,official:optimization
make test FILTER=custom
make test FILTER=official:optimization COMPILE_TIMEOUT=60 RUN_TIMEOUT=30
make test VERBOSE=true
```

Supported environment variables include:

- `FILTER`, which selects directories under `tests`, using `:` between folder names and `,` between selections. Omit `FILTER` or leave it empty to run all supported tests.
- `VERBOSE=true`, which shows every test name and its duration instead of grouped progress. Defaults to `false`.
- `COMPILE_TIMEOUT` and `RUN_TIMEOUT`, which override the default timeouts for compilation and execution.

## Optimization cycle reports

Run the optimization suite with:

```sh
make test FILTER=official:optimization
```

The runner prints REIMU's `Total cycles` for each input/output pair of every passing testcase with `"stage": "optimization"` in its manifest, followed by their total.

Each test session saves `optimization-cycles.json` in its log directory under `target/tests/run-.../`. The report records the testcase, input, I/O pair index, cycles, and path to the raw `run-N.profile` for each execution. Raw profiles also contain REIMU's instruction and libc operation counts. Failed testcases are excluded from cycle totals. Reports appear in both normal and `VERBOSE=true` output.

These are REIMU's simulated, weighted cycle counts, including libc costs. Use the same REIMU weights and cache/predictor settings when comparing compiler optimizations.

Custom `RUN` commands that omit `{profile}` continue to work without cycle reporting. When `{profile}` is present, optimization runs must produce a profile containing exactly one `Total cycles: N` line; a missing or invalid profile fails the case rather than reporting a misleading zero.
