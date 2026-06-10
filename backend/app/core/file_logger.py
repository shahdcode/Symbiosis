"""
Symbiosis File Logger
---------------------
Writes two output streams per session:
  1. symbiosis_readings_YYYYMMDD.csv  — timestamped sensor rows (machine-readable)
  2. symbiosis_report_YYYYMMDD.txt    — human-readable narrative report

Call `setup_file_logging()` once at startup.
Call `log_cycle(cycle_data)` after each allocation cycle.
"""
import csv
import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_LOG_DIR = Path(os.environ.get("LOG_DIR", "logs"))
_csv_path: Path | None = None
_txt_path: Path | None = None
_csv_writer = None
_csv_file = None

CSV_FIELDS = [
    "timestamp", "cycle_id",
    "plant_id", "moisture_pct", "ekf_moisture", "moisture_target",
    "light_lux", "temperature_c", "humidity_pct",
    "water_deficit", "urgency", "utility",
    "water_granted_ml", "water_remaining_ml",
    "tank_level_ml", "tank_hours_remaining",
    "action_taken", "servo_angle",
    "rl_k_param", "optimization_latency_ms",
    "total_utility", "coordinator_notes",
]


def setup_file_logging(log_dir: str | None = None) -> None:
    global _LOG_DIR, _csv_path, _txt_path, _csv_writer, _csv_file
    if log_dir:
        _LOG_DIR = Path(log_dir)
    _LOG_DIR.mkdir(parents=True, exist_ok=True)

    date_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    _csv_path = _LOG_DIR / f"symbiosis_readings_{date_str}.csv"
    _txt_path = _LOG_DIR / f"symbiosis_report_{date_str}.txt"

    _csv_file = open(_csv_path, "w", newline="", encoding="utf-8")
    _csv_writer = csv.DictWriter(_csv_file, fieldnames=CSV_FIELDS, extrasaction="ignore")
    _csv_writer.writeheader()
    _csv_file.flush()

    _write_txt(f"""
╔══════════════════════════════════════════════════════════╗
║          SYMBIOSIS — System Report                       ║
║          Session started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}           ║
╚══════════════════════════════════════════════════════════╝
Plants monitored: Basil (plant_1), Coleus (plant_2)
Log directory   : {_LOG_DIR.resolve()}
CSV data file   : {_csv_path.name}
""")
    logging.getLogger("app").info("File logging initialised → %s", _LOG_DIR)


