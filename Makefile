.DEFAULT_GOAL := test

include config.mk

PYTHON ?= python3
# Directory paths below tests, joined with ':'; separate selections with ','.
FILTER ?=
COMPILE_TIMEOUT ?= 30
RUN_TIMEOUT ?= 10

# Export commands as data, so shell quoting survives Make's recipe expansion.
export RX_TEST_BUILD = $(BUILD)
export RX_TEST_SEMANTIC = $(SEMANTIC)
export RX_TEST_CODEGEN = $(CODEGEN)
export RX_TEST_RUN = $(RUN)
export FILTER COMPILE_TIMEOUT RUN_TIMEOUT

.PHONY: test
test:
	@$(PYTHON) scripts/test.py
