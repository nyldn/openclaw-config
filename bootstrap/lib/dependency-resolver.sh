#!/bin/bash
#
# Dependency resolution engine for OpenClaw bootstrap
# Implements graph-based dependency resolution with topological sorting
# Compatible with bash 3.2+
#

set -euo pipefail

# Source required libraries
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/logger.sh"

#
# Get dependencies for a module
#
# Arguments:
#   $1 - Module file path
#
# Returns:
#   Space-separated list of dependencies
#
get_module_dependencies() {
    local module_file="$1"

    if [[ ! -f "$module_file" ]]; then
        return 0
    fi

    # Extract MODULE_DEPS from the file
    local deps
    deps=$(grep -E '^MODULE_DEPS=' "$module_file" 2>/dev/null || echo "")

    if [[ -z "$deps" ]]; then
        return 0
    fi

    # Parse the array: MODULE_DEPS=("dep1" "dep2") or MODULE_DEPS=(dep1 dep2)
    deps=$(echo "$deps" | sed 's/^MODULE_DEPS=(//' | sed 's/)$//' | tr -d '"' | tr -d "'")

    echo "$deps"
}

#
# Get module name from module file
#
# Arguments:
#   $1 - Module file path
#
# Returns:
#   Module name
#
get_module_name() {
    local module_file="$1"

    if [[ ! -f "$module_file" ]]; then
        return 1
    fi

    local name
    name=$(grep -E '^MODULE_NAME=' "$module_file" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")

    if [[ -z "$name" ]]; then
        # Fall back to filename
        name=$(basename "$module_file" .sh | sed 's/^[0-9]*-//')
    fi

    echo "$name"
}

#
# Find module file by name
#
# Arguments:
#   $1 - Module name
#   $2 - Modules directory
#
# Returns:
#   Module file path or empty string
#
find_module_file() {
    local module_name="$1"
    local modules_dir="$2"

    # Try direct match first
    local module_file
    for file in "$modules_dir"/*-"${module_name}".sh "$modules_dir"/"${module_name}".sh; do
        if [[ -f "$file" ]]; then
            echo "$file"
            return 0
        fi
    done

    # Try partial match
    for file in "$modules_dir"/*"${module_name}"*.sh; do
        if [[ -f "$file" ]]; then
            local found_name
            found_name=$(get_module_name "$file")
            if [[ "$found_name" == "$module_name" ]]; then
                echo "$file"
                return 0
            fi
        fi
    done

    return 1
}

#
# Resolve dependencies for a list of modules
# Returns modules in dependency order (dependencies first)
#
# Arguments:
#   $1 - Modules directory
#   $@ - List of module names
#
# Returns:
#   Space-separated list of modules in dependency order
#
resolve_dependencies() {
    local modules_dir="$1"
    shift
    local -a input_modules=("$@")

    local -a resolved=()
    local -a processing=()

    # Recursive function to resolve a module's dependencies
    resolve_module() {
        local module_name="$1"

        # Check if already resolved
        for resolved_mod in "${resolved[@]}"; do
            if [[ "$resolved_mod" == "$module_name" ]]; then
                return 0
            fi
        done

        # Check for circular dependency
        for proc_mod in "${processing[@]}"; do
            if [[ "$proc_mod" == "$module_name" ]]; then
                log_error "Circular dependency detected: $module_name"
                return 1
            fi
        done

        # Mark as processing
        processing+=("$module_name")

        # Find module file
        local module_file
        module_file=$(find_module_file "$module_name" "$modules_dir")

        if [[ -z "$module_file" ]]; then
            log_warn "Module not found: $module_name"
            return 0
        fi

        # Get dependencies
        local deps
        deps=$(get_module_dependencies "$module_file")

        # Resolve each dependency first
        if [[ -n "$deps" ]]; then
            local dep
            for dep in $deps; do
                resolve_module "$dep" || return 1
            done
        fi

        # Add this module to resolved list
        resolved+=("$module_name")

        # Remove from processing
        local -a new_processing=()
        for proc_mod in "${processing[@]}"; do
            if [[ "$proc_mod" != "$module_name" ]]; then
                new_processing+=("$proc_mod")
            fi
        done
        processing=("${new_processing[@]}")
    }

    # Resolve each input module
    for module in "${input_modules[@]}"; do
        resolve_module "$module" || return 1
    done

    # Return resolved modules as space-separated string
    echo "${resolved[@]}"
}

#
# Validate that all dependencies for a module are available
#
# Arguments:
#   $1 - Module file path
#   $2 - Modules directory
#
# Returns:
#   0 if all dependencies available, 1 otherwise
#
validate_dependencies() {
    local module_file="$1"
    local modules_dir="$2"

    local module_name
    module_name=$(get_module_name "$module_file")

    local deps
    deps=$(get_module_dependencies "$module_file")

    if [[ -z "$deps" ]]; then
        return 0
    fi

    local missing=()
    for dep in $deps; do
        local dep_file
        dep_file=$(find_module_file "$dep" "$modules_dir")

        if [[ -z "$dep_file" ]]; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Module $module_name has missing dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

#
# Auto-include dependencies for selected modules
#
# Arguments:
#   $1 - Modules directory
#   $@ - Selected module names
#
# Returns:
#   Space-separated list including all dependencies
#
auto_include_dependencies() {
    local modules_dir="$1"
    shift
    local -a selected=("$@")

    # Use resolve_dependencies to get the full list
    resolve_dependencies "$modules_dir" "${selected[@]}"
}
