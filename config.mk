# Fill in these four commands. See README.md for how to fill in this.

# Optional: build your compiler once before testing. Leave empty if prebuilt.
BUILD = cargo build --quiet --locked \
    --manifest-path crates/rx/Cargo.toml \
    --target-dir target/reference \
    --target i686-unknown-linux-gnu

# Required for semantic tests: exit 0 to accept {source}, 1 to reject it.
SEMANTIC = $(REFERENCE_RUSTC) --emit=metadata {source} -o {output}

# Required for codegen/optimization tests: compile {source} into {output}.
CODEGEN = $(REFERENCE_RUSTC) -C opt-level=2 {source} -o {output}

# Required alongside CODEGEN: run {output} on your local machine or via an emulator.
RUN = {output}

# Rust reference helper; remove once your commands no longer use it.
REFERENCE_RUSTC = rustc \
    --edition=2021 \
    --target=i686-unknown-linux-gnu \
    --crate-name=rx_test \
    -Awarnings -Aarithmetic_overflow \
    -C overflow-checks=off \
    --extern rx=target/reference/i686-unknown-linux-gnu/debug/librx.rlib \
    -L dependency=target/reference/i686-unknown-linux-gnu/debug/deps
