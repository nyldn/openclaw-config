#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

if [[ -f "$LIB_DIR/logger.sh" ]]; then
    source "$LIB_DIR/logger.sh"
else
    log_info() { echo -e "\033[0;34m[i]\033[0m $1"; }
    log_success() { echo -e "\033[0;32m[✓]\033[0m $1"; }
    log_error() { echo -e "\033[0;31m[✗]\033[0m $1" >&2; }
    log_warn() { echo -e "\033[0;33m[!]\033[0m $1"; }
    log_section() { echo -e "\n\033[0;36m═══════════════════════════════════════════════════════\033[0m"; echo -e "\033[0;36m  $1\033[0m"; echo -e "\033[0;36m═══════════════════════════════════════════════════════\033[0m\n"; }
fi

CONFIG_DIR="$HOME/.openclaw"
WORKSPACE_DIR="$HOME/openclaw-workspace"
ENV_FILE="$WORKSPACE_DIR/.env"

load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
    fi
}

auth_claude() {
    log_section "Claude CLI Authentication"
    
    if ! command -v claude &>/dev/null; then
        log_error "Claude CLI not installed"
        log_info "Install with: ./bootstrap.sh --only claude-cli"
        return 1
    fi
    
    if claude whoami &>/dev/null 2>&1; then
        local user_info
        user_info=$(claude whoami 2>/dev/null || echo "authenticated")
        log_success "Already authenticated: $user_info"
        read -r -p "Re-authenticate? [y/N] " response
        [[ ! "$response" =~ ^[Yy]$ ]] && return 0
    fi
    
    echo ""
    echo "This will open a browser window for authentication."
    echo "Follow the prompts to sign in with your Anthropic account."
    echo ""
    read -r -p "Continue with authentication? [Y/n] " response
    
    if [[ "$response" =~ ^[Nn]$ ]]; then
        log_info "Skipped Claude authentication"
        return 0
    fi
    
    if claude login; then
        log_success "Claude CLI authenticated successfully"
    else
        log_error "Claude authentication failed"
        echo ""
        echo "Troubleshooting:"
        echo "  • Ensure you have an Anthropic account"
        echo "  • Check your internet connection"
        echo "  • Try again: claude login"
        return 1
    fi
}

auth_gemini() {
    log_section "Gemini CLI / gcloud Authentication"
    
    load_env
    
    if [[ -n "${GOOGLE_API_KEY:-}" ]]; then
        log_success "Google API key is configured in .env"
        
        source "$HOME/.local/venv/openclaw/bin/activate" 2>/dev/null || true
        if python3 -c "import google.generativeai as genai; genai.configure(api_key='${GOOGLE_API_KEY}')" 2>/dev/null; then
            log_success "API key is valid"
            deactivate 2>/dev/null || true
            return 0
        else
            log_warn "API key may be invalid"
            deactivate 2>/dev/null || true
        fi
    fi
    
    if command -v gcloud &>/dev/null; then
        echo ""
        echo "You have gcloud CLI installed. Would you like to:"
        echo "  1) Use API key (simpler, already configured if set)"
        echo "  2) Use gcloud auth (for full GCP integration)"
        echo ""
        read -r -p "Select option [1]: " choice
        choice="${choice:-1}"
        
        if [[ "$choice" == "2" ]]; then
            log_info "Running gcloud auth login..."
            if gcloud auth login; then
                log_success "gcloud authenticated"
                
                log_info "Setting application default credentials..."
                if gcloud auth application-default login; then
                    log_success "Application default credentials set"
                fi
            else
                log_error "gcloud authentication failed"
                return 1
            fi
            return 0
        fi
    fi
    
    echo ""
    echo "Gemini uses an API key for authentication."
    echo "Get your key from: https://aistudio.google.com/apikey"
    echo ""
    
    if [[ -z "${GOOGLE_API_KEY:-}" ]]; then
        read -r -p "Enter your Google API key: " api_key
        
        if [[ -n "$api_key" ]]; then
            if [[ -f "$ENV_FILE" ]]; then
                if grep -q "^GOOGLE_API_KEY=" "$ENV_FILE"; then
                    if [[ "$(uname)" == "Darwin" ]]; then
                        sed -i '' "s|^GOOGLE_API_KEY=.*|GOOGLE_API_KEY=${api_key}|" "$ENV_FILE"
                    else
                        sed -i "s|^GOOGLE_API_KEY=.*|GOOGLE_API_KEY=${api_key}|" "$ENV_FILE"
                    fi
                else
                    echo "GOOGLE_API_KEY=${api_key}" >> "$ENV_FILE"
                fi
            fi
            export GOOGLE_API_KEY="$api_key"
            log_success "Google API key saved to .env"
        fi
    fi
    
    log_success "Gemini configuration complete"
}

