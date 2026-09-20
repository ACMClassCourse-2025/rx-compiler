# Fill in these four commands. See README.md for how to fill in this.

# Optional: build your compiler once before testing. Leave empty if prebuilt.
BUILD = CARGO_PROFILE_RELEASE_LTO=true cargo build --quiet --locked --release \
    --manifest-path crates/rx/Cargo.toml \
    --target-dir target/reference \
    --target riscv32im-unknown-none-elf

# Required for semantic tests: exit 0 to accept {source}, 1 to reject it.
SEMANTIC = RX_SOURCE={source} $(REFERENCE_RUSTC) --cfg rx_semantic \
    --emit=metadata crates/rx/src/entry.rs -o {output}

# Required for codegen/optimization tests: compile {source} into {output}.
# To test LLVM IR, write RV32-compatible IR to {output}.ir and append:
#   && clang -S -x ir {output}.ir -o {output} --target=riscv32-unknown-none-elf -march=rv32im -mabi=ilp32 -mllvm -riscv-no-aliases
#   && $(PYTHON) scripts/strip_asm_debug.py {output}
CODEGEN = RUST_MIN_STACK=16777216 RX_SOURCE={source} $(REFERENCE_RUSTC) --crate-type=staticlib \
    --emit=asm={output},link={output}.a -C opt-level=2 -C lto=fat \
    -C llvm-args=-riscv-no-aliases crates/rx/src/entry.rs && \
    $(PYTHON) scripts/strip_asm_debug.py {output}

# Required alongside CODEGEN: run RV32IM assembly in REIMU.
# Keep program output separate from simulator messages and cycle profiles.
RUN = xmake run -P vendor/REIMU reimu --memory=256M --stack=1M \
    -f {output} -o {stdout} -p {profile} 1>&2

# Rust reference helper; remove once your commands no longer use it.
# v0 symbols avoid quoted section names that REIMU does not recognize.
REFERENCE_RUSTC = rustc \
    --edition=2021 \
    --target=riscv32im-unknown-none-elf \
    --crate-name=rx_test \
    -Awarnings -Aarithmetic_overflow \
    -C overflow-checks=off -C panic=abort -C symbol-mangling-version=v0 \
    --extern rx=target/reference/riscv32im-unknown-none-elf/release/librx.rlib \
    -L dependency=target/reference/riscv32im-unknown-none-elf/release/deps
