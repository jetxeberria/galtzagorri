# Makefile file to host common environment targets

PDM := pdm

.PHONY: common-target

# Target to set up the system (run only once on the system)
setup-system:
	@echo "System setup is complete."

# Target to set up the repository environment (run each time repo is cloned)
setup-repo: create-env
	@echo "Repository environment is set up."

create-env:
	@echo "Creating and activating the PDM environment..."
	$(PDM) install

# Target to update the repository environment with remote changes (run each time after pulling changes)
update-repo: verify-env update-template update-env
	@echo "Repository environment is updated."

update-template:
	@echo "Updating the Copier template..."

	
update-env:
	@echo "Updating the local environment with new dependencies..."
	$(PDM) sync

verify-env:
	@echo "Verifying the local environment is activated"
	@if [ "$$(which python)" != "$$(pdm info --python)" ]; then \
		echo "Error: Local PDM environment is not activated!"; \
		exit 1; \
	fi

# Targets to update the local environment
add-package:
	@package_name=$${package_name}; \
	if [ -z "$$package_name" ]; then \
		if [ -z "$1"]; then \

		read -p "Enter package name to add: " package_name; \
		else \
			package_name=$1; \
			fi; \
	fi; \
	$(PDM) add $$package_name
	@echo "Package $$package_name added."

remove-package:
	@read -p "Enter package name to remove: " package_name; \
	$(PDM) remove $$package_name
	@echo "Package $$package_name removed."

update-package:
	@read -p "Enter package name to update: " package_name; \
	$(PDM) update $$package_name
	@echo "Package $$package_name updated."
