#!/usr/bin/env bash

# Module: Memory System Initialization
# Initializes the memory system databases and files

MODULE_NAME="memory-init"
MODULE_VERSION="1.0.0"
MODULE_DESCRIPTION="Memory system initialization"
MODULE_DEPS=("system-deps" "python" "openclaw-env")

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib"

# shellcheck source=../lib/logger.sh
source "$LIB_DIR/logger.sh"
# shellcheck source=../lib/validation.sh
source "$LIB_DIR/validation.sh"

WORKSPACE_DIR="$HOME/openclaw-workspace"
VENV_DIR="$HOME/.local/venv/openclaw"
TEMPLATE_DIR="$(dirname "$SCRIPT_DIR")/templates"

# Check if module is already installed
check_installed() {
    log_debug "Checking if $MODULE_NAME is installed"

    # Check if .env exists
    if [[ ! -f "$WORKSPACE_DIR/.env" ]]; then
        return 1
    fi

    # Check if MEMORY.md exists
    if [[ ! -f "$WORKSPACE_DIR/memory/MEMORY.md" ]]; then
        return 1
    fi

    # Check if database exists
    if [[ ! -f "$WORKSPACE_DIR/data/memory.db" ]]; then
        return 1
    fi

    log_debug "Memory system is initialized"
    return 0
}

# Install the module
install() {
    log_section "Initializing Memory System"

    # Create .env file from template
    if [[ ! -f "$WORKSPACE_DIR/.env" ]]; then
        log_progress "Creating .env file from template"

        if [[ -f "$TEMPLATE_DIR/.env.template" ]]; then
            cp "$TEMPLATE_DIR/.env.template" "$WORKSPACE_DIR/.env"
            log_success ".env file created"
            log_info "Please edit $WORKSPACE_DIR/.env and add your API keys"
        else
            log_warn "Template not found, creating basic .env"
            cat > "$WORKSPACE_DIR/.env" <<'EOF'
# OpenClaw Environment Configuration
ANTHROPIC_API_KEY=sk-ant-your-key-here
OPENAI_API_KEY=sk-proj-your-key-here
GOOGLE_API_KEY=your-google-api-key-here
DATABASE_PATH=data/memory.db
MEMORY_DIR=memory
LOGS_DIR=memory/logs
EMBEDDING_MODEL=text-embedding-ada-002
EOF
            log_success "Basic .env file created"
        fi
    else
        log_info ".env file already exists"
    fi

    # Create MEMORY.md from template
    if [[ ! -f "$WORKSPACE_DIR/memory/MEMORY.md" ]]; then
        log_progress "Creating memory/MEMORY.md from template"

        if [[ -f "$TEMPLATE_DIR/MEMORY.md.template" ]]; then
            local timestamp
            timestamp=$(date +"%Y-%m-%d %H:%M:%S")

            # Replace timestamp placeholder
            sed "s/{{ TIMESTAMP }}/$timestamp/g" "$TEMPLATE_DIR/MEMORY.md.template" > "$WORKSPACE_DIR/memory/MEMORY.md"

            log_success "MEMORY.md created"
        else
            log_warn "Template not found, creating basic MEMORY.md"
            cat > "$WORKSPACE_DIR/memory/MEMORY.md" <<'EOF'
# OpenClaw Memory System

Memory system initialized.

## Usage

- Write: `python tools/memory/memory_write.py --content "text" --type fact`
- Read: `python tools/memory/memory_read.py --format markdown`
- Search: `python tools/memory/hybrid_search.py --query "search"`
EOF
            log_success "Basic MEMORY.md created"
        fi
    else
        log_info "MEMORY.md already exists"
    fi

    # Create first daily log
    local today
    today=$(date +"%Y-%m-%d")
    local log_file="$WORKSPACE_DIR/memory/logs/$today.md"

    if [[ ! -f "$log_file" ]]; then
        log_progress "Creating first daily log: $today.md"

        local time
        time=$(date +"%H:%M:%S")

        if [[ -f "$TEMPLATE_DIR/daily-log.md.template" ]]; then
            sed -e "s/{{ DATE }}/$today/g" -e "s/{{ TIME }}/$time/g" "$TEMPLATE_DIR/daily-log.md.template" > "$log_file"
        else
            cat > "$log_file" <<EOF
# Daily Log: $today

## Session Summary

**Date**: $today
**Started**: $time

## Activities

- Memory system initialized
- Bootstrap installation completed

## Next Steps

- Configure API keys in .env
- Test memory system
EOF
        fi

        log_success "Daily log created"
    else
        log_info "Daily log already exists"
    fi

    # Initialize SQLite database
    log_progress "Initializing SQLite database"

    # Check if memory_db.py exists
    if [[ ! -f "$WORKSPACE_DIR/tools/memory/memory_db.py" ]]; then
        log_warn "memory_db.py not found, creating basic database schema"

        # Activate venv
        # shellcheck source=/dev/null
        source "$VENV_DIR/bin/activate"

        # Create database with basic schema using sqlite3
        sqlite3 "$WORKSPACE_DIR/data/memory.db" <<'EOF'
CREATE TABLE IF NOT EXISTS memory_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    type TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    tags TEXT,
    embedding BLOB
);

