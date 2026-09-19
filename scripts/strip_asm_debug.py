#!/usr/bin/env python3
"""Remove rustc's non-executable DWARF sections before REIMU assembles them.

LTO can import debug information from Rust's prebuilt core/alloc libraries even
when this crate disables debuginfo. REIMU does not support DWARF data directives.
"""

from pathlib import Path
import re
import sys


def strip_debug(assembly):
    result = []
    debug_section = False
    for line in assembly.splitlines(keepends=True):
        section = re.match(r'\s*\.section\s+"?([^",\s]+)', line)
        if section:
            debug_section = section[1].startswith(".debug_")
        elif re.match(r"\s*\.(text|data|sdata|rodata|bss|sbss)\b", line):
            debug_section = False
        if not debug_section:
            result.append(line)
    return "".join(result)


if __name__ == "__main__":
    path = Path(sys.argv[1])
    path.write_text(strip_debug(path.read_text()))
