#!/usr/bin/env python3
"""Run the manifest contract using the commands exported by the root Makefile."""

import argparse
from dataclasses import dataclass
import difflib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import textwrap
import time

from strip_asm_debug import strip_debug

RUNTIME_STAGES = ("ir", "codegen", "optimization")
STAGES = ("semantic", *RUNTIME_STAGES)
MANIFEST_STAGES = ("semantic", "codegen", "optimization")


class TestError(Exception):
    pass


@dataclass
class Case:
    directory: tuple[str, ...]
    source: Path
    stage: str
    success: bool
    io: list
    description: str = ""

    @property
    def label(self):
        directory = ":".join(self.directory)
        name = f"{directory}/{self.source.name}" if directory else self.source.name
        return f"{name}@{self.stage}"

    @property
    def optimization(self):
        return self.stage == "optimization"

    @property
    def compiler_command(self):
        return "codegen" if self.stage == "optimization" else self.stage


def display_path(path):
    return os.path.relpath(path)


class Reporter:
    """Small, dependency-free terminal reporter; redirected output stays plain."""

    STYLES = {"bold": "1", "dim": "2", "red": "31", "green": "32", "cyan": "36"}

    def __init__(self, verbose):
        self.verbose = verbose
        self.width = max(40, min(120, shutil.get_terminal_size((80, 24)).columns))
        self.total = 0
        self.completed = 0
        self.group = None
        self.line_length = 0

    def paint(self, text, style, stream=None):
        stream = sys.stdout if stream is None else stream
        enabled = (
            stream.isatty()
            and "NO_COLOR" not in os.environ and os.environ.get("TERM") != "dumb"
        )
        return f"\033[{self.STYLES[style]}m{text}\033[0m" if enabled else text

    def heading(self, title, style="bold", fill="="):
        print(self.paint(f" {title} ".center(self.width, fill), style), flush=True)

    def start(self, cases, selected_filter, directory):
        self.total = len(cases)
        self.heading("test session starts")
        stages = ", ".join(f"{sum(c.stage == stage for c in cases)} {stage}"
                           for stage in STAGES if any(c.stage == stage for c in cases))
        print(f"collected {self.paint(str(self.total), 'bold')} tests ({stages})")
        if selected_filter:
            print(f"filter: {selected_filter}")
        print(f"logs: {self.paint(display_path(directory), 'dim')}")
        if not self.verbose:
            print(self.paint(". passed  F failed", "dim"))
        print(flush=True)

    def finish_line(self):
        if self.line_length:
            progress = f"[{self.completed * 100 // self.total:3d}%]"
            padding = " " * max(1, self.width - self.line_length - len(progress))
            print(padding + self.paint(progress, "dim"), flush=True)
            self.line_length = 0

    def result(self, case, passed, elapsed):
        style = "green" if passed else "red"
        if self.verbose:
            status = self.paint("PASSED" if passed else "FAILED", style)
            duration = self.paint(f"({elapsed:.2f}s)", "dim")
            print(f"{status} {case.label} {duration}", flush=True)
            self.completed += 1
            return

        group = (":".join(case.directory) or ".") + f"@{case.stage}"
        if group != self.group:
            self.finish_line()
            self.group = group
        if not self.line_length:
            # Leave space for progress even with deeply nested custom suites.
            label = group if len(group) <= self.width - 16 else "..." + group[-(self.width - 19):]
            print(self.paint(label, "bold") + " ", end="", flush=True)
            self.line_length = len(label) + 1
        print(self.paint("." if passed else "F", style), end="", flush=True)
        self.completed += 1
        self.line_length += 1
        if self.line_length >= self.width - 8:
            self.finish_line()

    def finish(self, failures, executions, elapsed, cycles=(), cycle_file=None):
        self.finish_line()
        print()
        if failures:
            self.heading("failures", "red")
            for index, (case, message, work, duration) in enumerate(failures, 1):
                print()
                print(self.paint(f"{index}) {case.label}", "red"))
                print(self.paint(f"   {case.stage} / {duration:.2f}s", "dim"))
                if case.description:
                    print(textwrap.fill(case.description, width=self.width,
                                        initial_indent="   ", subsequent_indent="   "))
                print()
                for line in message.splitlines():
                    style = ("green" if line.startswith("+") else
                             "red" if line.startswith("-") else
                             "cyan" if line.startswith("@@") else None)
                    print("    " + (self.paint(line, style) if style else line))
                print(f"\n   logs: {self.paint(display_path(work), 'dim')}")
            print()
        if cycles:
            self.heading("optimization cycles (REIMU)")
            previous = None
            for row in cycles:
                if row["testcase"] != previous:
                    print(self.paint(row["testcase"], "bold"))
                    previous = row["testcase"]
                inp = Path(row["input"]).name if row["input"] else "empty stdin"
                print(f"  io {row['io']:>2}: {row['cycles']:>15,} cycles  {inp}")
            total = sum(row["cycles"] for row in cycles)
            print(f"Total: {total:,} cycles across {len(cycles)} input/output pairs")
            print(f"report: {self.paint(display_path(cycle_file), 'dim')}\n")
        if executions:
            noun = "check" if executions == 1 else "checks"
            print(f"{executions} runtime {noun} passed")
        passed = self.total - len(failures)
        summary = f"{len(failures)} failed, {passed} passed" if failures else f"{passed} passed"
        self.heading(f"{summary} in {elapsed:.2f}s", "red" if failures else "green")

    def error(self, message, label="ERROR"):
        self.finish_line()
        print(self.paint(label, "red", sys.stderr) + ": " +
              message.replace("\n", "\n    "), file=sys.stderr, flush=True)


