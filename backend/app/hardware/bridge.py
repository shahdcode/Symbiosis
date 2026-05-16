"""Serial-backed hardware bridge.

Uses `app.hardware.serial_bridge` to manage a serial connection to the
Arduino. Exposes `start_bridge`, `stop_bridge`, `read_sensors`, and
actuation functions used by the scheduler.
"""
import asyncio
import logging
import json
from typing import Optional

from app.core.config import settings
from app.models.domain import SensorReading
from app.core.logging import get_logger
from app.hardware.serial_bridge import open_serial, SerialBridgeProtocol

logger = get_logger(__name__)

# Holds latest sensor messages keyed by plant_id
_latest_readings: dict[str, SensorReading] = {}

# Serial protocol instance
_serial_protocol: Optional[SerialBridgeProtocol] = None
_serial_transport = None


def _on_serial_message(msg: dict):
    """Callback for incoming parsed JSON messages from Arduino."""
    try:
        # Accept messages with plant_id and sensor fields
        if 'plant_id' in msg:
            sr = SensorReading(
                plant_id=msg.get('plant_id'),
                moisture_pct=float(msg.get('moisture', 0.0)),
                light_lux=float(msg.get('light', 0.0)),
                temperature_c=float(msg.get('temperature')) if msg.get('temperature') is not None else None,
                humidity_pct=float(msg.get('humidity')) if msg.get('humidity') is not None else None,
                sensor_ok=True,
            )
            _latest_readings[sr.plant_id] = sr
            logger.debug("Received sensor reading: %s", sr.plant_id)
    except Exception as e:
        logger.exception("Failed to handle serial message: %s", e)


async def start_bridge():
    """Open serial connection to Arduino if configured. Non-blocking."""
    global _serial_protocol, _serial_transport
    if not settings.arduino_port:
        logger.info("No ARDUINO_PORT configured — using simulated bridge")
        return
    try:
        _serial_transport, _serial_protocol = await open_serial(settings.arduino_port, settings.arduino_baud_rate, _on_serial_message)
        logger.info("Serial bridge started on %s@%d", settings.arduino_port, settings.arduino_baud_rate)
    except Exception as e:
        logger.exception("Failed to open serial port: %s", e)


async def stop_bridge():
    global _serial_transport, _serial_protocol
    if _serial_transport:
        _serial_transport.close()
        _serial_transport = None
    _serial_protocol = None
    logger.info("Serial bridge stopped")


def read_sensors() -> list[SensorReading]:
    """Return the latest sensor readings collected from the Arduino.

    If no hardware connected, returns an empty list.
    """
    return list(_latest_readings.values())


def _send_command(cmd: dict) -> None:
    if _serial_protocol is None:
        logger.warning("Serial protocol not connected — cannot send command: %s", cmd)
        return
    try:
        _serial_protocol.send_command(cmd)
    except Exception as e:
        logger.exception("Failed to send serial command: %s", e)


def actuate_water(plant_id: str, ml: float) -> bool:
    _send_command({"water": {"plant": plant_id, "ml": float(ml)}})
    logger.info("Commanded water → %s: %.1f ml", plant_id, ml)
    return True


def actuate_light(plant_id: str, duration_minutes: float) -> bool:
    _send_command({"light": {"plant": plant_id, "minutes": float(duration_minutes)}})
    logger.info("Commanded light → %s: %.1f min", plant_id, duration_minutes)
    return True


def actuate_servo_lid(angle: int) -> bool:
    _send_command({"servo_lid": {"angle": int(angle)}})
    logger.info("Commanded servo_lid → angle=%d", angle)
    return True