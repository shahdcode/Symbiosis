"""Hardware bridge using simple serial reader"""
import logging
from app.core.config import settings
from app.models.domain import SensorReading
import simple_serial

logger = logging.getLogger(__name__)

_serial_started = False

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