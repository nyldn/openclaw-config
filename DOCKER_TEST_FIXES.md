# Docker Test Fixes

## Issues Identified and Fixed

### Issue 1: Claude CLI Not Found After Installation ✅ FIXED

**Problem:**
- The Claude CLI module installed the CLI successfully via the installer from `https://install.claude.ai/cli`
- However, the validation step immediately failed with "Claude CLI not found"
- Root cause: The installer adds Claude to PATH via shell profile (~/.bashrc or ~/.profile), but the current shell doesn't see the PATH update until it's sourced

**Fix Applied:**
- Modified `/Users/chris/git/openclaw-config/bootstrap/modules/04-claude-cli.sh` (lines 95-127)
- After running the Claude CLI installer, the script now:
  1. Sources ~/.bashrc and ~/.profile to pick up PATH changes
  2. Searches common Claude CLI installation locations:
     - `$HOME/.local/bin/claude`
     - `$HOME/bin/claude`
     - `/usr/local/bin/claude`
     - `$HOME/.claude/bin/claude`
  3. Adds the Claude CLI directory to PATH if found
- This ensures the `claude` command is available for validation immediately after installation

**Changes:**
```bash
# After installer runs successfully:
- Source shell profiles to update PATH
- Search for Claude CLI executable in common locations
- Export PATH with Claude CLI directory if found
```

### Issue 2: Nested Directory Path (NEEDS TESTING)

**Problem:**
- Docker logs showed working directory with recursive nesting:
  `~/openclaw-config/bootstrap/openclaw-config/bootstrap/openclaw-config/bootstrap`
- This suggests something is creating `openclaw-config/bootstrap/` subdirectories repeatedly

**Debugging Added:**
- Added debug output to `bootstrap.sh` to track working directory at key points:
  1. Initial working directory at script start
  2. Before each module installation
  3. After each module installation
  4. After each module validation
  5. After any installation failures

**What to Look For:**
- Run the automated test script: `./test-automated.sh`
- Review logs for lines starting with `[DEBUG]` that show "Working directory"
- Identify which module (if any) causes the directory to change unexpectedly
- Look for patterns like:
  - Before module X: `/home/testuser/openclaw-config/bootstrap`
  - After module X: `/home/testuser/openclaw-config/bootstrap/openclaw-config/bootstrap`

## Testing Instructions

### Option 1: Automated Test (Recommended)

```bash
# Run automated test with logging
./test-automated.sh
```

This will:
1. Build the Docker image
2. Run bootstrap with verbose logging
3. Save logs to `/tmp/openclaw-test-<timestamp>.log`
4. Show you how to review the logs

### Option 2: Manual Interactive Test

```bash
# Build and run container
./test-interactive.sh

# Inside the container, run with verbose output:
./bootstrap.sh --verbose --interactive

# Or test specific modules:
./bootstrap.sh --verbose --non-interactive --only system-deps,python
```

### Option 3: Quick Directory Check

```bash
docker run --rm openclaw-interactive:latest bash -c \
  "find /home/testuser -name openclaw-config -type d && \
   cd /home/testuser/openclaw-config/bootstrap && \
   pwd && \
   ./bootstrap.sh --dry-run"
```

## What's Been Fixed

1. ✅ **Claude CLI PATH issue** - Fixed by sourcing shell profiles and searching common installation locations
2. ✅ **Debug output added** - Working directory tracked at all key points
3. ✅ **Verbose mode enabled** - Docker container automatically enables VERBOSE=true
4. ✅ **Automated test script** - Easy way to capture full logs

## What Still Needs Investigation

1. ⚠️ **Nested path root cause** - Need to run test and review debug output to identify which module (if any) is causing the issue
2. ⚠️ **Module execution environment** - Modules run in subshells (`bash "$module_file" install`), so they shouldn't affect parent directory, but need to verify

## Next Steps

1. Run `./test-automated.sh`
2. Review the log file: `cat /tmp/openclaw-test-<timestamp>.log`
3. Search for issues: `grep -i "working directory\|error\|failed" <logfile>`
4. If nested paths still occur, identify which module causes it from debug output
5. Fix the problematic module

## Files Modified

- `bootstrap/modules/04-claude-cli.sh` - Fixed PATH issue after installation
- `bootstrap/bootstrap.sh` - Added debug output for directory tracking
- `Dockerfile.interactive` - Enabled verbose mode by default
- `test-automated.sh` - New automated test script with logging

## Commit Message

```
Fix Docker test issues: Claude CLI PATH and add debugging

- Fixed Claude CLI not found after installation by sourcing shell profiles
- Added debug output to track working directory changes during installation
- Enabled verbose mode in Docker test environment
- Created automated test script with logging for easier debugging

This addresses the Claude CLI validation failure and adds instrumentation
to identify the root cause of the nested directory path issue.
```
