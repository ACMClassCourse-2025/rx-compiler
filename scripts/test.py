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
import signal
import subprocess
import sys
import tempfile


STAGES = ("semantic", "codegen")


class TestError(Exception):
    pass


@dataclass
class Case:
    directory: tuple[str, ...]
    source: Path
    stage: str
    success: bool
    io: list

    @property
    def label(self):
        directory = ":".join(self.directory)
        return f"{directory}/{self.source.name}" if directory else self.source.name


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
                if entry["stage"] not in STAGES or type(entry["compilation_success"]) is not bool:
                    raise TestError(f"entry {index}: invalid stage or compilation_success")
                if "description" in entry and not isinstance(entry["description"], str):
                    raise TestError(f"entry {index}: description must be a string")
                if "metadata" in entry and not isinstance(entry["metadata"], dict):
                    raise TestError(f"entry {index}: metadata must be an object")
                pairs = entry.get("io", [])
                if "io" in entry and (not isinstance(pairs, list) or not pairs):
                    raise TestError(f"entry {index}: io must be a nonempty array")
                if entry["stage"] == "codegen" and (not entry["compilation_success"] or not pairs):
                    raise TestError(f"entry {index}: codegen requires compilation_success=true and io")
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
                                  entry["compilation_success"], io))
        except (TestError, ValueError, OSError) as error:
            raise TestError(f"{manifest}: {error}") from error
    if not cases:
        raise TestError(f"no semantic or codegen testcases found under {root}")
    return cases


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


def expand(command, source, output):
    values = {"source": source, "output": output}
    return re.sub(r"\{(source|output)\}", lambda match: shlex.quote(str(values[match[1]])), command)


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


def run_case(case, commands, directory, compile_timeout, run_timeout):
    output = directory / "program"
    prefix = directory / "compile"
    command = expand(commands[case.stage], case.source, output)
    code = execute(command, prefix, compile_timeout)
    # Exit 1 is a normal diagnostic rejection. Panics, signals, missing tools,
    # and other unexpected exits must never pass a negative testcase.
    expected = 0 if case.success else 1
    if code != expected:
        raise TestError(f"compiler exited {code}, expected {expected}\n{excerpt(prefix.with_suffix('.stderr'))}")
    if case.stage != "codegen":
        return
    if not output.is_file():
        raise TestError("compiler succeeded but did not create {output}")
    for index, (stdin, expected_file) in enumerate(case.io, 1):
        prefix = directory / f"run-{index}"
        code = execute(expand(commands["run"], case.source, output), prefix, run_timeout, stdin)
        if code != 0:
            raise TestError(f"io pair {index}: program exited {code}\n{excerpt(prefix.with_suffix('.stderr'))}")
        actual = prefix.with_suffix(".stdout").read_bytes()
        expected = expected_file.read_bytes()
        if actual != expected:
            diff = "".join(difflib.unified_diff(
                expected.decode(errors="replace").splitlines(keepends=True),
                actual.decode(errors="replace").splitlines(keepends=True),
                fromfile=str(expected_file), tofile="actual stdout"))[:4000]
            raise TestError(f"io pair {index}: stdout differs (expected {len(expected)} bytes, got {len(actual)})\n{diff}")


def positive_timeout(name, default):
    value = float(os.environ.get(name, default))
    if not 0 < value < float("inf"):
        raise TestError(f"{name} must be a positive finite number of seconds")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tests-dir", type=Path, default=Path("tests"))
    parser.add_argument("--output-dir", type=Path, default=Path("target/tests"))
    args = parser.parse_args()
    try:
        cases = select(discover(args.tests_dir.resolve()), os.environ.get("FILTER", ""))
        commands = {stage: os.environ.get(f"RX_TEST_{stage.upper()}", "") for stage in (*STAGES, "run")}
        for stage in {c.stage for c in cases} | ({"run"} if any(c.stage == "codegen" for c in cases) else set()):
            if not commands[stage].strip():
                raise TestError(f"set {stage.upper()} in config.mk before running these tests")
        compile_timeout = positive_timeout("COMPILE_TIMEOUT", "30")
        run_timeout = positive_timeout("RUN_TIMEOUT", "10")
        args.output_dir.mkdir(parents=True, exist_ok=True)
        directory = Path(tempfile.mkdtemp(prefix="run-", dir=args.output_dir.resolve()))
        print(f"Running {len(cases)} testcases. Logs: {directory}", flush=True)
        build = os.environ.get("RX_TEST_BUILD", "").strip()
        if build:
            code = execute(build, directory / "build", 300)
            if code:
                raise TestError(f"BUILD exited {code}\n{excerpt(directory / 'build.stderr')}")
        failures = 0
        executions = 0
        for index, case in enumerate(cases, 1):
            work = directory / f"{index:04d}"
            work.mkdir()
            try:
                run_case(case, commands, work, compile_timeout, run_timeout)
                executions += len(case.io) if case.stage == "codegen" else 0
                print(f"PASS {case.label}", flush=True)
            except (TestError, OSError) as error:
                failures += 1
                print(f"FAIL {case.label}: {error}\n  Logs: {work}", flush=True)
        print(f"\n{len(cases) - failures} passed; {failures} failed; {executions} runtime checks passed.")
        return 1 if failures else 0
    except (TestError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
