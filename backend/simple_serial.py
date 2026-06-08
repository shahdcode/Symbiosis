import serial
import threading
import json
import time
from collections import deque
import logging

logger = logging.getLogger(__name__)

# Store latest sensor readings
latest_readings = {}
_readings_lock = threading.Lock()
_serial_thread = None
_serial_connection = None
_running = False

def start_serial_reader(port='COM3', baudrate=115200):
    global _serial_connection, _serial_thread, _running
    
    try:
        _serial_connection = serial.Serial(port, baudrate, timeout=1)
        _running = True
        _serial_thread = threading.Thread(target=_read_serial, daemon=True)
        _serial_thread.start()
        logger.info(f"Serial reader started on {port} at {baudrate}")
        return True
    except Exception as e:
        logger.error(f"Failed to open serial port: {e}")
        return False

def _read_serial():
    global _serial_connection, _running
    buffer = ""
    while _running and _serial_connection and _serial_connection.is_open:
        try:
            if _serial_connection.in_waiting:
                data = _serial_connection.read(_serial_connection.in_waiting).decode('utf-8', errors='ignore')
                buffer += data
                
                # Process complete lines
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    line = line.strip()
                    if line:
                        try:
                            reading = json.loads(line)
                            plant_id = reading.get('plant_id')
                            if plant_id:
                                with _readings_lock:
                                    latest_readings[plant_id] = reading
                                logger.debug(f"Received: {plant_id} moisture={reading.get('moisture')}%")
                        except json.JSONDecodeError:
                            logger.warning(f"Invalid JSON: {line}")
            else:
                time.sleep(0.01)
        except Exception as e:
            logger.error(f"Serial read error: {e}")
            time.sleep(0.1)

def get_sensor_readings():
    """Return list of SensorReading objects from latest data"""
    from app.models.domain import SensorReading
    
    readings = []
    with _readings_lock:
        for plant_id, data in latest_readings.items():
            try:
                reading = SensorReading(
                    plant_id=plant_id,
                    moisture_pct=float(data.get('moisture', 0)),
                    light_lux=float(data.get('light', 0)),
                    temperature_c=float(data.get('temperature', 0)) if data.get('temperature') else None,
                    humidity_pct=float(data.get('humidity', 0)) if data.get('humidity') else None,
                    sensor_ok=True
                )
                readings.append(reading)
            except Exception as e:
                logger.error(f"Error creating reading for {plant_id}: {e}")
    return readings

def stop_serial_reader():
    global _running, _serial_connection
    _running = False
    if _serial_connection and _serial_connection.is_open:
        _serial_connection.close()
    logger.info("Serial reader stopped")