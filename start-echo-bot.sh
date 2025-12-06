#!/bin/bash
# Standalone startup script for Echo Bot
# Usage: ./start-echo-bot.sh [config_file]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${1:-${SCRIPT_DIR}/config.json}"
VENV_DIR="${SCRIPT_DIR}/.venv"
LOG_FILE="${SCRIPT_DIR}/echo_bot.log"
PID_FILE="${SCRIPT_DIR}/echo_bot.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if bot is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        log_error "Echo bot is already running (PID: $PID)"
        exit 1
    else
        log_warn "Stale PID file found, removing..."
        rm -f "$PID_FILE"
    fi
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    log_info "Copy config.example.json to config.json and configure it"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
REQUIRED_VERSION="3.11"
if ! python3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)"; then
    log_error "Python 3.11+ required, found: $PYTHON_VERSION"
    exit 1
fi

log_info "Python version: $PYTHON_VERSION"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    log_info "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
log_info "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Install/update dependencies
log_info "Installing dependencies..."
pip install --upgrade pip > /dev/null 2>&1
pip install kryten-py > /dev/null 2>&1 || {
    log_error "Failed to install kryten-py"
    exit 1
}

# Check NATS connectivity (optional)
if command -v nc > /dev/null 2>&1; then
    NATS_HOST=$(python3 -c "import json; config=json.load(open('$CONFIG_FILE')); print(config['nats']['servers'][0].split('//')[1].split(':')[0])" 2>/dev/null || echo "localhost")
    NATS_PORT=$(python3 -c "import json; config=json.load(open('$CONFIG_FILE')); print(config['nats']['servers'][0].split(':')[-1])" 2>/dev/null || echo "4222")
    
    if nc -z "$NATS_HOST" "$NATS_PORT" > /dev/null 2>&1; then
        log_info "NATS server reachable at $NATS_HOST:$NATS_PORT"
    else
        log_warn "NATS server not reachable at $NATS_HOST:$NATS_PORT"
        log_warn "Bot will attempt to connect anyway..."
    fi
fi

# Start the bot
log_info "Starting Echo Bot..."
log_info "Config: $CONFIG_FILE"
log_info "Log file: $LOG_FILE"

cd "$SCRIPT_DIR"
nohup python3 -m echo_bot.main --config "$CONFIG_FILE" >> "$LOG_FILE" 2>&1 &
BOT_PID=$!

# Save PID
echo $BOT_PID > "$PID_FILE"

# Wait a moment and check if it's still running
sleep 2
if ps -p $BOT_PID > /dev/null 2>&1; then
    log_info "Echo Bot started successfully (PID: $BOT_PID)"
    log_info "Monitor logs with: tail -f $LOG_FILE"
    log_info "Stop with: kill $BOT_PID"
else
    log_error "Bot failed to start. Check $LOG_FILE for details"
    rm -f "$PID_FILE"
    exit 1
fi
