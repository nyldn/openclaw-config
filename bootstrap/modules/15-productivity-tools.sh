#!/usr/bin/env bash

# Module: Productivity Tools
# Installs personal productivity MCP servers (Calendar, Email, Tasks, Slack)

MODULE_NAME="productivity-tools"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Personal productivity integrations (Calendar, Email, Tasks, Slack)"
MODULE_DEPS=("nodejs" "deployment-tools")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

WORKSPACE_DIR="$HOME/openclaw-workspace"
MCP_DIR="$WORKSPACE_DIR/mcp-servers"
CONFIG_DIR="$HOME/.openclaw/productivity"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check if MCP servers are installed
    if [[ ! -d "$MCP_DIR" ]]; then
        return 1
    fi

    # Check if at least one MCP server exists
    if [[ ! -f "$MCP_DIR/google-calendar-mcp.js" ]]; then
        return 1
    fi

    log_debug "Productivity tools are installed"
    return 0
}

# Install the module
install() {
    log_section "Installing Productivity Tools"

    # Create directories
    log_progress "Creating productivity directories"
    mkdir -p "$MCP_DIR"
    mkdir -p "$CONFIG_DIR"
    chmod 0700 "$CONFIG_DIR"  # Restrictive permissions for credentials
    log_success "Directories created"

    # Install npm dependencies
    log_progress "Installing npm dependencies for MCP servers"

    local -a npm_packages=(
        "@modelcontextprotocol/sdk"
        "googleapis"
        "imap"
        "mailparser"
        "nodemailer"
        "@doist/todoist-api-typescript"
        "@slack/web-api"
    )

    for package in "${npm_packages[@]}"; do
        log_progress "Installing $package..."

        if npm install -g "$package" --silent; then
            log_success "$package installed"
        else
            log_error "Failed to install $package"
            return 1
        fi
    done

    log_success "All npm dependencies installed"

    # Copy MCP server implementations
    log_progress "Copying MCP server implementations"

    local source_dir="$SCRIPT_DIR/../deployment-tools/mcp/implementations"

    if [[ ! -d "$source_dir" ]]; then
        log_error "MCP implementations directory not found: $source_dir"
        return 1
    fi

    local -a mcp_servers=(
        "google-calendar-mcp.js"
        "email-mcp.js"
        "todoist-mcp.js"
        "slack-mcp.js"
    )

    for server in "${mcp_servers[@]}"; do
        if [[ -f "$source_dir/$server" ]]; then
            cp "$source_dir/$server" "$MCP_DIR/"
            chmod +x "$MCP_DIR/$server"
            log_success "Copied: $server"
        else
            log_warn "MCP server not found: $server"
        fi
    done

    # Create credential template files
    log_progress "Creating credential templates"

    # Google Calendar credentials template
    cat > "$CONFIG_DIR/google-calendar-setup.md" <<'EOF'
# Google Calendar Setup

## 1. Enable Google Calendar API

1. Go to: https://console.cloud.google.com/
2. Create a new project or select existing one
3. Enable the Google Calendar API
4. Go to "Credentials" → "Create Credentials" → "OAuth client ID"
5. Choose "Desktop app"
6. Download the credentials JSON file

## 2. Save Credentials

Save the downloaded JSON file to:
~/.openclaw/google-calendar-credentials.json

## 3. Authenticate

Run the authentication flow:
node ~/.openclaw/workspace/mcp-servers/google-calendar-mcp.js

Follow the URL to grant permissions, then paste the code back.

## 4. Test

Your token will be saved to:
~/.openclaw/google-calendar-token.json

The MCP server is now ready to use!
EOF

    # Email credentials template
    cat > "$CONFIG_DIR/email-credentials.template.env" <<'EOF'
# Email Configuration Template
# Copy this to ~/.openclaw/productivity/email-credentials.env
# and fill in your actual values

# IMAP Configuration (for reading emails)
EMAIL_IMAP_HOST=imap.gmail.com
EMAIL_IMAP_PORT=993

# SMTP Configuration (for sending emails)
EMAIL_SMTP_HOST=smtp.gmail.com
EMAIL_SMTP_PORT=587

# Authentication
EMAIL_USERNAME=your-email@gmail.com
EMAIL_PASSWORD=your-app-password

# Gmail App Password:
# 1. Go to: https://myaccount.google.com/apppasswords
# 2. Generate an app password for "Mail"
# 3. Use that password above (not your regular password)

# For other providers:
# - Outlook: imap-mail.outlook.com / smtp-mail.outlook.com
# - Yahoo: imap.mail.yahoo.com / smtp.mail.yahoo.com
EOF

    # Todoist credentials template
    cat > "$CONFIG_DIR/todoist-setup.md" <<'EOF'
# Todoist Setup

## 1. Get API Token

1. Go to: https://todoist.com/prefs/integrations
2. Scroll to "API token"
3. Copy your API token

## 2. Set Environment Variable

Add to your ~/.bashrc or ~/.zshrc:

export TODOIST_API_TOKEN=your-api-token-here

Then reload:
source ~/.bashrc

## 3. Test

The MCP server is now ready to use!
EOF

    # Slack credentials template
    cat > "$CONFIG_DIR/slack-setup.md" <<'EOF'
# Slack Setup

## 1. Create Slack App

1. Go to: https://api.slack.com/apps
2. Click "Create New App" → "From scratch"
3. Name your app and select workspace

## 2. Configure OAuth & Permissions

Add these Bot Token Scopes:
- channels:history
- channels:read
- channels:write
- chat:write
- files:write
- groups:history
- groups:read
- groups:write
- im:history
- im:read
- im:write
- mpim:history
- mpim:read
- mpim:write
- reactions:write
- search:read
- users:read

## 3. Install App to Workspace

1. Click "Install to Workspace"
2. Authorize the app
3. Copy the "Bot User OAuth Token" (starts with xoxb-)

## 4. Set Environment Variables

Add to your ~/.bashrc or ~/.zshrc:

export SLACK_BOT_TOKEN=xoxb-your-bot-token
export SLACK_APP_TOKEN=xapp-your-app-token  # Optional, for Socket Mode

Then reload:
source ~/.bashrc

## 5. Test

The MCP server is now ready to use!
EOF

    log_success "Credential templates created in: $CONFIG_DIR"

    # Add shell aliases
    log_progress "Adding productivity shell aliases"

    local bashrc="$HOME/.bashrc"
    local aliases_marker="# OpenClaw Productivity Aliases"

    if ! grep -q "$aliases_marker" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" <<'EOF'

# OpenClaw Productivity Aliases
alias productivity-setup='cat ~/.openclaw/productivity/*.md'
alias calendar-auth='node ~/.openclaw/workspace/mcp-servers/google-calendar-mcp.js'
alias productivity-config='cd ~/.openclaw/productivity && ls -la'
EOF
        log_success "Shell aliases added to .bashrc"
    else
        log_debug "Shell aliases already exist"
    fi

    # Display setup instructions
    log_section "Setup Instructions"

    echo ""
    log_info "Productivity MCP servers have been installed!"
    echo ""
    log_info "Next steps:"
    echo "  1. Set up credentials for each service:"
    echo "     - Google Calendar: See ~/.openclaw/productivity/google-calendar-setup.md"
    echo "     - Email: Copy and edit ~/.openclaw/productivity/email-credentials.template.env"
    echo "     - Todoist: See ~/.openclaw/productivity/todoist-setup.md"
    echo "     - Slack: See ~/.openclaw/productivity/slack-setup.md"
    echo ""
    log_info "  2. View all setup instructions:"
    echo "     productivity-setup"
    echo ""
    log_info "  3. Test MCP servers with Claude Code CLI"
    echo ""

    return 0
}

