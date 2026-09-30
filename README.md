# Southern Ocean Environment Simulation

Synthetic, physics-informed environment simulator for the SIH26065 virtual
buoy prototype. **Not** a real ocean circulation model or weather forecast —
see `todo.md` §4 for full scope.

## Quick start
```bash
pip install -r requirements.txt
python simulation/main.py --hours 10 --zone B --event NORMAL
```

### CLI options
| Flag | Default | Notes |
|---|---|---|
| `--hours` | 10 | simulated duration |
| `--zone` | B | A=~45S, B=~55S (ACC core), C=~65S (ice edge) |
| `--depth` | 10.0 | sensor pod depth, clamped 0-20 m |
| `--event` | NORMAL | NORMAL / STORM / LOW_TEMPERATURE / HIGH_CURRENT |
| `--fault-prob` | 0.0 | probability (0-1) any sensor reports FAULT per step |
| `--seed` | 42 | RNG seed for reproducibility |
| `--day` | 15 | day-of-year, drives seasonal cycle |
| `--drift` | off | enable buoy lat/lon drift from ocean current (Step 12) |

Outputs: `output/telemetry.json`, `output/observations.csv`,
`plots/environment_overview.png`.

## Architecture (layers kept separate per engineering rule)
```
ENVIRONMENT (ocean_model, atmosphere_model) -> TRUE values
        -> SENSOR (sensor_model: noise/bias/fault) -> measured values
        -> exported telemetry (JSON/CSV) for backend consumption
```

## Documented synthetic assumptions
- Temperature: linear lat interpolation (8C@40S to -1.5C@70S), seasonal
  cosine peaking mid-Jan, mild depth cooling 0-20m, small Gaussian noise.
- Salinity: lat interpolation 34.2-34.7 psu, slight depth/seasonal terms.
- Pressure: 1 dbar ≈ 1 m depth (standard oceanographic approximation).
- Dissolved oxygen: simplified inverse relation to temperature (colder =
  more O2 solubility), not a full solubility equation (e.g. Garcia & Gordon).
- Turbidity: low baseline (clear open ocean), amplified during STORM.
- Current: Gaussian bump centered at 55S to represent the Antarctic
  Circumpolar Current core; amplified for STORM/HIGH_CURRENT events.
- Wind: persistent westerly baseline (~8 m/s) with gusts; amplified in STORM.
- Atmospheric pressure: ~1005 hPa baseline (Southern Ocean low-pressure
  belt), drops in STORM.
- Sensor layer: per-parameter Gaussian noise + fixed bias per datasheet
  class (see `sensors/sensor_model.py`), independent random FAULT flag.

All figures above are engineering placeholders for a virtual prototype and
should be validated against real observational data (e.g. Argo floats,
WOA23) before any operational use.

## Status vs todo.md
Implements Phase 1 (basic core), Phase 2 (zones, season, events, regional
current behaviour), the full Phase 6 event system (all 8 event types:
NORMAL, STORM, LOW_TEMPERATURE, HIGH_CURRENT, LOW_SUNLIGHT, SEA_ICE,
SENSOR_DISTURBANCE, COMMUNICATION_OUTAGE — each with a documented
cause→effect, manual/scheduled/random selection), sensor noise/fault
(Step 9), JSON+CSV telemetry (Step 10), overview plots + automated Phase 11
validation (Step 11, `validation/test_phase11.py` — 16 tests, run with
`python -m unittest validation.test_phase11 -v`), buoy drift (Step 12),
the energy-environment interface (Step 13) and a database + FastAPI
backend (Step 14, see below).

### Waves + wind-drag drift (latest)
- `environment/wave_model.py`: `wave_height_m` (≈0.0246·U²) and `wave_period_s` (≈0.82·U) from wind; sea ice damps waves ×0.1. Simplified, not a spectral model.
- `environment/buoy_drift.py`: buoy now moves with current **plus 3% windage** downwind.
- Sensor layer clamps physically non-negative readings at 0.
- Tests: 19 + 4 API tests (`python -m unittest validation.test_phase11 -v`).

## Dashboard server (Flutter integration)
`buoy_server/` is the Flask API the Flutter app talks to. Same URLs and JSON shapes as the
original mock server, but every value now comes from the simulation (3 buoys: SO-01..03).
```bash
pip install -r buoy_server/requirements.txt
cd buoy_server && python server.py          # http://localhost:5000  (health: /api/health)
python -m unittest validation.test_server -v  # contract tests (Flask test client)
```
- On start it simulates 14 days of history (~1-2 s), then adds one reading per buoy every 5 s
  (each = 1 simulated hour, so a full day passes in ~2 min). Tune with env vars
  `BUOY_TICK_SECONDS`, `BUOY_STEP_MINUTES`, `BUOY_EVENT_PROB`, `BUOY_LIVE=0`.
- Fresh database at every start: `output/dashboard.db`.
- Store-and-forward: readings taken during a COMMUNICATION_OUTAGE stay hidden until the link
  returns; meanwhile the buoy shows `offline` and the satellite card shows a backlog.