def fixture(directory, value):
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        raise TestError(f"expected a nonempty relative file path, got {value!r}")
    path = (directory / value).resolve()
    if not path.is_file():
        raise TestError(f"file does not exist: {path}")
    return path


def discover(root):
    """Validate the v1 manifest fields; metadata never affects grading."""
    cases = []
    allowed = {"source", "stage", "compilation_success", "io", "description", "metadata"}
    for manifest in sorted(root.rglob("manifest.json")):
        try:
            entries = json.loads(manifest.read_text())
            if not isinstance(entries, list) or not entries:
                raise TestError("manifest must be a nonempty array")
            for index, entry in enumerate(entries, 1):
                # Stage, rather than folder name or depth, determines support.
                if isinstance(entry, dict) and entry.get("stage") in ("lex", "parse"):
                    continue
                if not isinstance(entry, dict) or entry.keys() - allowed:
                    raise TestError(f"entry {index}: invalid testcase fields")
                if not {"source", "stage", "compilation_success"} <= entry.keys():
                    raise TestError(f"entry {index}: missing required testcase fields")
                if entry["stage"] not in MANIFEST_STAGES or type(entry["compilation_success"]) is not bool:
                    raise TestError(f"entry {index}: invalid stage or compilation_success")
                if "description" in entry and not isinstance(entry["description"], str):
                    raise TestError(f"entry {index}: description must be a string")
                if "metadata" in entry and not isinstance(entry["metadata"], dict):
                    raise TestError(f"entry {index}: metadata must be an object")
                pairs = entry.get("io", [])
                if "io" in entry and (not isinstance(pairs, list) or not pairs):
                    raise TestError(f"entry {index}: io must be a nonempty array")
                if entry["stage"] in RUNTIME_STAGES and (not entry["compilation_success"] or not pairs):
                    raise TestError(f"entry {index}: {entry['stage']} requires compilation_success=true and io")
                io = []
                for pair in pairs:
                    if not isinstance(pair, dict) or pair.keys() != {"input", "output"}:
                        raise TestError(f"entry {index}: each io pair requires exactly input and output")
                    # Even unused io fields must follow the schema.
                    inp = None if pair["input"] is None else fixture(manifest.parent, pair["input"])
                    io.append((inp, fixture(manifest.parent, pair["output"])))
                source = fixture(manifest.parent, entry["source"])
                directory = manifest.parent.relative_to(root).parts
                cases.append(Case(directory, source, entry["stage"],
                                  entry["compilation_success"], io, entry.get("description", "")))
                if entry["stage"] == "codegen":
                    cases.append(Case(directory, source, "ir", True, io, entry.get("description", "")))
        except (TestError, ValueError, OSError) as error:
            raise TestError(f"{manifest}: {error}") from error
    if not cases:
        raise TestError(f"no semantic, codegen, or optimization testcases found under {root}")
    return [case for stage in STAGES for case in cases if case.stage == stage]


def select(cases, expression):
    if not expression:
        return cases
    selectors = set()
    available = {c.directory[:depth] for c in cases for depth in range(1, len(c.directory) + 1)}
    for item in expression.split(","):
        item = item.strip()
        parts = tuple(item.split(":"))
        if not all(parts):
            raise TestError("FILTER must be DIR[:DIR...](,DIR[:DIR...])*; empty items are invalid")
        if parts not in available:
            raise TestError(f"no supported testcases match FILTER item {item!r}; use directory names under tests joined with ':'")
        selectors.add(parts)
    return [c for c in cases if any(c.directory[:len(parts)] == parts for parts in selectors)]


