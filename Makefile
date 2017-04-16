NAME := enviar-email
VERSION := v1.0.0
LDFLAGS := -ldflags "-X main.Version=$(VERSION) -X main.AppName=$(NAME)"
BLDTAGS := -tags ""

help: ## Shows this help text
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

dev:
	go build

build: ## Generates a build for darwin and windows into build/ folder
	@rm -rf build/
	@gox $(BLDTAGS) $(LDFLAGS) \
	-osarch="darwin/amd64 darwin/386" \
	-osarch="windows/amd64 windows/386" \
	-output "build/{{.Dir}}_$(VERSION)_{{.OS}}_{{.Arch}}/$(NAME)" \
	./...

install: ## Installs binary in Go's binary folder
	go install $(DEVTAGS) $(LDFLAGS)

dist: build ## Generates distributable artifacts in dist/ folder
	$(eval FILES := $(shell ls build))
	@rm -rf dist && mkdir dist
	@for f in $(FILES); do \
		(cd $(shell pwd)/build/$$f && zip ../../dist/$$f.zip * ../../vendor/* ../../scripts/*); \
		(cd $(shell pwd)/dist && shasum -a 512 $$f.zip > $$f.sha512); \
		echo $$f; \
	done

release: dist ## Generates a release in Github and uploads artifacts.
	@latest_tag=$$(git describe --tags `git rev-list --tags --max-count=1`); \
	comparison="$$latest_tag..HEAD"; \
	if [ -z "$$latest_tag" ]; then comparison=""; fi; \
	changelog=$$(git log $$comparison --oneline --no-merges); \
	github-release c4milo/$(NAME) $(VERSION) "$$(git rev-parse --abbrev-ref HEAD)" "**Changelog**<br/>$$changelog" 'dist/*'; \
	git pull

.PHONY: help dev build install deps dist release

.DEFAULT_GOAL := help
