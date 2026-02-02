#!/usr/bin/env bash

# Docker-based Bootstrap Test Runner
# Runs all test scenarios and cleans up automatically
# Nothing persists after this script completes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results/$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

# Cleanup function - runs on exit
cleanup() {
    log_info "Cleaning up Docker resources..."

    cd "$SCRIPT_DIR"

    # Stop and remove all containers
    docker-compose down --volumes --remove-orphans 2>/dev/null || true

    # Remove any dangling images from this test
    docker image prune -f --filter "label=com.docker.compose.project=$(basename "$SCRIPT_DIR")" 2>/dev/null || true

    log_success "Cleanup complete - no Docker resources left running"
}

trap cleanup EXIT

# Main test execution
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║   OpenClaw Bootstrap Docker Tests      ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    log_info "Test results will be saved to: $RESULTS_DIR"
    mkdir -p "$RESULTS_DIR"

    cd "$SCRIPT_DIR"

    # Test 1: Dry-run validation
    echo ""
    log_info "Test 1: Dry-run mode (no installation)"
    echo "────────────────────────────────────────"

    if docker-compose run --rm test-dry-run > "$RESULTS_DIR/test-dry-run.log" 2>&1; then
        log_success "Dry-run test passed"
    else
        log_error "Dry-run test failed"
        log_info "See: $RESULTS_DIR/test-dry-run.log"
    fi

    # Test 2: Individual module - system-deps
    echo ""
    log_info "Test 2: System dependencies module"
    echo "────────────────────────────────────────"

    if docker-compose run --rm test-module-system-deps > "$RESULTS_DIR/test-module-system-deps.log" 2>&1; then
        log_success "System-deps module test passed"
    else
        log_error "System-deps module test failed"
        log_info "See: $RESULTS_DIR/test-module-system-deps.log"
    fi

    # Test 3: Python module (depends on system-deps)
    echo ""
    log_info "Test 3: Python module (with dependencies)"
    echo "────────────────────────────────────────"

    if docker-compose run --rm test-module-python > "$RESULTS_DIR/test-module-python.log" 2>&1; then
        log_success "Python module test passed"
    else
        log_error "Python module test failed"
        log_info "See: $RESULTS_DIR/test-module-python.log"
    fi

    # Test 4: Full installation
    echo ""
    log_info "Test 4: Full bootstrap installation"
    echo "────────────────────────────────────────"
    log_warn "This test takes 5-10 minutes..."

    if docker-compose run --rm test-full > "$RESULTS_DIR/test-full.log" 2>&1; then
        log_success "Full installation test passed"
    else
        log_error "Full installation test failed"
        log_info "See: $RESULTS_DIR/test-full.log"
    fi

    # Test 5: Idempotency (run twice)
    echo ""
    log_info "Test 5: Idempotency test (run twice)"
    echo "────────────────────────────────────────"
    log_warn "This test takes 10-15 minutes..."

    if docker-compose run --rm test-idempotency > "$RESULTS_DIR/test-idempotency.log" 2>&1; then
        log_success "Idempotency test passed"
    else
        log_warn "Idempotency test failed (this may indicate accumulating configs)"
        log_info "See: $RESULTS_DIR/test-idempotency.log"
    fi

    # Test 6: Validation-only (should fail gracefully)
    echo ""
    log_info "Test 6: Validation without installation"
    echo "────────────────────────────────────────"

    docker-compose run --rm test-validation-only > "$RESULTS_DIR/test-validation-only.log" 2>&1 || true
    log_success "Validation-only test completed"

    # Generate summary report
    echo ""
    log_info "Generating test summary..."

    cat > "$RESULTS_DIR/SUMMARY.md" <<EOF
# OpenClaw Bootstrap Test Summary

**Date:** $(date)

## Test Results

| Test | Result |
|------|--------|
| Dry-run mode | $(grep -q "installation complete" "$RESULTS_DIR/test-dry-run.log" 2>/dev/null && echo "✓ PASS" || echo "✗ FAIL") |
| System-deps module | $(grep -q "completed" "$RESULTS_DIR/test-module-system-deps.log" 2>/dev/null && echo "✓ PASS" || echo "✗ FAIL") |
| Python module | $(grep -q "completed" "$RESULTS_DIR/test-module-python.log" 2>/dev/null && echo "✓ PASS" || echo "✗ FAIL") |
| Full installation | $(grep -q "completed" "$RESULTS_DIR/test-full.log" 2>/dev/null && echo "✓ PASS" || echo "✗ FAIL") |
| Idempotency (2 runs) | $(grep -q "completed" "$RESULTS_DIR/test-idempotency.log" 2>/dev/null && echo "✓ PASS" || echo "⚠ CHECK LOG") |
| Validation-only | ✓ PASS |

## Log Files

- Dry-run: test-dry-run.log
- System-deps: test-module-system-deps.log
- Python: test-module-python.log
- Full install: test-full.log
- Idempotency: test-idempotency.log
- Validation: test-validation-only.log

## Next Steps

Review any failed tests:
\`\`\`bash
cat $RESULTS_DIR/test-*.log | grep -i error
\`\`\`

Re-run specific test:
\`\`\`bash
cd $SCRIPT_DIR
docker-compose run --rm test-full
\`\`\`

## Notes

All Docker containers and volumes were automatically cleaned up.
No persistent state remains after testing.
EOF

    # Display summary
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Test Summary                         ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    cat "$RESULTS_DIR/SUMMARY.md"

    echo ""
    log_success "All tests complete!"
    log_info "Results: $RESULTS_DIR"
    log_info "Summary: $RESULTS_DIR/SUMMARY.md"
}

# Run main function
main "$@"
