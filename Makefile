.PHONY: build test clean help

IMAGE_NAME ?= squid
IMAGE_TAG ?= latest

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

test: ## Run the test suite
	./test.sh

clean: ## Clean up Docker containers and images
	docker stop squid-test-container 2>/dev/null || true
	docker rm squid-test-container 2>/dev/null || true
	docker rmi squid-test 2>/dev/null || true

all: build test ## Build and test
