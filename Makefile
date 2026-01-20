# CERES Makefile

.PHONY: help build run test clean install lint fmt docker-build docker-run setup-go

# Variables
BINARY_NAME=ceres
GO=go
GOFMT=gofmt
MAIN_PATH=./cmd/ceres
BIN_DIR=./bin

help: ## Show this help message
	@echo "CERES v3.0.0 - Build Commands"
	@echo "================================"
	@echo "🐳 Docker builds (no local Go required):"
	@echo "  make docker-build  - Build using Docker"
	@echo "  make docker-run    - Run in Docker"
	@echo ""
	@echo "🔧 Local builds (requires Go 1.21+):"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

docker-build: ## Build using Docker (no local Go required)
	@echo "🐳 Building with Docker..."
	@docker build -t ceres-builder:latest --target builder .
	@mkdir -p bin
	@docker create --name ceres-temp ceres-builder:latest
	@docker cp ceres-temp:/build/bin/. ./bin/
	@docker rm ceres-temp
	@echo "✅ Docker build complete! Binaries in ./bin/"

docker-run: ## Run CERES CLI in Docker
	@docker-compose run --rm ceres

setup-go: ## Auto-install Go on target system
	@bash scripts/setup-go.sh

build: ## Build CLI binary (requires Go 1.21+)
	@echo "🔨 Building CERES CLI..."
	@echo "💡 Tip: Use 'make docker-build' if Go is not installed"
	$(GO) build -o $(BIN_DIR)/$(BINARY_NAME) $(MAIN_PATH)
	@echo "✅ Binary created: $(BIN_DIR)/$(BINARY_NAME)"

build-all: ## Build for multiple platforms
	@echo "🔨 Building for multiple platforms..."
	GOOS=linux GOARCH=amd64 $(GO) build -o $(BIN_DIR)/$(BINARY_NAME)-linux-amd64 $(MAIN_PATH)
	GOOS=darwin GOARCH=amd64 $(GO) build -o $(BIN_DIR)/$(BINARY_NAME)-darwin-amd64 $(MAIN_PATH)
	GOOS=darwin GOARCH=arm64 $(GO) build -o $(BIN_DIR)/$(BINARY_NAME)-darwin-arm64 $(MAIN_PATH)
	GOOS=windows GOARCH=amd64 $(GO) build -o $(BIN_DIR)/$(BINARY_NAME)-windows-amd64.exe $(MAIN_PATH)
	@echo "✅ Cross-platform builds complete"

run: build ## Build and run CLI
	./$(BIN_DIR)/$(BINARY_NAME)

install: build ## Install CLI to system
	@echo "📦 Installing CERES CLI..."
	cp $(BIN_DIR)/$(BINARY_NAME) /usr/local/bin/
	@echo "✅ Installed to /usr/local/bin/$(BINARY_NAME)"

test: ## Run tests
	@echo "🧪 Running tests..."
	$(GO) test -v ./...

coverage: ## Generate coverage report
	@echo "📊 Generating coverage report..."
	$(GO) test -v -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "✅ Coverage report: coverage.html"

lint: ## Run linter
	@echo "🔍 Running linter..."
	golangci-lint run ./...

fmt: ## Format code
	@echo "✨ Formatting code..."
	$(GOFMT) -s -w .
	@echo "✅ Code formatted"

vet: ## Run go vet
	@echo "🔍 Running go vet..."
	$(GO) vet ./...

deps: ## Download dependencies
	@echo "📦 Downloading dependencies..."
	$(GO) mod download
	$(GO) mod tidy
	@echo "✅ Dependencies updated"

clean: ## Clean build artifacts
	@echo "🧹 Cleaning..."
	rm -rf $(BIN_DIR)
	$(GO) clean
	rm -f coverage.out coverage.html
	@echo "✅ Cleaned"

deploy-dev: ## Deploy to dev environment
	@echo "🚀 Deploying to dev..."
	./$(BIN_DIR)/$(BINARY_NAME) deploy --environment dev --cloud aws --dry-run

deploy-prod: ## Deploy to production
	@echo "🚀 Deploying to production..."
	./$(BIN_DIR)/$(BINARY_NAME) deploy --environment prod --cloud aws

status: ## Check deployment status
	@echo "📊 Checking status..."
	./$(BIN_DIR)/$(BINARY_NAME) status

validate: ## Validate infrastructure
	@echo "✅ Validating infrastructure..."
	./$(BIN_DIR)/$(BINARY_NAME) validate

.DEFAULT_GOAL := help
