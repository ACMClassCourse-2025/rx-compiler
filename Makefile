.DEFAULT_GOAL := test

include config.mk

PYTHON ?= python3
VERBOSE ?= false
# Directory paths below tests, joined with ':'; separate selections with ','.
FILTER ?=
# Optional single stage: semantic, ir, codegen, or optimization.
STAGE ?=
CLANG ?= clang-22
COMPILE_TIMEOUT ?= 30
RUN_TIMEOUT ?= 10

# Export commands as data, so shell quoting survives Make's recipe expansion.
export RX_TEST_BUILD = $(BUILD)
export RX_TEST_SEMANTIC = $(SEMANTIC)
export RX_TEST_IR = $(IR)
export RX_TEST_CODEGEN = $(CODEGEN)
export RX_TEST_RUN = $(RUN)
export FILTER STAGE CLANG COMPILE_TIMEOUT RUN_TIMEOUT VERBOSE

.PHONY: test
test:
	@$(PYTHON) scripts/test.py
