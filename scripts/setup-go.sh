#!/bin/bash
# Auto-install Go if not present on target system

set -e

GO_VERSION="1.21.6"
GO_OS="linux"
GO_ARCH="amd64"

echo "🔍 Checking for Go installation..."

if command -v go &> /dev/null; then
    CURRENT_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
    echo "✅ Go $CURRENT_VERSION is already installed"
    
    # Check if version is sufficient (1.21+)
    REQUIRED_VERSION="1.21"
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
        echo "✅ Go version is sufficient"
        exit 0
    else
        echo "⚠️  Go version is too old (required: $REQUIRED_VERSION+, current: $CURRENT_VERSION)"
        echo "📥 Updating Go..."
    fi
else
    echo "❌ Go is not installed"
    echo "📥 Installing Go $GO_VERSION..."
fi

# Detect OS and architecture
if [[ "$OSTYPE" == "darwin"* ]]; then
    GO_OS="darwin"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    GO_OS="linux"
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

if [[ $(uname -m) == "arm64" ]] || [[ $(uname -m) == "aarch64" ]]; then
    GO_ARCH="arm64"
else
    GO_ARCH="amd64"
fi

# Download and install Go
GO_TARBALL="go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz"
GO_URL="https://go.dev/dl/${GO_TARBALL}"

echo "📥 Downloading Go from $GO_URL..."
curl -LO "$GO_URL"

echo "📦 Extracting Go..."
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "$GO_TARBALL"
rm "$GO_TARBALL"

# Add Go to PATH if not already there
if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
    echo "📝 Adding Go to PATH in ~/.bashrc"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
fi

if ! grep -q "/usr/local/go/bin" ~/.profile; then
    echo "📝 Adding Go to PATH in ~/.profile"
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
fi

# Add to current session
export PATH=$PATH:/usr/local/go/bin

echo "✅ Go $GO_VERSION installed successfully!"
go version

echo ""
echo "🔧 Installing Go dependencies..."
cd "$(dirname "$0")/.."
go mod download
echo "✅ Dependencies installed!"

echo ""
echo "🏗️  Building CERES CLI..."
go build -o bin/ceres ./cmd/ceres
echo "✅ CERES CLI built successfully!"
echo ""
echo "Run: ./bin/ceres --help"
