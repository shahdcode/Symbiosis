"""Hardware bridge using simple serial reader"""
import logging
from typing import Optional

import simple_serial
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
_serial_started = False

# Reference to the ResourceAgent — set by scheduler on startup
_resource_agent = None

def set_resource_agent(agent) -> None:
    global _resource_agent
    _resource_agent = agent


def _on_serial_message(msg: dict):
    """Callback for incoming parsed JSON messages from Arduino."""
    try:
        # ── Hardware event confirmations ──────────────────────────────
        if msg.get("event") in ("water_delivered", "lid_moved", "lid_auto_closed"):
            logger.info("Hardware event: %s", msg)
            return

        # ── Sensor readings ───────────────────────────────────────────
        if 'plant_id' in msg:
            tank_raw = msg.get('tank_level')
            # Update tank level from ultrasonic sensor if available
            # tank_raw is distance in cm; convert to ml using tank geometry
            # Assumes cylindrical tank: 20 cm diameter → ~314 cm² cross-section
            # Adjust TANK_CROSS_SECTION_CM2 and TANK_MAX_HEIGHT_CM for your tank
            if tank_raw is not None and tank_raw > 0 and _resource_agent is not None:
                TANK_MAX_HEIGHT_CM = 20.0
                TANK_CROSS_SECTION_CM2 = 314.0   # π * r² for r=10 cm
                depth_cm = max(0.0, TANK_MAX_HEIGHT_CM - float(tank_raw))
                level_ml = depth_cm * TANK_CROSS_SECTION_CM2
                try:
                    _resource_agent.update_tank_level(level_ml)
                except Exception:
                    logger.exception("Failed to update resource agent tank level")

            sr = SensorReading(
                plant_id=msg.get('plant_id'),
                moisture_pct=float(msg.get('moisture', 0.0)),
                light_lux=float(msg.get('light', 0.0)),
                temperature_c=float(msg.get('temperature')) if msg.get('temperature') is not None else None,
                humidity_pct=float(msg.get('humidity')) if msg.get('humidity') is not None else None,
                sensor_ok=True,
            )
            _latest_readings[sr.plant_id] = sr
            logger.debug("Received sensor reading for %s: moisture=%.1f%%", sr.plant_id, sr.moisture_pct)
    except Exception as e:
        logger.exception("Failed to handle serial message: %s", e)


async def start_bridge():
    global _serial_started
    if not settings.arduino_port:
        logger.info("No ARDUINO_PORT configured — using simulated bridge")
        return
    
    if simple_serial.start_serial_reader(settings.arduino_port, settings.arduino_baud_rate):
        _serial_started = True
        logger.info(f"Serial bridge started on {settings.arduino_port}@{settings.arduino_baud_rate}")
    else:
        logger.error(f"Failed to start serial bridge on {settings.arduino_port}")

async def stop_bridge():
    simple_serial.stop_serial_reader()
    logger.info("Serial bridge stopped")

def read_sensors() -> list[SensorReading]:
    """Return the latest sensor readings from the ESP32"""
    if not _serial_started:
        # Fallback to simulation if configured
        if settings.simulate_sensors:
            return _simulate_sensors()
        return []
    
    return simple_serial.get_sensor_readings()

def _simulate_sensors() -> list[SensorReading]:
    """Simulate sensor readings for testing"""
    import random
    readings = []
    for pid in ["plant_1", "plant_2"]:
        readings.append(SensorReading(
            plant_id=pid,
            moisture_pct=round(random.uniform(30, 70), 1),
            light_lux=round(random.uniform(1000, 8000), 1),
            temperature_c=round(random.uniform(20, 30), 1),
            humidity_pct=round(random.uniform(40, 80), 1),
            sensor_ok=True,
        ))
    return readings

def actuate_water(plant_id: str, ml: float) -> bool:
    """Send water command to ESP32"""
    if not _serial_started:
        logger.warning(f"Cannot send water command: serial not connected")
        return False
    
    cmd = {"water": {"plant": plant_id, "ml": float(ml)}}
    try:
        import json
        simple_serial._serial_connection.write((json.dumps(cmd) + "\n").encode())
        logger.info(f"Commanded water → {plant_id}: {ml} ml")
        return True
    except Exception as e:
        logger.error(f"Failed to send water command: {e}")
        return False

def actuate_servo_lid(angle: int) -> bool:
    """Send servo command to ESP32"""
    if not _serial_started:
        logger.warning(f"Cannot send servo command: serial not connected")
        return False
    
    cmd = {"servo_lid": {"angle": int(angle)}}
    try:
        import json
        simple_serial._serial_connection.write((json.dumps(cmd) + "\n").encode())
        logger.info(f"Commanded servo_lid → angle={angle}")
        return True
    except Exception as e:
        logger.error(f"Failed to send servo command: {e}")
        return False

def actuate_light(plant_id: str, duration_minutes: float) -> bool:
    """Light command (informational only)"""
    logger.info(f"Light command ignored: {plant_id} for {duration_minutes} min")
    return True