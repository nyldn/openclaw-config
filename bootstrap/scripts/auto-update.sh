#!/usr/bin/env bash

# OpenClaw VM Auto-Update Script
# Keeps all software components up-to-date
# Runs daily via systemd timer

set -euo pipefail

# Configuration
LOG_DIR="${LOG_DIR:-/var/log/openclaw}"
LOG_FILE="$LOG_DIR/auto-update-$(date +%Y%m%d).log"
LOCK_FILE="/var/run/openclaw-auto-update.lock"
VENV_DIR="${VENV_DIR:-$HOME/.local/venv/openclaw}"
NPM_GLOBAL_DIR="${NPM_GLOBAL_DIR:-$HOME/.local/npm-global}"
UPDATE_TIMEOUT=600  # 10 minutes max

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Setup
setup() {
    # Create log directory
    mkdir -p "$LOG_DIR"

    # Check for lock file
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE")

        if ps -p "$lock_pid" &>/dev/null; then
            log_warn "Update already running (PID: $lock_pid)"
            exit 0
        else
            log_warn "Stale lock file found, removing"
            rm -f "$LOCK_FILE"
        fi
    fi

    # Create lock file
    echo $$ > "$LOCK_FILE"

    log_info "Starting auto-update process (PID: $$)"
}

# Cleanup
cleanup() {
    rm -f "$LOCK_FILE"
    log_info "Auto-update process completed"
}

trap cleanup EXIT

# Update system packages
update_system_packages() {
    log_info "Updating system packages..."

    if command -v apt-get &>/dev/null; then
        # Debian/Ubuntu
        log_info "Detected APT package manager"

        if sudo apt-get update -qq 2>&1 | tee -a "$LOG_FILE"; then
            log_success "APT package index updated"
        else
            log_error "Failed to update APT package index"
            return 1
        fi

        # Check for upgradable packages
        local upgradable
        upgradable=$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)

        if [[ $upgradable -gt 0 ]]; then
            log_info "Upgrading $upgradable packages..."

            if sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq 2>&1 | tee -a "$LOG_FILE"; then
                log_success "System packages upgraded"
            else
                log_error "Failed to upgrade system packages"
                return 1
            fi
        else
            log_info "All system packages are up-to-date"
        fi

    elif command -v yum &>/dev/null; then
        # RHEL/CentOS
        log_info "Detected YUM package manager"

        if sudo yum update -y -q 2>&1 | tee -a "$LOG_FILE"; then
            log_success "YUM packages updated"
        else
            log_error "Failed to update YUM packages"
            return 1
        fi

    elif command -v dnf &>/dev/null; then
        # Fedora
        log_info "Detected DNF package manager"

        if sudo dnf upgrade -y -q 2>&1 | tee -a "$LOG_FILE"; then
            log_success "DNF packages updated"
        else
            log_error "Failed to update DNF packages"
            return 1
        fi

    else
        log_warn "No supported package manager found"
    fi

    return 0
}

# Update Python packages
update_python_packages() {
    log_info "Updating Python packages..."

    if [[ ! -d "$VENV_DIR" ]]; then
        log_warn "Python virtual environment not found: $VENV_DIR"
        return 0
    fi

    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate" 2>/dev/null || {
        log_error "Failed to activate virtual environment"
        return 1
    }

    # Update pip first
    log_info "Updating pip..."
    if pip install --upgrade pip -q 2>&1 | tee -a "$LOG_FILE"; then
        log_success "pip updated"
    else
        log_warn "Failed to update pip"
    fi

    # Get list of outdated packages
    local outdated
    outdated=$(pip list --outdated --format=freeze 2>/dev/null | cut -d= -f1 || true)

    if [[ -n "$outdated" ]]; then
        log_info "Updating outdated Python packages..."

        while IFS= read -r package; do
            log_info "Updating $package..."
            if pip install --upgrade "$package" -q 2>&1 | tee -a "$LOG_FILE"; then
                log_success "$package updated"
            else
                log_warn "Failed to update $package"
            fi
        done <<< "$outdated"
    else
        log_info "All Python packages are up-to-date"
    fi

    deactivate 2>/dev/null || true

    return 0
}

