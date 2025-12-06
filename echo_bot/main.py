"""
Echo Bot - Main entry point

A CyTube bot that echoes messages back to users.
- Responds to "!echo <message>" in chat
- Responds to "echo <message>" in private messages
"""

import argparse
import asyncio
import logging
import sys
from pathlib import Path

from kryten import KrytenClient, KrytenConfig
from kryten.models import ChatMessageEvent
from kryten.models import RawEvent

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("echo_bot.log"),
    ],
)
logger = logging.getLogger(__name__)


class EchoBot:
    """Echo bot that responds to chat and PM commands."""

    def __init__(self, client: KrytenClient, bot_name: str = "EchoBot"):
        """Initialize the echo bot.

        Args:
            client: KrytenClient instance
            bot_name: Name of the bot (to avoid echoing itself)
        """
        self.client = client
        self.bot_name = bot_name
        self.messages_processed = 0

    async def handle_chat_message(self, event: ChatMessageEvent) -> None:
        """Handle chat messages looking for !echo command.

        Args:
            event: Chat message event
        """
        try:
            # Extract data from typed event
            username = event.username
            message = event.message
            channel = event.channel

            # Ignore our own messages
            if username == self.bot_name:
                return

            message = message.strip()
            logger.info(
                    u"%s:%s: %s", channel, username, message
                )
            # Check for !echo command
            if message.startswith("!echo "):
                echo_text = message[6:]  # Remove "!echo " prefix

                if echo_text == "" or echo_text is None:
                    await self.client.send_chat(
                        channel, f"@{username} Usage: !echo <message>"
                    )
                    return

                # Echo the message back to chat
                await self.client.send_chat(channel, f"@{username}: {echo_text}")

                self.messages_processed += 1
                

        except Exception as e:
            logger.error(f"Error handling chat message: {e}", exc_info=True)

    async def handle_pm_message(self, event: ChatMessageEvent) -> None:
        """Handle private messages - echo ALL PMs back.

        Args:
            event: Chat message event (PM)
        """
        try:
            # Extract data from typed event
            username = event.username
            message = event.message
            channel = event.channel

            # Debug logging
            logger.info(f"Received PM from {username}: '{message}'")

            # Ignore our own messages
            if username == self.bot_name:
                logger.debug(f"Ignoring PM from self")
                return

            message = message.strip()

            # Echo ALL PMs back (not just those starting with "echo")
            if message:
                # Echo the message back via PM
                await self.client.send_pm(channel, username, f"Echo: {message}")

                self.messages_processed += 1
                logger.info(f"Sent PM echo to {username}: '{message}'")
            else:
                await self.client.send_pm(channel, username, "Send me a message to echo!")

        except Exception as e:
            logger.error(f"Error handling PM: {e}", exc_info=True)

    def get_stats(self) -> dict[str, int]:
        """Get bot statistics.

        Returns:
            Dictionary with bot statistics
        """
        return {"messages_processed": self.messages_processed}


async def main(config_path: str | None = None) -> None:
    """Main bot entry point.

    Args:
        config_path: Path to configuration file (optional)
    """
    # Load configuration
    if config_path and Path(config_path).exists():
        logger.info(f"Loading configuration from {config_path}")
        config = KrytenConfig.from_json(config_path)
    else:
        # Default configuration
        logger.info("Using default configuration")
        config = {
            "nats": {"servers": ["nats://localhost:4222"]},
            "channels": [{"domain": "cytu.be", "channel": "lounge"}],
        }

    # Create client and bot
    async with KrytenClient(config) as client:
        bot = EchoBot(client, bot_name="EchoBot")

        # Register chat message handler
        @client.on("chatmsg")
        async def on_chat(event: RawEvent):
            """Handle all chat messages."""
            await bot.handle_chat_message(event)

        # Register PM handler (PMs are also chatmsg events with meta.to field)
        @client.on("pm")
        async def on_pm(event: RawEvent):
            """Handle private messages."""
            await bot.handle_pm_message(event)

        # Log startup
        health = client.health()
        logger.info(f"Echo Bot started! Connected to {len(health.channels)} channel(s)")
        logger.info("Waiting for messages...")
        logger.info("Commands:")
        logger.info("  Chat: !echo <message>")
        logger.info("  PM: echo <message>")
        logger.info("Press Ctrl+C to stop")

        # Run the bot
        try:
            await client.run()
        except KeyboardInterrupt:
            logger.info("Shutdown signal received")
        finally:
            stats = bot.get_stats()
            logger.info(f"Bot statistics: {stats}")


def parse_args() -> argparse.Namespace:
    """Parse command line arguments.

    Returns:
        Parsed arguments
    """
    parser = argparse.ArgumentParser(description="Echo Bot - CyTube message echo bot")
    parser.add_argument(
        "--config",
        "-c",
        type=str,
        help="Path to configuration file (JSON)",
        default="config.json",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true", help="Enable verbose logging"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    # Set logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    try:
        asyncio.run(main(config_path=args.config))
    except KeyboardInterrupt:
        logger.info("\nBot stopped by user")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
