ODIN ?= odin
ODINFMT ?= odinfmt

SRC_DIR := src
TEST_DIR := tests
BUILD_DIR := build
BIN := $(BUILD_DIR)/h2odin

ODIN_FLAGS := -vet -strict-style -vet-tabs -disallow-do -warnings-as-errors
COLLECTION_FLAGS := -collection:vendored=$(CURDIR)/vendored
ARGS ?=

.PHONY: all check build run test test-unit test-e2e format clean

all: check build

check:
	$(ODIN) check $(SRC_DIR) $(ODIN_FLAGS) $(COLLECTION_FLAGS)

build:
	mkdir -p $(BUILD_DIR)
	$(ODIN) build $(SRC_DIR) -out:$(BIN) $(ODIN_FLAGS) $(COLLECTION_FLAGS)

run: build
	./$(BIN) $(ARGS)

test: test-unit test-e2e

test-unit:
	$(ODIN) test $(SRC_DIR) $(ODIN_FLAGS) $(COLLECTION_FLAGS)

test-e2e: build
	@if find $(TEST_DIR) -maxdepth 1 -name "*.odin" 2>/dev/null | grep -q .; then \
		$(ODIN) test $(TEST_DIR) $(ODIN_FLAGS) $(COLLECTION_FLAGS); \
	else \
		echo "no e2e test package yet"; \
	fi

format:
	$(ODINFMT) $(SRC_DIR) -config:odinfmt.json -w
	@if find $(TEST_DIR) -maxdepth 1 -name "*.odin" 2>/dev/null | grep -q .; then \
		$(ODINFMT) $(TEST_DIR)/*.odin -config:odinfmt.json -w; \
	fi

clean:
	rm -rf $(BUILD_DIR)
