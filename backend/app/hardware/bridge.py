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


import random as _random

# Simulated moisture state per plant (drifts down over time, reset on watering)
_sim_moisture: dict[str, float] = {}

def read_sensors() -> list[SensorReading]:
    """Return the latest sensor readings collected from the Arduino.

    If no hardware connected and SIMULATE_SENSORS env var is set,
    returns simulated readings for all known plant IDs.
    """
    if _latest_readings:
        return list(_latest_readings.values())

    from app.core.config import settings
    if not settings.simulate_sensors:
        return []

    # Simulated plant IDs — must match what's seeded in the DB
    sim_plant_ids = ["plant_1", "plant_2", "plant_3", "plant_4", "plant_5"]
    readings = []
    for pid in sim_plant_ids:
        # Drift moisture down slowly, simulate different stress levels
        if pid not in _sim_moisture:
            _sim_moisture[pid] = _random.uniform(25.0, 75.0)
        else:
            # each cycle loses 1–3% moisture (evapotranspiration)
            _sim_moisture[pid] = max(5.0, _sim_moisture[pid] - _random.uniform(1.0, 3.0))

        readings.append(SensorReading(
            plant_id=pid,
            moisture_pct=round(_sim_moisture[pid], 1),
            light_lux=round(_random.uniform(800.0, 8000.0), 1),
            temperature_c=round(_random.uniform(18.0, 28.0), 1),
            humidity_pct=round(_random.uniform(40.0, 80.0), 1),
            sensor_ok=True,
        ))
    return readings


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
    # update simulated moisture when water is dispensed
    if plant_id in _sim_moisture:
        _sim_moisture[plant_id] = min(100.0, _sim_moisture[plant_id] + ml * 0.02)
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