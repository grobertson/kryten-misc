# PowerShell stop script for Echo Bot (Windows)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PidFile = Join-Path $ScriptDir "echo_bot.pid"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if PID file exists
if (-not (Test-Path $PidFile)) {
    Write-Error-Custom "PID file not found. Bot may not be running."
    exit 1
}

$Pid = Get-Content $PidFile

# Check if process is running
$Process = Get-Process -Id $Pid -ErrorAction SilentlyContinue

if (-not $Process) {
    Write-Warn "Bot process (PID: $Pid) is not running"
    Remove-Item $PidFile -Force
    exit 0
}

# Stop the bot
Write-Info "Stopping Echo Bot (PID: $Pid)..."
Stop-Process -Id $Pid -Force

# Wait for process to stop
Start-Sleep -Seconds 2

# Verify it stopped
if (-not (Get-Process -Id $Pid -ErrorAction SilentlyContinue)) {
    Write-Info "Bot stopped successfully"
    Remove-Item $PidFile -Force
} else {
    Write-Error-Custom "Failed to stop bot"
    exit 1
}
