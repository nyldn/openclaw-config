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
WORKSPACE_DIR="$HOME/.openclaw/workspace"
ENV_FILE="$WORKSPACE_DIR/.env"
VENV_DIR="$HOME/.local/venv/openclaw"

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

pass() {
    echo -e "  \033[0;32m✓\033[0m $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "  \033[0;31m✗\033[0m $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

skip() {
    echo -e "  \033[0;33m○\033[0m $1 (skipped)"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        # Validate .env contains only safe KEY=VALUE pairs
        if grep -qvE '^[[:space:]]*(#.*)?$|^[A-Za-z_][A-Za-z0-9_]*=.*$' "$ENV_FILE"; then
            log_error "Invalid content in .env file: $ENV_FILE"
            log_error "Only KEY=VALUE pairs and comments are allowed"
            return 1
        fi
        # Reject dangerous shell constructs
        if grep -qE '\$\(|`|;|\\|&&|\|\|' "$ENV_FILE"; then
            log_error "Suspicious content detected in .env file (shell constructs found)"
            return 1
        fi
        # Check file permissions
        local perms
        perms=$(stat -f "%OLp" "$ENV_FILE" 2>/dev/null || stat -c "%a" "$ENV_FILE" 2>/dev/null)
        if [[ "$perms" != "600" ]]; then
            log_warn ".env file permissions are $perms, should be 600. Fixing..."
            chmod 0600 "$ENV_FILE"
        fi
        set -a
        source "$ENV_FILE"
        set +a
    fi
}

validate_claude() {
    echo ""
    echo "Claude (Anthropic):"
    
    if command -v claude &>/dev/null; then
        local version
        version=$(claude --version 2>&1 | head -n1 || echo "unknown")
        pass "Claude CLI installed ($version)"
        
        if claude whoami &>/dev/null 2>&1; then
            pass "Claude CLI authenticated"
        else
            fail "Claude CLI not authenticated (run: claude login)"
        fi
    else
        skip "Claude CLI not installed"
    fi
    
    if [[ -n "${ANTHROPIC_API_KEY:-}" && "${ANTHROPIC_API_KEY}" != *"your-key"* ]]; then
        if [[ "${ANTHROPIC_API_KEY}" =~ ^sk-ant- ]]; then
            pass "Anthropic API key configured (format valid)"
            
            if [[ -f "$VENV_DIR/bin/activate" ]]; then
                source "$VENV_DIR/bin/activate" 2>/dev/null
                local test_result
                test_result=$(python3 -c "
import anthropic
import os
try:
    client = anthropic.Anthropic()
    # Just create client, don't make actual API call to avoid charges
    print('valid')
except Exception as e:
    print(f'error: {e}')
" 2>&1)
                deactivate 2>/dev/null || true
                
                if [[ "$test_result" == "valid" ]]; then
                    pass "Anthropic SDK initialized successfully"
                else
                    fail "Anthropic SDK error: $test_result"
                fi
            fi
        else
            fail "Anthropic API key format invalid (expected sk-ant-...)"
        fi
    else
        skip "Anthropic API key not configured"
    fi
}

validate_openai() {
    echo ""
    echo "OpenAI:"
    
    if [[ -n "${OPENAI_API_KEY:-}" && "${OPENAI_API_KEY}" != *"your-key"* ]]; then
        if [[ "${OPENAI_API_KEY}" =~ ^sk- ]]; then
            pass "OpenAI API key configured (format valid)"
            
            if [[ -f "$VENV_DIR/bin/activate" ]]; then
                source "$VENV_DIR/bin/activate" 2>/dev/null
                local test_result
                test_result=$(python3 -c "
import openai
try:
    client = openai.OpenAI()
    print('valid')
except Exception as e:
    print(f'error: {e}')
" 2>&1)
                deactivate 2>/dev/null || true
                
                if [[ "$test_result" == "valid" ]]; then
                    pass "OpenAI SDK initialized successfully"
                else
                    fail "OpenAI SDK error: $test_result"
                fi
            fi
        else
            fail "OpenAI API key format invalid (expected sk-...)"
        fi
    else
        skip "OpenAI API key not configured"
    fi
}

validate_gemini() {
    echo ""
    echo "Google Gemini:"
    
    if [[ -n "${GOOGLE_API_KEY:-}" && "${GOOGLE_API_KEY}" != *"your-key"* ]]; then
        pass "Google API key configured"
        
        if [[ -f "$VENV_DIR/bin/activate" ]]; then
            source "$VENV_DIR/bin/activate" 2>/dev/null
            local test_result
            test_result=$(python3 -c "
import google.generativeai as genai
import os
try:
    genai.configure(api_key=os.environ.get('GOOGLE_API_KEY'))
    print('valid')
except Exception as e:
    print(f'error: {e}')
" 2>&1)
            deactivate 2>/dev/null || true
            
            if [[ "$test_result" == "valid" ]]; then
                pass "Gemini SDK configured successfully"
            else
                fail "Gemini SDK error: $test_result"
            fi
        fi
    else
        skip "Google API key not configured"
    fi
    
    if command -v gcloud &>/dev/null; then
        local active_account
        active_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -n1)
        if [[ -n "$active_account" ]]; then
            pass "gcloud authenticated ($active_account)"
        else
            skip "gcloud not authenticated"
        fi
    fi
}

validate_github() {
    echo ""
    echo "GitHub:"
    
    if [[ -n "${GITHUB_PAT:-}" ]]; then
        if [[ "${GITHUB_PAT}" =~ ^gh[ps]_ ]]; then
            pass "GitHub PAT configured (format valid)"
            
            local test_result
            test_result=$(curl -s -o /dev/null -w "%{http_code}" \
                -H "Authorization: token ${GITHUB_PAT}" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/user" 2>/dev/null || echo "000")
            
            if [[ "$test_result" == "200" ]]; then
                pass "GitHub PAT validated successfully"
            elif [[ "$test_result" == "401" ]]; then
                fail "GitHub PAT is invalid or expired"
            else
                fail "GitHub API check failed (HTTP $test_result)"
            fi
        else
            fail "GitHub PAT format unusual (expected ghp_... or ghs_...)"
        fi
    else
        skip "GitHub PAT not configured"
    fi
}

validate_todoist() {
    echo ""
    echo "Todoist:"
    
    if [[ -n "${TODOIST_API_TOKEN:-}" ]]; then
        pass "Todoist API token configured"
        
        local test_result
        test_result=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer ${TODOIST_API_TOKEN}" \
            "https://api.todoist.com/rest/v2/projects" 2>/dev/null || echo "000")
        
        if [[ "$test_result" == "200" ]]; then
            pass "Todoist API validated successfully"
        elif [[ "$test_result" == "401" || "$test_result" == "403" ]]; then
            fail "Todoist token is invalid"
        else
            fail "Todoist API check failed (HTTP $test_result)"
        fi
    else
        skip "Todoist API token not configured"
    fi
}

validate_slack() {
    echo ""
    echo "Slack:"
    
    if [[ -n "${SLACK_BOT_TOKEN:-}" ]]; then
        if [[ "${SLACK_BOT_TOKEN}" =~ ^xoxb- ]]; then
            pass "Slack Bot token configured (format valid)"
            
            local test_result
            test_result=$(curl -s -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer ${SLACK_BOT_TOKEN}" \
                "https://slack.com/api/auth.test" 2>/dev/null || echo "000")
            
            if [[ "$test_result" == "200" ]]; then
                pass "Slack API accessible"
            else
                fail "Slack API check failed (HTTP $test_result)"
            fi
        else
            fail "Slack token format invalid (expected xoxb-...)"
        fi
    else
        skip "Slack Bot token not configured"
    fi
}

validate_google_services() {
    echo ""
    echo "Google Services:"
    
    if [[ -f "$CONFIG_DIR/google-calendar-credentials.json" ]]; then
        pass "Google Calendar credentials present"
        
        if [[ -f "$CONFIG_DIR/google-calendar-token.json" ]]; then
            pass "Google Calendar authenticated"
        else
            fail "Google Calendar not authenticated (run: openclaw-auth --google-calendar)"
        fi
    else
        skip "Google Calendar not configured"
    fi
    
    if [[ -f "$CONFIG_DIR/google-drive-credentials.json" ]]; then
        pass "Google Drive credentials present"
        
        if [[ -f "$CONFIG_DIR/google-drive-token.json" ]]; then
            pass "Google Drive authenticated"
        else
            fail "Google Drive not authenticated (run: openclaw-auth --google-drive)"
        fi
    else
        skip "Google Drive not configured"
    fi
}

validate_environment() {
    echo ""
    echo "Environment:"
    
    if [[ -f "$ENV_FILE" ]]; then
        pass "Environment file exists ($ENV_FILE)"
        
        local perms
        if [[ "$(uname)" == "Darwin" ]]; then
            perms=$(stat -f "%OLp" "$ENV_FILE" 2>/dev/null)
        else
            perms=$(stat -c "%a" "$ENV_FILE" 2>/dev/null)
        fi
        if [[ "$perms" == "600" ]]; then
            pass "Environment file has secure permissions (600)"
        else
            fail "Environment file permissions too open ($perms, should be 600)"
        fi
    else
        fail "Environment file not found"
    fi
    
    if [[ -d "$WORKSPACE_DIR" ]]; then
        pass "Workspace directory exists"
    else
        fail "Workspace directory not found"
    fi
    
    if [[ -d "$CONFIG_DIR" ]]; then
        pass "Config directory exists"
    else
        fail "Config directory not found"
    fi
    
    if [[ -f "$VENV_DIR/bin/activate" ]]; then
        pass "Python virtual environment exists"
    else
        fail "Python virtual environment not found"
    fi
}

validate_openclaw_doctor() {
    echo ""
    echo "OpenClaw Doctor:"

    if command -v openclaw &>/dev/null; then
        local doctor_log
        doctor_log=$(mktemp /tmp/openclaw-doctor-XXXXXX.log)
        if openclaw doctor 2>&1 | tee "$doctor_log" | grep -qi "error\|fail\|critical"; then
            fail "openclaw doctor reported issues (see $doctor_log)"
        else
            pass "openclaw doctor passed"
        fi
    else
        skip "openclaw CLI not installed"
    fi
}

validate_mcp_servers() {
    echo ""
    echo "MCP Servers:"
    
    local mcp_dir="$WORKSPACE_DIR/mcp-servers"
    local impl_dir="$(dirname "$SCRIPT_DIR")/../deployment-tools/mcp/implementations"
    
    local -a servers=("google-calendar-mcp.js" "google-drive-mcp.js" "todoist-mcp.js" "slack-mcp.js" "email-mcp.js")
    
    for server in "${servers[@]}"; do
        if [[ -f "$mcp_dir/$server" ]] || [[ -f "$impl_dir/$server" ]]; then
            pass "MCP server available: $server"
        else
            skip "MCP server not found: $server"
        fi
    done
}

show_summary() {
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo ""
    
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "  \033[0;32m✓ All checks passed!\033[0m"
    else
        echo -e "  \033[0;31m✗ Some checks failed\033[0m"
    fi
    
    echo ""
    echo "  Results: $TESTS_PASSED passed, $TESTS_FAILED failed, $TESTS_SKIPPED skipped"
    echo ""
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo "  To fix issues:"
        echo "    • Run: openclaw-setup  (configure credentials)"
        echo "    • Run: openclaw-auth   (authenticate services)"
        echo ""
    fi
}

usage() {
    cat <<EOF
OpenClaw Service Validation

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    --all               Validate all services (default)
    --llm               Validate AI/LLM services only
    --productivity      Validate productivity services only
    --env               Validate environment only
    --mcp               Validate MCP servers only
    --quiet             Only show failures

EXAMPLES:
    $0                  # Validate everything
    $0 --llm            # Check Claude, OpenAI, Gemini
    $0 --quiet          # Only show problems

EOF
}

main() {
    load_env
    
    local validate_all=true
    local quiet=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --all)
                validate_all=true
                shift
                ;;
            --llm)
                validate_all=false
                log_section "AI/LLM Validation"
                validate_claude
                validate_openai
                validate_gemini
                shift
                ;;
            --productivity)
                validate_all=false
                log_section "Productivity Services Validation"
                validate_github
                validate_todoist
                validate_slack
                validate_google_services
                shift
                ;;
            --env)
                validate_all=false
                log_section "Environment Validation"
                validate_environment
                shift
                ;;
            --mcp)
                validate_all=false
                log_section "MCP Server Validation"
                validate_mcp_servers
                shift
                ;;
            --quiet)
                quiet=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    if [[ "$validate_all" == "true" ]]; then
        log_section "OpenClaw Service Validation"
        
        validate_environment
        validate_claude
        validate_openai
        validate_gemini
        validate_github
        validate_todoist
        validate_slack
        validate_google_services
        validate_mcp_servers
        validate_openclaw_doctor
    fi
    
    show_summary
    
    [[ $TESTS_FAILED -eq 0 ]]
}

main "$@"
