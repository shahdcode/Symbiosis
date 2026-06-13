"""Hardware bridge for Symbiosis.
backend/app/hardware/bridge.py

Owns the serial connection to the ESP32 via SerialBridgeProtocol (async,
JSON-lines). All commands go through send_command() on the protocol so
the same connection handles both RX (sensor data) and TX (actuation).

Key points:
- simple_serial is NOT used here — that was a test module.
- set_resource_agent() must be called before start_bridge() so tank
  level updates from the ultrasonic sensor reach the ResourceAgent.
- actuate_servo_lid() must ONLY be called when the scheduler has
  determined the lid should actually move. Do not call it every cycle.
"""

import json
import logging
from typing import Optional

from app.core.config import settings
from app.models.domain import SensorReading
from app.core.logging import get_logger
from app.hardware.serial_bridge import open_serial, SerialBridgeProtocol

logger = get_logger(__name__)

# ── State ─────────────────────────────────────────────────────────────────────
_latest_readings: dict[str, SensorReading] = {}
_serial_protocol: Optional[SerialBridgeProtocol] = None
_serial_transport = None
_resource_agent = None

# ── Tank geometry — adjust to your physical reservoir ────────────────────────
# Ultrasonic sensor returns distance-to-water-surface in cm.
# depth_cm = MAX_HEIGHT - sensor_reading  →  level_ml = depth_cm × BASE_AREA
_TANK_MAX_HEIGHT_CM: float = 20.0
_TANK_BASE_AREA_CM2: float = 314.0   # π × r² for a 10 cm radius cylinder


def set_resource_agent(agent) -> None:
    """Inject the ResourceAgent so tank level is updated from sensor data."""
    global _resource_agent
    _resource_agent = agent


# ── Serial message handler ────────────────────────────────────────────────────

def _on_serial_message(msg: dict) -> None:
    """Called for every valid JSON line received from the Arduino."""
    try:
        event = msg.get("event")

        # Hardware confirmation — log and done
        if event in ("water_delivered", "lid_moved", "lid_auto_closed", "boot"):
            logger.info("Hardware event: %s", msg)
            return

        # Sensor reading
        if "plant_id" not in msg:
            logger.debug("Unrecognised message from Arduino: %s", msg)
            return

        pid = str(msg["plant_id"])

        # Update tank level from ultrasonic (every reading carries it)
        tank_raw = msg.get("tank_level")
        if tank_raw is not None and float(tank_raw) >= 0 and _resource_agent is not None:
            depth_cm = max(0.0, _TANK_MAX_HEIGHT_CM - float(tank_raw))
            level_ml = depth_cm * _TANK_BASE_AREA_CM2
            try:
                _resource_agent.update_tank_level(level_ml)
            except Exception:
                logger.exception("Failed to update tank level on ResourceAgent")

        # Safe float conversion — handles NaN from DHT failures
        def _f(val, fallback=None):
            try:
                v = float(val)
                return None if v != v else v   # NaN → None
            except (TypeError, ValueError):
                return fallback

        sr = SensorReading(
            plant_id=pid,
            moisture_pct=_f(msg.get("moisture"), 0.0),
            light_lux=_f(msg.get("light"), 0.0),
            temperature_c=_f(msg.get("temperature")),
            humidity_pct=_f(msg.get("humidity")),
            sensor_ok=True,
        )
        _latest_readings[pid] = sr
        logger.debug(
            "Sensor — %s: moisture=%.1f%%  temp=%s°C  humidity=%s%%  light=%.0f lux",
            pid,
            sr.moisture_pct,
            f"{sr.temperature_c:.1f}" if sr.temperature_c is not None else "N/A",
            f"{sr.humidity_pct:.1f}" if sr.humidity_pct is not None else "N/A",
            sr.light_lux,
        )

    except Exception:
        logger.exception("Error processing serial message: %s", msg)


# ── Bridge lifecycle ──────────────────────────────────────────────────────────

