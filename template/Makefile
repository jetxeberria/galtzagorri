#!/bin/bash

# Include common and specific makefiles
include makefiles/common/environment.mk
include makefiles/common/package.mk
include makefiles/specific.mk

# Default target
.PHONY: help

help:
	@echo "Makefile"
	@echo "Available targets:"
	@echo "  help                   - Show this help message"
	@echo "  setup-system           - Install PDM and system-wide setup"
	@echo "  setup-repo             - Initialize and set up the repository environment"
	@echo "  create-new-repository  - Create a new repository using Copier template"
	@echo "  update-env             - Update the local environment with new dependencies"
	@echo "  clean                  - Remove virtual environment and cache"
	@echo "  update-pdm             - Update PDM to the latest version"
