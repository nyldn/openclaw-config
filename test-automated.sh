#!/usr/bin/env bash
# Automated test script for OpenClaw bootstrap in Docker
# Runs installation with verbose output and saves logs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LOG_FILE="/tmp/openclaw-test-$(date +%Y%m%d-%H%M%S).log"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  OpenClaw Automated Test Runner                           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "This script will:"
echo "  1. Build the Docker image"
echo "  2. Run bootstrap installation with verbose logging"
echo "  3. Save logs to: $LOG_FILE"
echo ""

# Build Docker image
echo "Building Docker image..."
docker build -f Dockerfile.interactive -t openclaw-interactive:latest . 2>&1 | tee -a "$LOG_FILE"

echo ""
echo "Running automated installation (this may take 10-15 minutes)..."
echo ""

# Run installation in container with --non-interactive and minimal modules for testing
docker run --rm openclaw-interactive:latest bash -c \
    "export VERBOSE=true && \
     cd /home/testuser/openclaw-config/bootstrap && \
     echo '=== START BOOTSTRAP ===' && \
     echo 'Working directory:' \$(pwd) && \
     echo 'Directory structure:' && \
     find /home/testuser -name openclaw-config -type d 2>/dev/null || true && \
     echo '=== RUNNING BOOTSTRAP ===' && \
     ./bootstrap.sh --verbose --non-interactive --only system-deps,python 2>&1" | tee -a "$LOG_FILE"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Test Complete                                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Logs saved to: $LOG_FILE"
echo ""
echo "To review logs:"
echo "  cat $LOG_FILE"
echo ""
echo "To search for issues:"
echo "  grep -i 'error\|failed\|working directory' $LOG_FILE"
echo ""
