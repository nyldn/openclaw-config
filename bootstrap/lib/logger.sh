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

    mkdir -p "$log_dir"
    LOG_FILE="$log_dir/bootstrap-$timestamp.log"

    log_info "Logging initialized: $LOG_FILE"
}

# Write to log file
_log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    if [[ -n "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Log success message
# Usage: log_success "message"
log_success() {
    local message="$1"
    echo -e "${COLOR_GREEN}[${SYMBOL_SUCCESS}]${COLOR_RESET} $message"
    _log_to_file "SUCCESS" "$message"
}

# Log error message
# Usage: log_error "message"
log_error() {
    local message="$1"
    echo -e "${COLOR_RED}[${SYMBOL_ERROR}]${COLOR_RESET} $message" >&2
    _log_to_file "ERROR" "$message"
}

# Log warning message
# Usage: log_warn "message"
log_warn() {
    local message="$1"
    echo -e "${COLOR_YELLOW}[${SYMBOL_WARNING}]${COLOR_RESET} $message"
    _log_to_file "WARN" "$message"
}

# Log info message
# Usage: log_info "message"
log_info() {
    local message="$1"
    echo -e "${COLOR_BLUE}[${SYMBOL_INFO}]${COLOR_RESET} $message"
    _log_to_file "INFO" "$message"
}

# Log progress message
# Usage: log_progress "message"
log_progress() {
    local message="$1"
    echo -e "${COLOR_CYAN}[${SYMBOL_PROGRESS}]${COLOR_RESET} $message"
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
export -f log_success
export -f log_error
export -f log_warn
export -f log_info
export -f log_progress
export -f log_debug
export -f log_cmd
export -f log_section
export -f log_progress_bar
