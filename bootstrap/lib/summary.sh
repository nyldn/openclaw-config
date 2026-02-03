#!/usr/bin/env bash

# Installation Summary Generation
# Tracks installation progress and generates summary reports

set -euo pipefail

# Global arrays to track installation
declare -g -a SUMMARY_MODULES_SUCCESS=()
declare -g -a SUMMARY_MODULES_FAILED=()
declare -g -a SUMMARY_MODULES_SKIPPED=()
declare -g -A SUMMARY_MODULE_TIMES=()
declare -g -A SUMMARY_MODULE_LOGS=()
declare -g SUMMARY_START_TIME=""
declare -g SUMMARY_END_TIME=""
declare -g SUMMARY_PRESET=""
declare -g SUMMARY_SELECTED_MODULES=()
declare -g SUMMARY_STATUS="completed"
declare -g SUMMARY_STATUS_REASON=""

#
# Initialize summary tracking
#
summary_init() {
    SUMMARY_START_TIME=$(date +%s)
    SUMMARY_MODULES_SUCCESS=()
    SUMMARY_MODULES_FAILED=()
    SUMMARY_MODULES_SKIPPED=()
    declare -g -A SUMMARY_MODULE_TIMES=()
    declare -g -A SUMMARY_MODULE_LOGS=()
    SUMMARY_PRESET=""
    SUMMARY_SELECTED_MODULES=()
    SUMMARY_STATUS="completed"
    SUMMARY_STATUS_REASON=""
}

#
# Record module start
#
# Arguments:
#   $1 - Module name
#
summary_module_start() {
    local module="$1"
    SUMMARY_MODULE_TIMES["${module}_start"]=$(date +%s)
}

#
# Record module success
#
# Arguments:
#   $1 - Module name
#
summary_module_success() {
    local module="$1"
    local end_time
    end_time=$(date +%s)
    SUMMARY_MODULE_TIMES["${module}_end"]=$end_time

    local start_time=${SUMMARY_MODULE_TIMES["${module}_start"]:-$end_time}
    local duration=$((end_time - start_time))
    SUMMARY_MODULE_TIMES["${module}_duration"]=$duration

    SUMMARY_MODULES_SUCCESS+=("$module")
}

#
# Record module failure
#
# Arguments:
#   $1 - Module name
#
summary_module_failed() {
    local module="$1"
    local end_time
    end_time=$(date +%s)
    SUMMARY_MODULE_TIMES["${module}_end"]=$end_time

    local start_time=${SUMMARY_MODULE_TIMES["${module}_start"]:-$end_time}
    local duration=$((end_time - start_time))
    SUMMARY_MODULE_TIMES["${module}_duration"]=$duration

    SUMMARY_MODULES_FAILED+=("$module")
}

#
# Record module skipped
#
# Arguments:
#   $1 - Module name
#
summary_module_skipped() {
    local module="$1"
    SUMMARY_MODULES_SKIPPED+=("$module")
}

#
# Record module log path
#
# Arguments:
#   $1 - Module name
#   $2 - Log file path
#
summary_module_log() {
    local module="$1"
    local log_path="$2"
    SUMMARY_MODULE_LOGS["$module"]="$log_path"
}

#
# Record preset selection (if any)
#
# Arguments:
#   $1 - Preset name
#
summary_set_preset() {
    SUMMARY_PRESET="$1"
}

#
# Record selected modules
#
# Arguments:
#   $@ - Module names
#
summary_set_selected_modules() {
    SUMMARY_SELECTED_MODULES=("$@")
}

#
# Mark summary as interrupted
#
# Arguments:
#   $1 - Reason (e.g., SIGINT)
#
summary_set_interrupted() {
    SUMMARY_STATUS="interrupted"
    SUMMARY_STATUS_REASON="$1"
}

