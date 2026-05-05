SHELL := /bin/sh

BINARY := velvet
BIN_PATH := bin/$(BINARY)
INSTALL_DIR := /usr/local/bin
INSTALL_PATH := $(INSTALL_DIR)/$(BINARY)
WATCH_CMD := watchexec --debounce 1s --ignore lib/ --ignore .crystal/ -e cr,ecr,yml -- make install

.PHONY: help build install dev uninstall

help:
	@echo "make build              # shards build --release"
	@echo "make install            # build + install to /usr/local/bin"
	@echo "make dev                # watch and run install on changes"
	@echo "make uninstall          # remove /usr/local/bin/velvet"

build:
	shards build --release

install: build
	@install -d "$(INSTALL_DIR)"
	@install -m 0755 "$(BIN_PATH)" "$(INSTALL_PATH)"
	@echo "Installed $(INSTALL_PATH)"

dev:
	@command -v watchexec >/dev/null 2>&1 || { echo "watchexec is required for 'make dev'"; exit 1; }
	$(WATCH_CMD)

uninstall:
	@rm -f "$(INSTALL_PATH)"
