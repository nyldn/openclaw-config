#!/bin/bash
#
# Secure download and verification utilities
# Provides functions for downloading files with SHA256 and GPG signature verification
#

set -euo pipefail

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/logger.sh"

#
# Download a file with verification
#
# Arguments:
#   $1 - URL to download
#   $2 - Output file path
#   $3 - Expected SHA256 checksum (optional, but recommended)
#   $4 - GPG signature URL (optional)
#
# Returns:
#   0 on success, 1 on failure
#
download_with_verification() {
    local url="$1"
    local output="$2"
    local expected_sha256="${3:-}"
    local gpg_signature_url="${4:-}"

    # Validate inputs
    if [[ -z "$url" || -z "$output" ]]; then
        log_error "download_with_verification: URL and output path are required"
        return 1
    fi

    # Ensure output directory exists
    local output_dir
    output_dir=$(dirname "$output")
    mkdir -p "$output_dir"

    log_info "Downloading from: $url"

    # Download file with retry logic
    local max_retries=3
    local retry_count=0
    local download_success=false

    while [[ $retry_count -lt $max_retries ]]; do
        if curl -fsSL -o "$output" "$url"; then
            download_success=true
            break
        fi

        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            log_warn "Download failed, retrying ($retry_count/$max_retries)..."
            sleep 2
        fi
    done

    if [[ "$download_success" != "true" ]]; then
        log_error "Failed to download after $max_retries attempts"
        return 1
    fi

    log_success "Download completed"

    # Verify SHA256 checksum if provided
    if [[ -n "$expected_sha256" ]]; then
        log_info "Verifying SHA256 checksum..."

        local actual_sha256
        if command -v sha256sum &> /dev/null; then
            actual_sha256=$(sha256sum "$output" | awk '{print $1}')
        elif command -v shasum &> /dev/null; then
            actual_sha256=$(shasum -a 256 "$output" | awk '{print $1}')
        else
            log_error "Neither sha256sum nor shasum found, cannot verify checksum"
            rm -f "$output"
            return 1
        fi

        if [[ "$actual_sha256" != "$expected_sha256" ]]; then
            log_error "SHA256 checksum mismatch!"
            log_error "Expected: $expected_sha256"
            log_error "Got:      $actual_sha256"
            log_error "This could indicate a corrupted download or a security issue"
            rm -f "$output"
            return 1
        fi

        log_success "SHA256 checksum verified"
    else
        log_warn "No checksum provided, skipping verification (not recommended)"
    fi

    # Verify GPG signature if provided
    if [[ -n "$gpg_signature_url" ]]; then
        log_info "Verifying GPG signature..."

        if ! command -v gpg &> /dev/null; then
            log_warn "GPG not found, skipping signature verification"
        else
            local sig_file="${output}.sig"

            # Download signature file
            if ! curl -fsSL -o "$sig_file" "$gpg_signature_url"; then
                log_error "Failed to download GPG signature"
                rm -f "$output"
                return 1
            fi

            # Verify signature
            if ! gpg --verify "$sig_file" "$output" 2>/dev/null; then
                log_error "GPG signature verification failed"
                log_error "This could indicate a security issue"
                rm -f "$output" "$sig_file"
                return 1
            fi

            log_success "GPG signature verified"
            rm -f "$sig_file"
        fi
    fi

    log_success "File downloaded and verified: $output"
    return 0
}

#
# Download and execute a script with verification
#
# Arguments:
#   $1 - URL to download
#   $2 - Expected SHA256 checksum (optional)
#   $3 - GPG signature URL (optional)
#   $@ - Additional arguments to pass to the script
#
# Returns:
#   Exit code of the executed script
#
download_and_execute() {
    local url="$1"
    local expected_sha256="${2:-}"
    local gpg_signature_url="${3:-}"
    shift 3 || shift $#

    # Create secure temporary file
    local temp_script
    temp_script=$(mktemp)

    # Ensure cleanup on exit
    trap 'rm -f "$temp_script"' EXIT INT TERM

    # Download with verification
    if ! download_with_verification "$url" "$temp_script" "$expected_sha256" "$gpg_signature_url"; then
        log_error "Failed to download and verify script"
        return 1
    fi

    # Make executable
    chmod +x "$temp_script"

    # Execute script with remaining arguments
    log_info "Executing downloaded script..."
    bash "$temp_script" "$@"
    local exit_code=$?

    # Cleanup is handled by trap
    return $exit_code
}

#
# Verify checksum of an existing file
#
# Arguments:
#   $1 - File path
#   $2 - Expected SHA256 checksum
#
# Returns:
#   0 if checksum matches, 1 otherwise
#
verify_checksum() {
    local file="$1"
    local expected_sha256="$2"

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    log_info "Verifying checksum for: $file"

    local actual_sha256
    if command -v sha256sum &> /dev/null; then
        actual_sha256=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum &> /dev/null; then
        actual_sha256=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        log_error "Neither sha256sum nor shasum found"
        return 1
    fi

    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        log_error "Checksum mismatch!"
        log_error "Expected: $expected_sha256"
        log_error "Got:      $actual_sha256"
        return 1
    fi

    log_success "Checksum verified"
    return 0
}

#
# Download a file to a secure temporary location
#
# Arguments:
#   $1 - URL to download
#   $2 - Expected SHA256 checksum (optional)
#
# Outputs:
#   Path to the downloaded temporary file
#
# Returns:
#   0 on success, 1 on failure
#
download_to_temp() {
    local url="$1"
    local expected_sha256="${2:-}"

    # Create secure temporary file
    local temp_file
    temp_file=$(mktemp)

    if ! download_with_verification "$url" "$temp_file" "$expected_sha256"; then
        rm -f "$temp_file"
        return 1
    fi

    echo "$temp_file"
    return 0
}
