SHELL := /bin/sh

BINARY := velvet
BIN_PATH := bin/$(BINARY)
PREFIX ?= /usr/local
INSTALL_DIR ?= $(PREFIX)/bin
INSTALL_PATH := $(INSTALL_DIR)/$(BINARY)
HASH_FILE := .build_hash
HASH_CMD = find src -type f \( -name '*.cr' -o -name '*.md' -o -name '*.yml' -o -name '*.ecr' \) | LC_ALL=C sort | xargs shasum -a 256 | shasum -a 256 | awk '{print $$1}'
DEV_WATCH_CMD := watchexec --debounce 1s --ignore lib/ --ignore .crystal/ -e cr,ecr,yml -- make install-if-changed

.PHONY: help deps build build-release build-if-changed install install-if-changed uninstall dev

help:
	@echo "Targets:"
	@echo "  make deps          # install shard dependencies"
	@echo "  make build         # debug build to bin/velvet"
	@echo "  make build-release # release build to bin/velvet"
	@echo "  make build-if-changed   # build only when source hash changes"
	@echo "  make install-if-changed # build-if-changed + copy to /usr/local/bin"
	@echo "  make dev           # watch files and rebuild on changes"
	@echo "  make install       # copy binary to /usr/local/bin/velvet"
	@echo "  make uninstall     # remove /usr/local/bin/velvet"

deps:
	shards install

build:
	shards build

build-release:
	shards build --release

build-if-changed:
	@HASH="$$($(HASH_CMD))"; \
	if [ "$$(cat $(HASH_FILE) 2>/dev/null)" = "$$HASH" ]; then \
		echo "No source changes; skipping build"; \
		exit 0; \
	fi; \
	shards build; \
	echo "$$HASH" > $(HASH_FILE); \
	echo "Build complete"

dev:
	@command -v watchexec >/dev/null 2>&1 || { echo "watchexec is required for 'make dev'"; exit 1; }
	$(DEV_WATCH_CMD)

install: build-release
	install -d "$(INSTALL_DIR)"
	install -m 0755 "$(BIN_PATH)" "$(INSTALL_PATH)"
	@echo "Installed $(INSTALL_PATH)"

install-if-changed: build-if-changed
	install -d "$(INSTALL_DIR)"
	install -m 0755 "$(BIN_PATH)" "$(INSTALL_PATH)"
	@echo "Installed $(INSTALL_PATH)"

uninstall:
	rm -f "$(INSTALL_PATH)"
	@echo "Removed $(INSTALL_PATH)"
