"""Tests for echo bot."""

import pytest
from kryten import MockKrytenClient
from kryten.models import RawEvent

from echo_bot.main import EchoBot


@pytest.mark.asyncio
async def test_echo_bot_chat_command():
    """Test echo bot responds to !echo command in chat."""
    config = {
        "nats": {"servers": ["nats://localhost:4222"]},
        "channels": [{"domain": "test", "channel": "test"}],
    }

    async with MockKrytenClient(config) as client:
        bot = EchoBot(client, bot_name="EchoBot")

        @client.on("chatmsg")
        async def handler(event):
            await bot.handle_chat_message(event)

        # Simulate !echo command
        await client.simulate_event(
            "chatmsg",
            {"username": "Alice", "msg": "!echo Hello, world!", "time": 1234567890},
            channel="test",
            domain="test",
        )

        # Check that bot sent chat message
        commands = client.get_published_commands()
        assert len(commands) == 1
        assert commands[0]["action"] == "chat"
        assert "Hello, world!" in commands[0]["data"]["message"]
        assert "@Alice" in commands[0]["data"]["message"]


@pytest.mark.asyncio
async def test_echo_bot_ignores_own_messages():
    """Test echo bot ignores its own messages."""
    config = {
        "nats": {"servers": ["nats://localhost:4222"]},
        "channels": [{"domain": "test", "channel": "test"}],
    }

    async with MockKrytenClient(config) as client:
        bot = EchoBot(client, bot_name="EchoBot")

        @client.on("chatmsg")
        async def handler(event):
            await bot.handle_chat_message(event)

        # Simulate message from bot itself
        await client.simulate_event(
            "chatmsg",
            {"username": "EchoBot", "msg": "!echo test", "time": 1234567890},
            channel="test",
        )

        # Should not respond
        commands = client.get_published_commands()
        assert len(commands) == 0


@pytest.mark.asyncio
async def test_echo_bot_empty_message():
    """Test echo bot handles empty !echo command."""
    config = {
        "nats": {"servers": ["nats://localhost:4222"]},
        "channels": [{"domain": "test", "channel": "test"}],
    }

    async with MockKrytenClient(config) as client:
        bot = EchoBot(client, bot_name="EchoBot")

        @client.on("chatmsg")
        async def handler(event):
            await bot.handle_chat_message(event)

        # Simulate empty !echo (just the command without space)
        await client.simulate_event(
            "chatmsg",
            {"username": "Bob", "msg": "!echo", "time": 1234567890},
            channel="test",
        )

        # Should not respond since command doesn't match pattern
        commands = client.get_published_commands()
        assert len(commands) == 0


@pytest.mark.asyncio
async def test_echo_bot_pm_command():
    """Test echo bot responds to echo command in PM."""
    config = {
        "nats": {"servers": ["nats://localhost:4222"]},
        "channels": [{"domain": "test", "channel": "test"}],
    }

    async with MockKrytenClient(config) as client:
        bot = EchoBot(client, bot_name="EchoBot")

        @client.on("pm")
        async def handler(event):
            await bot.handle_pm_message(event)

        # Simulate PM with echo command
        await client.simulate_event(
            "pm",
            {"username": "Charlie", "msg": "echo Secret message", "time": 1234567890},
            channel="test",
        )

        # Should send PM back
        commands = client.get_published_commands()
        assert len(commands) == 1
        assert commands[0]["action"] == "pm"
        assert commands[0]["data"]["to"] == "Charlie"
        assert commands[0]["data"]["message"] == "Secret message"


@pytest.mark.asyncio
async def test_echo_bot_stats():
    """Test echo bot tracks statistics."""
    config = {
        "nats": {"servers": ["nats://localhost:4222"]},
        "channels": [{"domain": "test", "channel": "test"}],
    }

    async with MockKrytenClient(config) as client:
        bot = EchoBot(client, bot_name="EchoBot")

        @client.on("chatmsg")
        async def handler(event):
            await bot.handle_chat_message(event)

        # Process multiple messages
        for i in range(3):
            await client.simulate_event(
                "chatmsg",
                {"username": f"User{i}", "msg": f"!echo test{i}", "time": 1234567890},
                channel="test",
            )

        # Check stats
        stats = bot.get_stats()
        assert stats["messages_processed"] == 3
