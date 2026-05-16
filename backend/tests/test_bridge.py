import asyncio
from app.hardware import bridge


def test_read_sensors_no_port_returns_list():
    # Ensure calling read_sensors when no serial configured returns list (likely empty)
    readings = bridge.read_sensors()
    assert isinstance(readings, list)
