#!/bin/bash
#
# Dependency resolution engine for OpenClaw bootstrap
# Implements graph-based dependency resolution with topological sorting
#

set -euo pipefail

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

# Dependency graph (associative array)
declare -gA DEPENDENCY_GRAPH=()

#
# Build dependency graph from module files
#
# Arguments:
#   $@ - Array of module file paths
#
# Returns:
#   0 on success, 1 on failure
#
build_dependency_graph() {
    local -a module_files=("$@")

    log_debug "Building dependency graph from ${#module_files[@]} modules"

    for module_file in "${module_files[@]}"; do
        if [[ ! -f "$module_file" ]]; then
            log_warn "Module file not found: $module_file"
            continue
        fi

        # Extract MODULE_NAME and MODULE_DEPS from the file
        local module_name
        local module_deps

        module_name=$(grep -E '^MODULE_NAME=' "$module_file" | cut -d'=' -f2 | tr -d '"' || echo "")
        module_deps=$(grep -E '^MODULE_DEPS=' "$module_file" | sed 's/^MODULE_DEPS=(//' | sed 's/)$//' | tr -d '"' || echo "")

        if [[ -z "$module_name" ]]; then
            log_warn "Could not extract MODULE_NAME from: $module_file"
            continue
        fi

        # Store dependencies in graph (space-separated string)
        DEPENDENCY_GRAPH["$module_name"]="$module_deps"

        log_debug "Added to graph: $module_name -> [$module_deps]"
    done

    log_success "Dependency graph built with ${#DEPENDENCY_GRAPH[@]} modules"
    return 0
}

