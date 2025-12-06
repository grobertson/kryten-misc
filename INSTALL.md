# Echo Bot Installation Guide

This guide covers installing and running the Echo Bot on Linux and Windows systems.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Linux Installation](#linux-installation)
- [Windows Installation](#windows-installation)
- [systemd Service (Linux)](#systemd-service-linux)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## Prerequisites

- Python 3.11 or higher
- Access to a NATS server
- CyTube channel credentials (if required)

## Quick Start

### Linux/macOS

```bash
# 1. Copy example config
cp config.example.json config.json

# 2. Edit configuration
nano config.json

# 3. Make scripts executable
chmod +x start-echo-bot.sh stop-echo-bot.sh

# 4. Start the bot
./start-echo-bot.sh
```

### Windows

```powershell
# 1. Copy example config
Copy-Item config.example.json config.json

# 2. Edit configuration
notepad config.json

# 3. Start the bot
.\start-echo-bot.ps1
```

## Linux Installation

### Standalone Mode

1. **Clone or download the repository**
   ```bash
   git clone <repository-url>
   cd kryten-misc
   ```

2. **Create configuration**
   ```bash
   cp config.example.json config.json
   nano config.json
   ```

3. **Configure NATS and channels**
   ```json
   {
     "nats": {
       "servers": ["nats://localhost:4222"],
       "user": "your_user",
       "password": "your_password"
     },
     "channels": [
       {
         "domain": "cytu.be",
         "channel": "your-channel"
       }
     ]
   }
   ```

4. **Make scripts executable**
   ```bash
   chmod +x start-echo-bot.sh stop-echo-bot.sh
   ```

5. **Start the bot**
   ```bash
   ./start-echo-bot.sh
   ```

6. **Monitor logs**
   ```bash
   tail -f echo_bot.log
   ```

7. **Stop the bot**
   ```bash
   ./stop-echo-bot.sh
   ```

## Windows Installation

### Standalone Mode

1. **Clone or download the repository**
   ```powershell
   git clone <repository-url>
   cd kryten-misc
   ```

2. **Create configuration**
   ```powershell
   Copy-Item config.example.json config.json
   notepad config.json
   ```

3. **Configure NATS and channels** (same as Linux)

4. **Start the bot**
   ```powershell
   # Foreground (see output)
   .\start-echo-bot.ps1
   
   # Background
   .\start-echo-bot.ps1 -Background
   ```

5. **Monitor logs**
   ```powershell
   Get-Content -Path echo_bot.log -Wait
   ```

6. **Stop the bot**
   ```powershell
   .\stop-echo-bot.ps1
   ```

## systemd Service (Linux)

For production deployments on Linux, use systemd to manage the bot as a service.

### Installation

1. **Create bot user (recommended)**
   ```bash
   sudo useradd -r -s /bin/false -d /opt/kryten-misc bot
   ```

2. **Install bot files**
   ```bash
   sudo mkdir -p /opt/kryten-misc
   sudo cp -r * /opt/kryten-misc/
   sudo chown -R bot:bot /opt/kryten-misc
   ```

3. **Set up Python environment**
   ```bash
   cd /opt/kryten-misc
   sudo -u bot python3 -m venv .venv
   sudo -u bot .venv/bin/pip install kryten-py
   ```

4. **Configure the bot**
   ```bash
   sudo -u bot cp config.example.json config.json
   sudo -u bot nano config.json
   ```

5. **Install systemd service**
   ```bash
   # Edit service file paths if needed
   sudo nano echo-bot.service
   
   # Copy to systemd directory
   sudo cp echo-bot.service /etc/systemd/system/
   
   # Reload systemd
   sudo systemctl daemon-reload
   ```

6. **Enable and start service**
   ```bash
   sudo systemctl enable echo-bot
   sudo systemctl start echo-bot
   ```

### Service Management

```bash
# Check status
sudo systemctl status echo-bot

# View logs
sudo journalctl -u echo-bot -f

# Restart
sudo systemctl restart echo-bot

# Stop
sudo systemctl stop echo-bot

# Disable autostart
sudo systemctl disable echo-bot
```

## Configuration

### Basic Configuration

```json
{
  "nats": {
    "servers": ["nats://localhost:4222"],
    "user": "bot_user",
    "password": "bot_password"
  },
  "channels": [
    {
      "domain": "cytu.be",
      "channel": "lounge"
    }
  ],
  "retry_attempts": 3,
  "handler_timeout": 30.0
}
```

### Environment Variables

You can use environment variables in your config:

```json
{
  "nats": {
    "servers": ["nats://localhost:4222"],
    "user": "${NATS_USER}",
    "password": "${NATS_PASSWORD}"
  }
}
```

Set them before running:

```bash
# Linux
export NATS_USER=bot_user
export NATS_PASSWORD=bot_password
./start-echo-bot.sh

# Windows
$env:NATS_USER="bot_user"
$env:NATS_PASSWORD="bot_password"
.\start-echo-bot.ps1
```

### Advanced Configuration

```json
{
  "nats": {
    "servers": ["nats://server1:4222", "nats://server2:4222"],
    "user": "bot_user",
    "password": "bot_password",
    "connect_timeout": 5.0,
    "reconnect_time_wait": 2.0,
    "max_reconnect_attempts": 10,
    "ping_interval": 120,
    "max_pending_size": 65536
  },
  "channels": [
    {
      "domain": "cytu.be",
      "channel": "channel1"
    },
    {
      "domain": "cytu.be",
      "channel": "channel2"
    }
  ],
  "retry_attempts": 5,
  "retry_delay": 1.0,
  "handler_timeout": 60.0,
  "log_level": "INFO"
}
```

## Troubleshooting

### Bot Won't Start

1. **Check Python version**
   ```bash
   python3 --version  # Should be 3.11+
   ```

2. **Check NATS connectivity**
   ```bash
   nc -zv localhost 4222
   ```

3. **Check logs**
   ```bash
   cat echo_bot.log
   ```

### Connection Issues

1. **Verify NATS server is running**
   ```bash
   systemctl status nats  # Linux
   ```

2. **Check firewall rules**
   ```bash
   sudo ufw status  # Linux
   ```

3. **Test NATS connection**
   ```bash
   nats-server --version
   nats sub test
   ```

### Permission Issues (Linux)

```bash
# Fix ownership
sudo chown -R bot:bot /opt/kryten-misc

# Fix permissions
chmod +x /opt/kryten-misc/start-echo-bot.sh
```

### Memory Issues

If the bot uses too much memory, adjust the systemd service:

```ini
[Service]
MemoryMax=256M
```

### High CPU Usage

Adjust CPU quota in systemd service:

```ini
[Service]
CPUQuota=25%
```

## Upgrading

### Standalone

```bash
# Update kryten-py
pip install --upgrade kryten-py

# Restart bot
./stop-echo-bot.sh
./start-echo-bot.sh
```

### systemd

```bash
sudo systemctl stop echo-bot
sudo -u bot .venv/bin/pip install --upgrade kryten-py
sudo systemctl start echo-bot
```

## Support

For issues or questions:
- Check logs: `echo_bot.log` or `journalctl -u echo-bot`
- Review configuration: verify NATS settings and channel names
- Test NATS connectivity independently
- Check kryten-py documentation: https://pypi.org/project/kryten-py/
