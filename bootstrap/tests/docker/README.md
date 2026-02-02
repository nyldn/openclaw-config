# Docker-Based Bootstrap Testing

Temporary, ephemeral testing infrastructure for the OpenClaw bootstrap system. All containers are automatically cleaned up after testing - nothing persists.

## Quick Start

```bash
cd /Users/chris/git/openclaw-config/bootstrap/tests/docker

# Make runner executable (one-time setup)
chmod +x test-runner.sh

# Run all tests (auto-cleanup)
./test-runner.sh
```

## What Gets Tested

1. **Dry-run mode** - Validates --dry-run flag works
2. **System-deps module** - Tests basic package installation
3. **Python module** - Tests Python + dependencies
4. **Full installation** - Complete bootstrap (5-10 min)
5. **Idempotency** - Runs bootstrap twice to detect issues
6. **Validation-only** - Tests --validate without installation

## Storage Footprint

- **Base image:** debian:12-slim (~80MB compressed, ~220MB extracted)
- **After build:** ~350MB per test container
- **Temporary:** All containers/volumes removed automatically
- **No persistence:** Nothing left after test-runner.sh completes

The slim variant is the smallest official Debian image that includes apt-get and essential tools required for bootstrap testing.

## Individual Test Scenarios

Run specific tests without the full suite:

```bash
# Dry-run only (fastest, 30 seconds)
docker-compose run --rm test-dry-run

# Full installation test
docker-compose run --rm test-full

# Idempotency test (run bootstrap twice)
docker-compose run --rm test-idempotency

# Specific module test
docker-compose run --rm test-module-system-deps
docker-compose run --rm test-module-python
```

## Manual Cleanup

If tests are interrupted, clean up manually:

```bash
# Remove all test containers and volumes
docker-compose down --volumes --remove-orphans

# Remove dangling images
docker image prune -f
```

## Interactive Testing

For manual testing/debugging in a container:

```bash
# Start interactive shell
docker-compose run --rm test-full bash

# Inside container:
cd /home/testuser/openclaw-config/bootstrap
./bootstrap.sh --dry-run
./bootstrap.sh --validate
exit
```

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Bootstrap Tests

on: [push, pull_request]

jobs:
  docker-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Docker tests
        run: |
          cd bootstrap/tests/docker
          chmod +x test-runner.sh
          ./test-runner.sh
      - name: Upload test results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: bootstrap/tests/docker/results/
```

## Test Results

Results are saved to `results/YYYYMMDD-HHMMSS/`:
- Individual log files per test
- `SUMMARY.md` with pass/fail status
- Automatically timestamped

## Requirements

- Docker Desktop or Docker Engine
- 2GB available disk space
- Internet connection (for image download and package installation)

## Troubleshooting

**"Permission denied" on test-runner.sh:**
```bash
chmod +x test-runner.sh
```

**"Cannot connect to Docker daemon":**
```bash
# Start Docker Desktop (macOS/Windows)
# Or start Docker service (Linux)
sudo systemctl start docker
```

**Tests fail with network errors:**
- Check internet connectivity
- Verify GitHub is accessible
- Check APT repository availability

**Container cleanup not working:**
```bash
# Force cleanup
docker-compose down --volumes --remove-orphans --rmi all
docker system prune -af --volumes
```

## Design Philosophy

This testing infrastructure follows these principles:

1. **Ephemeral** - Nothing persists after test completion
2. **Isolated** - No impact on host system
3. **Repeatable** - Same results every run
4. **Fast** - Optimized for quick iteration
5. **Safe** - No production risk

## Next Steps

- **For development:** Use these tests before committing
- **For CI/CD:** Integrate into GitHub Actions
- **For staging:** Use cloud VM tests (see `../staging/`)
- **For mocking:** Use mock framework (see `../mock/`)