async def start_bridge() -> None:
    """Open the serial connection to the Arduino. Call once at startup."""
    global _serial_protocol, _serial_transport
    if not settings.arduino_port:
        logger.info("No ARDUINO_PORT set — serial bridge inactive (simulation mode)")
        return
    try:
        _serial_transport, _serial_protocol = await open_serial(
            settings.arduino_port,
            settings.arduino_baud_rate,
            _on_serial_message,
        )
        logger.info(
            "Serial bridge started on %s @ %d baud",
            settings.arduino_port, settings.arduino_baud_rate,
        )
    except Exception:
        logger.exception(
            "Failed to open serial port %s — check cable and port name",
            settings.arduino_port,
        )


async def stop_bridge() -> None:
    global _serial_transport, _serial_protocol
    if _serial_transport:
        _serial_transport.close()
        _serial_transport = None
    _serial_protocol = None
    logger.info("Serial bridge stopped")


# ── Sensor reads ──────────────────────────────────────────────────────────────

import random as _random
_sim_moisture: dict[str, float] = {}


def read_sensors() -> list[SensorReading]:
    """Return the most recent sensor readings.

    Uses real Arduino data if the bridge is connected.
    Falls back to simulation only when SIMULATE_SENSORS=true and no real
    data has arrived yet.
    """
    if _latest_readings:
        return list(_latest_readings.values())

    if not settings.simulate_sensors:
        return []

    # Simulation path
    for pid in ("plant_1", "plant_2"):
        if pid not in _sim_moisture:
            _sim_moisture[pid] = _random.uniform(35.0, 70.0)
        else:
            _sim_moisture[pid] = max(5.0, _sim_moisture[pid] - _random.uniform(0.5, 2.0))

    return [
        SensorReading(
            plant_id=pid,
            moisture_pct=round(_sim_moisture[pid], 1),
            light_lux=round(_random.uniform(800.0, 8000.0), 1),
            temperature_c=round(_random.uniform(18.0, 32.0), 1),
            humidity_pct=round(_random.uniform(40.0, 80.0), 1),
            sensor_ok=True,
        )
        for pid in ("plant_1", "plant_2")
    ]


# ── Serial command sender ─────────────────────────────────────────────────────

def _send_command(cmd: dict) -> bool:
    """Send a JSON command to the Arduino through the shared serial protocol."""
    if _serial_protocol is None:
        if settings.arduino_port:
            logger.warning("Serial not connected — command NOT sent: %s", cmd)
        else:
            logger.debug("No serial port configured — ignoring command: %s", cmd)
        return False
    try:
        _serial_protocol.send_command(cmd)
        return True
    except Exception:
        logger.exception("Failed to send command: %s", cmd)
        return False


# ── Actuation functions ───────────────────────────────────────────────────────

def actuate_water(plant_id: str, ml: float) -> bool:
    """Trigger pump + correct valve for `ml` ml to `plant_id`."""
    ok = _send_command({"water": {"plant": plant_id, "ml": float(ml)}})
    if ok:
        logger.info("Commanded water → %s: %.1f ml", plant_id, ml)
        # Keep simulated moisture consistent
        if plant_id in _sim_moisture:
            _sim_moisture[plant_id] = min(100.0, _sim_moisture[plant_id] + ml * 0.02)
    return ok


def actuate_servo_lid(angle: int) -> bool:
    """
    Rotate the servo lid to `angle` degrees.

    ONLY call this when the scheduler humidity check has decided the lid
    should move.  Do NOT call with angle=0 every cycle — that causes
    continuous servo movement.
    """
    ok = _send_command({"servo_lid": {"angle": int(angle)}})
    if ok:
        logger.info("Commanded servo_lid → angle=%d", angle)
    return ok


def actuate_light(plant_id: str, duration_minutes: float) -> bool:
    """Grow-light command (informational only — no dedicated hardware)."""
    logger.info("Light informational → %s: %.1f min (no hardware)", plant_id, duration_minutes)
    return True