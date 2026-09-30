"""
Simulated satellite-communication relay: loads the JSON telemetry produced
by simulation/main.py and pushes it into the database, standing in for
the "Simulated Satellite Communication -> FastAPI -> Database" leg of the
architecture until the real ESP32/satellite simulation exists.

Usage:
    python -m backend.ingest                 # ingest output/telemetry.json
    python -m backend.ingest path/to/other.json
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.database import init_db, insert_many, count_observations, DEFAULT_DB_PATH

DEFAULT_TELEMETRY_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "output", "telemetry.json"
)


def ingest_file(telemetry_path: str = DEFAULT_TELEMETRY_PATH, db_path: str = DEFAULT_DB_PATH) -> int:
    if not os.path.exists(telemetry_path):
        raise FileNotFoundError(
            f"{telemetry_path} not found. Run `python simulation/main.py` first."
        )
    with open(telemetry_path) as f:
        observations = json.load(f)

    init_db(db_path)
    inserted = insert_many(observations, db_path)
    return inserted


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_TELEMETRY_PATH
    inserted = ingest_file(path)
    total = count_observations()
    print(f"Ingested {inserted} observation(s) from {path}")
    print(f"Database now holds {total} observation(s) at {DEFAULT_DB_PATH}")


if __name__ == "__main__":
    main()
