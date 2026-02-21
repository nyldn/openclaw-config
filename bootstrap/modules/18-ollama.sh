#!/usr/bin/env bash

# Module: Ollama Local LLM
# Installs Ollama for running local language models

MODULE_NAME="ollama"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Ollama local LLM runtime with llama3.2 model"
MODULE_DEPS=("system-deps")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

DEFAULT_MODEL="llama3.2"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    if validate_command "ollama"; then
        log_debug "Ollama is installed"
        return 0
    fi

    log_debug "Ollama not found"
    return 1
}

# Install the module
install() {
    log_section "Installing Ollama"

    if validate_command "ollama"; then
        local version
        version=$(ollama --version 2>/dev/null || echo "unknown")
        log_success "Ollama already installed: $version"
    else
        log_progress "Installing Ollama..."

        if [[ "$(uname)" == "Darwin" ]]; then
            # macOS — use Homebrew
            if validate_command "brew"; then
                if brew install ollama 2>&1 | tee -a /tmp/ollama-install.log; then
                    log_success "Ollama installed via Homebrew"
                else
                    log_error "Failed to install Ollama via Homebrew"
                    return 1
                fi
            else
                log_error "Homebrew required to install Ollama on macOS"
                log_info "Install Homebrew: https://brew.sh"
                log_info "Or install Ollama manually: https://ollama.com/download"
                return 1
            fi
        else
            # Linux — use official install script
            local install_script
            install_script=$(mktemp)
            trap 'rm -f "$install_script"' RETURN

            if curl -fsSL -o "$install_script" https://ollama.com/install.sh; then
                if bash "$install_script" 2>&1 | tee -a /tmp/ollama-install.log; then
                    log_success "Ollama installed"
                else
                    log_error "Failed to install Ollama"
                    return 1
                fi
            else
                log_error "Failed to download Ollama installer"
                return 1
            fi
        fi
    fi

    # Start Ollama service
    log_progress "Starting Ollama service..."
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS — brew services
        if validate_command "brew"; then
            brew services start ollama 2>/dev/null || true
            log_info "Ollama service started via Homebrew"
        fi
    else
        # Linux — systemd
        if command -v systemctl &>/dev/null; then
            sudo systemctl enable ollama 2>/dev/null || true
            sudo systemctl start ollama 2>/dev/null || true
            log_info "Ollama service started via systemd"
        fi
    fi

    # Wait for service to be ready
    log_progress "Waiting for Ollama API to be ready..."
    local retries=10
    while [[ $retries -gt 0 ]]; do
        if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
            log_success "Ollama API is ready"
            break
        fi
        retries=$((retries - 1))
        sleep 2
    done

    if [[ $retries -eq 0 ]]; then
        log_warn "Ollama API not responding yet — model pull may fail"
        log_info "Start manually: ollama serve"
    fi

    # Pull default model
    log_progress "Pulling default model: $DEFAULT_MODEL (this may take a few minutes)..."
    if ollama pull "$DEFAULT_MODEL" 2>&1 | tee -a /tmp/ollama-install.log; then
        log_success "Model pulled: $DEFAULT_MODEL"
    else
        log_warn "Failed to pull $DEFAULT_MODEL"
        log_info "Pull manually: ollama pull $DEFAULT_MODEL"
    fi

    log_info ""
    log_info "Ollama installation complete!"
    log_info ""
    log_info "Useful commands:"
    log_info "  Run a model:    ollama run $DEFAULT_MODEL"
    log_info "  List models:    ollama list"
    log_info "  Pull a model:   ollama pull <model>"
    log_info "  API endpoint:   http://localhost:11434"
    log_info ""

    return 0
}

# Validate installation
validate() {
    log_progress "Validating Ollama installation"

    local all_valid=true

    if validate_command "ollama"; then
        local version
        version=$(ollama --version 2>/dev/null || echo "unknown")
        log_success "Ollama installed: $version"
    else
        log_error "Ollama not found"
        all_valid=false
    fi

    # Check API endpoint
    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        log_success "Ollama API is responding"
    else
        log_warn "Ollama API not responding (service may not be running)"
    fi

    # Check for default model
    if ollama list 2>/dev/null | grep -q "$DEFAULT_MODEL"; then
        log_success "Default model available: $DEFAULT_MODEL"
    else
        log_warn "Default model not found: $DEFAULT_MODEL"
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "Ollama validation passed"
        return 0
    else
        log_error "Ollama validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back Ollama installation"

    if [[ "$(uname)" == "Darwin" ]]; then
        if validate_command "brew"; then
            brew services stop ollama 2>/dev/null || true
            brew uninstall ollama 2>/dev/null || true
        fi
    else
        sudo systemctl stop ollama 2>/dev/null || true
        sudo systemctl disable ollama 2>/dev/null || true
    fi

    log_info "Ollama models preserved at ~/.ollama"
    log_info "To remove models: rm -rf ~/.ollama"

    log_success "Rollback complete"
    return 0
}

# Main execution when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-install}" in
        check)
            check_installed
            ;;
        install)
            install
            ;;
        validate)
            validate
            ;;
        rollback)
            rollback
            ;;
        *)
            echo "Usage: $0 {check|install|validate|rollback}"
            exit 1
            ;;
    esac
fi
