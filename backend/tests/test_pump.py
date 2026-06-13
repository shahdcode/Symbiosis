#!/usr/bin/env python3
"""
test_pump.py
------------
Standalone pump + valve tester. Runs completely outside the backend.
Usage:
    python test_pump.py --port COM3 --plant plant_1 --ml 50
    python test_pump.py --port COM3 --plant plant_2 --ml 100
    python test_pump.py --port COM3 --plant plant_1 --ml 50 --plant plant_2 --ml 80

Place this file anywhere — it has no imports from the app.

Requirements: pip install pyserial
"""

import argparse
import json
import sys
import time

try:
    import serial
except ImportError:
    print("ERROR: pyserial not installed. Run:  pip install pyserial")
    sys.exit(1)


# ── Helpers ───────────────────────────────────────────────────────────────────

def open_port(port: str, baud: int = 115200, timeout: float = 3.0) -> serial.Serial:
    print(f"Opening {port} @ {baud} baud…")
    ser = serial.Serial(port, baud, timeout=timeout)
    time.sleep(2.5)          # wait for ESP32 boot
    ser.reset_input_buffer()
    print("  Connected.\n")
    return ser


def send_json(ser: serial.Serial, cmd: dict) -> None:
    line = json.dumps(cmd, separators=(",", ":")) + "\n"
    ser.write(line.encode("utf-8"))
    print(f"  → Sent: {line.strip()}")


def wait_for_confirm(ser: serial.Serial, timeout: float = 30.0) -> dict | None:
    """Block until the Arduino sends back a JSON event or timeout."""
    deadline = time.time() + timeout
    buf = b""
    while time.time() < deadline:
        if ser.in_waiting:
            buf += ser.read(ser.in_waiting)
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                text = line.decode("utf-8", errors="replace").strip()
                if not text:
                    continue
                if text.startswith("{"):
                    try:
                        msg = json.loads(text)
                        return msg
                    except json.JSONDecodeError:
                        pass
                else:
                    print(f"  (Arduino) {text}")
        time.sleep(0.05)
    return None


# ── Test routines ─────────────────────────────────────────────────────────────

def test_water(ser: serial.Serial, plant_id: str, ml: float) -> None:
    print(f"\n{'─'*50}")
    print(f"  WATER TEST — {plant_id}  →  {ml:.1f} ml")
    print(f"{'─'*50}")
    print(f"  Pump duration ≈ {ml / 10.0:.1f} s  (calibrate if needed)")

    send_json(ser, {"water": {"plant": plant_id, "ml": ml}})
    print("  Waiting for confirmation…")

    confirm = wait_for_confirm(ser, timeout=ml / 10.0 + 10.0)
    if confirm:
        if confirm.get("event") == "water_delivered":
            print(f"  ✅ Confirmed: {confirm['plant']} received {confirm['ml']} ml")
        else:
            print(f"  ℹ️  Got event: {confirm}")
    else:
        print("  ⚠️  No confirmation received within timeout")


def test_servo(ser: serial.Serial, angle: int) -> None:
    print(f"\n{'─'*50}")
    print(f"  SERVO TEST — moving to {angle}°")
    print(f"{'─'*50}")

    send_json(ser, {"servo_lid": {"angle": angle}})
    print("  Waiting for confirmation…")

    confirm = wait_for_confirm(ser, timeout=5.0)
    if confirm:
        if confirm.get("event") == "lid_moved":
            print(f"  ✅ Lid moved to {confirm['angle']}°")
        else:
            print(f"  ℹ️  Got event: {confirm}")
    else:
        print("  ⚠️  No confirmation received within timeout")


def read_sensors_once(ser: serial.Serial) -> None:
    """Print one round of sensor readings (waits up to 35 s for the next burst)."""
    print(f"\n{'─'*50}")
    print("  SENSOR SNAPSHOT  (waiting up to 35 s for next reading burst…)")
    print(f"{'─'*50}")
    buf = b""
    deadline = time.time() + 35
    count = 0
    while time.time() < deadline and count < 2:
        if ser.in_waiting:
            buf += ser.read(ser.in_waiting)
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                text = line.decode("utf-8", errors="replace").strip()
                if not text:
                    continue
                if text.startswith("{"):
                    try:
                        msg = json.loads(text)
                        if "plant_id" in msg:
                            pid = msg["plant_id"]
                            name = "Basil" if pid == "plant_1" else "Coleus"
                            print(
                                f"  {name:10s} | "
                                f"moisture={msg.get('moisture','?')}%  "
                                f"temp={msg.get('temperature','?')}°C  "
                                f"humidity={msg.get('humidity','?')}%  "
                                f"light={msg.get('light','?')}  "
                                f"tank={msg.get('tank_level','?')} cm"
                            )
                            count += 1
                    except json.JSONDecodeError:
                        pass
                else:
                    print(f"  (Arduino) {text}")
        time.sleep(0.05)
    if count == 0:
        print("  ⚠️  No sensor data received — check that firmware is running")


# ── CLI ───────────────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Symbiosis hardware tester — pump, valve, servo, sensors"
    )
    p.add_argument("--port", default="COM3", help="Serial port (default: COM3)")
    p.add_argument("--baud", type=int, default=115200)
    p.add_argument(
        "--plant", dest="plants", action="append", default=[],
        choices=["plant_1", "plant_2"],
        help="Plant to water (repeat for multiple)",
    )
    p.add_argument(
        "--ml", dest="mls", type=float, action="append", default=[],
        help="ml to dispense for the corresponding --plant (repeat to match)",
    )
    p.add_argument(
        "--servo", type=int, default=None, metavar="ANGLE",
        help="Move servo to ANGLE degrees (0 = close, 90 = open)",
    )
    p.add_argument(
        "--sensors", action="store_true",
        help="Print one round of sensor readings then exit",
    )
    return p


def main() -> None:
    args = build_parser().parse_args()

    if not args.plants and args.servo is None and not args.sensors:
        print("Nothing to do. Use --plant, --servo, or --sensors.")
        build_parser().print_help()
        sys.exit(0)

    # Pair up plants and ml values
    plants = args.plants
    mls = args.mls
    if len(mls) < len(plants):
        # Fill missing ml values with a safe default of 50 ml
        mls += [50.0] * (len(plants) - len(mls))

    ser = open_port(args.port, args.baud)

    try:
        if args.sensors:
            read_sensors_once(ser)

        for plant_id, ml in zip(plants, mls):
            test_water(ser, plant_id, ml)
            time.sleep(1.0)   # brief pause between plants

        if args.servo is not None:
            test_servo(ser, args.servo)

    finally:
        ser.close()
        print("\n  Serial port closed. Done.")


if __name__ == "__main__":
    main()