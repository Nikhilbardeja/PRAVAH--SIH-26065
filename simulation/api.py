"""
Step 14 — Backend integration (Phase-1 scope).

Per todo.md §4/§25: direct FastAPI/Flutter integration is explicitly
OUT of scope for the first development phase, so this stays a thin
routing layer. All real logic (storage, ingestion, validation) lives in
backend/database.py and backend/ingest.py, which are unit tested directly
against SQLite in this sandbox. FastAPI itself could not be installed
here (no network egress), so this file is syntax-checked but its HTTP
layer is untested live — the person deploying it should smoke-test the
endpoints after `pip install -r requirements-backend.txt`.

Run:
    pip install -r requirements-backend.txt
    python simulation/main.py                 # generate telemetry
    python -m backend.ingest                  # load it into the database
    uvicorn simulation.api:app --reload --port 8000

Endpoints:
    GET  /health                       -> {"status": "ok"}
    GET  /telemetry                     -> raw output/telemetry.json (legacy, file-based)
    GET  /telemetry/latest
    GET  /telemetry/schema
    POST /ingest/telemetry               -> body: list[observation]; inserts into the DB
    GET  /observations?limit=&offset=      -> paginated DB rows, newest first
    GET  /observations/latest
    GET  /observations/{obs_id}
    GET  /observations/count
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.database import (
    init_db, insert_many, get_observations, get_latest, get_since, get_by_id, count_observations,
)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TELEMETRY_PATH = os.path.join(BASE_DIR, "output", "telemetry.json")


def load_telemetry() -> list:
    """Loads the telemetry file written by simulation/main.py.
    Raises FileNotFoundError with a clear message if no run has happened yet."""
    if not os.path.exists(TELEMETRY_PATH):
        raise FileNotFoundError(
            "No telemetry found. Run `python simulation/main.py` first to "
            "generate output/telemetry.json."
        )
    with open(TELEMETRY_PATH) as f:
        return json.load(f)


def telemetry_schema(observations: list) -> dict:
    """Derives a simple {field: python_type_name} schema from one observation,
    for the backend team (matches README §"Example telemetry schema")."""
    if not observations:
        return {}
    sample = observations[0]
    return {k: type(v).__name__ for k, v in sample.items()}


try:
    from fastapi import FastAPI, HTTPException
    from pydantic import BaseModel
    from typing import Optional, Dict, Any, List

    init_db()  # ensure the observations table exists on startup

    app = FastAPI(
        title="Southern Ocean Environment Simulation — Backend",
        description="Ingests and serves simulated buoy telemetry. "
                     "Not a real-time ocean prediction service.",
        version="0.2.0",
    )

    from fastapi.middleware.cors import CORSMiddleware
    # Dev-friendly CORS so Flutter Web can call the API. Restrict origins in production.
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

    class ObservationIn(BaseModel):
        water_temp_c: Optional[float] = None
        salinity_psu: Optional[float] = None
        pressure_dbar: Optional[float] = None
        dissolved_oxygen_mg_l: Optional[float] = None
        turbidity_ntu: Optional[float] = None
        current_speed_ms: Optional[float] = None
        wind_speed_ms: Optional[float] = None
        air_temp_c: Optional[float] = None
        humidity_pct: Optional[float] = None
        atm_pressure_hpa: Optional[float] = None
        current_direction_deg: Optional[float] = None
        wind_direction_deg: Optional[float] = None
        depth_m: float
        timestamp_min: float
        event: str
        latitude: float
        longitude: float
        transmitted: bool = True
        buoy_id: str = "SO-01"
        sim_time: Optional[str] = None
        wave_height_m: Optional[float] = None
        wave_period_s: Optional[float] = None
        sensor_status: Dict[str, Any]
        energy: Dict[str, Any]

    @app.get("/health")
    def health():
        return {"status": "ok"}

    # --- legacy file-based endpoints (unchanged from the read-only bridge) ---
    @app.get("/telemetry")
    def telemetry():
        try:
            return load_telemetry()
        except FileNotFoundError as e:
            raise HTTPException(status_code=404, detail=str(e))

    @app.get("/telemetry/latest")
    def telemetry_latest():
        try:
            obs = load_telemetry()
        except FileNotFoundError as e:
            raise HTTPException(status_code=404, detail=str(e))
        if not obs:
            raise HTTPException(status_code=404, detail="Telemetry file is empty.")
        return obs[-1]

    @app.get("/telemetry/schema")
    def telemetry_schema_endpoint():
        try:
            obs = load_telemetry()
        except FileNotFoundError as e:
            raise HTTPException(status_code=404, detail=str(e))
        return telemetry_schema(obs)

    # --- database-backed endpoints (new) ---
    @app.post("/ingest/telemetry")
    def ingest_telemetry(observations: List[ObservationIn]):
        try:
            inserted = insert_many([o.model_dump() for o in observations])
        except ValueError as e:
            raise HTTPException(status_code=422, detail=str(e))
        return {"inserted": inserted, "total": count_observations()}

    @app.get("/observations")
    def list_observations(limit: int = 100, offset: int = 0):
        if limit < 1 or limit > 1000:
            raise HTTPException(status_code=422, detail="limit must be 1-1000")
        return get_observations(limit=limit, offset=offset)

    @app.get("/observations/count")
    def observations_count():
        return {"count": count_observations()}

    @app.get("/observations/latest")
    def observations_latest():
        obs = get_latest()
        if obs is None:
            raise HTTPException(status_code=404, detail="No observations in database yet.")
        return obs

    @app.get("/observations/since/{obs_id}")
    def observations_since(obs_id: int, limit: int = 1000):
        return get_since(obs_id, limit=limit)

    @app.get("/observations/{obs_id}")
    def observation_by_id(obs_id: int):
        obs = get_by_id(obs_id)
        if obs is None:
            raise HTTPException(status_code=404, detail=f"No observation with id={obs_id}")
        return obs

except ImportError:
    # FastAPI/pydantic not installed in this environment — the helper
    # functions above and backend/database.py still work standalone and
    # are unit tested independently of the web framework.
    app = None
