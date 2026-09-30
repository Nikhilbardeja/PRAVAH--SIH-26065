"""Server settings + buoy registry. IMPORTED FIRST: it fixes sys.path and the DB path."""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)                      # gives access to simulation/, environment/, backend/
os.environ.setdefault("SOUTHERN_DB_PATH", os.path.join(ROOT, "output", "dashboard.db"))

# --- demo clock (override with environment variables) -----------------------
LIVE = os.environ.get("BUOY_LIVE", "1") == "1"                 # background thread on/off
TICK_SECONDS = float(os.environ.get("BUOY_TICK_SECONDS", 5))   # real seconds per new reading
STEP_MINUTES = int(os.environ.get("BUOY_STEP_MINUTES", 60))    # simulated minutes per reading
HISTORY_DAYS = 14
RANDOM_EVENT_PROB = float(os.environ.get("BUOY_EVENT_PROB", 0.02))

# Positions/names are the teammate's original fleet data (unchanged).
BUOYS = [
    {"id": "SO-01", "name": "Weddell Gyre", "tagline": "Circling the ice edge",
     "latitude": -63, "longitude": 30, "seed": 101, "start_soc": 85},
    {"id": "SO-02", "name": "Kerguelen Shelf", "tagline": "Watching the sub-Antarctic front",
     "latitude": -49, "longitude": -140, "seed": 202, "start_soc": 70},
    {"id": "SO-03", "name": "Ross Sea", "tagline": "Deep in the storm belt",
     "latitude": -71, "longitude": 120, "seed": 303, "start_soc": 65},
    {"id": "SO-04", "name": "Amundsen Sea", "tagline": "Deploying December",
        "latitude": -72, "longitude": -110, "seed": 404, "start_soc": 80,
     "scheduled": True},
]
ACTIVE = [b for b in BUOYS if not b.get("scheduled")]
ACTIVE_IDS = [b["id"] for b in ACTIVE]
NAME = {b["id"]: b["name"] for b in BUOYS}
SPEC = {b["id"]: b for b in ACTIVE}
