#!/usr/bin/env bash
#
# Simple CLI menu system for OpenClaw bootstrap
# Provides a fast, single-pass interactive selection flow
#

set -euo pipefail

# Source required libraries
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=logger.sh
source "${LIB_DIR}/logger.sh"

# TTY detection
HAS_TTY=false

#
# Initialize interactive system
# Returns:
#   0 on success, 1 if not interactive
#
interactive_init() {
    log_debug "Initializing interactive system"

    if [[ -t 0 && -t 1 ]]; then
        HAS_TTY=true
        log_debug "TTY detected"
        return 0
    fi

    HAS_TTY=false
    log_debug "No TTY detected (non-interactive environment)"
    return 1
}

#
# Show welcome screen
#
show_welcome_screen() {
    local title="OpenClaw Bootstrap"
    local message="Quick install wizard. Pick a preset or choose modules, then we run once."

    echo ""
    echo "========================================================"
    echo "  ${title}"
    echo "========================================================"
    echo "${message}"
    echo ""
}

#
# Show preset selection menu
#
# Outputs:
#   Selected preset name (minimal, developer, full, custom)
#
print_preset_menu() {
    local message="Choose an installation preset:"

    echo "${message}" >&2
    echo "" >&2
    echo "1) Minimal   - System deps, Python, Node.js" >&2
    echo "2) Developer - Minimal + AI CLIs + Dev tools" >&2
    echo "3) Full      - Everything" >&2
    echo "4) Custom    - Select modules" >&2
    echo "Q) Quit" >&2
    echo "" >&2
}

show_preset_menu() {
    print_preset_menu

    while true; do
        local choice
        read -r -p "Select preset [1-4/Q]: " choice
        choice="$(echo "${choice}" | tr '[:upper:]' '[:lower:]')"

        case "$choice" in
            1|minimal|m) echo "minimal"; return 0 ;;
            2|developer|dev|d) echo "developer"; return 0 ;;
            3|full|f) echo "full"; return 0 ;;
            4|custom|c) echo "custom"; return 0 ;;
            q|quit) return 1 ;;
            *)
                echo "Invalid choice. Enter 1-4 or Q." >&2
                print_preset_menu
                ;;
        esac
    done
}

#
# Show module selection menu (fast CLI)
#
# Arguments:
#   $@ - Array of available modules
#
# Outputs:
#   Space-separated list of selected module names
#
show_module_menu() {
    local -a available_modules=("$@")
    local count=${#available_modules[@]}

    print_module_menu() {
        echo "" >&2
        echo "Custom module selection" >&2
        echo "Enter numbers or names separated by spaces or commas." >&2
        echo "Examples: 1 2 5   or   python,nodejs,dev-tools" >&2
        echo "Type 'all' for everything, or 'q' to cancel." >&2
        echo "" >&2

        local i=1
        for module in "${available_modules[@]}"; do
            local description
            description=$(get_module_description "$module")
            if [[ "$module" == "system-deps" ]]; then
                printf "%2d) %-18s - %s (required)\n" "$i" "$module" "$description" >&2
            else
                printf "%2d) %-18s - %s\n" "$i" "$module" "$description" >&2
            fi
            i=$((i + 1))
        done

        echo "" >&2
    }

    print_module_menu

    while true; do
        local input
        read -r -p "Modules to install: " input
        input="$(echo "${input}" | tr ',' ' ')"

        if [[ -z "$input" ]]; then
            echo "Please select at least one module." >&2
            continue
        fi

        if [[ "$input" == "q" || "$input" == "Q" ]]; then
            return 1
        fi

        local -a selected=()
        local valid=true

        for token in $input; do
            local item="$token"
            item="$(echo "${item}" | tr '[:upper:]' '[:lower:]')"

            if [[ "$item" == "all" ]]; then
                echo "${available_modules[*]}"
                return 0
            fi

            if [[ "$item" =~ ^[0-9]+$ ]]; then
                if (( item < 1 || item > count )); then
                    echo "Invalid index: $item" >&2
                    valid=false
                    break
                fi
                local module_name="${available_modules[$((item - 1))]}"
                if ! array_contains "$module_name" "${selected[@]}"; then
                    selected+=("$module_name")
                fi
            else
                if ! array_contains "$item" "${available_modules[@]}"; then
                    echo "Unknown module: $item" >&2
                    valid=false
                    break
                fi
                if ! array_contains "$item" "${selected[@]}"; then
                    selected+=("$item")
                fi
            fi
        done

        if [[ "$valid" != "true" ]]; then
            echo "Try again." >&2
            print_module_menu
            continue
        fi

        # Always include system-deps
        if ! array_contains "system-deps" "${selected[@]}"; then
            selected=("system-deps" "${selected[@]}")
        fi

        # Preserve module order from available_modules
        local -a ordered=()
        for module in "${available_modules[@]}"; do
            if array_contains "$module" "${selected[@]}"; then
                ordered+=("$module")
            fi
        done

        if [[ ${#ordered[@]} -eq 0 ]]; then
            echo "No modules selected." >&2
            print_module_menu
            continue
        fi

        echo "${ordered[*]}"
        return 0
    done
}

#
# Get module description
#
# Arguments:
#   $1 - Module name
#
# Outputs:
#   Module description
#
get_module_description() {
    local module="$1"

    case "$module" in
        system-deps) echo "System dependencies (git, curl, build tools)" ;;
        python) echo "Python 3.9+ with virtual environment" ;;
        nodejs) echo "Node.js 20+ with npm" ;;
        claude-cli) echo "Claude Code CLI (Anthropic)" ;;
        codex-cli) echo "OpenAI CLI (GPT-4, GPT-3.5)" ;;
        gemini-cli) echo "Google Gemini CLI" ;;
        openclaw-env) echo "OpenClaw environment configuration" ;;
        memory-init) echo "SQLite-based memory system" ;;
        claude-octopus) echo "Multi-AI orchestration system" ;;
        deployment-tools) echo "Vercel, Netlify, Supabase CLIs" ;;
        dev-tools) echo "Development utilities and tools" ;;
        auto-updates) echo "Automated daily updates" ;;
        security) echo "SSH hardening, firewall, fail2ban" ;;
        openclaw) echo "OpenClaw AI assistant (optional)" ;;
        productivity-tools) echo "Calendar, Email, Tasks, Slack integration" ;;
        *) echo "Unknown module" ;;
    esac
}