# Validate installation
validate() {
    log_progress "Validating productivity tools installation"

    local all_valid=true

    # Check npm packages
    local -a required_packages=(
        "@modelcontextprotocol/sdk"
        "googleapis"
        "imap"
        "nodemailer"
        "@doist/todoist-api-typescript"
        "@slack/web-api"
    )

    for package in "${required_packages[@]}"; do
        if npm list -g "$package" &>/dev/null; then
            log_success "Package installed: $package"
        else
            log_error "Package missing: $package"
            all_valid=false
        fi
    done

    # Check MCP server files
    local -a mcp_servers=(
        "google-calendar-mcp.js"
        "email-mcp.js"
        "todoist-mcp.js"
        "slack-mcp.js"
    )

    for server in "${mcp_servers[@]}"; do
        if [[ -f "$MCP_DIR/$server" ]] && [[ -x "$MCP_DIR/$server" ]]; then
            log_success "MCP server exists: $server"
        else
            log_error "MCP server missing or not executable: $server"
            all_valid=false
        fi
    done

    # Check config directory
    if [[ -d "$CONFIG_DIR" ]]; then
        log_success "Config directory exists: $CONFIG_DIR"

        # Check permissions
        local perms
        perms=$(stat -f "%OLp" "$CONFIG_DIR" 2>/dev/null || stat -c "%a" "$CONFIG_DIR" 2>/dev/null)

        if [[ "$perms" == "700" ]]; then
            log_success "Config directory has correct permissions (700)"
        else
            log_warn "Config directory permissions: $perms (expected: 700)"
        fi
    else
        log_error "Config directory not found: $CONFIG_DIR"
        all_valid=false
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "Productivity tools validation passed"
        return 0
    else
        log_error "Productivity tools validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back productivity tools installation"

    log_progress "Removing MCP servers"
    rm -rf "$MCP_DIR"

    log_progress "Removing config directory"
    rm -rf "$CONFIG_DIR"

    log_progress "Removing npm packages"
    npm uninstall -g @modelcontextprotocol/sdk googleapis imap mailparser nodemailer @doist/todoist-api-typescript @slack/web-api 2>/dev/null || true

    log_success "Rollback complete"

    return 0
}

# Main execution when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-install}" in
        check)
            check_installed
            ;;
        install)
            install
            ;;
        validate)
            validate
            ;;
        rollback)
            rollback
            ;;
        *)
            echo "Usage: $0 {check|install|validate|rollback}"
            exit 1
            ;;
    esac
fi
