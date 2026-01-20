# Multi-stage build for CERES CLI without local Go installation
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum* ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags="-w -s" -o /build/bin/ceres ./cmd/ceres

# Build for multiple platforms
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags="-w -s" -o /build/bin/ceres-linux-amd64 ./cmd/ceres
RUN CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -a -installsuffix cgo -ldflags="-w -s" -o /build/bin/ceres-darwin-amd64 ./cmd/ceres
RUN CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -a -installsuffix cgo -ldflags="-w -s" -o /build/bin/ceres-windows-amd64.exe ./cmd/ceres

# Runtime stage - minimal image
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates kubectl terraform

# Create non-root user
RUN addgroup -g 1000 ceres && \
    adduser -D -u 1000 -G ceres ceres

WORKDIR /app

# Copy binaries from builder
COPY --from=builder /build/bin/ceres /usr/local/bin/ceres
COPY --from=builder /build/bin/* /app/binaries/

# Copy configuration examples
COPY examples/ /app/examples/
COPY infrastructure/ /app/infrastructure/
COPY deployment/ /app/deployment/

# Set permissions
RUN chown -R ceres:ceres /app && \
    chmod +x /usr/local/bin/ceres

# Switch to non-root user
USER ceres

# Set default command
ENTRYPOINT ["/usr/local/bin/ceres"]
CMD ["--help"]