- Scripted demo story: SO-03 has a storm active "now"; SO-02 had a 6 h link outage earlier.
- Battery/generation come from `services/power_model.py` - a **placeholder** (assumed hardware
  constants) until the real energy model exists.
- Sim clock = each buoy's local solar time, anchored to today's date.

### Live mode, reference check, FastAPI testing (latest)
```bash
# Live buoy-style stream (one reading per tick; store-and-forward during outages)
python simulation/live.py --interval 1 --count 0 --post http://localhost:8000   # or --db

# Sanity-check the model against typical ocean ranges / your own real data
python validation/reference_check.py
python validation/reference_check.py --csv real_argo.csv --zone B

# Verify the FastAPI layer (needs internet once for pip)
pip install -r requirements-backend.txt httpx
python -m unittest validation.test_api -v
uvicorn simulation.api:app --reload --port 8000     # then open http://localhost:8000/docs
```
- Reference ranges are **approximate, from general knowledge** (no internet in the build sandbox) — swap in WOA23/Argo statistics for real validation. The check found and fixed: DO too low (now Garcia-Gordon solubility), water below freezing point (floored at -1.9C), polar surface salinity too high (now freshest near ~58S, summer meltwater freshening).
- `transmitted=False` means the link was down when the reading was taken; buffered readings are delivered late.
- API additions for Flutter: CORS enabled (`*` for dev — restrict in production), `GET /observations/since/{id}` for polling, sensor-fault `null` values accepted. Android emulator reaches the host at `http://10.0.2.2:8000`.

### Event system (Phase 6)
| Event | Cause → effect (documented assumption) |
|---|---|
| STORM | ↑wind, ↑current, ↑turbidity, ↓atm. pressure |
| LOW_TEMPERATURE | ↓water/air temp |
| HIGH_CURRENT | ↑current, ↑turbidity |
| LOW_SUNLIGHT | ↓solar availability, ↑humidity (overcast) |
| SEA_ICE | ↓water/air temp, ↓current, ↓wind, ↓turbidity, ↓↓solar |
| SENSOR_DISTURBANCE | sensor noise ×3, fault probability +0.15 (env. unaffected) |
| COMMUNICATION_OUTAGE | `transmitted=False` (env./sensors unaffected — comms only) |

Select an event three ways:
```bash
--event STORM                                  # manual, fixed for the whole run
--schedule "2:4:STORM,6:7:SEA_ICE"              # scheduled step windows
--random-event-prob 0.3                         # random draw each step
```

### Step 13 — Energy fields (per observation, under `"energy"`)
| Field | Meaning |
|---|---|
| `solar_availability` | 0-1, day/night + storm cloud-cover factor |
| `solar_irradiance_wm2` | estimated W/m² at the buoy |
| `wind_energy_potential_wm2` | wind power density, 0.5·ρ·v³ |
| `current_energy_potential_wm2` | current/hydrokinetic power density |

### Step 14 — Backend (database + FastAPI)
```bash
pip install -r requirements-backend.txt
python simulation/main.py         # 1. generate output/telemetry.json
python -m backend.ingest          # 2. load it into output/buoy_telemetry.db (SQLite)
uvicorn simulation.api:app --reload --port 8000   # 3. serve it
```
- `backend/database.py` — SQLite storage (stdlib `sqlite3` only, no extra
  install needed). Fully unit-tested in this environment: insert, paginated
  list, latest, by-id, count, and missing-field validation all verified
  against a real database.
- `backend/ingest.py` — stands in for "Simulated Satellite Communication",
  loading `telemetry.json` into the database. Append-only: re-running it
  adds a new batch rather than de-duplicating; add a `timestamp`-based
  uniqueness check before using it with a real, continuously-running buoy.
- `simulation/api.py` — thin FastAPI routing layer over `backend/database.py`:
  `POST /ingest/telemetry`, `GET /observations` (paginated), `/observations/latest`,
  `/observations/{id}`, `/observations/count`, plus the original file-based
  `/telemetry*` endpoints for backward compatibility.

**Caveat:** this sandbox has no network egress, so FastAPI/uvicorn/pydantic
could not be installed or run here. The file is syntax-checked and every
endpoint delegates to the tested `backend/database.py` functions, but the
HTTP layer itself is unverified — smoke-test it (e.g. `curl localhost:8000/health`)
after installing in an environment with internet access. `fastapi`/`uvicorn`
are kept in a separate optional requirements file — the base
`requirements.txt` stays numpy/pandas/matplotlib only.

## Example telemetry schema (for backend team)
```json
{
  "water_temp_c": 5.62, "salinity_psu": 34.55, "pressure_dbar": 10.22,
  "dissolved_oxygen_mg_l": 7.83, "turbidity_ntu": 1.95,
  "current_speed_ms": 0.66, "current_direction_deg": 210.4,
  "wind_speed_ms": 9.7, "wind_direction_deg": 265.1,
  "air_temp_c": 4.6, "humidity_pct": 81.3, "atm_pressure_hpa": 1006.1,
  "latitude": -55.0, "longitude": 60.0, "depth_m": 10.0,
  "timestamp_min": 0, "event": "NORMAL",
  "sensor_status": {"water_temp_c": "OK", "...": "OK/FAULT"}
}
```