#
# Resolve dependencies for a set of modules
# Performs topological sort to determine installation order
#
# Arguments:
#   $@ - Array of selected module names
#
# Outputs:
#   Space-separated list of modules in installation order (dependencies first)
#
# Returns:
#   0 on success, 1 on circular dependency
#
resolve_dependencies() {
    local -a selected_modules=("$@")

    log_debug "Resolving dependencies for: ${selected_modules[*]}"

    # Collect all required modules (including transitive dependencies)
    local -A all_required=()
    local -a to_process=("${selected_modules[@]}")

    while [[ ${#to_process[@]} -gt 0 ]]; do
        local current="${to_process[0]}"
        to_process=("${to_process[@]:1}")  # Remove first element

        # Skip if already processed
        if [[ -n "${all_required[$current]:-}" ]]; then
            continue
        fi

        # Mark as required
        all_required["$current"]=1

        # Get dependencies for this module
        local deps="${DEPENDENCY_GRAPH[$current]:-}"

        if [[ -n "$deps" ]]; then
            # Add dependencies to processing queue
            for dep in $deps; do
                if [[ -z "${all_required[$dep]:-}" ]]; then
                    to_process+=("$dep")
                fi
            done
        fi
    done

    log_debug "Total modules required (with dependencies): ${#all_required[@]}"

    # Perform topological sort
    local -a sorted_modules
    if ! sorted_modules=($(topological_sort "${!all_required[@]}")); then
        log_error "Topological sort failed (circular dependency detected)"
        return 1
    fi

    # Output sorted modules
    echo "${sorted_modules[*]}"
    return 0
}

#
# Topological sort using Kahn's algorithm
#
# Arguments:
#   $@ - Array of module names to sort
#
# Outputs:
#   Space-separated list of modules in topological order
#
# Returns:
#   0 on success, 1 on circular dependency
#
topological_sort() {
    local -a modules=("$@")

    log_debug "Performing topological sort on ${#modules[@]} modules"

    # Calculate in-degree for each module
    declare -A in_degree=()
    declare -A adjacency_list=()

    # Initialize in-degree to 0
    for module in "${modules[@]}"; do
        in_degree["$module"]=0
        adjacency_list["$module"]=""
    done

    # Build adjacency list and calculate in-degrees
    for module in "${modules[@]}"; do
        local deps="${DEPENDENCY_GRAPH[$module]:-}"

        if [[ -n "$deps" ]]; then
            for dep in $deps; do
                # Only consider dependencies that are in our module set
                if [[ -n "${in_degree[$dep]:-}" ]]; then
                    # dep -> module edge
                    adjacency_list["$dep"]+=" $module"
                    in_degree["$module"]=$((in_degree["$module"] + 1))
                fi
            done
        fi
    done

    # Find all modules with in-degree 0
    local -a queue=()
    for module in "${modules[@]}"; do
        if [[ ${in_degree["$module"]} -eq 0 ]]; then
            queue+=("$module")
        fi
    done

    # Process queue
    local -a sorted=()

    while [[ ${#queue[@]} -gt 0 ]]; do
        local current="${queue[0]}"
        queue=("${queue[@]:1}")  # Remove first element

        sorted+=("$current")

        # Process neighbors
        local neighbors="${adjacency_list[$current]:-}"
        if [[ -n "$neighbors" ]]; then
            for neighbor in $neighbors; do
                in_degree["$neighbor"]=$((in_degree["$neighbor"] - 1))

                if [[ ${in_degree["$neighbor"]} -eq 0 ]]; then
                    queue+=("$neighbor")
                fi
            done
        fi
    done

    # Check if all modules were sorted (no circular dependencies)
    if [[ ${#sorted[@]} -ne ${#modules[@]} ]]; then
        log_error "Circular dependency detected!"
        log_error "Sorted ${#sorted[@]} out of ${#modules[@]} modules"
        return 1
    fi

    log_debug "Topological sort complete: ${sorted[*]}"

    # Output sorted modules
    echo "${sorted[*]}"
    return 0
}

#
# Validate selected modules have all required dependencies
#
# Arguments:
#   $@ - Array of selected module names
#
# Returns:
#   0 if all dependencies satisfied, 1 if missing dependencies
#
validate_dependencies() {
    local -a selected_modules=("$@")

    log_debug "Validating dependencies for: ${selected_modules[*]}"

    local all_valid=true

    for module in "${selected_modules[@]}"; do
        local deps="${DEPENDENCY_GRAPH[$module]:-}"

        if [[ -n "$deps" ]]; then
            for dep in $deps; do
                # Check if dependency is in selected modules
                local found=false
                for selected in "${selected_modules[@]}"; do
                    if [[ "$dep" == "$selected" ]]; then
                        found=true
                        break
                    fi
                done

                if [[ "$found" == "false" ]]; then
                    log_error "Module '$module' requires '$dep' but it is not selected"
                    all_valid=false
                fi
            done
        fi
    done

    if [[ "$all_valid" == "true" ]]; then
        log_debug "All dependencies validated"
        return 0
    else
        log_error "Dependency validation failed"
        return 1
    fi
}

#
# Auto-include missing dependencies
# Adds required dependencies to the selected modules list
#
# Arguments:
#   $@ - Array of selected module names
#
# Outputs:
#   Space-separated list of modules with dependencies included
#
auto_include_dependencies() {
    local -a selected_modules=("$@")

    log_debug "Auto-including dependencies for: ${selected_modules[*]}"

    # Collect all required modules (including transitive dependencies)
    local -A all_required=()
    local -a to_process=("${selected_modules[@]}")
    local -a newly_added=()

    while [[ ${#to_process[@]} -gt 0 ]]; do
        local current="${to_process[0]}"
        to_process=("${to_process[@]:1}")  # Remove first element

        # Skip if already processed
        if [[ -n "${all_required[$current]:-}" ]]; then
            continue
        fi

        # Mark as required
        all_required["$current"]=1

        # Get dependencies for this module
        local deps="${DEPENDENCY_GRAPH[$current]:-}"

        if [[ -n "$deps" ]]; then
            for dep in $deps; do
                if [[ -z "${all_required[$dep]:-}" ]]; then
                    to_process+=("$dep")

                    # Check if this was not in original selection
                    local was_selected=false
                    for selected in "${selected_modules[@]}"; do
                        if [[ "$dep" == "$selected" ]]; then
                            was_selected=true
                            break
                        fi
                    done

                    if [[ "$was_selected" == "false" ]]; then
                        newly_added+=("$dep")
                    fi
                fi
            done
        fi
    done

    # Log newly added dependencies
    if [[ ${#newly_added[@]} -gt 0 ]]; then
        log_info "Auto-included dependencies: ${newly_added[*]}"
    fi

    # Output all required modules
    echo "${!all_required[@]}"
    return 0
}

#
# Detect circular dependencies
#
# Arguments:
#   $@ - Array of module names
#
# Outputs:
#   List of modules involved in circular dependency (if any)
#
# Returns:
#   0 if no circular dependencies, 1 if circular dependency found
#
detect_circular_dependencies() {
    local -a modules=("$@")

    log_debug "Detecting circular dependencies in: ${modules[*]}"

    # Use DFS to detect cycles
    declare -A visited=()
    declare -A rec_stack=()

    for module in "${modules[@]}"; do
        visited["$module"]=0
        rec_stack["$module"]=0
    done

    for module in "${modules[@]}"; do
        if [[ ${visited["$module"]} -eq 0 ]]; then
            if dfs_cycle_detect "$module"; then
                log_error "Circular dependency detected involving: $module"
                return 1
            fi
        fi
    done

    log_debug "No circular dependencies detected"
    return 0
}

#
# DFS helper for cycle detection
#
# Arguments:
#   $1 - Current module
#
# Returns:
#   0 if no cycle, 1 if cycle detected
#
dfs_cycle_detect() {
    local module="$1"

    visited["$module"]=1
    rec_stack["$module"]=1

    local deps="${DEPENDENCY_GRAPH[$module]:-}"

    if [[ -n "$deps" ]]; then
        for dep in $deps; do
            # Skip if dependency not in graph
            if [[ -z "${visited[$dep]:-}" ]]; then
                continue
            fi

            if [[ ${visited["$dep"]} -eq 0 ]]; then
                if dfs_cycle_detect "$dep"; then
                    return 1
                fi
            elif [[ ${rec_stack["$dep"]} -eq 1 ]]; then
                # Back edge found - cycle detected
                log_error "Cycle: $module -> $dep"
                return 1
            fi
        done
    fi

    rec_stack["$module"]=0
    return 0
}

#
# Get transitive dependencies for a module
#
# Arguments:
#   $1 - Module name
#
# Outputs:
#   Space-separated list of all transitive dependencies
#
get_transitive_dependencies() {
    local module="$1"

    local -A all_deps=()
    local -a to_process=("$module")

    while [[ ${#to_process[@]} -gt 0 ]]; do
        local current="${to_process[0]}"
        to_process=("${to_process[@]:1}")

        local deps="${DEPENDENCY_GRAPH[$current]:-}"

        if [[ -n "$deps" ]]; then
            for dep in $deps; do
                if [[ -z "${all_deps[$dep]:-}" ]]; then
                    all_deps["$dep"]=1
                    to_process+=("$dep")
                fi
            done
        fi
    done

    echo "${!all_deps[@]}"
}

# Export functions
export -f build_dependency_graph
export -f resolve_dependencies
export -f topological_sort
export -f validate_dependencies
export -f auto_include_dependencies
export -f detect_circular_dependencies
export -f get_transitive_dependencies
