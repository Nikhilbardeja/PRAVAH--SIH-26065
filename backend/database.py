"""SQLite storage for buoy observations (stdlib only).

Multi-buoy: every row carries buoy_id + sim_time. Older databases are
migrated automatically (missing columns are added)."""

import json
import os
import sqlite3
from contextlib import contextmanager

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DB_PATH = os.environ.get("SOUTHERN_DB_PATH") or os.path.join(_ROOT, "output", "buoy_telemetry.db")

SCALAR_FIELDS = [
    "water_temp_c", "salinity_psu", "pressure_dbar", "dissolved_oxygen_mg_l",
    "turbidity_ntu", "current_speed_ms", "wind_speed_ms", "air_temp_c",
    "humidity_pct", "atm_pressure_hpa", "current_direction_deg",
    "wind_direction_deg", "depth_m", "timestamp_min", "event",
    "latitude", "longitude", "transmitted",
    "wave_height_m", "wave_period_s",
]
JSON_FIELDS = ["sensor_status", "energy"]
EXTRA_FIELDS = ["buoy_id", "sim_time"]          # optional on insert
DEFAULT_BUOY = "SO-01"


def _row_to_observation(row: sqlite3.Row) -> dict:
    obs = {k: row[k] for k in SCALAR_FIELDS}
    obs["id"] = row["id"]
    obs["received_at"] = row["received_at"]
    obs["buoy_id"] = row["buoy_id"]
    obs["sim_time"] = row["sim_time"]
    for k in JSON_FIELDS:
        obs[k] = json.loads(row[k]) if row[k] is not None else None
    return obs


@contextmanager
def get_connection(db_path: str = DEFAULT_DB_PATH):
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path, timeout=10)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")   # readers don't block the writer
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def _col_type(name):
    return "TEXT" if name in ("event", "sim_time") else "REAL"


def init_db(db_path: str = DEFAULT_DB_PATH):
    with get_connection(db_path) as conn:
        cols = ",\n  ".join(f"{c} {_col_type(c)}" for c in SCALAR_FIELDS)
        conn.execute(f"""CREATE TABLE IF NOT EXISTS observations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            received_at TEXT DEFAULT CURRENT_TIMESTAMP,
            buoy_id TEXT DEFAULT '{DEFAULT_BUOY}',
            sim_time TEXT,
            {cols},
            sensor_status TEXT,
            energy TEXT);""")
        # migrate older databases: add any column that is missing
        have = {r["name"] for r in conn.execute("PRAGMA table_info(observations)")}
        wanted = [("buoy_id", f"TEXT DEFAULT '{DEFAULT_BUOY}'"), ("sim_time", "TEXT")] + \
                 [(c, _col_type(c)) for c in SCALAR_FIELDS] + [("sensor_status", "TEXT"), ("energy", "TEXT")]
        for name, ddl in wanted:
            if name not in have:
                conn.execute(f"ALTER TABLE observations ADD COLUMN {name} {ddl}")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_obs_timestamp ON observations(timestamp_min);")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_obs_buoy ON observations(buoy_id, id);")


def reset_db(db_path: str = DEFAULT_DB_PATH):
    for suffix in ("", "-wal", "-shm"):
        try:
            os.remove(db_path + suffix)
        except FileNotFoundError:
            pass


_ALL_COLS = SCALAR_FIELDS + JSON_FIELDS + EXTRA_FIELDS


def _values(obs: dict) -> list:
    missing = [f for f in SCALAR_FIELDS if f not in obs]
    if missing:
        raise ValueError(f"Observation missing required fields: {missing}")
    return ([obs[c] for c in SCALAR_FIELDS]
            + [json.dumps(obs.get(c)) for c in JSON_FIELDS]
            + [obs.get("buoy_id") or DEFAULT_BUOY, obs.get("sim_time")])


_INSERT_SQL = (f"INSERT INTO observations ({', '.join(_ALL_COLS)}) "
               f"VALUES ({', '.join('?' for _ in _ALL_COLS)});")


def insert_observation(obs: dict, db_path: str = DEFAULT_DB_PATH) -> int:
    values = _values(obs)
    with get_connection(db_path) as conn:
        return conn.execute(_INSERT_SQL, values).lastrowid


def insert_many(observations: list, db_path: str = DEFAULT_DB_PATH) -> int:
    rows = [_values(o) for o in observations]     # validate everything first
    with get_connection(db_path) as conn:
        conn.executemany(_INSERT_SQL, rows)
    return len(rows)


def _query(sql, params=(), db_path=DEFAULT_DB_PATH):
    with get_connection(db_path) as conn:
        return [_row_to_observation(r) for r in conn.execute(sql, params).fetchall()]


def get_observations(limit: int = 100, offset: int = 0, db_path: str = DEFAULT_DB_PATH) -> list:
    return _query("SELECT * FROM observations ORDER BY id DESC LIMIT ? OFFSET ?;", (limit, offset), db_path)


def get_since(after_id: int, limit: int = 1000, db_path: str = DEFAULT_DB_PATH) -> list:
    """Rows with id > after_id, oldest first — for frontend polling."""
    return _query("SELECT * FROM observations WHERE id > ? ORDER BY id ASC LIMIT ?;", (after_id, limit), db_path)


def get_latest(db_path: str = DEFAULT_DB_PATH):
    rows = _query("SELECT * FROM observations ORDER BY id DESC LIMIT 1;", (), db_path)
    return rows[0] if rows else None


def get_by_id(obs_id: int, db_path: str = DEFAULT_DB_PATH):
    rows = _query("SELECT * FROM observations WHERE id = ?;", (obs_id,), db_path)
    return rows[0] if rows else None


def count_observations(db_path: str = DEFAULT_DB_PATH) -> int:
    with get_connection(db_path) as conn:
        return conn.execute("SELECT COUNT(*) AS c FROM observations;").fetchone()["c"]


# ---- per-buoy queries (dashboard) ----------------------------------------
def delivered_upto_id(buoy_id: str, db_path: str = DEFAULT_DB_PATH):
    """Id of the newest reading that reached the ground station (link was up).
    Store-and-forward: everything at/below it has been delivered."""
    with get_connection(db_path) as conn:
        r = conn.execute("SELECT MAX(id) AS m FROM observations WHERE buoy_id=? AND transmitted=1;",
                          (buoy_id,)).fetchone()
    return r["m"]


def get_buoy_observations(buoy_id: str, up_to_id=None, db_path: str = DEFAULT_DB_PATH) -> list:
    if up_to_id is None:
        return _query("SELECT * FROM observations WHERE buoy_id=? ORDER BY id ASC;", (buoy_id,), db_path)
    return _query("SELECT * FROM observations WHERE buoy_id=? AND id<=? ORDER BY id ASC;",
                  (buoy_id, up_to_id), db_path)


def get_last(buoy_id: str, db_path: str = DEFAULT_DB_PATH):
    rows = _query("SELECT * FROM observations WHERE buoy_id=? ORDER BY id DESC LIMIT 1;", (buoy_id,), db_path)
    return rows[0] if rows else None


def count_after(buoy_id: str, after_id, db_path: str = DEFAULT_DB_PATH) -> int:
    with get_connection(db_path) as conn:
        return conn.execute("SELECT COUNT(*) AS c FROM observations WHERE buoy_id=? AND id>?;",
                             (buoy_id, after_id or 0)).fetchone()["c"]