CREATE TABLE IF NOT EXISTS daily_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT UNIQUE NOT NULL,
    summary TEXT,
    activities TEXT,
    decisions TEXT,
    context TEXT
);

CREATE TABLE IF NOT EXISTS memory_access_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entry_id INTEGER,
    access_type TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (entry_id) REFERENCES memory_entries(id)
);

CREATE INDEX IF NOT EXISTS idx_memory_type ON memory_entries(type);
CREATE INDEX IF NOT EXISTS idx_memory_timestamp ON memory_entries(timestamp);
CREATE INDEX IF NOT EXISTS idx_daily_logs_date ON daily_logs(date);
EOF

        deactivate 2>/dev/null || true

        log_success "Database schema created"
    else
        log_progress "Running memory_db.py to initialize database"

        # Activate venv
        # shellcheck source=/dev/null
        source "$VENV_DIR/bin/activate"

        cd "$WORKSPACE_DIR" || return 1

        # Run memory_db.py if it has initialization code
        if python3 tools/memory/memory_db.py 2>/dev/null; then
            log_success "Database initialized via memory_db.py"
        else
            log_warn "memory_db.py execution failed, using basic schema"

            # Fallback to basic schema
            sqlite3 "$WORKSPACE_DIR/data/memory.db" <<'EOF'
CREATE TABLE IF NOT EXISTS memory_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    type TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    tags TEXT,
    embedding BLOB
);

CREATE TABLE IF NOT EXISTS daily_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT UNIQUE NOT NULL,
    summary TEXT,
    activities TEXT,
    decisions TEXT,
    context TEXT
);

CREATE TABLE IF NOT EXISTS memory_access_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entry_id INTEGER,
    access_type TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (entry_id) REFERENCES memory_entries(id)
);
EOF
            log_success "Basic database schema created"
        fi

        cd - > /dev/null || return 1
        deactivate 2>/dev/null || true
    fi

    # Test memory system
    log_progress "Testing memory system"

    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"

    cd "$WORKSPACE_DIR" || return 1

    if [[ -f "tools/memory/memory_read.py" ]]; then
        if python3 tools/memory/memory_read.py --format markdown &>/dev/null; then
            log_success "Memory read test passed"
        else
            log_warn "Memory read test failed (may need API keys)"
        fi
    else
        log_warn "memory_read.py not found, skipping test"
    fi

    cd - > /dev/null || return 1
    deactivate 2>/dev/null || true

    log_success "Memory system initialization complete"

    return 0
}

# Validate installation
validate() {
    log_progress "Validating memory system initialization"

    local all_valid=true

    # Check .env file
    if [[ -f "$WORKSPACE_DIR/.env" ]]; then
        log_success ".env file exists"
    else
        log_error ".env file not found"
        all_valid=false
    fi

    # Check MEMORY.md
    if [[ -f "$WORKSPACE_DIR/memory/MEMORY.md" ]]; then
        log_success "memory/MEMORY.md exists"
    else
        log_error "memory/MEMORY.md not found"
        all_valid=false
    fi

    # Check database
    if [[ -f "$WORKSPACE_DIR/data/memory.db" ]]; then
        log_success "Database exists: data/memory.db"

        # Check database tables
        local tables
        tables=$(sqlite3 "$WORKSPACE_DIR/data/memory.db" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null)

        if echo "$tables" | grep -q "memory_entries"; then
            log_success "Database table 'memory_entries' exists"
        else
            log_warn "Database table 'memory_entries' not found"
        fi
    else
        log_error "Database not found: data/memory.db"
        all_valid=false
    fi

    # Check daily logs directory
    if [[ -d "$WORKSPACE_DIR/memory/logs" ]]; then
        log_success "Daily logs directory exists"

        local log_count
        log_count=$(find "$WORKSPACE_DIR/memory/logs" -name "*.md" 2>/dev/null | wc -l)
        log_info "Daily log files: $log_count"
    else
        log_error "Daily logs directory not found"
        all_valid=false
    fi

    if [[ "$all_valid" == "true" ]]; then
        log_success "Memory system validation passed"
        return 0
    else
        log_error "Memory system validation failed"
        return 1
    fi
}

# Rollback installation
rollback() {
    log_warn "Rolling back memory system initialization"

    # Remove .env (backup first)
    if [[ -f "$WORKSPACE_DIR/.env" ]]; then
        log_progress "Backing up and removing .env"
        cp "$WORKSPACE_DIR/.env" "$WORKSPACE_DIR/.env.backup" 2>/dev/null || true
        rm -f "$WORKSPACE_DIR/.env"
    fi

    # Remove MEMORY.md
    if [[ -f "$WORKSPACE_DIR/memory/MEMORY.md" ]]; then
        log_progress "Removing MEMORY.md"
        rm -f "$WORKSPACE_DIR/memory/MEMORY.md"
    fi

    # Remove database
    if [[ -f "$WORKSPACE_DIR/data/memory.db" ]]; then
        log_progress "Removing database"
        rm -f "$WORKSPACE_DIR/data/memory.db"
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
