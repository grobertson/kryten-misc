# Echo Bot

A CyTube bot that echoes messages back to users.

## Features

- Responds to `!echo <message>` in chat
- Responds to `echo <message>` in private messages
- Parrots the exact message back to the sender

## Installation

```bash
poetry install
```

## Configuration

Create a `config.json` file:

```json
{
  "nats": {
    "servers": ["nats://localhost:4222"],
    "user": "${NATS_USER}",
    "password": "${NATS_PASSWORD}"
  },
  "channels": [
    {"domain": "cytu.be", "channel": "lounge"}
  ]
}
```

Set environment variables:

```bash
export NATS_USER=your_user
export NATS_PASSWORD=your_password
```

## Usage

```bash
poetry run python echo_bot/main.py
```

Or with custom config:

```bash
poetry run python echo_bot/main.py --config /path/to/config.json
```

## Commands

- **Chat**: `!echo <message>` - Bot responds with `@username: <message>`
- **PM**: `echo <message>` - Bot responds via PM with `<message>`

## Testing

Run the test suite:

```bash
PYTHONPATH="d:\Devel\kryten-py\src;d:\Devel\kryten-misc" python -m pytest test_echo_bot.py -v
```

All tests passing:
- ✅ test_echo_bot_chat_command
- ✅ test_echo_bot_ignores_own_messages  
- ✅ test_echo_bot_empty_message
- ✅ test_echo_bot_pm_command
- ✅ test_echo_bot_stats

## Development

Built with:
- Python 3.11+
- kryten-py library
- Poetry for dependency management
