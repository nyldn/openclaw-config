#!/usr/bin/env bash

# Setup script for testing infrastructure
# Makes all scripts executable and verifies structure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up OpenClaw bootstrap testing infrastructure..."
echo ""

# Make test runner executable
if [[ -f "$SCRIPT_DIR/tests/docker/test-runner.sh" ]]; then
    chmod +x "$SCRIPT_DIR/tests/docker/test-runner.sh"
    echo "✓ Docker test runner is executable"
else
    echo "✗ Docker test runner not found"
    exit 1
fi

# Make OpenClaw tools doc generator executable
if [[ -f "$SCRIPT_DIR/scripts/generate-openclaw-tools-doc.sh" ]]; then
    chmod +x "$SCRIPT_DIR/scripts/generate-openclaw-tools-doc.sh"
    echo "✓ OpenClaw tools doc generator is executable"
else
    echo "✗ OpenClaw tools doc generator not found"
    exit 1
fi

# Make auto-update script executable (if not already)
if [[ -f "$SCRIPT_DIR/scripts/auto-update.sh" ]]; then
    chmod +x "$SCRIPT_DIR/scripts/auto-update.sh"
    echo "✓ Auto-update script is executable"
fi

echo ""
echo "Testing infrastructure setup complete!"
echo ""
echo "Next steps:"
echo ""
echo "1. Run Docker tests:"
echo "   cd $SCRIPT_DIR/tests/docker"
echo "   ./test-runner.sh"
echo ""
echo "2. Generate OpenClaw documentation:"
echo "   $SCRIPT_DIR/scripts/generate-openclaw-tools-doc.sh"
echo ""
echo "3. Review documentation:"
echo "   cat ~/OPENCLAW_DOCUMENTATION.md"
echo ""
