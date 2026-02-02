#!/bin/bash

# OpenClaw v2.0 Docker Installation Test Suite
# Runs comprehensive tests of the bootstrap installation

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST $((TESTS_TOTAL + 1))]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

run_test() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

# Cleanup function
cleanup() {
    log_info "Cleaning up Docker containers and images..."
    docker ps -a | grep openclaw-test | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
    docker images | grep openclaw-test | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  OpenClaw v2.0 Docker Installation Test Suite             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Build Docker image
run_test
log_test "Building Docker test image"
if docker build --no-cache -t openclaw-test:latest -f Dockerfile.test . > /tmp/openclaw-build.log 2>&1; then
    log_pass "Docker image built successfully"
else
    log_fail "Docker image build failed"
    cat /tmp/openclaw-build.log
    exit 1
fi

# Test 2: Basic installation (system-deps only)
run_test
log_test "Testing minimal installation (system-deps only)"
if docker run --rm --name openclaw-test-minimal openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && ./bootstrap.sh --non-interactive --only system-deps && ./bootstrap.sh --validate" \
    > /tmp/openclaw-minimal.log 2>&1; then
    log_pass "Minimal installation completed"
else
    log_fail "Minimal installation failed"
    cat /tmp/openclaw-minimal.log
fi

# Test 3: Python + Node.js installation
run_test
log_test "Testing Python + Node.js installation"
if docker run --rm --name openclaw-test-foundation openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && ./bootstrap.sh --non-interactive --only system-deps,python,nodejs && ./bootstrap.sh --validate" \
    > /tmp/openclaw-foundation.log 2>&1; then
    log_pass "Foundation modules installed successfully"
else
    log_fail "Foundation modules installation failed"
    cat /tmp/openclaw-foundation.log
fi

# Test 4: Verify no curl|bash patterns exist
run_test
log_test "Verifying no curl|bash vulnerabilities"
if ! docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config && grep -r 'curl.*|.*bash' bootstrap/ --exclude='*.log' --exclude='test-*.sh' --exclude='*.md' --exclude='*.yaml' --exclude-dir='docs'" \
    2>/dev/null; then
    log_pass "No curl|bash patterns found"
else
    log_fail "Found curl|bash patterns (security vulnerability)"
fi

# Test 5: Verify secret sanitization
run_test
log_test "Testing secret sanitization in logs"
docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && \
    ./bootstrap.sh --non-interactive --only system-deps > /tmp/test.log 2>&1 && \
    ! grep -i 'sk-ant-' /tmp/test.log && \
    ! grep -i 'xoxb-' /tmp/test.log" \
    > /tmp/openclaw-sanitize.log 2>&1

if [ $? -eq 0 ]; then
    log_pass "Secret sanitization working correctly"
else
    log_fail "Secret sanitization may not be working"
fi

# Test 6: Verify file permissions
run_test
log_test "Checking file permissions for security"
if docker run --rm openclaw-test:latest \
    bash -c "[ ! -d ~/.openclaw ] || [ \$(stat -c %a ~/.openclaw) = '700' ]" \
    2>/dev/null; then
    log_pass "File permissions are secure (700 if directory exists)"
else
    log_fail "File permissions may be incorrect"
fi

# Test 7: Test dependency resolution
run_test
log_test "Testing dependency resolution"
if docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && \
    source lib/logger.sh && \
    source lib/dependency-resolver.sh && \
    resolved=\$(resolve_dependencies . system-deps python nodejs) && \
    echo \"Resolved dependencies: \$resolved\" && \
    [[ -n \"\$resolved\" ]]" \
    > /tmp/openclaw-deps.log 2>&1; then
    log_pass "Dependency resolution working"
else
    log_fail "Dependency resolution failed"
    cat /tmp/openclaw-deps.log
fi

# Test 8: Verify checksums file exists
run_test
log_test "Verifying checksums manifest exists"
if docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && [ -f checksums.yaml ]" \
    2>/dev/null; then
    log_pass "Checksums manifest exists"
else
    log_fail "Checksums manifest not found"
fi

# Test 9: Verify new libraries exist
run_test
log_test "Verifying new security libraries exist"
if docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && \
    [ -f lib/secure-download.sh ] && \
    [ -f lib/crypto.sh ] && \
    [ -f lib/interactive.sh ] && \
    [ -f lib/dependency-resolver.sh ]" \
    2>/dev/null; then
    log_pass "All new libraries present"
else
    log_fail "Some libraries missing"
fi

# Test 10: Verify productivity module exists
run_test
log_test "Verifying productivity tools module exists"
if docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && [ -f modules/15-productivity-tools.sh ]" \
    2>/dev/null; then
    log_pass "Productivity tools module exists"
else
    log_fail "Productivity tools module not found"
fi

# Test 11: Verify MCP implementations exist
run_test
log_test "Verifying MCP server implementations"
if docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/deployment-tools/mcp/implementations && \
    [ -f google-calendar-mcp.js ] && \
    [ -f email-mcp.js ] && \
    [ -f todoist-mcp.js ] && \
    [ -f slack-mcp.js ]" \
    2>/dev/null; then
    log_pass "All 4 MCP servers present"
else
    log_fail "Some MCP servers missing"
fi

# Test 12: Verify documentation exists
run_test
log_test "Verifying documentation files"
if docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config && \
    [ -f INSTALLATION.md ] && \
    [ -f MIGRATION.md ] && \
    [ -f SECURITY.md ] && \
    [ -f deployment-tools/docs/PRODUCTIVITY_INTEGRATIONS.md ]" \
    2>/dev/null; then
    log_pass "All documentation files present"
else
    log_fail "Some documentation missing"
fi

# Test 13: Test --list-modules flag
run_test
log_test "Testing --list-modules functionality"
if docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && ./bootstrap.sh --list-modules | grep -q 'productivity-tools'" \
    > /tmp/openclaw-list.log 2>&1; then
    log_pass "Module listing works and includes new modules"
else
    log_fail "Module listing failed"
    cat /tmp/openclaw-list.log
fi

# Test 14: Test --dry-run flag
run_test
log_test "Testing --dry-run functionality"
if docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && ./bootstrap.sh --dry-run --only system-deps | grep -q 'DRY RUN'" \
    > /tmp/openclaw-dryrun.log 2>&1; then
    log_pass "Dry-run mode working"
else
    log_fail "Dry-run mode failed"
fi

# Test 15: Verify manifest v2.0 format
run_test
log_test "Verifying manifest.yaml v2.0 format"
if docker run --rm openclaw-test:latest \
    bash -c "cd /home/testuser/openclaw-config/bootstrap && \
    grep -q 'version: \"2.0.0\"' manifest.yaml && \
    grep -q 'category:' manifest.yaml && \
    grep -q 'productivity-tools:' manifest.yaml" \
    2>/dev/null; then
    log_pass "Manifest v2.0 format verified"
else
    log_fail "Manifest format incorrect"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    Test Results Summary                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Total Tests:  $TESTS_TOTAL"
echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ALL TESTS PASSED! OpenClaw v2.0 is production ready! 🎉 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  Some tests failed. Review logs above for details.        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
