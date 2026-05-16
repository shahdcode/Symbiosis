"""Serial bridge: JSON-lines over USB serial to Arduino.

This is a lightweight, non-blocking bridge using `pyserial` that reads
JSON lines from the Arduino and exposes a callback for processed readings.
Commands can be sent via `send_command`.
"""
import asyncio
import json
import logging
import serial
import serial.asyncio
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
            try:
                msg = json.loads(line.decode('utf-8').strip())
                self.on_message(msg)
            except Exception as e:
                logger.exception("Failed to parse serial line: %s", e)

    def send_command(self, obj: dict):
        if self.transport is None:
            raise RuntimeError("Serial transport not connected")
        line = (json.dumps(obj) + "\n").encode('utf-8')
        self.transport.write(line)


async def open_serial(port: str, baud: int, on_message: Callable[[dict], None]):
    loop = asyncio.get_running_loop()
    protocol_factory = lambda: SerialBridgeProtocol(on_message)
    transport, protocol = await serial.asyncio.create_serial_connection(loop, protocol_factory, port, baudrate=baud)
    return transport, protocol
