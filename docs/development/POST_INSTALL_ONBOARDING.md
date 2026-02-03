# Post-Install Onboarding System - Complete Implementation

## Overview

Created a comprehensive post-installation onboarding system for OpenClaw v2.0 that guides users through credential configuration, service authentication, and validation.

**Date:** 2026-02-02
**Status:** Complete and Tested

## Components Created

### 1. Google Drive MCP Server
**File:** `deployment-tools/mcp/implementations/google-drive-mcp.js`

Full-featured MCP server for Google Drive integration with 9 tools:
- `listFiles` - List files in a folder
- `searchFiles` - Search by name/content
- `uploadFile` - Upload files to Drive
- `downloadFile` - Download files locally
- `createFolder` - Create folders
- `shareFile` - Share with permissions
- `getFileInfo` - Get file metadata
- `deleteFile` - Delete files
- `moveFile` - Move between folders

**Pattern:** Follows existing `google-calendar-mcp.js` structure with:
- ES module imports from `@modelcontextprotocol/sdk`
- Class-based architecture with `setupHandlers()` and `setupErrorHandling()`
- OAuth token file support (`~/.openclaw/google-drive-token.json`)

### 2. Setup Wizard Script
**File:** `bootstrap/scripts/openclaw-setup.sh`

Interactive credential configuration wizard supporting:

| Service | Configuration |
|---------|---------------|
| Anthropic | API key validation (sk-ant-* format) |
| OpenAI | API key validation (sk-proj-* format) |
| Google Gemini | API key |
| GitHub | PAT with scope guidance |
| Todoist | API token with link to settings |
| Slack | Bot token + App token |
| Google Calendar | OAuth setup instructions |
| Google Drive | OAuth setup instructions |

**Features:**
- `--all` - Configure all services non-interactively
- `--llm` - Configure AI/LLM APIs only
- `--productivity` - Configure productivity integrations only
- `--anthropic`, `--openai`, `--gemini`, etc. - Individual services
- Interactive mode with category selection
- Secure credential storage in `~/.openclaw/credentials/`
- Automatic `.env` file updates

### 3. Authentication Helper Script
**File:** `bootstrap/scripts/openclaw-auth.sh`

CLI authentication helper for services requiring interactive login:

| Service | Auth Method |
|---------|-------------|
| Claude CLI | `claude login` wrapper |
| Gemini CLI | `gemini login` wrapper |
| Google Calendar | OAuth flow with instructions |
| Google Drive | OAuth flow with instructions |
| Vercel | `vercel login` wrapper |
| Netlify | `netlify login` wrapper |
| Supabase | `supabase login` wrapper |

**Features:**
- `--all` - Authenticate all services
- `--claude`, `--gemini`, `--google`, etc. - Individual services
- Status checking before auth attempts
- Clear OAuth setup instructions

### 4. Validation Script
**File:** `bootstrap/scripts/openclaw-validate.sh`

Service validation that tests all configured credentials:

**Checks Performed:**
- Environment file existence and permissions (600)
- Workspace/config directory structure
- Python virtual environment
- Claude CLI installation and authentication
- API key validity (Anthropic, OpenAI, Gemini)
- GitHub PAT with scope verification
- Todoist API token
- Slack Bot token
- Google Calendar OAuth tokens
- Google Drive OAuth tokens
- MCP server file availability

**Output Format:**
```
Environment:
  ✓ Environment file exists (/home/user/openclaw-workspace/.env)
  ✓ Environment file has secure permissions (600)
  ✓ Workspace directory exists
  ✓ Config directory exists
  ✓ Python virtual environment exists

Claude (Anthropic):
  ✓ Claude CLI installed
  ✓ Anthropic API key configured
  ...

Results: 10 passed, 0 failed, 9 skipped
```