def log_cycle(cycle_data: dict[str, Any]) -> None:
    """
    Call once per allocation cycle with a dict containing all cycle info.

    Expected keys (all optional — missing keys are logged as blank):
      cycle_id, timestamp,
      readings: list of dicts per plant,
      ekf_states: dict plant_id -> {moisture, rate},
      requests: list of dicts {plant_id, water_deficit, urgency, utility, requested_ml},
      allocations: dict plant_id -> granted_ml,
      water_remaining_ml, tank_level_ml, tank_hours_remaining,
      servo_angle, action_taken,
      rl_params: dict plant_id -> k,
      optimization_latency_ms, total_utility, coordinator_notes,
    """
    if _csv_writer is None:
        return

    ts = cycle_data.get("timestamp", datetime.now(timezone.utc).isoformat())
    cycle_id = cycle_data.get("cycle_id", "—")
    allocations = cycle_data.get("allocations", {})
    rl_params = cycle_data.get("rl_params", {})
    requests_by_plant = {r["plant_id"]: r for r in cycle_data.get("requests", [])}
    ekf = cycle_data.get("ekf_states", {})

    # ── CSV rows (one per plant per cycle) ───────────────────────────────────
    for reading in cycle_data.get("readings", []):
        pid = reading.get("plant_id", "?")
        req = requests_by_plant.get(pid, {})
        row = {
            "timestamp": ts,
            "cycle_id": cycle_id,
            "plant_id": pid,
            "moisture_pct": reading.get("moisture_pct"),
            "ekf_moisture": ekf.get(pid, {}).get("moisture"),
            "moisture_target": reading.get("moisture_target"),
            "light_lux": reading.get("light_lux"),
            "temperature_c": reading.get("temperature_c"),
            "humidity_pct": reading.get("humidity_pct"),
            "water_deficit": req.get("water_deficit"),
            "urgency": req.get("urgency"),
            "utility": req.get("utility"),
            "water_granted_ml": allocations.get(pid, 0.0),
            "water_remaining_ml": cycle_data.get("water_remaining_ml"),
            "tank_level_ml": cycle_data.get("tank_level_ml"),
            "tank_hours_remaining": cycle_data.get("tank_hours_remaining"),
            "action_taken": cycle_data.get("action_taken", {}).get(pid, "none"),
            "servo_angle": cycle_data.get("servo_angle"),
            "rl_k_param": rl_params.get(pid),
            "optimization_latency_ms": cycle_data.get("optimization_latency_ms"),
            "total_utility": cycle_data.get("total_utility"),
            "coordinator_notes": cycle_data.get("coordinator_notes"),
        }
        _csv_writer.writerow(row)
    _csv_file.flush()

    # ── TXT narrative entry ───────────────────────────────────────────────────
    lines = [
        f"\n{'═'*60}",
        f"  CYCLE {cycle_id}  |  {ts}",
        f"{'═'*60}",
    ]

    # Sensor readings block
    lines.append("\n📡  RAW SENSOR READINGS")
    for r in cycle_data.get("readings", []):
        pid = r.get("plant_id", "?")
        name = "Basil" if pid == "plant_1" else "Coleus"
        m = r.get("moisture_pct", "?")
        tgt_lo = r.get("moisture_min", "?")
        tgt_hi = r.get("moisture_max", "?")
        lines.append(
            f"  {name:10s} | moisture={m}%  target=[{tgt_lo}–{tgt_hi}%]"
            f"  temp={r.get('temperature_c','?')}°C"
            f"  humidity={r.get('humidity_pct','?')}%"
            f"  light={r.get('light_lux','?')} lux"
        )

    # EKF block
    if ekf:
        lines.append("\n🔬  EKF STATE ESTIMATES")
        for pid, state in ekf.items():
            name = "Basil" if pid == "plant_1" else "Coleus"
            lines.append(
                f"  {name:10s} | ekf_moisture={state.get('moisture','?'):.1f}%"
                f"  drift_rate={state.get('rate','?'):.3f}%/h"
                f"  time_to_critical={state.get('ttc','∞')} h"
            )

    # Plant agent decisions
    lines.append("\n🌿  PLANT AGENT DECISIONS")
    for req in cycle_data.get("requests", []):
        pid = req.get("plant_id", "?")
        name = "Basil" if pid == "plant_1" else "Coleus"
        lines.append(
            f"  {name:10s} | deficit={req.get('water_deficit','?'):.2f}"
            f"  urgency={req.get('urgency','?'):.3f}"
            f"  utility={req.get('utility','?'):.4f}"
            f"  requested={req.get('requested_ml','?'):.1f} ml"
        )

    # Resource state
    lines.append(f"\n💧  TANK: {cycle_data.get('tank_level_ml','?'):.0f} ml"
                 f"  (~{cycle_data.get('tank_hours_remaining','?'):.1f} h remaining)")
    if cycle_data.get("tank_warning"):
        lines.append("  ⚠️  TANK LOW — please refill soon!")

    # Allocations
    lines.append("\n⚖️   COORDINATOR ALLOCATIONS")
    lines.append(f"  Notes: {cycle_data.get('coordinator_notes','—')}")
    lines.append(f"  Optimisation latency: {cycle_data.get('optimization_latency_ms','?'):.1f} ms")
    lines.append(f"  Total utility: {cycle_data.get('total_utility','?'):.4f}")
    for pid, ml in allocations.items():
        name = "Basil" if pid == "plant_1" else "Coleus"
        lines.append(f"  → {name:10s} granted {ml:.1f} ml")
    if not allocations:
        lines.append("  → No water allocated this cycle.")

    # RL learning
    if rl_params:
        lines.append("\n🧠  RL LEARNING UPDATE")
        for pid, k in rl_params.items():
            name = "Basil" if pid == "plant_1" else "Coleus"
            lines.append(f"  {name:10s} | k={k:.3f} (utility curvature)")

    # Actions taken
    lines.append("\n⚙️   HARDWARE ACTIONS")
    actions = cycle_data.get("action_taken", {})
    if actions:
        for pid, act in actions.items():
            name = "Basil" if pid == "plant_1" else "Coleus"
            lines.append(f"  {name:10s} | {act}")
    servo = cycle_data.get("servo_angle")
    if servo is not None:
        lines.append(f"  Servo lid → {servo}°")
    if not actions and servo is None:
        lines.append("  No hardware actions this cycle.")

    _write_txt("\n".join(lines))


def _write_txt(text: str) -> None:
    if _txt_path is None:
        return
    with open(_txt_path, "a", encoding="utf-8") as f:
        f.write(text + "\n")
