#!/bin/bash
#
# Interactive menu system for OpenClaw bootstrap
# Provides user-friendly module selection with dependency resolution
#

set -euo pipefail

# Source required libraries
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/logger.sh"

# UI mode detection
UI_MODE=""
HAS_TTY=false

#
# Initialize interactive system
# Detects available UI tools and TTY capability
#
# Returns:
#   0 on success, 1 if not interactive
#
interactive_init() {
    log_debug "Initializing interactive system"

    # Check if we have a TTY
    if [[ -t 0 && -t 1 ]]; then
        HAS_TTY=true
        log_debug "TTY detected"
    else
        HAS_TTY=false
        log_debug "No TTY detected (non-interactive environment)"
        return 1
    fi

    # Detect available UI tools (in order of preference)
    if command -v dialog &> /dev/null; then
        UI_MODE="dialog"
        log_debug "Using dialog for UI"
    elif command -v whiptail &> /dev/null; then
        UI_MODE="whiptail"
        log_debug "Using whiptail for UI"
    else
        UI_MODE="simple"
        log_debug "Using simple prompts for UI"
    fi

    return 0
}

#
# Show welcome screen
#
show_welcome_screen() {
    local title="OpenClaw Bootstrap System"
    local message="Welcome to the OpenClaw interactive installer!

This wizard will help you select and install the components you need:

• System Dependencies (Required)
• Python Environment
• Node.js Environment
• AI CLI Tools (Claude, OpenAI, Gemini)
• Deployment Tools (Vercel, Netlify, Supabase)
• Development Tools
• Productivity Integrations
• Security Hardening

You can choose a preset or customize your installation."

    case "$UI_MODE" in
        dialog)
            dialog --title "$title" \
                   --msgbox "$message" 20 70
            ;;
        whiptail)
            whiptail --title "$title" \
                     --msgbox "$message" 20 70
            ;;
        simple)
            echo ""
            echo "═══════════════════════════════════════════════════════"
            echo "  $title"
            echo "═══════════════════════════════════════════════════════"
            echo ""
            echo "$message"
            echo ""
            read -p "Press Enter to continue..." -r
            ;;
    esac
}

#
# Show preset selection menu
#
# Outputs:
#   Selected preset name (minimal, developer, full, custom)
#
show_preset_menu() {
    local title="Installation Preset"
    local message="Choose an installation preset:"

    local -a presets=(
        "minimal" "Essential tools only (System deps, Python, Node.js)" \
        "developer" "Development environment (Minimal + AI CLIs + Dev tools)" \
        "full" "Complete installation (All modules including productivity)" \
        "custom" "Custom selection (Choose modules manually)"
    )

    case "$UI_MODE" in
        dialog)
            dialog --title "$title" \
                   --menu "$message" 20 70 10 \
                   "${presets[@]}" \
                   2>&1 >/dev/tty
            ;;
        whiptail)
            whiptail --title "$title" \
                     --menu "$message" 20 70 10 \
                     "${presets[@]}" \
                     3>&1 1>&2 2>&3
            ;;
        simple)
            echo ""
            echo "═══ Installation Preset ═══"
            echo ""
            echo "1) Minimal     - Essential tools only (System deps, Python, Node.js)"
            echo "2) Developer   - Development environment (Minimal + AI CLIs + Dev tools)"
            echo "3) Full        - Complete installation (All modules)"
            echo "4) Custom      - Choose modules manually"
            echo ""

            while true; do
                read -p "Select preset (1-4): " -r choice
                case "$choice" in
                    1) echo "minimal"; return 0 ;;
                    2) echo "developer"; return 0 ;;
                    3) echo "full"; return 0 ;;
                    4) echo "custom"; return 0 ;;
                    *) echo "Invalid choice. Please enter 1-4." ;;
                esac
            done
            ;;
    esac
}