#
# Format duration in human-readable form
#
# Arguments:
#   $1 - Duration in seconds
#
# Outputs:
#   Formatted duration string
#
format_duration() {
    local total_seconds="$1"
    local minutes=$((total_seconds / 60))
    local seconds=$((total_seconds % 60))

    if [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" "$minutes" "$seconds"
    else
        printf "%ds" "$seconds"
    fi
}

#
# Generate and display installation summary
#
summary_show() {
    SUMMARY_END_TIME=$(date +%s)
    local total_duration=$((SUMMARY_END_TIME - SUMMARY_START_TIME))

    # Source logger if not already loaded
    if ! declare -f log_section &>/dev/null; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # shellcheck source=./logger.sh
        source "$SCRIPT_DIR/logger.sh"
    fi

    echo "" >&2
    log_section "Installation Summary"

    if [[ "$SUMMARY_STATUS" != "completed" ]]; then
        log_warn "Status: $SUMMARY_STATUS (${SUMMARY_STATUS_REASON})"
    fi

    if [[ -n "$SUMMARY_PRESET" ]]; then
        log_info "Preset: $SUMMARY_PRESET"
    fi

    if [[ ${#SUMMARY_SELECTED_MODULES[@]} -gt 0 ]]; then
        log_info "Selected modules: ${SUMMARY_SELECTED_MODULES[*]}"
    fi

    # Success count
    if [[ ${#SUMMARY_MODULES_SUCCESS[@]} -gt 0 ]]; then
        log_success "Modules installed successfully (${#SUMMARY_MODULES_SUCCESS[@]}):"
        for module in "${SUMMARY_MODULES_SUCCESS[@]}"; do
            local duration=${SUMMARY_MODULE_TIMES["${module}_duration"]:-0}
            local formatted
            formatted=$(format_duration "$duration")
            echo "  ✓ $module ($formatted)" >&2
        done
        echo "" >&2
    fi

    # Failure count
    if [[ ${#SUMMARY_MODULES_FAILED[@]} -gt 0 ]]; then
        log_warn "Modules that failed (${#SUMMARY_MODULES_FAILED[@]}):"
        for module in "${SUMMARY_MODULES_FAILED[@]}"; do
            local duration=${SUMMARY_MODULE_TIMES["${module}_duration"]:-0}
            local formatted
            formatted=$(format_duration "$duration")
            local module_log="${SUMMARY_MODULE_LOGS[$module]:-}"
            if [[ -n "$module_log" ]]; then
                echo "  ✗ $module ($formatted) - log: $module_log" >&2
            else
                echo "  ✗ $module ($formatted)" >&2
            fi
        done
        echo "" >&2
        log_info "Retry failed modules:"
        echo "  ./bootstrap.sh --only $(IFS=,; echo "${SUMMARY_MODULES_FAILED[*]}")" >&2
        echo "" >&2
    fi

    # Skipped count
    if [[ ${#SUMMARY_MODULES_SKIPPED[@]} -gt 0 ]]; then
        log_info "Modules skipped (${#SUMMARY_MODULES_SKIPPED[@]}):"
        for module in "${SUMMARY_MODULES_SKIPPED[@]}"; do
            echo "  ⊘ $module (already installed)" >&2
        done
        echo "" >&2
    fi

    # Total time
    local formatted_total
    formatted_total=$(format_duration "$total_duration")
    log_info "Total installation time: $formatted_total"

    # Save summary to file
    local summary_file="$SCRIPT_DIR/../logs/install-summary-$(date +%Y%m%d-%H%M%S).txt"
    if [[ -n "${SCRIPT_DIR:-}" ]]; then
        summary_save "$summary_file"
        log_info "Summary saved to: $summary_file"
    fi
}

#
# Save summary to file
#
# Arguments:
#   $1 - Output file path
#
summary_save() {
    local output_file="$1"

    mkdir -p "$(dirname "$output_file")"

    {
        echo "OpenClaw Bootstrap Installation Summary"
        echo "========================================"
        echo ""
        echo "Date: $(date)"
        echo "Status: $SUMMARY_STATUS${SUMMARY_STATUS_REASON:+ (${SUMMARY_STATUS_REASON})}"
        echo "Total Duration: $(format_duration $((SUMMARY_END_TIME - SUMMARY_START_TIME)))"
        if [[ -n "$SUMMARY_PRESET" ]]; then
            echo "Preset: $SUMMARY_PRESET"
        fi
        if [[ ${#SUMMARY_SELECTED_MODULES[@]} -gt 0 ]]; then
            echo "Selected Modules: ${SUMMARY_SELECTED_MODULES[*]}"
        fi
        echo ""

        if [[ ${#SUMMARY_MODULES_SUCCESS[@]} -gt 0 ]]; then
            echo "Successfully Installed (${#SUMMARY_MODULES_SUCCESS[@]}):"
            for module in "${SUMMARY_MODULES_SUCCESS[@]}"; do
                local duration=${SUMMARY_MODULE_TIMES["${module}_duration"]:-0}
                printf "  ✓ %-30s %s\n" "$module" "$(format_duration "$duration")"
            done
            echo ""
        fi

        if [[ ${#SUMMARY_MODULES_FAILED[@]} -gt 0 ]]; then
            echo "Failed (${#SUMMARY_MODULES_FAILED[@]}):"
            for module in "${SUMMARY_MODULES_FAILED[@]}"; do
                local duration=${SUMMARY_MODULE_TIMES["${module}_duration"]:-0}
                local module_log="${SUMMARY_MODULE_LOGS[$module]:-}"
                if [[ -n "$module_log" ]]; then
                    printf "  ✗ %-30s %s (log: %s)\n" "$module" "$(format_duration "$duration")" "$module_log"
                else
                    printf "  ✗ %-30s %s\n" "$module" "$(format_duration "$duration")"
                fi
            done
            echo ""
            echo "Retry Command:"
            echo "  ./bootstrap.sh --only $(IFS=,; echo "${SUMMARY_MODULES_FAILED[*]}")"
            echo ""
        fi

        if [[ ${#SUMMARY_MODULES_SKIPPED[@]} -gt 0 ]]; then
            echo "Skipped (${#SUMMARY_MODULES_SKIPPED[@]}):"
            for module in "${SUMMARY_MODULES_SKIPPED[@]}"; do
                printf "  ⊘ %-30s %s\n" "$module" "(already installed)"
            done
            echo ""
        fi
    } > "$output_file"
}

# Export functions
export -f summary_init
export -f summary_module_start
export -f summary_module_success
export -f summary_module_failed
export -f summary_module_skipped
export -f summary_module_log
export -f summary_set_preset
export -f summary_set_selected_modules
export -f summary_set_interrupted
export -f summary_show
export -f summary_save
export -f format_duration
