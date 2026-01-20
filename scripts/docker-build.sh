#!/bin/bash
# Build CERES CLI using Docker (no local Go required)

set -e

echo "🐳 Building CERES CLI using Docker..."
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed!"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

# Build the Docker image
echo "📦 Building Docker image..."
docker build -t ceres-builder:latest --target builder .

echo ""
echo "🏗️  Extracting binaries..."

# Create bin directory if it doesn't exist
mkdir -p bin

# Run container and copy binaries
CONTAINER_ID=$(docker create ceres-builder:latest)
docker cp "$CONTAINER_ID:/build/bin/." ./bin/
docker rm "$CONTAINER_ID"

echo ""
echo "✅ Build complete!"
echo ""
echo "Available binaries:"
ls -lh bin/

echo ""
echo "🚀 Usage:"
echo "  Linux:   ./bin/ceres-linux-amd64 --help"
echo "  macOS:   ./bin/ceres-darwin-amd64 --help"
echo "  Windows: ./bin/ceres-windows-amd64.exe --help"
