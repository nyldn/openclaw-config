#!/usr/bin/env bash

# Logger utility for OpenClaw bootstrap system
# Provides color-coded logging and progress tracking

# Color codes
COLOR_RESET='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_GRAY='\033[0;90m'

# Log symbols
SYMBOL_SUCCESS="✓"
SYMBOL_ERROR="✗"
SYMBOL_PROGRESS="→"
SYMBOL_WARNING="!"
SYMBOL_INFO="i"

# Log level
LOG_LEVEL="${LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARN, ERROR
VERBOSE="${VERBOSE:-false}"

# Log file path
LOG_FILE=""

# Initialize logger
# Usage: logger_init [log_file_path]
logger_init() {
    local log_dir="${1:-bootstrap/logs}"
    local timestamp
    timestamp=$(date +"%Y-%m-%d-%H-%M-%S")

    # Create log directory with restrictive permissions
    mkdir -p "$log_dir"
    chmod 0700 "$log_dir"

    LOG_FILE="$log_dir/bootstrap-$timestamp.log"

    # Create log file with restrictive permissions (owner read/write only)
    touch "$LOG_FILE"
    chmod 0600 "$LOG_FILE"

    log_info "Logging initialized: $LOG_FILE"
}

# Sanitize sensitive information from log messages
# Usage: log_sanitize "message"
log_sanitize() {
    local message="$1"

    # Redact common secret patterns
    # API keys, tokens, passwords, secrets
    message=$(echo "$message" | sed -E \
        -e 's/(api[_-]?key|apikey)[[:space:]]*[=:][[:space:]]*['\''"]?[a-zA-Z0-9_-]{10,}['\''"]?/\1=***REDACTED***/gi' \
        -e 's/(token|access[_-]?token)[[:space:]]*[=:][[:space:]]*['\''"]?[a-zA-Z0-9._-]{10,}['\''"]?/\1=***REDACTED***/gi' \
        -e 's/(password|passwd|pwd)[[:space:]]*[=:][[:space:]]*['\''"]?[^[:space:]'\''\"]{6,}['\''"]?/\1=***REDACTED***/gi' \
        -e 's/(secret|secret[_-]?key)[[:space:]]*[=:][[:space:]]*['\''"]?[a-zA-Z0-9_-]{10,}['\''"]?/\1=***REDACTED***/gi')

    # Redact specific secret formats
    # Anthropic API keys (sk-ant-...)
    message=$(echo "$message" | sed -E 's/sk-ant-[a-zA-Z0-9_-]{95,}/***REDACTED_ANTHROPIC_KEY***/g')

    # OpenAI API keys (sk-...)
    message=$(echo "$message" | sed -E 's/sk-[a-zA-Z0-9]{48}/***REDACTED_OPENAI_KEY***/g')

    # GitHub tokens (ghp_..., gho_..., ghs_...)
    message=$(echo "$message" | sed -E 's/gh[pso]_[a-zA-Z0-9]{36,}/***REDACTED_GITHUB_TOKEN***/g')

    # Slack tokens (xox[bpa]-...)
    message=$(echo "$message" | sed -E 's/xox[bpa]-[a-zA-Z0-9-]+/***REDACTED_SLACK_TOKEN***/g')

    # AWS access keys
    message=$(echo "$message" | sed -E 's/AKIA[A-Z0-9]{16}/***REDACTED_AWS_KEY***/g')

    # JWT tokens (header.payload.signature)
    message=$(echo "$message" | sed -E 's/eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+/***REDACTED_JWT***/g')

    # Bearer tokens
    message=$(echo "$message" | sed -E 's/Bearer[[:space:]]+[a-zA-Z0-9._-]{20,}/Bearer ***REDACTED***/gi')

    # URLs with embedded credentials (https://user:pass@host)
    message=$(echo "$message" | sed -E 's|(https?://)([^:]+):([^@]+)@|\1***REDACTED***:***REDACTED***@|g')

    # Credit card numbers (simple pattern)
    message=$(echo "$message" | sed -E 's/[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}[- ]?[0-9]{4}/****-****-****-****/g')

    echo "$message"
}

# Write to log file
_log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Sanitize message before writing to log
    local sanitized_message
    sanitized_message=$(log_sanitize "$message")

    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $sanitized_message" >> "$LOG_FILE"
    fi
}

# Log success message
# Usage: log_success "message"
log_success() {
    local message="$1"
    local sanitized
    sanitized=$(log_sanitize "$message")
    echo -e "${COLOR_GREEN}[${SYMBOL_SUCCESS}]${COLOR_RESET} $sanitized"
    _log_to_file "SUCCESS" "$message"
}

# Log error message
# Usage: log_error "message"
log_error() {
    local message="$1"
    local sanitized
    sanitized=$(log_sanitize "$message")
    echo -e "${COLOR_RED}[${SYMBOL_ERROR}]${COLOR_RESET} $sanitized" >&2
    _log_to_file "ERROR" "$message"
}

# Log warning message
# Usage: log_warn "message"
log_warn() {
    local message="$1"
    local sanitized
    sanitized=$(log_sanitize "$message")
    echo -e "${COLOR_YELLOW}[${SYMBOL_WARNING}]${COLOR_RESET} $sanitized"
    _log_to_file "WARN" "$message"
}

# Log info message
# Usage: log_info "message"
log_info() {
    local message="$1"
    local sanitized
    sanitized=$(log_sanitize "$message")
    echo -e "${COLOR_BLUE}[${SYMBOL_INFO}]${COLOR_RESET} $sanitized"
    _log_to_file "INFO" "$message"
}

# Log progress message
# Usage: log_progress "message"
log_progress() {
    local message="$1"
    local sanitized
    sanitized=$(log_sanitize "$message")
    echo -e "${COLOR_CYAN}[${SYMBOL_PROGRESS}]${COLOR_RESET} $sanitized"
    _log_to_file "PROGRESS" "$message"
}

# Log debug message (only shown in verbose mode)
# Usage: log_debug "message"
log_debug() {
    local message="$1"
    _log_to_file "DEBUG" "$message"

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${COLOR_GRAY}[DEBUG]${COLOR_RESET} $message"
    fi
}

# Log command execution
# Usage: log_cmd "command"
log_cmd() {
    local cmd="$1"
    log_debug "Executing: $cmd"
    _log_to_file "CMD" "$cmd"
}

# Section header
# Usage: log_section "Section Title"
log_section() {
    local title="$1"
    echo ""
    echo -e "${COLOR_CYAN}═══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_CYAN}  $title${COLOR_RESET}"
    echo -e "${COLOR_CYAN}═══════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    _log_to_file "SECTION" "$title"
}

# Progress bar
# Usage: log_progress_bar current total
log_progress_bar() {
    local current="$1"
    local total="$2"
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r${COLOR_CYAN}["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] %3d%% (%d/%d)${COLOR_RESET}" "$percentage" "$current" "$total"

    if [[ "$current" -eq "$total" ]]; then
        echo ""
    fi
}

# Export functions
export -f logger_init
export -f log_sanitize
export -f log_success
export -f log_error
export -f log_warn
export -f log_info
export -f log_progress
export -f log_debug
export -f log_cmd
export -f log_section
export -f log_progress_bar