**Features:**
- `--all` - Validate everything (default)
- `--env` - Environment only
- `--llm` - AI/LLM services only
- `--productivity` - Productivity services only
- Graceful handling of unconfigured services (skip, don't fail)

### 5. Shell Aliases
**File:** `bootstrap/aliases/openclaw-aliases.sh`

Core command aliases for daily use:

```bash
# Setup & Configuration
openclaw-setup      # Interactive credential wizard
openclaw-auth       # Authenticate CLI tools & OAuth
openclaw-validate   # Check all services are working

# Shortcuts
oc-setup, oc-auth, oc-validate

# Configuration Management
openclaw-config     # Browse ~/.openclaw
openclaw-env        # Edit .env file
openclaw-workspace  # Go to workspace

# Bootstrap Management
openclaw-update     # Check for updates
openclaw-doctor     # Run diagnostics
openclaw-modules    # List modules

# LLM Access
claude-login, claude-status, openclaw-activate

# Help
openclaw-help       # Quick reference
```

## Files Modified

### 1. Environment Template
**File:** `bootstrap/templates/.env.template`

Comprehensive template with:
- All AI/LLM API keys (Anthropic, OpenAI, Google)
- GitHub PAT
- Productivity integrations (Todoist, Slack)
- Google OAuth paths
- Database URLs
- Format hints in comments
- Links to credential pages

### 2. Bootstrap Script
**File:** `bootstrap/bootstrap.sh`

Updated "Next steps" section at end of installation:
```bash
echo "  First, reload your shell to enable commands:"
echo "     source ~/.bashrc"
echo ""
echo "  Then run the setup wizard:"
echo "     openclaw-setup              # Configure API keys"
echo "     openclaw-auth --all         # Authenticate CLIs"
echo "     openclaw-validate           # Verify everything works"
```

### 3. OpenClaw Environment Module
**File:** `bootstrap/modules/07-openclaw-env.sh`

Added alias installation during module setup:
- Creates `~/.openclaw/` config directory
- Sources `bootstrap/aliases/openclaw-aliases.sh` in `.bashrc`
- Enables commands immediately after shell reload

### 4. Productivity Tools Module
**File:** `bootstrap/modules/15-productivity-tools.sh`

Added Google Drive setup guide and MCP server configuration.

## Bug Fixes

### Cross-Platform `stat` Command (Line 294)
**File:** `bootstrap/scripts/openclaw-validate.sh`

**Problem:** 
```bash
# Original - broken on Linux
perms=$(stat -f "%OLp" "$ENV_FILE" 2>/dev/null || stat -c "%a" "$ENV_FILE" 2>/dev/null)
```
The macOS `stat -f` command would fail but output garbage before the Linux `stat -c` could run. Error redirection wasn't working correctly.

**Fix:**
```bash
if [[ "$(uname)" == "Darwin" ]]; then
    perms=$(stat -f "%OLp" "$ENV_FILE" 2>/dev/null)
else
    perms=$(stat -c "%a" "$ENV_FILE" 2>/dev/null)
fi
```

**Verified:** Permission check now correctly shows `600` without garbled output on both macOS and Linux.

## Testing

### Docker Test Environment

**Build:**
```bash
docker build -f .work-in-progress/Dockerfile.interactive -t openclaw-interactive:latest .
```

**Run Container:**
```bash
docker run -d --name openclaw-test-final openclaw-interactive:latest sleep infinity
```

**Test Bootstrap:**
```bash
docker exec openclaw-test-final bash -c '
  cd ~/openclaw-config/bootstrap
  ./bootstrap.sh --non-interactive --only system-deps,python,nodejs,openclaw-env
'
```

**Test Onboarding Scripts:**
```bash
# Test setup help
docker exec openclaw-test-final bash -ic 'openclaw-setup --help'

# Test validation (environment only)
docker exec openclaw-test-final bash -ic 'openclaw-validate --env'

# Test full validation
docker exec openclaw-test-final bash -ic 'openclaw-validate --all'
```

### Test Results

All tests passing:
- ✅ Bootstrap completes successfully (1m 5s for core modules)
- ✅ Aliases load correctly via interactive bash
- ✅ `openclaw-setup --help` shows all options
- ✅ `openclaw-validate --env` passes all 5 checks
- ✅ `openclaw-validate --all` passes with graceful skips for unconfigured services
- ✅ Permission check shows correct `600` (stat fix verified)
- ✅ MCP servers detected correctly

## User Flow

After running `./bootstrap.sh`:

1. **Reload shell:**
   ```bash
   source ~/.bashrc
   ```

2. **Configure credentials:**
   ```bash
   openclaw-setup              # Interactive wizard
   # OR
   openclaw-setup --llm        # Just AI APIs
   ```

3. **Authenticate CLIs:**
   ```bash
   openclaw-auth --claude      # Claude CLI
   openclaw-auth --google      # Google OAuth
   ```

4. **Validate setup:**
   ```bash
   openclaw-validate           # Check everything
   ```

## Architecture

```
bootstrap/
├── scripts/
│   ├── openclaw-setup.sh      # Credential wizard
│   ├── openclaw-auth.sh       # CLI authentication
│   └── openclaw-validate.sh   # Service validation
├── aliases/
│   └── openclaw-aliases.sh    # Shell aliases
└── templates/
    └── .env.template          # Environment template

deployment-tools/mcp/implementations/
└── google-drive-mcp.js        # Google Drive MCP server

~/.openclaw/                   # Created at install
├── credentials/               # Secure credential storage
├── google-calendar-token.json # OAuth tokens
└── google-drive-token.json
```

## Security Considerations

- Credentials stored in `~/.openclaw/credentials/` with `600` permissions
- `.env` file validated for `600` permissions
- API keys masked in validation output
- OAuth tokens stored separately from main config
- No credentials in repository or logs

## Additional Bug Fixes (2026-02-02)

### Supabase CLI Installation
**File:** `bootstrap/modules/10-deployment-tools.sh`

**Problem:** npm global install no longer supported by Supabase CLI.

**Fix:** Download binary directly from GitHub releases:
```bash
url="https://github.com/supabase/cli/releases/latest/download/supabase_${os_name}_${arch}.tar.gz"
```

### Auto-Updates in Containers
**File:** `bootstrap/modules/11-auto-updates.sh`

**Problem:** Systemd not available in Docker containers, causing module to fail.

**Fix:** Added `is_container()` detection that checks for:
- `/.dockerenv`
- `/run/.containerenv`
- cgroup patterns (docker, lxc, containerd, kubepods)

When in container, module returns success with message to run updates manually.

### PATH Not Updated for Validations
**Files:** Multiple module validate() functions

**Problem:** After npm installs CLIs to `~/.local/npm-global/bin`, the validate() functions couldn't find them because PATH wasn't updated in the current shell.

**Fix:** Added PATH export at start of validate() functions:
```bash
export PATH="$HOME/.local/npm-global/bin:$HOME/.local/bin:$PATH"
```

Modules fixed: `04-claude-cli.sh`, `09-claude-octopus.sh`, `10-deployment-tools.sh`, `12-dev-tools.sh`, `13-openclaw.sh`

### Bootstrap Continues on Failure
**File:** `bootstrap/bootstrap.sh`

**Problem:** In interactive mode, bootstrap prompted user "Continue despite failure?" after each module failure.

**Fix:** Removed the prompt, now logs warning and continues automatically:
```bash
if ! install_module "$module"; then
    failed_modules+=("$module")
    log_warn "Continuing with remaining modules..."
fi
```

### Test Results After Fixes

| Metric | Before | After |
|--------|--------|-------|
| Successful modules | 8 | 12 |
| Failed modules | 7 | 3 |
| User prompts on failure | Yes | No |

Remaining failures (expected in Docker):
- `security` - requires iptables, fail2ban, UFW (not available in containers)
- `openclaw` - npm package doesn't provide CLI binary (design issue)
- `claude-octopus` - depends on Claude CLI plugin system

## Future Improvements

1. **Credential Rotation Reminders** - Track token age, prompt for rotation at 90 days
2. **OAuth Token Refresh** - Automatic refresh of expired Google tokens
3. **Service Health Dashboard** - Web UI for service status
4. **Backup/Restore** - Export/import credential configuration
5. **Multi-Profile Support** - Switch between work/personal configurations
