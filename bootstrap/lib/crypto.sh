#!/bin/bash
#
# Cryptographic utilities for OpenClaw bootstrap system
# Provides functions for encrypting and decrypting sensitive configuration files
#

set -euo pipefail

# Source required libraries
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/logger.sh"

# Encryption configuration
OPENCLAW_DIR="$HOME/.openclaw"
KEY_FILE="$OPENCLAW_DIR/config.key"
CIPHER="aes-256-cbc"
PBKDF2_ITERATIONS=10000

#
# Initialize encryption system
# Creates encryption key if it doesn't exist
#
# Returns:
#   0 on success, 1 on failure
#
crypto_init() {
    log_debug "Initializing encryption system"

    # Create .openclaw directory if it doesn't exist
    if [[ ! -d "$OPENCLAW_DIR" ]]; then
        mkdir -p "$OPENCLAW_DIR"
        chmod 0700 "$OPENCLAW_DIR"
        log_debug "Created $OPENCLAW_DIR with restrictive permissions"
    fi

    # Generate encryption key if it doesn't exist
    if [[ ! -f "$KEY_FILE" ]]; then
        log_info "Generating encryption key..."

        if ! command -v openssl &> /dev/null; then
            log_error "OpenSSL not found, cannot generate encryption key"
            return 1
        fi

        # Generate a strong random key
        if ! openssl rand -base64 32 > "$KEY_FILE"; then
            log_error "Failed to generate encryption key"
            return 1
        fi

        # Set restrictive permissions (owner read/write only)
        chmod 0600 "$KEY_FILE"

        log_success "Encryption key generated: $KEY_FILE"
        log_warn "Keep this key secure! If lost, encrypted data cannot be recovered."
    else
        log_debug "Encryption key already exists: $KEY_FILE"
    fi

    return 0
}

#
# Encrypt a configuration file
#
# Arguments:
#   $1 - Input file path (plaintext)
#   $2 - Output file path (encrypted) [optional, defaults to input_file.enc]
#   $3 - Remove plaintext after encryption [optional, true/false, default: false]
#
# Returns:
#   0 on success, 1 on failure
#
encrypt_config() {
    local input_file="$1"
    local output_file="${2:-${input_file}.enc}"
    local remove_plaintext="${3:-false}"

    # Validate inputs
    if [[ -z "$input_file" ]]; then
        log_error "encrypt_config: Input file path is required"
        return 1
    fi

    if [[ ! -f "$input_file" ]]; then
        log_error "Input file not found: $input_file"
        return 1
    fi

    # Initialize encryption system
    if ! crypto_init; then
        return 1
    fi

    # Check for OpenSSL
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL not found, cannot encrypt file"
        return 1
    fi

    log_info "Encrypting: $input_file"

    # Encrypt using AES-256-CBC with PBKDF2
    if ! openssl enc -"$CIPHER" -salt -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$input_file" \
        -out "$output_file" \
        -pass file:"$KEY_FILE" 2>/dev/null; then
        log_error "Failed to encrypt file"
        return 1
    fi

    # Set restrictive permissions on encrypted file
    chmod 0600 "$output_file"

    log_success "File encrypted: $output_file"

    # Optionally remove plaintext
    if [[ "$remove_plaintext" == "true" ]]; then
        log_warn "Removing plaintext file: $input_file"
        if rm -f "$input_file"; then
            log_success "Plaintext file removed"
        else
            log_error "Failed to remove plaintext file"
            return 1
        fi
    fi

    return 0
}

#
# Decrypt a configuration file
#
# Arguments:
#   $1 - Input file path (encrypted)
#   $2 - Output file path (plaintext) [optional, defaults to input_file without .enc]
#
# Returns:
#   0 on success, 1 on failure
#
decrypt_config() {
    local input_file="$1"
    local output_file="${2:-}"

    # Validate inputs
    if [[ -z "$input_file" ]]; then
        log_error "decrypt_config: Input file path is required"
        return 1
    fi

    if [[ ! -f "$input_file" ]]; then
        log_error "Encrypted file not found: $input_file"
        return 1
    fi

    # Default output file: remove .enc extension if present
    if [[ -z "$output_file" ]]; then
        if [[ "$input_file" == *.enc ]]; then
            output_file="${input_file%.enc}"
        else
            output_file="${input_file}.dec"
        fi
    fi

    # Check for encryption key
    if [[ ! -f "$KEY_FILE" ]]; then
        log_error "Encryption key not found: $KEY_FILE"
        log_error "Cannot decrypt without the encryption key"
        return 1
    fi

    # Check for OpenSSL
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL not found, cannot decrypt file"
        return 1
    fi

    log_info "Decrypting: $input_file"

    # Decrypt using AES-256-CBC with PBKDF2
    if ! openssl enc -"$CIPHER" -d -pbkdf2 -iter "$PBKDF2_ITERATIONS" \
        -in "$input_file" \
        -out "$output_file" \
        -pass file:"$KEY_FILE" 2>/dev/null; then
        log_error "Failed to decrypt file"
        log_error "This could mean:"
        log_error "  - Wrong encryption key"
        log_error "  - File is corrupted"
        log_error "  - File was not encrypted with this system"
        return 1
    fi

    # Set restrictive permissions on decrypted file
    chmod 0600 "$output_file"

    log_success "File decrypted: $output_file"

    return 0
}

