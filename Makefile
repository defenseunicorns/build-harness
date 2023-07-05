include .env

.DEFAULT_GOAL := help

# Optionally add the "-it" flag for docker run commands if the env var "CI" is not set (meaning we are on a local machine and not in github actions)
TTY_ARG :=
ifndef CI
	TTY_ARG := -it
endif

# Silent mode by default. Run `make VERBOSE=1` to turn off silent mode.
ifndef VERBOSE
.SILENT:
endif

# Idiomatic way to force a target to always run, by having it depend on this dummy target
FORCE:

.PHONY: help
help: ## Show a list of all targets
	grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| sed -n 's/^\(.*\): \(.*\)##\(.*\)/\1:\3/p' \
	| column -t -s ":"

.PHONY: _create-folders
_create-folders:
	mkdir -p .cache/docker

.PHONY: docker-save-build-harness
docker-save-build-harness: _create-folders ## Pulls the build harness docker image and saves it to a tarball
	docker pull ${BUILD_HARNESS_REPO}:${BUILD_HARNESS_VERSION}
	docker save -o .cache/docker/build-harness.tar ${BUILD_HARNESS_REPO}:${BUILD_HARNESS_VERSION}

.PHONY: docker-load-build-harness
docker-load-build-harness: ## Loads the saved build harness docker image
	docker load -i .cache/docker/build-harness.tar

.PHONY: sbom
sbom: ## Generate an SBOM of the given image
	# Fail if the variable IMAGE_TO_SCAN is not set
	$(if $(IMAGE_TO_SCAN),,$(error IMAGE_TO_SCAN is not set))
	# Generate the SBOM. Use Docker for maximum portability
	docker run $(TTY_ARG) --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v "${PWD}:/app" \
		--workdir "/app" \
		${BUILD_HARNESS_REPO}:${BUILD_HARNESS_VERSION} \
		bash -c 'syft "${IMAGE_TO_SCAN}" -o json=sbom.syft.json -o cyclonedx-json=sbom.cyclonedx.json -o spdx-json=sbom.spdx.json -o syft-table=sbom.table.txt'

.PHONY: vuln-report
vuln-report: ## Generate the vuln report from the sbom.syft.json file
	# Fail if the file sbom.syft.json does not exist
	$(if $(wildcard sbom.syft.json),,$(error sbom.syft.json does not exist))
	# Generate the vuln report. Use Docker for maximum portability
	docker run $(TTY_ARG) --rm \
		-v "${PWD}:/app" \
		--workdir "/app" \
		${BUILD_HARNESS_REPO}:${BUILD_HARNESS_VERSION} \
		bash -c 'cat ./sbom.syft.json | grype --add-cpes-if-none -o json --file vulns.grype.json \
				&& cat ./sbom.syft.json | grype --add-cpes-if-none -o table --file vulns.grype.txt'
