# OpenClaw Bootstrap Test Summary

**Date:** Sun Feb  1 20:59:20 EST 2026

## Test Results

| Test | Result |
|------|--------|
| Dry-run mode | ✗ FAIL |
| System-deps module | ✗ FAIL |
| Python module | ✗ FAIL |
| Full installation | ✗ FAIL |
| Idempotency (2 runs) | ⚠ CHECK LOG |
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
```bash
cat /Users/chris/git/openclaw-config/bootstrap/tests/docker/results/20260201-205920/test-*.log | grep -i error
```

Re-run specific test:
```bash
cd /Users/chris/git/openclaw-config/bootstrap/tests/docker
docker-compose run --rm test-full
```

## Notes

All Docker containers and volumes were automatically cleaned up.
No persistent state remains after testing.
