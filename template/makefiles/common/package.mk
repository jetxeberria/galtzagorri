# Makefile file to host common package management targets

PDM := pdm

.PHONY: common-target

# Targets to manage versioning
plan-release:
	@read -p "Enter the new version (e.g., 1.0.0): " new_version; \
	$(PDM) version $${new_version}

build-rc:
	@$(PDM) version --pre-release
	@$(PDM) build
	@echo "Release candidate built and version updated."

build-release:
	@$(PDM) version --finalize
	@$(PDM) build
	@echo "Release finalized and version updated."

reset-version:
	@$(PDM) version --reset
	@echo "Version planning reset."


# Target to clean up the environment
clean:
	@echo "Cleaning up..."
	rm -rf __pypackages__
	rm -rf __pycache__
	rm -rf .pdm-python