# Update Node.js packages
update_nodejs_packages() {
    log_info "Updating Node.js global packages..."

    if ! command -v npm &>/dev/null; then
        log_warn "npm not found, skipping Node.js updates"
        return 0
    fi

    # Update npm itself
    log_info "Updating npm..."
    if npm install -g npm@latest 2>&1 | tee -a "$LOG_FILE"; then
        log_success "npm updated"
    else
        log_warn "Failed to update npm"
    fi

    # Update global packages
    log_info "Updating global npm packages..."
    if npm update -g 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Global npm packages updated"
    else
        log_warn "Failed to update global npm packages"
    fi

    return 0
}

# Update specific CLI tools
update_cli_tools() {
    log_info "Updating CLI tools..."

    local updated=0

    # Vercel CLI
    if command -v vercel &>/dev/null; then
        log_info "Updating Vercel CLI..."
        if npm install -g vercel@latest 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Vercel CLI updated"
            ((updated++))
        else
            log_warn "Failed to update Vercel CLI"
        fi
    fi

    # Netlify CLI
    if command -v netlify &>/dev/null; then
        log_info "Updating Netlify CLI..."
        if npm install -g netlify-cli@latest 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Netlify CLI updated"
            ((updated++))
        else
            log_warn "Failed to update Netlify CLI"
        fi
    fi

    # Supabase CLI
    if command -v supabase &>/dev/null; then
        log_info "Updating Supabase CLI..."
        if npm install -g supabase@latest 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Supabase CLI updated"
            ((updated++))
        else
            log_warn "Failed to update Supabase CLI"
        fi
    fi

    # Claude Code CLI
    if command -v claude &>/dev/null; then
        log_info "Checking Claude Code CLI for updates..."
        # Claude Code auto-updates itself, just log version
        local claude_version
        claude_version=$(claude --version 2>/dev/null | head -n1 || echo "unknown")
        log_info "Claude Code version: $claude_version"
    fi

    if [[ $updated -gt 0 ]]; then
        log_success "Updated $updated CLI tools"
    else
        log_info "All CLI tools are up-to-date"
    fi

    return 0
}

# Update MCP servers
update_mcp_servers() {
    log_info "Updating MCP servers..."

    local mcp_config="$HOME/.config/claude/mcp.json"

    if [[ ! -f "$mcp_config" ]]; then
        log_warn "MCP configuration not found: $mcp_config"
        return 0
    fi

    # MCP servers using npx are auto-updated on each run
    log_info "MCP servers using npx will auto-update on next use"

    # Update local MCP server dependencies if package.json exists
    local mcp_package="$HOME/.config/claude/mcp-servers/package.json"

    if [[ -f "$mcp_package" ]]; then
        log_info "Updating local MCP server dependencies..."
        local mcp_dir
        mcp_dir=$(dirname "$mcp_package")

        if (cd "$mcp_dir" && npm update 2>&1 | tee -a "$LOG_FILE"); then
            log_success "MCP server dependencies updated"
        else
            log_warn "Failed to update MCP server dependencies"
        fi
    fi

    return 0
}

# Update openclaw-config repository
update_openclaw_config() {
    log_info "Checking openclaw-config repository for updates..."

    local repo_dir="$HOME/openclaw-config"

    if [[ ! -d "$repo_dir/.git" ]]; then
        log_warn "openclaw-config repository not found: $repo_dir"
        return 0
    fi

    (
        cd "$repo_dir"

        # Fetch latest changes
        log_info "Fetching latest changes..."
        if git fetch origin 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Fetched latest changes"
        else
            log_warn "Failed to fetch changes"
            return 1
        fi

        # Check if behind remote
        local local_commit remote_commit
        local_commit=$(git rev-parse HEAD)
        remote_commit=$(git rev-parse origin/main)

        if [[ "$local_commit" != "$remote_commit" ]]; then
            log_info "Updates available for openclaw-config"
            log_info "Local: ${local_commit:0:7}, Remote: ${remote_commit:0:7}"

            # Check for local changes
            if ! git diff-index --quiet HEAD --; then
                log_warn "Local changes detected, skipping auto-pull"
                log_info "Run 'git pull' manually to update"
                return 0
            fi

            # Pull updates
            log_info "Pulling updates..."
            if git pull origin main 2>&1 | tee -a "$LOG_FILE"; then
                log_success "openclaw-config updated"

                # Re-run bootstrap if needed
                log_info "Consider running bootstrap to apply updates: cd $repo_dir/bootstrap && ./bootstrap.sh"
            else
                log_error "Failed to pull updates"
                return 1
            fi
        else
            log_info "openclaw-config is up-to-date"
        fi
    )

    return 0
}

