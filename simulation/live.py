"""Live mode: emits one observation per tick (like a real buoy would).

  python simulation/live.py --interval 1 --count 20                 # just print
  python simulation/live.py --post http://localhost:8000            # push to FastAPI
  python simulation/live.py --db                                    # write straight to SQLite
  python simulation/live.py --count 0 ...                           # run until Ctrl-C

Store-and-forward: during COMMUNICATION_OUTAGE nothing is sent; readings are
buffered and flushed together when the link returns."""
import argparse, json, os, sys, time, urllib.request

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from simulation.config import SimConfig, EventType, ZONES
from simulation.main import iter_simulation
from environment.event_model import EventSchedule


def post_batch(base_url, batch):
    req = urllib.request.Request(base_url.rstrip("/") + "/ingest/telemetry",
                                  data=json.dumps(batch).encode(), method="POST",
                                  headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return r.status


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--zone", choices=list(ZONES), default="B")
    p.add_argument("--event", choices=[e.value for e in EventType], default="NORMAL")
    p.add_argument("--interval", type=float, default=1.0, help="real seconds between readings")
    p.add_argument("--step-minutes", type=int, default=60, help="simulated minutes per reading")
    p.add_argument("--count", type=int, default=10, help="0 = run forever")
    p.add_argument("--post", type=str, default=None, help="FastAPI base URL")
    p.add_argument("--db", action="store_true", help="write directly to SQLite")
    p.add_argument("--drift", action="store_true")
    p.add_argument("--fault-prob", type=float, default=0.0)
    p.add_argument("--random-event-prob", type=float, default=0.0)
    p.add_argument("--seed", type=int, default=42)
    a = p.parse_args()

    cfg = SimConfig(seed=a.seed, latitude=ZONES[a.zone]["latitude"], event=EventType(a.event),
                    fault_probability=a.fault_prob, drift_enabled=a.drift,
                    timestep_minutes=a.step_minutes)
    if a.db:
        from backend.database import init_db, insert_many
        init_db()

    buffer, sent = [], 0
    fmt = lambda v: "FAULT" if v is None else f"{v:.2f}"
    try:
        for i, obs in enumerate(iter_simulation(cfg, None, None, a.random_event_prob)):
            print(f"[{i:04d}] {obs['event']:<20} T={fmt(obs['water_temp_c'])}C "
                  f"Wind={fmt(obs['wind_speed_ms'])}m/s Hs={fmt(obs['wave_height_m'])}m "
                  f"link={'UP' if obs['transmitted'] else 'DOWN'}")
            if a.post or a.db:
                buffer.append(obs)
                if obs["transmitted"]:
                    try:
                        if a.post: post_batch(a.post, buffer)
                        if a.db: insert_many(buffer)
                        sent += len(buffer)
                        if len(buffer) > 1: print(f"       link restored: flushed {len(buffer)} buffered readings")
                        buffer.clear()
                    except Exception as e:
                        print(f"       send failed ({e}); keeping {len(buffer)} in buffer")
                else:
                    print(f"       outage: {len(buffer)} reading(s) buffered")
            if a.count and i + 1 >= a.count:
                break
            time.sleep(a.interval)
    except KeyboardInterrupt:
        print("\nstopped")
    print(f"done. delivered={sent} still_buffered={len(buffer)}")


if __name__ == "__main__":
    main()