def expand(command, source=None, output=None, **paths):
    values = {key: value for key, value in {"source": source, "output": output, **paths}.items()
              if value is not None}
    pattern = r"\{(" + "|".join(values) + r")\}"
    return re.sub(pattern, lambda match: shlex.quote(str(values[match[1]])), command)


def execute(command, prefix, timeout, stdin=None):
    """Keep full logs on disk and kill the entire process group on timeout."""
    prefix.with_suffix(".command").write_text(command + "\n")
    with prefix.with_suffix(".stdout").open("wb") as out, prefix.with_suffix(".stderr").open("wb") as err:
        with (stdin.open("rb") if stdin else open(os.devnull, "rb")) as inp:
            process = subprocess.Popen(command, shell=True, stdin=inp, stdout=out,
                                       stderr=err, start_new_session=True)
            try:
                return process.wait(timeout=timeout)
            except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                if isinstance(error, KeyboardInterrupt):
                    raise
                raise TestError(f"timed out after {timeout:g}s") from None


def excerpt(path):
    with path.open("rb") as stream:
        return stream.read(4000).decode(errors="replace").rstrip()


def read_cycles(profile):
    try:
        contents = profile.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        raise TestError(f"cannot read REIMU cycle profile {display_path(profile)}: {error}") from error
    matches = re.findall(r"^Total cycles:[ \t]*([0-9]+)[ \t]*$", contents, re.MULTILINE)
    if len(matches) != 1:
        raise TestError(f"expected one 'Total cycles: N' line in {display_path(profile)}; "
                        "check RUN profiling options (REIMU --silent disables profiling)")
    return int(matches[0])


def write_cycle_report(directory, cycles):
    if not cycles:
        return None
    path = directory / "optimization-cycles.json"
    path.write_text(json.dumps({
        "metric": "REIMU Total cycles",
        "total_cycles": sum(row["cycles"] for row in cycles),
        "runs": cycles,
    }, indent=2) + "\n")
    return path


def run_case(case, commands, directory, compile_timeout, run_timeout, runtime=b""):
    output = directory / ("program.ll" if case.stage == "ir" else "program.s")
    runtime_path = directory / "runtime.s"
    runtime_path.write_bytes(b"")
    prefix = directory / "compile"
    command = expand(commands[case.compiler_command], case.source, output, runtime=runtime_path)
    code = execute(command, prefix, compile_timeout)
    # Exit 1 is a normal diagnostic rejection. Panics, signals, missing tools,
    # and other unexpected exits must never pass a negative testcase.
    expected = 0 if case.success else 1
    if code != expected:
        raise TestError(f"compiler exited {code}, expected {expected}\n{excerpt(prefix.with_suffix('.stderr'))}")
    if case.stage not in RUNTIME_STAGES:
        return []
    if not output.is_file():
        raise TestError("compiler succeeded but did not create {output}")
    if case.stage == "ir":
        assembly = directory / "program.s"
        prefix = directory / "clang"
        command = shlex.join([
            os.environ.get("CLANG", "clang-22"), "-S", "-x", "ir", str(output),
            "-o", str(assembly), "--target=riscv32-unknown-none-elf",
            "-march=rv32im", "-mabi=ilp32", "-O0", "-mllvm", "-riscv-no-aliases",
        ])
        code = execute(command, prefix, compile_timeout)
        if code:
            raise TestError(f"Clang could not compile LLVM IR (exit {code})\n{excerpt(prefix.with_suffix('.stderr'))}")
        if not assembly.is_file():
            raise TestError("Clang succeeded but did not create assembly")
        assembly.write_text(strip_debug(assembly.read_text()))
        output = assembly
    cycles = []
    for index, (stdin, expected_file) in enumerate(case.io, 1):
        # Every execution gets the runtime captured after BUILD.
        runtime_path.unlink(missing_ok=True)
        runtime_path.write_bytes(runtime)
        prefix = directory / f"run-{index}"
        stdout = prefix.with_suffix(".stdout")
        profile = prefix.with_suffix(".profile")
        command = expand(commands["run"], case.source, output, stdout=stdout, profile=profile,
                         runtime=runtime_path)
        code = execute(command, prefix, run_timeout, stdin)
        if code != 0:
            raise TestError(f"io pair {index}: program exited {code}\n{excerpt(prefix.with_suffix('.stderr'))}")
        actual = prefix.with_suffix(".stdout").read_bytes()
        expected = expected_file.read_bytes()
        if actual != expected:
            lines = difflib.unified_diff(
                expected.decode(errors="replace").splitlines(keepends=True),
                actual.decode(errors="replace").splitlines(keepends=True),
                fromfile=display_path(expected_file), tofile="actual stdout")
            diff = "".join(line if line.endswith("\n") else
                           line + "\n\\ No newline at end of file\n" for line in lines)[:4000]
            raise TestError(f"io pair {index}: stdout differs (expected {len(expected)} bytes, got {len(actual)})\n{diff}")
        if case.optimization and "{profile}" in commands["run"]:
            cycles.append({
                "testcase": case.label,
                "io": index,
                "input": display_path(stdin) if stdin else None,
                "cycles": read_cycles(profile),
                "profile": display_path(profile),
            })
    return cycles