# Clean up old packages
cleanup_packages() {
    log_info "Cleaning up old packages..."

    if command -v apt-get &>/dev/null; then
        log_info "Running apt autoremove..."
        if sudo apt-get autoremove -y -qq 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Removed unused packages"
        else
            log_warn "Failed to remove unused packages"
        fi

        log_info "Running apt autoclean..."
        if sudo apt-get autoclean -y -qq 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Cleaned package cache"
        else
            log_warn "Failed to clean package cache"
        fi
    fi

    # Clean npm cache
    if command -v npm &>/dev/null; then
        log_info "Cleaning npm cache..."
        if npm cache clean --force 2>&1 | tee -a "$LOG_FILE"; then
            log_success "npm cache cleaned"
        else
            log_warn "Failed to clean npm cache"
        fi
    fi

    return 0
}

# Generate update report
generate_report() {
    log_info "Generating update report..."

    local report_file="$LOG_DIR/update-report-$(date +%Y%m%d).txt"

    {
        echo "==================================="
        echo "OpenClaw VM Update Report"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "==================================="
        echo ""

        echo "System Information:"
        echo "  OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
        echo "  Kernel: $(uname -r)"
        echo "  Uptime: $(uptime -p)"
        echo ""

        echo "Package Versions:"
        echo "  Python: $(python3 --version 2>/dev/null || echo 'not installed')"
        echo "  Node.js: $(node --version 2>/dev/null || echo 'not installed')"
        echo "  npm: $(npm --version 2>/dev/null || echo 'not installed')"
        echo ""

        echo "CLI Tools:"
        echo "  Claude Code: $(claude --version 2>/dev/null | head -n1 || echo 'not installed')"
        echo "  Vercel: $(vercel --version 2>/dev/null | head -n1 || echo 'not installed')"
        echo "  Netlify: $(netlify --version 2>/dev/null | head -n1 || echo 'not installed')"
        echo "  Supabase: $(supabase --version 2>/dev/null | head -n1 || echo 'not installed')"
        echo ""

        echo "Disk Usage:"
        df -h / | tail -n1
        echo ""

        echo "Memory Usage:"
        free -h | grep Mem
        echo ""

        echo "Recent Updates (last 7 days):"
        if command -v apt-get &>/dev/null; then
            grep " install " /var/log/dpkg.log* 2>/dev/null | grep "$(date +%Y-%m)" | tail -n10 || echo "  No recent updates"
        else
            echo "  Log not available for this package manager"
        fi
        echo ""

        echo "Update Log: $LOG_FILE"

    } > "$report_file"

    log_success "Update report generated: $report_file"
}

# Main update process
main() {
    setup

    local start_time
    start_time=$(date +%s)

    log_info "========================================="
    log_info "OpenClaw VM Auto-Update - $(date '+%Y-%m-%d')"
    log_info "========================================="
    echo ""

    # Run updates
    update_system_packages || log_warn "System package update had issues"
    echo ""

    update_python_packages || log_warn "Python package update had issues"
    echo ""

    update_nodejs_packages || log_warn "Node.js package update had issues"
    echo ""

    update_cli_tools || log_warn "CLI tools update had issues"
    echo ""

    update_mcp_servers || log_warn "MCP servers update had issues"
    echo ""

    update_openclaw_config || log_warn "openclaw-config update had issues"
    echo ""

    cleanup_packages || log_warn "Package cleanup had issues"
    echo ""

    # Regenerate OpenClaw TOOLS.md documentation
    log_info "Regenerating OpenClaw TOOLS.md documentation..."
    local tools_script="$HOME/openclaw-config/bootstrap/scripts/generate-openclaw-tools-doc.sh"

    if [[ -x "$tools_script" ]]; then
        if bash "$tools_script" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "TOOLS.md regenerated successfully"
        else
            log_warn "Failed to regenerate TOOLS.md"
        fi
    else
        log_warn "TOOLS.md generation script not found"
    fi
    echo ""

    generate_report

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_info "========================================="
    log_success "Auto-update completed in ${duration}s"
    log_info "========================================="
}

# Run main
main "$@"
