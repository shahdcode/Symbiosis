"""Serial bridge: JSON-lines over USB serial to Arduino.
backend/app/hardware/serial_bridge.py
This is a lightweight, non-blocking bridge using `pyserial` that reads
JSON lines from the Arduino and exposes a callback for processed readings.
Commands can be sent via `send_command`.
"""
import asyncio
import json
import logging
try:
    import serial
    import serial.asyncio
except ImportError:
    serial = None
from typing import Callable

logger = logging.getLogger(__name__)


class SerialBridgeProtocol(asyncio.Protocol):
    def __init__(self, on_message: Callable[[dict], None]):
        self.on_message = on_message
        self.transport = None
        self._buffer = b""

    def connection_made(self, transport):
        self.transport = transport
        logger.info("Serial connection established")

    def data_received(self, data):
        self._buffer += data
        while b"\n" in self._buffer:
            line, self._buffer = self._buffer.split(b"\n", 1)
            stripped = line.decode('utf-8', errors='replace').strip()
            if not stripped:
                continue
            try:
                msg = json.loads(stripped)
                self.on_message(msg)
            except json.JSONDecodeError:
                logger.debug("Non-JSON serial line (ignored): %s", stripped)
            except Exception as e:
                logger.warning("Serial parse error: %s — line: %s", e, stripped)

    def send_command(self, obj: dict):
        if self.transport is None:
            raise RuntimeError("Serial transport not connected")
        line = (json.dumps(obj) + "\n").encode('utf-8')
        self.transport.write(line)


# async def open_serial(port: str, baud: int, on_message: Callable[[dict], None]):
#     loop = asyncio.get_running_loop()
#     protocol_factory = lambda: SerialBridgeProtocol(on_message)
#     transport, protocol = await serial.asyncio.create_serial_connection(loop, protocol_factory, port, baudrate=baud)
#     return transport, protocol


async def open_serial(port: str, baud: int, on_message):
    if serial is None:
        raise RuntimeError("pyserial not installed")
    loop = asyncio.get_running_loop()
    protocol_factory = lambda: SerialBridgeProtocol(on_message)
    transport, protocol = await serial.asyncio.create_serial_connection(loop, protocol_factory, port, baudrate=baud)
    return transport, protocol