auth_google_calendar() {
    log_section "Google Calendar OAuth Authentication"
    
    local creds_file="$CONFIG_DIR/google-calendar-credentials.json"
    local token_file="$CONFIG_DIR/google-calendar-token.json"
    
    if [[ -f "$token_file" ]]; then
        log_success "Google Calendar token already exists"
        read -r -p "Re-authenticate? [y/N] " response
        [[ ! "$response" =~ ^[Yy]$ ]] && return 0
    fi
    
    if [[ ! -f "$creds_file" ]]; then
        log_error "OAuth credentials not found: $creds_file"
        echo ""
        echo "Setup steps:"
        echo "  1. Go to: https://console.cloud.google.com/"
        echo "  2. Create a project and enable Google Calendar API"
        echo "  3. Create OAuth 2.0 credentials (Desktop app)"
        echo "  4. Download the JSON file"
        echo "  5. Save it to: $creds_file"
        echo ""
        echo "Or run: openclaw-setup --google"
        return 1
    fi
    
    local mcp_server="$WORKSPACE_DIR/mcp-servers/google-calendar-mcp.js"
    if [[ ! -f "$mcp_server" ]]; then
        mcp_server="$(dirname "$SCRIPT_DIR")/../deployment-tools/mcp/implementations/google-calendar-mcp.js"
    fi
    
    if [[ ! -f "$mcp_server" ]]; then
        log_error "Google Calendar MCP server not found"
        return 1
    fi
    
    echo ""
    echo "Starting OAuth flow..."
    echo "A URL will be displayed. Open it in your browser,"
    echo "grant permissions, and paste the authorization code back here."
    echo ""
    
    node "$mcp_server" --auth 2>&1 || {
        log_warn "MCP server doesn't support --auth flag"
        echo ""
        echo "Manual authentication required:"
        echo "  1. Run the MCP server directly: node $mcp_server"
        echo "  2. Follow the OAuth prompts"
        echo "  3. Token will be saved automatically"
    }
    
    if [[ -f "$token_file" ]]; then
        log_success "Google Calendar authenticated"
    else
        log_warn "Token file not created. Authentication may need to be completed manually."
    fi
}

auth_google_drive() {
    log_section "Google Drive OAuth Authentication"
    
    local creds_file="$CONFIG_DIR/google-drive-credentials.json"
    local token_file="$CONFIG_DIR/google-drive-token.json"
    
    if [[ -f "$token_file" ]]; then
        log_success "Google Drive token already exists"
        read -r -p "Re-authenticate? [y/N] " response
        [[ ! "$response" =~ ^[Yy]$ ]] && return 0
    fi
    
    if [[ ! -f "$creds_file" ]]; then
        local shared_creds="$CONFIG_DIR/google-credentials.json"
        if [[ -f "$shared_creds" ]]; then
            cp "$shared_creds" "$creds_file"
            chmod 0600 "$creds_file"
            log_info "Using shared Google credentials"
        else
            log_error "OAuth credentials not found: $creds_file"
            echo ""
            echo "Setup steps:"
            echo "  1. Go to: https://console.cloud.google.com/"
            echo "  2. Create a project and enable Google Drive API"
            echo "  3. Create OAuth 2.0 credentials (Desktop app)"
            echo "  4. Download the JSON file"
            echo "  5. Save it to: $creds_file"
            echo ""
            echo "Or run: openclaw-setup --google"
            return 1
        fi
    fi
    
    local mcp_server="$WORKSPACE_DIR/mcp-servers/google-drive-mcp.js"
    if [[ ! -f "$mcp_server" ]]; then
        mcp_server="$(dirname "$SCRIPT_DIR")/../deployment-tools/mcp/implementations/google-drive-mcp.js"
    fi
    
    if [[ ! -f "$mcp_server" ]]; then
        log_error "Google Drive MCP server not found"
        return 1
    fi
    
    echo ""
    echo "Starting OAuth flow..."
    echo "A URL will be displayed. Open it in your browser,"
    echo "grant permissions, and paste the authorization code back here."
    echo ""
    
    node "$mcp_server" --auth 2>&1 || {
        log_warn "MCP server doesn't support --auth flag"
        echo ""
        echo "Manual authentication required:"
        echo "  1. Run the MCP server directly: node $mcp_server"
        echo "  2. Follow the OAuth prompts"
        echo "  3. Token will be saved automatically"
    }
    
    if [[ -f "$token_file" ]]; then
        log_success "Google Drive authenticated"
    else
        log_warn "Token file not created. Authentication may need to be completed manually."
    fi
}

