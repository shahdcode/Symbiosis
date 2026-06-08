import csv
import logging
from datetime import datetime
from logging.handlers import RotatingFileHandler
from pathlib import Path

LOG_DIR = Path("logs")
LOG_DIR.mkdir(exist_ok=True)


def setup_file_logging() -> None:
    log_file = LOG_DIR / f"symbiosis_{datetime.now().strftime('%Y%m%d')}.log"
    handler = RotatingFileHandler(log_file, maxBytes=10_000_000, backupCount=10)
    formatter = logging.Formatter("%(asctime)s | %(levelname)-8s | %(name)s | %(message)s")
    handler.setFormatter(formatter)
    logging.getLogger().addHandler(handler)
    logging.info("File logging started: %s", log_file)


def log_sensor_csv(readings: list) -> None:
    csv_path = LOG_DIR / "sensor_history.csv"
    file_exists = csv_path.exists()
    with open(csv_path, "a", newline="") as f:
        writer = csv.writer(f)
        if not file_exists:
            writer.writerow([
                "timestamp",
                "plant_id",
                "moisture_pct",
                "light_lux",
                "temperature_c",
                "humidity_pct",
                "tank_level_cm",
            ])
        for r in readings:
            writer.writerow([
                datetime.utcnow().isoformat(),
                r.plant_id,
                r.moisture_pct,
                r.light_lux,
                r.temperature_c,
                r.humidity_pct,
                getattr(r, "tank_level_cm", None),
            ])