#
# Show module selection menu (checkbox style)
#
# Arguments:
#   $@ - Array of available modules
#
# Outputs:
#   Space-separated list of selected module names
#
show_module_menu() {
    local -a available_modules=("$@")
    local title="Module Selection"
    local message="Select modules to install (use SPACE to select/deselect):"

    # Build menu items array for dialog/whiptail
    # Format: "module_name" "Description" "on/off"
    local -a menu_items=()

    for module in "${available_modules[@]}"; do
        local description
        description=$(get_module_description "$module")

        # System-deps is always required and preselected
        if [[ "$module" == "system-deps" ]]; then
            menu_items+=("$module" "$description" "on")
        else
            menu_items+=("$module" "$description" "off")
        fi
    done

    case "$UI_MODE" in
        dialog)
            dialog --title "$title" \
                   --checklist "$message" 20 70 10 \
                   "${menu_items[@]}" \
                   2>&1 >/dev/tty | tr -d '"'
            ;;
        whiptail)
            whiptail --title "$title" \
                     --checklist "$message" 20 70 10 \
                     "${menu_items[@]}" \
                     3>&1 1>&2 2>&3 | tr -d '"'
            ;;
        simple)
            echo ""
            echo "═══ Module Selection ═══"
            echo ""

            local -a selected=()
            local index=1

            for module in "${available_modules[@]}"; do
                local description
                description=$(get_module_description "$module")

                echo "$index) $module - $description"

                if [[ "$module" == "system-deps" ]]; then
                    selected+=("$module")
                    echo "   [REQUIRED - Auto-selected]"
                else
                    read -p "   Install this module? (y/N): " -r choice
                    if [[ "$choice" =~ ^[Yy]$ ]]; then
                        selected+=("$module")
                    fi
                fi

                echo ""
                index=$((index + 1))
            done

            echo "${selected[*]}"
            ;;
    esac
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
    local title="Installation Summary"

    local message="The following modules will be installed:

"
    for module in "${modules[@]}"; do
        local desc
        desc=$(get_module_description "$module")
        message+="• $module - $desc
"
    done

    message+="
Total modules: ${#modules[@]}

Estimated time: ~5-15 minutes (depending on selections)
"

    case "$UI_MODE" in
        dialog)
            if dialog --title "$title" \
                      --yesno "$message" 20 70; then
                return 0
            else
                return 1
            fi
            ;;
        whiptail)
            if whiptail --title "$title" \
                        --yesno "$message" 20 70; then
                return 0
            else
                return 1
            fi
            ;;
        simple)
            echo ""
            echo "═══════════════════════════════════════════════════════"
            echo "  Installation Summary"
            echo "═══════════════════════════════════════════════════════"
            echo ""
            echo "The following modules will be installed:"
            echo ""

            for module in "${modules[@]}"; do
                local desc
                desc=$(get_module_description "$module")
                echo "  • $module - $desc"
            done

            echo ""
            echo "Total modules: ${#modules[@]}"
            echo "Estimated time: ~5-15 minutes"
            echo ""

            while true; do
                read -p "Proceed with installation? (y/N): " -r choice
                case "$choice" in
                    [Yy]*) return 0 ;;
                    [Nn]*|"") return 1 ;;
                    *) echo "Please answer y or n." ;;
                esac
            done
            ;;
    esac
}

#
# Show module details
#
# Arguments:
#   $1 - Module name
#
show_module_details() {
    local module="$1"
    local title="Module Details: $module"

    local description
    description=$(get_module_description "$module")

    local deps
    deps=$(get_module_dependencies "$module")

    local size
    size=$(get_module_size "$module")

    local message="Description:
$description

Dependencies:
$deps

Estimated size: $size
"

    case "$UI_MODE" in
        dialog)
            dialog --title "$title" \
                   --msgbox "$message" 15 60
            ;;
        whiptail)
            whiptail --title "$title" \
                     --msgbox "$message" 15 60
            ;;
        simple)
            echo ""
            echo "═══ Module Details: $module ═══"
            echo ""
            echo "Description: $description"
            echo "Dependencies: $deps"
            echo "Estimated size: $size"
            echo ""
            read -p "Press Enter to continue..." -r
            ;;
    esac
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
