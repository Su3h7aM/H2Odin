ODIN ?= odin
ODINFMT ?= odinfmt

SRC_DIR := src
TEST_DIR := tests
BUILD_DIR := build
BIN := $(BUILD_DIR)/h2odin

ODIN_FLAGS := -vet -strict-style -vet-tabs -disallow-do -warnings-as-errors
COLLECTION_FLAGS := -collection:vendored=$(CURDIR)/vendored
ARGS ?=

# Keep the compiler and its stdlib paired.
#
# mise often exports ODIN_ROOT for a nightly while PATH still resolves `odin` to
# /usr/bin/odin. That mix fails in the Odin *runtime* sources with errors like
# "Invalid build tag platform: bedrock" / "Expected '}', got 'where'" — not
# project bugs. If the selected binary ships with a sibling base/, pin
# ODIN_ROOT there; otherwise drop a foreign ODIN_ROOT so packaged layouts
# (e.g. /usr/bin/odin + /usr/lib/odin) use their own stdlib.
ODIN_PATH := $(shell command -v $(ODIN) 2>/dev/null)
ifneq ($(ODIN_PATH),)
  ifneq ($(wildcard $(dir $(ODIN_PATH))base/.),)
    export ODIN_ROOT := $(abspath $(dir $(ODIN_PATH)))
  else
    unexport ODIN_ROOT
    # `unexport` alone does not strip a variable already present in the
    # environment from recipe processes; force a clean env for odin invocations.
    RUN_ODIN := env -u ODIN_ROOT $(ODIN)
  endif
endif
RUN_ODIN ?= $(ODIN)

.PHONY: all check build run test test-unit test-e2e format clean regen-libclang

all: check build

check:
	$(RUN_ODIN) check $(SRC_DIR) $(ODIN_FLAGS) $(COLLECTION_FLAGS)

build:
	mkdir -p $(BUILD_DIR)
	$(RUN_ODIN) build $(SRC_DIR) -out:$(BIN) $(ODIN_FLAGS) $(COLLECTION_FLAGS)

run: build
	./$(BIN) $(ARGS)

test: test-unit test-e2e

test-unit:
	$(RUN_ODIN) test $(SRC_DIR) $(ODIN_FLAGS) $(COLLECTION_FLAGS)

test-e2e: build
	@if find $(TEST_DIR) -maxdepth 1 -name "*.odin" 2>/dev/null | grep -q .; then \
		$(RUN_ODIN) test $(TEST_DIR) $(ODIN_FLAGS) $(COLLECTION_FLAGS); \
	else \
		echo "no e2e test package yet"; \
	fi

# Bootstrap: generation N is produced by a binary linked against generation N−1
# (the checked-in vendored/libclang package). Headers stay pinned under
# vendored/libclang/headers/; config is vendored/libclang/config.lua.
regen-libclang: build
	./$(BIN) -config:vendored/libclang/config.lua
	$(RUN_ODIN) check vendored/libclang -no-entry-point $(COLLECTION_FLAGS)

format:
	$(ODINFMT) $(SRC_DIR) -config:odinfmt.json -w
	@if find $(TEST_DIR) -maxdepth 1 -name "*.odin" 2>/dev/null | grep -q .; then \
		$(ODINFMT) $(TEST_DIR)/*.odin -config:odinfmt.json -w; \
	fi

clean:
	rm -rf $(BUILD_DIR)