#
# Encrypt sensitive files in OpenClaw workspace
# Automatically encrypts common sensitive file patterns
#
# Arguments:
#   $1 - Workspace directory [optional, defaults to ~/.openclaw/workspace]
#
# Returns:
#   0 on success, 1 on failure
#
encrypt_workspace() {
    local workspace_dir="${1:-$HOME/.openclaw/workspace}"

    if [[ ! -d "$workspace_dir" ]]; then
        log_warn "Workspace directory not found: $workspace_dir"
        return 0
    fi

    log_section "Encrypting Sensitive Workspace Files"

    local -a sensitive_patterns=(
        ".env"
        ".env.*"
        "credentials.json"
        "token.json"
        "*_credentials.json"
        "*.key"
        "*.pem"
        "config.json"
    )

    local encrypted_count=0

    for pattern in "${sensitive_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            # Skip if already encrypted
            if [[ "$file" == *.enc ]]; then
                continue
            fi

            # Skip if encrypted version already exists
            if [[ -f "${file}.enc" ]]; then
                log_debug "Encrypted version already exists: ${file}.enc"
                continue
            fi

            log_progress "Encrypting: $file"

            if encrypt_config "$file" "${file}.enc" false; then
                encrypted_count=$((encrypted_count + 1))
            else
                log_error "Failed to encrypt: $file"
            fi
        done < <(find "$workspace_dir" -type f -name "$pattern" -print0 2>/dev/null)
    done

    if [[ $encrypted_count -gt 0 ]]; then
        log_success "Encrypted $encrypted_count sensitive file(s)"
        log_info "Plaintext files remain for compatibility"
        log_info "To remove plaintext files, use: crypto_remove_plaintext"
    else
        log_info "No sensitive files found to encrypt"
    fi

    return 0
}

#
# Decrypt sensitive files in OpenClaw workspace
# Decrypts all .enc files in the workspace
#
# Arguments:
#   $1 - Workspace directory [optional, defaults to ~/.openclaw/workspace]
#
# Returns:
#   0 on success, 1 on failure
#
decrypt_workspace() {
    local workspace_dir="${1:-$HOME/.openclaw/workspace}"

    if [[ ! -d "$workspace_dir" ]]; then
        log_error "Workspace directory not found: $workspace_dir"
        return 1
    fi

    log_section "Decrypting Workspace Files"

    local decrypted_count=0

    while IFS= read -r -d '' file; do
        log_progress "Decrypting: $file"

        if decrypt_config "$file"; then
            decrypted_count=$((decrypted_count + 1))
        else
            log_error "Failed to decrypt: $file"
        fi
    done < <(find "$workspace_dir" -type f -name "*.enc" -print0 2>/dev/null)

    if [[ $decrypted_count -gt 0 ]]; then
        log_success "Decrypted $decrypted_count file(s)"
    else
        log_info "No encrypted files found to decrypt"
    fi

    return 0
}

#
# Remove plaintext files that have encrypted versions
# Use with caution - plaintext files cannot be recovered without the key
#
# Arguments:
#   $1 - Workspace directory [optional, defaults to ~/.openclaw/workspace]
#
# Returns:
#   0 on success, 1 on failure
#
crypto_remove_plaintext() {
    local workspace_dir="${1:-$HOME/.openclaw/workspace}"

    if [[ ! -d "$workspace_dir" ]]; then
        log_error "Workspace directory not found: $workspace_dir"
        return 1
    fi

    log_section "Removing Plaintext Files (with encrypted backups)"

    local removed_count=0

    while IFS= read -r -d '' enc_file; do
        # Get corresponding plaintext file
        local plaintext_file="${enc_file%.enc}"

        if [[ -f "$plaintext_file" ]]; then
            log_warn "Removing plaintext: $plaintext_file"

            if rm -f "$plaintext_file"; then
                removed_count=$((removed_count + 1))
                log_success "Removed: $plaintext_file"
            else
                log_error "Failed to remove: $plaintext_file"
            fi
        fi
    done < <(find "$workspace_dir" -type f -name "*.enc" -print0 2>/dev/null)

    if [[ $removed_count -gt 0 ]]; then
        log_success "Removed $removed_count plaintext file(s)"
        log_warn "Encrypted versions remain and can be decrypted with the key"
    else
        log_info "No plaintext files with encrypted backups found"
    fi

    return 0
}

#
# Backup encryption key to a secure location
#
# Arguments:
#   $1 - Backup location [optional, prompts if not provided]
#
# Returns:
#   0 on success, 1 on failure
#
crypto_backup_key() {
    local backup_location="${1:-}"

    if [[ ! -f "$KEY_FILE" ]]; then
        log_error "Encryption key not found: $KEY_FILE"
        return 1
    fi

    if [[ -z "$backup_location" ]]; then
        log_error "Backup location not provided"
        log_info "Usage: crypto_backup_key /path/to/secure/location/config.key.backup"
        return 1
    fi

    log_warn "Backing up encryption key to: $backup_location"
    log_warn "This key can decrypt all encrypted files - keep it secure!"

    if cp "$KEY_FILE" "$backup_location"; then
        chmod 0600 "$backup_location"
        log_success "Encryption key backed up successfully"
        log_info "Store this backup in a secure location (encrypted USB, password manager, etc.)"
        return 0
    else
        log_error "Failed to backup encryption key"
        return 1
    fi
}

# Export functions
export -f crypto_init
export -f encrypt_config
export -f decrypt_config
export -f encrypt_workspace
export -f decrypt_workspace
export -f crypto_remove_plaintext
export -f crypto_backup_key