show_status() {
    log_section "Authentication Status"
    
    load_env
    
    if command -v claude &>/dev/null && claude whoami &>/dev/null 2>&1; then
        echo "  ✓ Claude CLI: authenticated"
    elif command -v claude &>/dev/null; then
        echo "  ○ Claude CLI: not authenticated"
    else
        echo "  - Claude CLI: not installed"
    fi
    
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        echo "  ✓ Anthropic API key: configured"
    else
        echo "  ○ Anthropic API key: not configured"
    fi
    
    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        echo "  ✓ OpenAI API key: configured"
    else
        echo "  ○ OpenAI API key: not configured"
    fi
    
    if [[ -n "${GOOGLE_API_KEY:-}" ]]; then
        echo "  ✓ Google API key: configured"
    else
        echo "  ○ Google API key: not configured"
    fi
    
    if command -v gcloud &>/dev/null && gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q "."; then
        echo "  ✓ gcloud: authenticated"
    elif command -v gcloud &>/dev/null; then
        echo "  ○ gcloud: not authenticated"
    else
        echo "  - gcloud: not installed"
    fi
    
    if [[ -f "$CONFIG_DIR/google-calendar-token.json" ]]; then
        echo "  ✓ Google Calendar: authenticated"
    else
        echo "  ○ Google Calendar: not authenticated"
    fi
    
    if [[ -f "$CONFIG_DIR/google-drive-token.json" ]]; then
        echo "  ✓ Google Drive: authenticated"
    else
        echo "  ○ Google Drive: not authenticated"
    fi
    
    echo ""
}

run_all() {
    auth_claude
    auth_gemini
    [[ -f "$CONFIG_DIR/google-calendar-credentials.json" ]] && auth_google_calendar
    [[ -f "$CONFIG_DIR/google-drive-credentials.json" ]] && auth_google_drive
    
    echo ""
    show_status
}

usage() {
    cat <<EOF
OpenClaw CLI Authentication Helper

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    --status                Show authentication status
    --all                   Authenticate all available services
    --claude                Authenticate Claude CLI only
    --gemini                Configure Gemini/Google API key
    --google-calendar       Authenticate Google Calendar OAuth
    --google-drive          Authenticate Google Drive OAuth
    --google                Authenticate both Google Calendar and Drive

Without options, shows authentication status.

EXAMPLES:
    $0 --status             # Check what's authenticated
    $0 --claude             # Authenticate Claude CLI
    $0 --all                # Authenticate everything

EOF
}

main() {
    if [[ $# -eq 0 ]]; then
        show_status
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --status)
                show_status
                shift
                ;;
            --all)
                run_all
                shift
                ;;
            --claude)
                auth_claude
                shift
                ;;
            --gemini)
                auth_gemini
                shift
                ;;
            --google-calendar)
                auth_google_calendar
                shift
                ;;
            --google-drive)
                auth_google_drive
                shift
                ;;
            --google)
                auth_google_calendar
                auth_google_drive
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

main "$@"