#
# Get preset modules
#
# Arguments:
#   $1 - Preset name (minimal, developer, full)
#
# Outputs:
#   Space-separated list of module names
#
get_preset_modules() {
    local preset="$1"

    case "$preset" in
        minimal)
            echo "system-deps python nodejs"
            ;;
        developer)
            echo "system-deps python nodejs claude-cli codex-cli gemini-cli dev-tools memory-init"
            ;;
        full)
            echo "system-deps python nodejs claude-cli codex-cli gemini-cli openclaw-env memory-init claude-octopus deployment-tools dev-tools auto-updates security productivity-tools"
            ;;
        *)
            echo ""
            ;;
    esac
}

#
# Show installation summary
#
# Arguments:
#   $@ - Array of modules to install
#
# Returns:
#   0 if user confirms, 1 if user cancels
#
confirm_installation() {
    local -a modules=("$@")

    echo ""
    echo "Installation summary:"
    echo ""

    for module in "${modules[@]}"; do
        local desc
        desc=$(get_module_description "$module")
        echo "- $module: $desc"
    done

    echo ""
    echo "Total modules: ${#modules[@]}"
    echo "Estimated time: ~5-15 minutes"
    echo ""

    while true; do
        local choice
        read -r -p "Proceed with installation? (y/N): " choice
        case "$choice" in
            [Yy]*) return 0 ;;
            [Nn]*|"") return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

#
# Show module details
#
# Arguments:
#   $1 - Module name
#
show_module_details() {
    local module="$1"

    local description
    description=$(get_module_description "$module")

    local deps
    deps=$(get_module_dependencies "$module")

    local size
    size=$(get_module_size "$module")

    echo ""
    echo "Module: $module"
    echo "Description: $description"
    echo "Dependencies: $deps"
    echo "Estimated size: $size"
    echo ""
    read -r -p "Press Enter to continue..." _
}

#
# Get module dependencies
#
# Arguments:
#   $1 - Module name
#
# Outputs:
#   Space-separated list of dependency module names
#
get_module_dependencies() {
    local module="$1"

    case "$module" in
        python) echo "system-deps" ;;
        nodejs) echo "system-deps" ;;
        claude-cli) echo "system-deps python nodejs" ;;
        codex-cli) echo "system-deps python" ;;
        gemini-cli) echo "system-deps python" ;;
        openclaw-env) echo "system-deps python nodejs" ;;
        memory-init) echo "system-deps python" ;;
        claude-octopus) echo "system-deps python nodejs" ;;
        deployment-tools) echo "system-deps nodejs" ;;
        dev-tools) echo "system-deps" ;;
        auto-updates) echo "system-deps" ;;
        security) echo "system-deps" ;;
        openclaw) echo "system-deps python nodejs openclaw-env" ;;
        productivity-tools) echo "system-deps nodejs deployment-tools" ;;
        *) echo "None" ;;
    esac
}

#
# Get estimated module size
#
# Arguments:
#   $1 - Module name
#
# Outputs:
#   Size estimate
#
get_module_size() {
    local module="$1"

    case "$module" in
        system-deps) echo "~50MB" ;;
        python) echo "~100MB" ;;
        nodejs) echo "~80MB" ;;
        claude-cli) echo "~200MB" ;;
        codex-cli) echo "~150MB" ;;
        gemini-cli) echo "~150MB" ;;
        openclaw-env) echo "~20MB" ;;
        memory-init) echo "~10MB" ;;
        claude-octopus) echo "~100MB" ;;
        deployment-tools) echo "~300MB" ;;
        dev-tools) echo "~50MB" ;;
        auto-updates) echo "~5MB" ;;
        security) echo "~30MB" ;;
        openclaw) echo "~500MB" ;;
        productivity-tools) echo "~100MB" ;;
        *) echo "Unknown" ;;
    esac
}

#
# Helpers
#
array_contains() {
    local seeking="$1"
    shift
    local item
    for item in "$@"; do
        if [[ "$item" == "$seeking" ]]; then
            return 0
        fi
    done
    return 1
}

# Export functions
export -f interactive_init
export -f show_welcome_screen
export -f show_preset_menu
export -f show_module_menu
export -f get_module_description
export -f get_preset_modules
export -f confirm_installation
export -f show_module_details
export -f get_module_dependencies
export -f get_module_size
