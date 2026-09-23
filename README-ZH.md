# Rx 编译器模板

[![Tests](https://github.com/ACMClassCourse-2025/rx-compiler/actions/workflows/test.yml/badge.svg)](https://github.com/ACMClassCourse-2025/rx-compiler/actions/workflows/test.yml)
[![Target: RV32IM](https://img.shields.io/badge/target-RV32IM-283272)](https://msyksphinz-self.github.io/riscv-isadoc/)
[![Simulator: REIMU](https://img.shields.io/badge/simulator-REIMU-d73a49)](https://github.com/wanoful/REIMU)
[English](README-EN.md) | [简体中文](README-ZH.md)

> 开始编写你的编译器时，请用你自己的 README 替换本文档。

## 快速上手

欢迎来到 Rx Compiler！本仓库提供了一个工程模板，供你基于此构建自己的 [Rx 编程语言](https://acmclasscourse-2025.github.io/rx-compiler-specification/) 编译器。它包含了官方测试用例、测试脚手架以及 Rx 语言的 G4 文法定义，帮助你快速起步。

我们强烈建议你 **Fork 本仓库**，以便我们在更新官方测试用例时你可以方便地同步更新。Fork 之后，将其克隆到你的本地。

初始化测试用例与 [REIMU](https://github.com/wanoful/REIMU) 子模块：

```sh
git submodule update --init --recursive
```

编译 REIMU 需要 Python 3、[xmake](https://xmake.io/) 以及支持 C++23 的编译器。在运行测试前，请在项目根目录下单独编译 REIMU：

```sh
xmake f -y -P vendor/REIMU -m release -o target/reimu
xmake -y -P vendor/REIMU
```

在更新 REIMU 子模块后需重复执行上述命令。

如果你想要运行默认的 `rustc` 测试，请先安装 `rustup`，然后运行
```sh
rustup target add riscv32im-unknown-none-elf
```

IR 测试还需要 **Clang 22**。

## 概述

在本门课程中，你可以使用**任意语言**来实现你的编译器。如果你的实现语言较为冷门，请联系助教以便我们在 Online Judge（评测机）上提供支持。因此，我们在此提供的模板是**与实现语言无关的（language-agnostic）**。仓库中包含：

- `tests/` 目录下的测试用例。官方测试用例位于 `tests/official`（作为 Git 子模块引入）。你可以在 `tests/custom` 下添加自己的测试用例。
- 测试运行器（Test runner）。`Makefile` 会调用在 `config.mk` 中配置的编译器来运行测试用例。默认情况下，它使用系统安装的 rustc（目标架构为 `riscv32im-unknown-none-elf`），并在 REIMU 中执行生成的汇编代码。**请将 `config.mk` 中的编译器命令替换为你自己的编译器命令**，以此为你的编译器配置测试。详见[运行测试](#运行测试)。
    - 一些辅助文件（如 `crates/rx` 中的参考编译器辅助代码）用于帮助默认的 rustc 输出适合 REIMU 的汇编文件。其中 `src/entry.rs` 针对每个测试用例单独编译，提供裸机程序入口点以及 `Box`/`Vec` 导入；库通过 REIMU 的 libc 实现了整数 I/O，并在 `src/runtime.rs` 中为裸机 RV32 目标提供内存分配与 panic 处理。默认的 IR 和 codegen 命令分别请求生成 LLVM IR 或汇编，同时生成静态库，以便 rustc 进行全程序 LTO（链接时优化）并将运行时包含在生成的程序中。额外的 `{output}.a` 属于构建产物。Codegen 通过 `scripts/strip_asm_debug.py` 去除 REIMU 无法汇编的调试元数据；IR 运行器先用 Clang 编译 `.ll`，再移除同类元数据。两种路径中的 `RUN` 都接收汇编形式的 `{output}`。当你将编译器命令替换为你自己的编译器时，这些辅助文件均可移除。
- `vendor/REIMU` 下的 REIMU，为 Git 子模块。`config.mk` 中的 `RUN` 命令会调用它；测试运行器本身并不依赖特定的模拟器。
- `grammar/` 目录下的 Rx 语言 G4 文法。你可以使用它来为编译器生成词法分析器和语法分析器。

## 配置 Makefile

Makefile 是调用你编译器的统一入口。你需要编辑 [`config.mk`](config.mk) 并接入你的编译器命令。具体来说，需要配置以下字段：

| 命令名称 | 用途 |
| --- | --- |
| `BUILD` | 构建编译器一次，可为空。必须以退出码 0 结束。可将公共运行时汇编写入 `{runtime}`。 |
| `SEMANTIC` | 对完整程序进行语义分析检查。接受（通过）时退出码为 0，拒绝（未通过）时退出码为 1。 |
| `IR` | 将 LLVM IR 写入 `{output}`（`.ll`）；运行器使用 Clang 将其编译为 RV32IM 汇编，再调用 `RUN`。 |
| `CODEGEN` | 编译代码生成（codegen）与优化（optimization）测试用例，并将生成的 RV32IM 汇编输出到 `{output}`，供默认的 `RUN` 命令调用。 |
| `RUN` | 将汇编 `{output}` 与构建时捕获的 `{runtime}` 一起运行。可选占位符 `{stdout}` 和 `{profile}` 分别用于指定单次执行的输出重定向文件和性能剖析文件。 |

例如，如果你的编译器支持 `--stage` 和 `-o` 选项并输出 RV32IM 汇编：

```make
BUILD = cargo build --release && cp runtime.s {runtime}
SEMANTIC = ./target/release/compiler --stage semantic {source}
IR = ./target/release/compiler --stage ir {source} -o {output}
CODEGEN = ./target/release/compiler --stage codegen {source} -o {output}
RUN = xmake run -P vendor/REIMU reimu -f {output},{runtime} -o {stdout} -p {profile} 1>&2
```

REIMU 从汇编代码中的全局 `main` 符号处开始执行，并提供其支持的 libc 函数。`-o {stdout}` 保存程序输出以供比对，`-p {profile}` 保存周期剖析数据（cycle profile），`1>&2` 将模拟器的状态消息重定向到标准错误日志中。在统计周期数时请勿添加 `--silent` 参数：REIMU 在静默模式下会抑制 profile 的生成。

将你所需的运行时汇编在 BUILD 阶段输出到 `{runtime}`。导出的函数须遵守 ILP32 调用约定，若运行时已内嵌在生成的程序中，可保留空文件。

IR 与 codegen 使用相同的测试点。IR 调用你的 `IR` 命令，由运行器调用 Clang，参数为 `-S -x ir --target=riscv32-unknown-none-elf -march=rv32im -mabi=ilp32 -O0 -mllvm -riscv-no-aliases`；Codegen 直接使用 `CODEGEN` 输出的汇编。

## 测试用例

测试用例位于 `tests/` 目录下，并按子目录组织。建议遵循 "命名空间:测试集:测试用例"（namespace:test-suite:testcase）的命名规范。例如，`official:semantic:arrays` 表示 `official` 命名空间下 `semantic` 测试集中的 `arrays` 测试用例。

每个测试用例可以包含一个或多个源文件、可选的输入和输出文件，以及一个必需的 `manifest.json` 清单文件（用于定义该测试用例的格式）。详情请参阅[官方 Schema](tests/official/manifest.schema.json)。清单中的 `stage` 参数决定了该测试用例的运行方式：`semantic` 调用 `SEMANTIC`，每个 `codegen` 条目会生成运行 `IR` → Clang → `RUN` 与 `CODEGEN` → `RUN`；`optimization` 调用 `CODEGEN` 后调用 `RUN`。

鼓励在 `tests/custom` 目录下添加你自己的测试用例，测试运行器会自动发现并加载它们。

各类测试用例的要求如下：

| 测试用例类型 | 判定要求 |
| --- | --- |
| Semantic | 编译器退出码必须为 0 或 1，且与 `compilation_success` 相符。其他退出码、异常信号或超时均视为用例失败。 |
| IR | 必须生成 LLVM `.ll`，由 Clang 成功编译；每组运行输出都必须与预期完全匹配。 |
| Codegen | 编译必须以退出码 0 结束并生成 `{output}`。每组 `io` 对都会执行该构建产物，且输出必须与预期文件完全匹配。 |
| Optimization | 判定要求同代码生成；当 `RUN` 提供 `{profile}` 占位符时，会额外报告周期数。 |

类型为 `lex` 和 `parse` 的测试用例将被跳过，因为我们已经提供了 G4 文法。如果你希望自行实现这些阶段，可以扩展 Makefile。

## 运行测试

在项目根目录下运行：

```sh
make test
make test FILTER=official:semantic
make test FILTER=official:codegen:arrays,official:optimization
make test STAGE=ir
make test STAGE=codegen FILTER=official:codegen:arrays
make test STAGE=ir CLANG=clang-22
make test FILTER=custom
make test FILTER=official:optimization COMPILE_TIMEOUT=60 RUN_TIMEOUT=30
make test VERBOSE=true
```

支持的环境变量包括：

- `FILTER`：用于筛选 `tests` 下的目录，文件夹名称之间使用 `:` 分隔，不同项之间使用 `,` 分隔。省略 `FILTER` 或留空则运行所有支持的测试。
- `STAGE`：可选，仅运行 `semantic`、`ir`、`codegen` 或 `optimization`。按目录筛选 codegen 用例时默认包含 IR 和 codegen 两项检查，可用 `STAGE` 限制。
- `CLANG`：编译 LLVM IR 使用的工具，默认 `clang-22`。
- `VERBOSE=true`：显示每个测试的名称及其耗时，而非分组进度。默认为 `false`。
- `COMPILE_TIMEOUT` 与 `RUN_TIMEOUT`：覆盖默认的编译与运行超时时限。

## CI/CD 支持

本仓库提供了 GitHub Actions 工作流，支持在每次提交或者 PR 时自动运行测试。你可以在 `.github/workflows/` 目录下查看或修改工作流配置。我们建议你在前期开发阶段禁用 CI/CD 流水线，并在编译器接近完成时再启用。

你可以将 `.github/workflows/test.yml` 重命名为 `.github/workflows/test.yml.disabled` 来禁用测试。GitHub Actions 仅会识别 `*.yml` 和 `*.yaml` 文件。