def positive_timeout(name, default):
    value = float(os.environ.get(name, default))
    if not 0 < value < float("inf"):
        raise TestError(f"{name} must be a positive finite number of seconds")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tests-dir", type=Path, default=Path("tests"))
    parser.add_argument("--output-dir", type=Path, default=Path("target/tests"))
    parser.add_argument("--stage", choices=STAGES, default=None)
    args = parser.parse_args()
    reporter = Reporter(os.environ.get("VERBOSE", "false").strip().lower() == "true")
    started = time.monotonic()
    try:
        selected_filter = os.environ.get("FILTER", "")
        cases = select(discover(args.tests_dir.resolve()), selected_filter)
        stage = args.stage or os.environ.get("STAGE", "").strip()
        if stage:
            if stage not in STAGES:
                raise TestError("STAGE must be semantic, ir, codegen, or optimization")
            cases = [case for case in cases if case.stage == stage]
            if not cases:
                raise TestError(f"no {stage} testcases match the selection")
        commands = {name: os.environ.get(f"RX_TEST_{name.upper()}", "")
                    for name in ("semantic", "ir", "codegen", "run")}
        for stage in {c.compiler_command for c in cases} | ({"run"} if any(c.stage in RUNTIME_STAGES for c in cases) else set()):
            if not commands[stage].strip():
                raise TestError(f"set {stage.upper()} in config.mk before running these tests")
        compile_timeout = positive_timeout("COMPILE_TIMEOUT", "30")
        run_timeout = positive_timeout("RUN_TIMEOUT", "10")
        args.output_dir.mkdir(parents=True, exist_ok=True)
        directory = Path(tempfile.mkdtemp(prefix="run-", dir=args.output_dir.resolve()))
        reporter.start(cases, selected_filter, directory)
        runtime = directory / "runtime.s"
        runtime.write_bytes(b"")
        build = os.environ.get("RX_TEST_BUILD", "").strip()
        if build:
            print("Building compiler ...", flush=True)
            build_started = time.monotonic()
            code = execute(expand(build, runtime=runtime), directory / "build", 300)
            if code:
                raise TestError(f"BUILD exited {code}\n{excerpt(directory / 'build.stderr')}")
            print(reporter.paint(f"Build finished in {time.monotonic() - build_started:.2f}s", "green"), flush=True)
            print()
        if runtime.is_symlink() or not runtime.is_file() or runtime.stat().st_size > 8 * 1024 * 1024:
            raise TestError("BUILD must leave {runtime} as a regular assembly file of at most 8 MiB")
        runtime_bytes = runtime.read_bytes()
        failures = []
        executions = 0
        cycles = []
        for index, case in enumerate(cases, 1):
            work = directory / f"{index:04d}"
            work.mkdir()
            case_started = time.monotonic()
            try:
                case_cycles = run_case(case, commands, work, compile_timeout, run_timeout, runtime_bytes)
                cycles.extend(case_cycles)
                executions += len(case.io) if case.stage in RUNTIME_STAGES else 0
            except (TestError, OSError) as error:
                elapsed = time.monotonic() - case_started
                failures.append((case, str(error), work, elapsed))
                reporter.result(case, False, elapsed)
            else:
                reporter.result(case, True, time.monotonic() - case_started)
        cycle_file = write_cycle_report(directory, cycles)
        reporter.finish(failures, executions, time.monotonic() - started, cycles, cycle_file)
        return 1 if failures else 0
    except (TestError, OSError, ValueError) as error:
        reporter.error(str(error))
        return 2
    except KeyboardInterrupt:
        reporter.error("test run interrupted", label="INTERRUPTED")
        return 130


if __name__ == "__main__":
    sys.exit(main())
