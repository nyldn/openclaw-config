#!/usr/bin/env bash

# Quick verification script for bootstrap system
# Checks that all files are in place and executable

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  OpenClaw Bootstrap Verification                 ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

total=0
passed=0

check_file() {
    local file="$1"
    local required="${2:-yes}"

    total=$((total + 1))

    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        echo -e "${GREEN}✓${NC} $file"
        passed=$((passed + 1))
    else
        if [[ "$required" == "yes" ]]; then
            echo -e "${RED}✗${NC} $file (MISSING)"
        else
            echo -e "${YELLOW}!${NC} $file (optional, missing)"
            passed=$((passed + 1))
        fi
    fi
}

check_dir() {
    local dir="$1"

    total=$((total + 1))

    if [[ -d "$SCRIPT_DIR/$dir" ]]; then
        echo -e "${GREEN}✓${NC} $dir/"
        passed=$((passed + 1))
    else
        echo -e "${RED}✗${NC} $dir/ (MISSING)"
    fi
}

check_executable() {
    local file="$1"

    total=$((total + 1))

    if [[ -x "$SCRIPT_DIR/$file" ]]; then
        echo -e "${GREEN}✓${NC} $file (executable)"
        passed=$((passed + 1))
    else
        echo -e "${YELLOW}!${NC} $file (not executable)"
    fi
}

echo "Checking directory structure..."
check_dir "config"
check_dir "modules"
check_dir "lib"
check_dir "templates"

echo ""
echo "Checking core files..."
check_file "bootstrap.sh"
check_file "install.sh"
check_file "README.md"
check_file "manifest.yaml"

echo ""
echo "Checking configuration files..."
check_file "config/packages.yaml"
check_file "config/llm-tools.yaml"

echo ""
echo "Checking library files..."
check_file "lib/logger.sh"
check_file "lib/validation.sh"
check_file "lib/network.sh"

echo ""
echo "Checking module files..."
check_file "modules/01-system-deps.sh"
check_file "modules/02-python.sh"
check_file "modules/03-nodejs.sh"
check_file "modules/04-claude-cli.sh"
check_file "modules/05-codex-cli.sh"
check_file "modules/06-gemini-cli.sh"
check_file "modules/07-openclaw-env.sh"
check_file "modules/08-memory-init.sh"
check_file "modules/09-claude-octopus.sh"

echo ""
echo "Checking template files..."
check_file "templates/MEMORY.md.template"
check_file "templates/.env.template"
check_file "templates/daily-log.md.template"

echo ""
echo "Checking executability..."
check_executable "bootstrap.sh"
check_executable "install.sh"
check_executable "lib/logger.sh"
check_executable "lib/validation.sh"
check_executable "lib/network.sh"
check_executable "modules/01-system-deps.sh"
check_executable "modules/02-python.sh"
check_executable "modules/03-nodejs.sh"
check_executable "modules/04-claude-cli.sh"
check_executable "modules/05-codex-cli.sh"
check_executable "modules/06-gemini-cli.sh"
check_executable "modules/07-openclaw-env.sh"
check_executable "modules/08-memory-init.sh"
check_executable "modules/09-claude-octopus.sh"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "Results: ${GREEN}$passed${NC}/$total checks passed"

if [[ $passed -eq $total ]]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "Ready to run bootstrap:"
    echo "  ./bootstrap.sh --help"
    exit 0
else
    echo -e "${RED}✗ Some checks failed${NC}"
    exit 1
fi
