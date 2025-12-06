# PowerShell startup script for Echo Bot (Windows)
# Usage: .\start-echo-bot.ps1 [-ConfigFile config.json]

param(
    [string]$ConfigFile = "config.json",
    [switch]$Background
)

$ErrorActionPreference = "Stop"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir $ConfigFile
$VenvDir = Join-Path $ScriptDir ".venv"
$LogFile = Join-Path $ScriptDir "echo_bot.log"
$PidFile = Join-Path $ScriptDir "echo_bot.pid"

# Logging functions
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

# Check if bot is already running
if (Test-Path $PidFile) {
    $Pid = Get-Content $PidFile
    if (Get-Process -Id $Pid -ErrorAction SilentlyContinue) {
        Write-Error-Custom "Echo bot is already running (PID: $Pid)"
        exit 1
    } else {
        Write-Warn "Stale PID file found, removing..."
        Remove-Item $PidFile -Force
    }
}

# Check if config file exists
if (-not (Test-Path $ConfigPath)) {
    Write-Error-Custom "Configuration file not found: $ConfigPath"
    Write-Info "Copy config.example.json to config.json and configure it"
    exit 1
}

# Check Python version
try {
    $PythonVersion = & python --version 2>&1
    Write-Info "Python version: $PythonVersion"
    
    $VersionMatch = $PythonVersion -match "Python (\d+)\.(\d+)"
    if (-not $VersionMatch -or [int]$Matches[1] -lt 3 -or ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -lt 11)) {
        Write-Error-Custom "Python 3.11+ required"
        exit 1
    }
} catch {
    Write-Error-Custom "Python not found. Install Python 3.11+"
    exit 1
}

# Create virtual environment if it doesn't exist
if (-not (Test-Path $VenvDir)) {
    Write-Info "Creating virtual environment..."
    python -m venv $VenvDir
}

# Activate virtual environment
Write-Info "Activating virtual environment..."
$ActivateScript = Join-Path $VenvDir "Scripts\Activate.ps1"
& $ActivateScript

# Install/update dependencies
Write-Info "Installing dependencies..."
python -m pip install --upgrade pip --quiet
python -m pip install kryten-py --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to install kryten-py"
    exit 1
}

# Check NATS connectivity (optional)
try {
    $Config = Get-Content $ConfigPath | ConvertFrom-Json
    $NatsUrl = $Config.nats.servers[0]
    $NatsHost = ([System.Uri]$NatsUrl).Host
    $NatsPort = ([System.Uri]$NatsUrl).Port
    
    $TcpClient = New-Object System.Net.Sockets.TcpClient
    $Connect = $TcpClient.BeginConnect($NatsHost, $NatsPort, $null, $null)
    $Wait = $Connect.AsyncWaitHandle.WaitOne(1000, $false)
    
    if ($Wait) {
        $TcpClient.EndConnect($Connect)
        Write-Info "NATS server reachable at ${NatsHost}:${NatsPort}"
        $TcpClient.Close()
    } else {
        Write-Warn "NATS server not reachable at ${NatsHost}:${NatsPort}"
        Write-Warn "Bot will attempt to connect anyway..."
    }
} catch {
    Write-Warn "Could not check NATS connectivity: $_"
}

# Start the bot
Write-Info "Starting Echo Bot..."
Write-Info "Config: $ConfigPath"
Write-Info "Log file: $LogFile"

# Clear PYTHONPATH to avoid loading development versions
$env:PYTHONPATH = ""

Push-Location $ScriptDir

if ($Background) {
    # Start in background
    $Process = Start-Process -FilePath "python" `
        -ArgumentList "-m", "echo_bot.main", "--config", $ConfigPath `
        -RedirectStandardOutput $LogFile `
        -RedirectStandardError $LogFile `
        -NoNewWindow `
        -PassThru
    
    $Process.Id | Out-File $PidFile -Encoding ASCII
    
    Start-Sleep -Seconds 2
    
    if (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue) {
        Write-Info "Echo Bot started successfully (PID: $($Process.Id))"
        Write-Info "Monitor logs with: Get-Content -Path $LogFile -Wait"
        Write-Info "Stop with: Stop-Process -Id $($Process.Id)"
    } else {
        Write-Error-Custom "Bot failed to start. Check $LogFile for details"
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
        exit 1
    }
} else {
    # Run in foreground
    Write-Info "Running in foreground (Ctrl+C to stop)..."
    python -m echo_bot.main --config $ConfigPath
}

Pop-Location
