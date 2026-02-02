#!/bin/bash
#
# OpenClaw v2.0 Interactive Testing Script
# Launches a Docker container for hands-on installation testing
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  OpenClaw v2.0 Interactive Testing Environment           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${GREEN}✓${NC} Found repository at: $SCRIPT_DIR"

# Check if Dockerfile.interactive exists
if [ ! -f "Dockerfile.interactive" ]; then
    echo "❌ Dockerfile.interactive not found in $SCRIPT_DIR"
    exit 1
fi

echo ""
echo -e "${BLUE}Building Docker image...${NC}"
echo ""

# Build the Docker image
if docker build -f Dockerfile.interactive -t openclaw-interactive:latest . > /tmp/openclaw-interactive-build.log 2>&1; then
    echo -e "${GREEN}✓${NC} Docker image built successfully"
else
    echo "❌ Docker build failed. See /tmp/openclaw-interactive-build.log for details"
    cat /tmp/openclaw-interactive-build.log
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Starting Interactive Testing Container${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Inside the container, you can:${NC}"
echo ""
echo "  1. Test interactive installation:"
echo "     ${GREEN}./bootstrap.sh --interactive${NC}"
echo ""
echo "  2. Test specific modules:"
echo "     ${GREEN}./bootstrap.sh --only system-deps,python,nodejs${NC}"
echo ""
echo "  3. Preview installation:"
echo "     ${GREEN}./bootstrap.sh --dry-run${NC}"
echo ""
echo "  4. List all modules:"
echo "     ${GREEN}./bootstrap.sh --list-modules${NC}"
echo ""
echo "  5. Validate installation:"
echo "     ${GREEN}./bootstrap.sh --validate${NC}"
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "  • Type ${GREEN}exit${NC} to leave the container"
echo "  • Your changes won't affect your host system"
echo "  • Each run starts fresh (no state persists)"
echo ""
echo "Press Enter to start the container..."
read

# Run the interactive container
docker run -it --rm \
    --name openclaw-interactive-test \
    openclaw-interactive:latest

echo ""
echo -e "${GREEN}✓${NC} Interactive testing session complete"
echo ""
