# Docker End-to-End Test Instructions

## Issues Fixed

Before testing, I fixed these issues found during code review:

1. **bootstrap.sh** - Updated manifest URL from:
   - ❌ `https://raw.githubusercontent.com/user/openclawd-config/main/...`
   - ✅ `https://raw.githubusercontent.com/nyldn/openclaw-config/main/...`

2. **auto-update.sh** - Renamed function from `update_openclawd_config()` to `update_openclaw_config()`

## Prerequisites

1. **Docker** must be installed and running
   - macOS: Docker Desktop
   - Linux: Docker Engine
   - Verify: `docker --version`

2. **docker-compose** must be available
   - Check: `docker-compose --version` or `docker compose version`

## Quick Test (Recommended First)

Run a fast validation test (~2 minutes):

```bash
# Navigate to test directory
cd /Users/chris/git/openclaw-config/bootstrap/tests/docker

# Make scripts executable
chmod +x ../../setup-testing.sh
chmod +x test-runner.sh
chmod +x ../../scripts/generate-openclaw-tools-doc.sh

# Build Docker image
docker-compose build test-dry-run

# Run dry-run test (fastest test)
docker-compose run --rm test-dry-run

# If successful, you'll see:
# - Bootstrap system initializes
# - Modules are discovered
# - Actions are previewed (not executed)
# - No errors

# Cleanup
docker-compose down --volumes --remove-orphans
```

## Full Test Suite

Run all 6 test scenarios (~10-15 minutes):

```bash
cd /Users/chris/git/openclaw-config/bootstrap/tests/docker

# Run full test suite
./test-runner.sh

# This will test:
# 1. Dry-run mode
# 2. System dependencies module
# 3. Python module
# 4. Full installation
# 5. Idempotency (run twice)
# 6. Validation-only

# Results saved to: tests/docker/results/YYYYMMDD-HHMMSS/
```

## Alternative: Use Test Wrapper

I created a standalone test wrapper that handles everything:

```bash
# Run the comprehensive test
chmod +x /tmp/run-docker-test-now.sh
/tmp/run-docker-test-now.sh

# This script:
# - Verifies Docker is running
# - Makes scripts executable
# - Builds Docker image
# - Runs dry-run test
# - Cleans up automatically
```

## Individual Test Scenarios

Run specific tests without the full suite:

### 1. Dry-Run Test (30 seconds)
```bash
cd /Users/chris/git/openclaw-config/bootstrap/tests/docker
docker-compose run --rm test-dry-run
```
**Tests:** Command-line parsing, module discovery, dry-run flag

### 2. System Dependencies (2-3 minutes)
```bash
docker-compose run --rm test-module-system-deps
```
**Tests:** APT package installation, sudo permissions, base dependencies

### 3. Python Module (3-4 minutes)
```bash
docker-compose run --rm test-module-python
```
**Tests:** Python venv creation, pip installation, dependency chain

### 4. Full Installation (5-10 minutes)
```bash
docker-compose run --rm test-full
```
**Tests:** All 14 modules, complete bootstrap flow, validation

### 5. Idempotency Test (10-15 minutes)
```bash
docker-compose run --rm test-idempotency
```
**Tests:** Running bootstrap twice, no duplicate configs, safe re-runs

### 6. Validation-Only
```bash
docker-compose run --rm test-validation-only
```
**Tests:** --validate flag works correctly

## Expected Results

### Success Indicators

**Dry-run test should show:**
```
[INFO] OpenClaw Bootstrap System v1.0.0
[INFO] Dry-run mode enabled
[INFO] Modules to install: 14
[✓] Module discovery complete
[✓] All prerequisite checks passed
```

**Module tests should show:**
```
[✓] System dependencies installed
[✓] Python virtual environment created
[✓] Validation passed
```

**Full installation should show:**
```
[✓] Bootstrap completed successfully
[✓] 14 modules installed
[✓] Validation passed
```

### Failure Indicators

**If you see:**
- `ERROR: Command not found` - Missing prerequisite in Dockerfile
- `Permission denied` - sudo configuration issue
- `Network unreachable` - DNS or network issue
- `Module dependency not met` - Module ordering problem

## Troubleshooting

### Docker image build fails

**Check:**
```bash
# Build with verbose output
docker-compose build --no-cache test-dry-run

# Check Docker daemon
docker info

# Check disk space
df -h
```

### Test hangs or times out

**Reasons:**
- Network downloading packages (normal for first run)
- apt-get update slow (use --verbose to see progress)
- Python/Node.js installation downloading

**To monitor:**
```bash
# In another terminal, watch container logs
docker-compose logs -f test-full
```

### Container exits with error

**Check logs:**
```bash
# View test output
cat tests/docker/results/YYYYMMDD-HHMMSS/test-*.log

# Check last 50 lines
docker-compose run --rm test-dry-run 2>&1 | tail -n 50
```

### Permission issues

**If you see "Permission denied":**
```bash
# Verify testuser has sudo
docker-compose run --rm test-dry-run bash -c "sudo whoami"
# Should output: root

# Check sudoers file
docker-compose run --rm test-dry-run bash -c "sudo cat /etc/sudoers | grep testuser"
# Should show: testuser ALL=(ALL) NOPASSWD:ALL
```

## Cleanup

After testing, ensure no containers are left running:

```bash
# From test directory
docker-compose down --volumes --remove-orphans

# Remove all test images
docker images | grep openclaw | awk '{print $3}' | xargs docker rmi -f

# Full Docker cleanup (optional)
docker system prune -af --volumes
```

## Test Results Interpretation

### PASS Criteria

All tests should:
- ✅ Exit with code 0
- ✅ Complete without errors
- ✅ Pass validation checks
- ✅ Create expected files/directories

### FAIL Analysis

If tests fail:

1. **Check test logs** in `results/` directory
2. **Review error messages** for specific module failures
3. **Verify Docker setup** is correct
4. **Check network connectivity** for package downloads
5. **Review module dependencies** in correct order

## Next Steps After Successful Test

1. **Commit changes:**
   ```bash
   cd /Users/chris/git/openclaw-config
   git add -A
   git commit -m "Add Docker testing infrastructure and OpenClaw documentation integration"
   git push
   ```

2. **CI/CD Integration:**
   - Add GitHub Actions workflow
   - Run tests on every PR
   - Automated testing in CI

3. **Documentation:**
   - Test README is complete
   - Examples work as documented
   - Troubleshooting covers common issues

## Files Modified/Created

**Fixed:**
- `bootstrap/bootstrap.sh` (line 26) - Corrected manifest URL
- `bootstrap/scripts/auto-update.sh` - Renamed function

**Created for testing:**
- `bootstrap/tests/docker/Dockerfile`
- `bootstrap/tests/docker/docker-compose.yml`
- `bootstrap/tests/docker/test-runner.sh`
- `bootstrap/tests/docker/README.md`
- `bootstrap/tests/docker/.dockerignore`
- `bootstrap/setup-testing.sh`
- `/tmp/run-docker-test-now.sh` (standalone wrapper)

**Created for OpenClaw:**
- `bootstrap/scripts/generate-openclaw-tools-doc.sh`
- `OPENCLAW_DOCUMENTATION.md`

## Support

If tests fail after following these instructions:

1. Save test output: `./test-runner.sh > test-output.log 2>&1`
2. Create GitHub issue with:
   - Error messages
   - Test logs
   - Docker version
   - OS version

---

**Ready to test!** Start with the quick test, then run the full suite if successful.
