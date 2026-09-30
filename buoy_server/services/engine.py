"""Runs one simulation per buoy: seeds 14 days of history, then adds a new
reading every TICK_SECONDS (background thread). Writes to SQLite."""
import threading
from datetime import datetime, timedelta, timezone

from . import config
from backend import database as db
from environment.event_model import EventSchedule
from simulation.config import SimConfig, EventType
from simulation.main import iter_simulation
from .power_model import PowerModel


class Engine:
    def __init__(self):
        self.lock = threading.Lock()
        self.buoys = {}
        self.seeded = False
        self._stop = threading.Event()
        self._thread = None

    def _next(self, bid):
        b = self.buoys[bid]
        obs = next(b["gen"])
        obs["buoy_id"] = bid
        obs["energy"].update(b["power"].step(obs, config.STEP_MINUTES / 60.0))
        return obs

    def seed_history(self):
        if self.seeded:
            return
        db.reset_db()
        db.init_db()
        today = datetime.now(timezone.utc).replace(tzinfo=None, hour=0, minute=0, second=0, microsecond=0)
        start = today - timedelta(days=config.HISTORY_DAYS)
        n = config.HISTORY_DAYS * 24 * 60 // config.STEP_MINUTES
        for spec in config.ACTIVE:
            bid = spec["id"]
            cfg = SimConfig(seed=spec["seed"], latitude=spec["latitude"], longitude=spec["longitude"],
                            timestep_minutes=config.STEP_MINUTES, start_datetime=start,
                            drift_enabled=True, event=EventType.NORMAL)
            # scripted story so the dashboard has something to show
            windows = {"SO-03": [(n - 4, n + 12, EventType.STORM)],                    # storm active "now"
                       "SO-02": [(n - 30, n - 24, EventType.COMMUNICATION_OUTAGE)]}.get(bid)
            sched = EventSchedule(windows, default=EventType.NORMAL) if windows else None
            prob = 0.0 if windows else config.RANDOM_EVENT_PROB
            self.buoys[bid] = {"gen": iter_simulation(cfg, None, sched, prob), "power": PowerModel(spec.get("start_soc", 80.0))}
            db.insert_many([self._next(bid) for _ in range(n)])
        self.seeded = True

    def tick(self):
        with self.lock:
            for bid in self.buoys:
                db.insert_observation(self._next(bid))

    def start_live(self):
        if self._thread:
            return

        def loop():
            while not self._stop.wait(config.TICK_SECONDS):
                try:
                    self.tick()
                except Exception as e:                      # keep the demo alive
                    print("engine tick failed:", e)
        self._thread = threading.Thread(target=loop, daemon=True)
        self._thread.start()


engine = Engine()
