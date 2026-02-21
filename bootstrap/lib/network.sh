#!/usr/bin/env bash

# Network utilities for OpenClaw bootstrap system
# Handles manifest fetching and remote update checking

# Source logger if not already loaded
if ! declare -f log_info &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=logger.sh
    source "$SCRIPT_DIR/logger.sh"
fi

# Default manifest URL
DEFAULT_MANIFEST_URL="https://raw.githubusercontent.com/user/openclawd-config/main/bootstrap/manifest.yaml"

# Fetch remote manifest
# Usage: fetch_manifest [url] [output_file]
fetch_manifest() {
    local url="${1:-$DEFAULT_MANIFEST_URL}"
    local output="${2:-$(mktemp /tmp/openclaw-manifest-XXXXXX.yaml)}"

    log_progress "Fetching remote manifest from $url"

    if command -v curl &>/dev/null; then
        if curl -fsSL -o "$output" "$url" --connect-timeout 10; then
            log_success "Manifest downloaded to $output"
            return 0
        else
            log_error "Failed to download manifest using curl"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if wget -q -O "$output" "$url" --timeout=10; then
            log_success "Manifest downloaded to $output"
            return 0
        else
            log_error "Failed to download manifest using wget"
            return 1
        fi
    else
        log_error "Neither curl nor wget is available for downloading manifest"
        return 1
    fi
}

# Parse YAML value (simple parser for basic key: value pairs)
# Usage: parse_yaml_value file key
parse_yaml_value() {
    local file="$1"
    local key="$2"

    if [[ ! -f "$file" ]]; then
        log_error "YAML file not found: $file"
        return 1
    fi

    # Simple grep-based parser for top-level keys
    local value
    value=$(grep "^${key}:" "$file" | head -n1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' | tr -d "'")

    if [[ -n "$value" ]]; then
        echo "$value"
        return 0
    else
        return 1
    fi
}

# Get module version from manifest
# Usage: get_module_version manifest_file module_name
get_module_version() {
    local manifest="$1"
    local module="$2"

    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest file not found: $manifest"
        return 1
    fi

    # Extract version for specific module
    # This is a simplified parser; for production use a proper YAML parser
    local in_modules=false
    local in_module=false
    local version=""

    while IFS= read -r line; do
        # Check if we're in the modules section
        if [[ "$line" =~ ^modules: ]]; then
            in_modules=true
            continue
        fi

        # Exit modules section if we hit another top-level key
        if [[ "$in_modules" == true ]] && [[ "$line" =~ ^[a-z_-]+: ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
            in_modules=false
        fi

        # Check if we found our module
        if [[ "$in_modules" == true ]] && [[ "$line" =~ ^[[:space:]]+${module}: ]]; then
            in_module=true
            continue
        fi

        # Get version from module section
        if [[ "$in_module" == true ]] && [[ "$line" =~ ^[[:space:]]+version: ]]; then
            version=$(echo "$line" | sed 's/^[[:space:]]*version:[[:space:]]*//' | tr -d '"' | tr -d "'")
            break
        fi

        # Exit module section if we hit another module
        if [[ "$in_module" == true ]] && [[ "$line" =~ ^[[:space:]]+[a-z_-]+: ]]; then
            break
        fi
    done < "$manifest"

    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    else
        return 1
    fi
}

# Compare versions
# Usage: compare_versions version1 version2
# Returns: 0 if version1 >= version2, 1 otherwise
compare_versions() {
    local v1="$1"
    local v2="$2"

    if [[ "$(printf '%s\n' "$v2" "$v1" | sort -V | head -n1)" == "$v2" ]]; then
        return 0  # v1 >= v2
    else
        return 1  # v1 < v2
    fi
}

# Check for updates
# Usage: check_updates local_state_file remote_manifest_url
check_updates() {
    local state_file="$1"
    local manifest_url="${2:-$DEFAULT_MANIFEST_URL}"
    local temp_manifest
    temp_manifest=$(mktemp /tmp/openclaw-manifest-check-XXXXXX.yaml)

    log_section "Checking for Updates"

    # Download remote manifest
    if ! fetch_manifest "$manifest_url" "$temp_manifest"; then
        log_error "Failed to fetch remote manifest for update check"
        return 1
    fi

    # Check if state file exists
    if [[ ! -f "$state_file" ]]; then
        log_info "No local state file found. Full installation recommended."
        rm -f "$temp_manifest"
        return 2  # Return 2 to indicate initial installation needed
    fi

    # Get remote manifest version
    local remote_version
    if ! remote_version=$(parse_yaml_value "$temp_manifest" "version"); then
        log_error "Failed to parse remote manifest version"
        rm -f "$temp_manifest"
        return 1
    fi

    # Get local manifest version
    local local_version
    if ! local_version=$(parse_yaml_value "$state_file" "version"); then
        log_warn "Failed to parse local state version. Assuming fresh install needed."
        rm -f "$temp_manifest"
        return 2
    fi

    log_info "Local version: $local_version"
    log_info "Remote version: $remote_version"

    # Compare versions
    if compare_versions "$local_version" "$remote_version"; then
        log_success "System is up to date (version $local_version)"
        rm -f "$temp_manifest"
        return 0
    else
        log_warn "Updates available: $local_version -> $remote_version"
        rm -f "$temp_manifest"
        return 3  # Return 3 to indicate updates available
    fi
}

# Download file with retry
# Usage: download_file url output_path [max_retries]
download_file() {
    local url="$1"
    local output="$2"
    local max_retries="${3:-3}"
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        log_progress "Downloading (attempt $attempt/$max_retries): $url"

        if command -v curl &>/dev/null; then
            if curl -fsSL -o "$output" "$url" --connect-timeout 10 --max-time 60; then
                log_success "Download successful"
                return 0
            fi
        elif command -v wget &>/dev/null; then
            if wget -q -O "$output" "$url" --timeout=60; then
                log_success "Download successful"
                return 0
            fi
        fi

        attempt=$((attempt + 1))
        if [[ $attempt -le $max_retries ]]; then
            log_warn "Download failed, retrying in 2 seconds..."
            sleep 2
        fi
    done

    log_error "Failed to download after $max_retries attempts"
    return 1
}

# Export functions
export -f fetch_manifest
export -f parse_yaml_value
export -f get_module_version
export -f compare_versions
export -f check_updates
export -f download_file
