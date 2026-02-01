#!/usr/bin/env bash

# Module: OpenClaw Environment
# Creates GOTCHA framework directory structure and copies files

MODULE_NAME="openclaw-env"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="GOTCHA framework directory structure"
MODULE_DEPS=("system-deps")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

WORKSPACE_DIR="$HOME/openclaw-workspace"
SOURCE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/atlas_framework"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check if workspace directory exists
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        return 1
    fi

    # Check if key directories exist
    local required_dirs=("goals" "tools" "context" "hardprompts" "args" "memory" "data")

    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$WORKSPACE_DIR/$dir" ]]; then
            log_debug "Directory missing: $dir"
            return 1
        fi
    done

    log_debug "OpenClaw environment is installed"
    return 0
}

# Install the module
install() {
    log_section "Setting Up OpenClaw Environment"

    # Create workspace directory
    log_progress "Creating workspace directory: $WORKSPACE_DIR"
    mkdir -p "$WORKSPACE_DIR"
    log_success "Workspace directory created"

    # Create GOTCHA subdirectories
    local directories=(
        "goals"
        "tools"
        "context"
        "hardprompts"
        "args"
        "memory"
        "memory/logs"
        "data"
        ".tmp"
    )

    log_progress "Creating GOTCHA directory structure"
    for dir in "${directories[@]}"; do
        mkdir -p "$WORKSPACE_DIR/$dir"
        log_debug "Created: $dir"
    done
    log_success "Directory structure created"

    # Copy CLAUDE.md if it exists in atlas_framework
    if [[ -f "$SOURCE_DIR/CLAUDE.md" ]]; then
        log_progress "Copying CLAUDE.md to workspace"
        cp "$SOURCE_DIR/CLAUDE.md" "$WORKSPACE_DIR/CLAUDE.md"
        log_success "CLAUDE.md copied"
    else
        log_warn "CLAUDE.md not found in atlas_framework (skipping)"
    fi

    # Copy build_app.md to goals/ if it exists
    if [[ -f "$SOURCE_DIR/build_app.md" ]]; then
        log_progress "Copying build_app.md to goals/"
        cp "$SOURCE_DIR/build_app.md" "$WORKSPACE_DIR/goals/build_app.md"
        log_success "build_app.md copied"
    else
        log_warn "build_app.md not found in atlas_framework (skipping)"
    fi

    # Copy memory tools if they exist
    if [[ -d "$SOURCE_DIR/memory" ]]; then
        log_progress "Copying memory tools to tools/memory/"
        mkdir -p "$WORKSPACE_DIR/tools/memory"

        # Copy all Python files from memory directory
        if cp -r "$SOURCE_DIR/memory/"* "$WORKSPACE_DIR/tools/memory/" 2>/dev/null; then
            log_success "Memory tools copied"
        else
            log_warn "No memory tools found to copy"
        fi
    else
        log_warn "Memory tools directory not found in atlas_framework"
    fi

    # Create tools/manifest.md
    log_progress "Creating tools/manifest.md"
    cat > "$WORKSPACE_DIR/tools/manifest.md" <<'EOF'
# OpenClaw Tools Manifest

This file lists all available tools in the OpenClaw workspace.

## Memory Tools

Located in `tools/memory/`:

- **memory_db.py**: Database initialization and schema management
- **memory_read.py**: Read and display memory entries
- **memory_write.py**: Write new memory entries
- **semantic_search.py**: Semantic search using embeddings
- **hybrid_search.py**: Combined keyword + semantic search
- **embed_memory.py**: Generate and store embeddings

### Usage Examples

```bash
# Write to memory
python tools/memory/memory_write.py --content "Important fact" --type fact

# Read all memory
python tools/memory/memory_read.py --format markdown

# Search memory
python tools/memory/hybrid_search.py --query "search term"
```

## Adding New Tools

To add a new tool:

1. Create the tool script in `tools/`
2. Add documentation here in manifest.md
3. Test the tool from the workspace root
4. Commit to version control
EOF

    log_success "tools/manifest.md created"

    # Set proper permissions
    log_progress "Setting permissions"
    chmod -R u+rwX "$WORKSPACE_DIR"

    # Make Python scripts executable
    find "$WORKSPACE_DIR/tools" -type f -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

    log_success "Permissions set"

    # Initialize git repository (optional)
    if command -v git &>/dev/null; then
        log_progress "Initializing git repository"

        cd "$WORKSPACE_DIR" || return 1

        if ! git rev-parse --git-dir > /dev/null 2>&1; then
            git init -q

            # Create .gitignore
            cat > .gitignore <<'EOF'
# Environment
.env
*.env.local

# Temporary files
.tmp/
*.tmp
*.log

# Python
__pycache__/
*.py[cod]
*$py.class
.venv/
venv/

# Database
*.db
*.sqlite
*.sqlite3

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF

            log_success "Git repository initialized"
        else
            log_info "Git repository already exists"
        fi

        cd - > /dev/null || return 1
    fi

    log_success "OpenClaw environment setup complete"
    log_info "Workspace location: $WORKSPACE_DIR"

    return 0
}

# Validate installation
validate() {
    log_progress "Validating OpenClaw environment"

    local all_valid=true

    # Check workspace directory
    if [[ -d "$WORKSPACE_DIR" ]]; then
        log_success "Workspace directory exists: $WORKSPACE_DIR"
    else
        log_error "Workspace directory not found: $WORKSPACE_DIR"
        all_valid=false
        return 1
    fi

    # Check required directories
    local required_dirs=(
        "goals"
        "tools"
        "context"
        "hardprompts"
        "args"
        "memory"
        "memory/logs"
        "data"
        ".tmp"
    )

    for dir in "${required_dirs[@]}"; do
        if [[ -d "$WORKSPACE_DIR/$dir" ]]; then
            log_success "Directory exists: $dir"
        else
            log_error "Directory missing: $dir"
            all_valid=false
        fi
    done

    # Check for key files
    local files_to_check=(
        "tools/manifest.md"
    )

    for file in "${files_to_check[@]}"; do
        if [[ -f "$WORKSPACE_DIR/$file" ]]; then
            log_success "File exists: $file"
        else
            log_warn "File missing: $file (non-critical)"
        fi
    done

    # Check if memory tools exist
    if [[ -d "$WORKSPACE_DIR/tools/memory" ]]; then
        log_success "Memory tools directory exists"

        # Count Python files
        local py_count
        py_count=$(find "$WORKSPACE_DIR/tools/memory" -name "*.py" 2>/dev/null | wc -l)
        log_info "Memory tools found: $py_count Python files"
    else
        log_warn "Memory tools directory not found"
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "OpenClaw environment validation passed"
        return 0
    else
        log_error "OpenClaw environment validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back OpenClaw environment"

    if [[ -d "$WORKSPACE_DIR" ]]; then
        log_progress "Removing workspace directory: $WORKSPACE_DIR"

        # Safety check - make sure it's our workspace
        if [[ "$WORKSPACE_DIR" == "$HOME/openclaw-workspace" ]]; then
            rm -rf "$WORKSPACE_DIR"
            log_success "Workspace removed"
        else
            log_error "Safety check failed - unexpected workspace path: $WORKSPACE_DIR"
            return 1
        fi
    fi

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
