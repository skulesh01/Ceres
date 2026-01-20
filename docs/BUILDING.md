# 🔨 Building CERES CLI

## Prerequisites

- Go 1.21 or higher
- Make (optional, but recommended)

## Building from Source

### 1. Install Go Dependencies

```bash
go mod download
go mod tidy
```

### 2. Build CLI Binary

Using Make (recommended):
```bash
make build
```

Or directly with Go:
```bash
go build -o bin/ceres ./cmd/ceres
```

### 3. Run CLI

```bash
./bin/ceres --help
```

## Usage Examples

### Deploy to AWS
```bash
./bin/ceres deploy --cloud aws --environment prod
```

### Dry-run deployment
```bash
./bin/ceres deploy --cloud aws --dry-run
```

### Check deployment status
```bash
./bin/ceres status
```

### Validate infrastructure
```bash
./bin/ceres validate
```

### Show configuration
```bash
./bin/ceres config show
```

## Cross-Platform Build

Build for multiple platforms:

```bash
make build-all
```

This will create:
- `bin/ceres-linux-amd64`
- `bin/ceres-darwin-amd64` (macOS Intel)
- `bin/ceres-darwin-arm64` (macOS ARM/M1)
- `bin/ceres-windows-amd64.exe`

## Installation

### System-wide Installation

```bash
make install
```

This installs to `/usr/local/bin/ceres`

After installation, you can use:
```bash
ceres --help
```

## Development

### Run Tests
```bash
make test
```

### Generate Coverage Report
```bash
make coverage
```

### Format Code
```bash
make fmt
```

### Run Linter
```bash
make lint
```

### Check with Go Vet
```bash
make vet
```

## Troubleshooting

### Command "go: command not found"
- Install Go from https://golang.org/dl/
- Verify installation: `go version`

### "make: command not found"
- On Windows: Install from https://www.gnu.org/software/make/
- On macOS: `brew install make`
- On Linux: `sudo apt install make`

### Build errors
- Clear Go cache: `go clean -cache`
- Update dependencies: `go mod tidy`
- Try rebuild: `make clean && make build`

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build CERES CLI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      - run: make build
      - run: make test
```

## Docker Build

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /build
COPY . .
RUN go build -o ceres ./cmd/ceres

FROM alpine:latest
COPY --from=builder /build/ceres /usr/local/bin/
ENTRYPOINT ["ceres"]
```

Build:
```bash
docker build -t ceres:3.0.0 .
```

Run:
```bash
docker run ceres:3.0.0 --help
```
