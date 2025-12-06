#!/bin/bash
# Stop script for Echo Bot

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${SCRIPT_DIR}/echo_bot.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if PID file exists
if [ ! -f "$PID_FILE" ]; then
    log_error "PID file not found. Bot may not be running."
    exit 1
fi

PID=$(cat "$PID_FILE")

# Check if process is running
if ! ps -p "$PID" > /dev/null 2>&1; then
    log_warn "Bot process (PID: $PID) is not running"
    rm -f "$PID_FILE"
    exit 0
fi

# Stop the bot
log_info "Stopping Echo Bot (PID: $PID)..."
kill "$PID"

# Wait for graceful shutdown
for i in {1..10}; do
    if ! ps -p "$PID" > /dev/null 2>&1; then
        log_info "Bot stopped successfully"
        rm -f "$PID_FILE"
        exit 0
    fi
    sleep 1
done

# Force kill if still running
if ps -p "$PID" > /dev/null 2>&1; then
    log_warn "Bot did not stop gracefully, forcing..."
    kill -9 "$PID"
    sleep 1
fi

if ! ps -p "$PID" > /dev/null 2>&1; then
    log_info "Bot stopped"
    rm -f "$PID_FILE"
else
    log_error "Failed to stop bot"
    exit 1
fi
