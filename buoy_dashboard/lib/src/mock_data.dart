/// Hardcoded mock data. The server must return the same JSON shape.
class MockData {
  /// Latest reading (Version 1) - exactly as provided.
  static final Map<String, dynamic> latest = {
    "position": {"latitude": -55.0, "longitude": 60.0},
    "ocean": {
      "depth_m": 10.0,
      "water_temp_c": 5.622,
      "salinity_psu": 34.553,
      "pressure_dbar": 10.215,
      "dissolved_oxygen_mg_l": 7.833,
      "turbidity_ntu": 1.949
    },
    "atmosphere": {
      "air_temp_c": 4.487,
      "humidity_pct": 82.38,
      "atm_pressure_hpa": 1003.09,
      "wind_speed_ms": 9.653,
      "wind_direction_deg": 285.56
    },
    "ocean_current": {"speed_ms": 0.662, "direction_deg": 274.01},
    "sensor_status": {
      "water_temp_c": "OK",
      "salinity_psu": "OK",
      "pressure_dbar": "OK",
      "dissolved_oxygen_mg_l": "OK",
      "turbidity_ntu": "OK",
      "current_speed_ms": "OK",
      "wind_speed_ms": "OK",
      "air_temp_c": "OK",
      "humidity_pct": "OK",
      "atm_pressure_hpa": "OK"
    },
  };

  static final Map<String, dynamic> fleet = {
    "region": "67°S, Weddell Gyre transect",
    "alert": {
      "title": "Storm system approaching the Ross Sea.",
      "message":
          "SO-03 has switched to scientific-event sampling (every 15 min) and is conserving power — expect a shorter satellite session tonight."
    },
    "stats": {
      "buoys_online": "2/3",
      "avg_battery_pct": 71,
      "sea_surface_temp_c": -1.2,
      "wind_so_01_ms": 21,
      "next_satellite_pass": "03:40 UTC"
    },
    "buoys": [
      {"id": "SO-01", "name": "Weddell Gyre", "latitude": -63, "longitude": 30, "status": "online", "battery_pct": 82, "trend": [70, 74, 72, 77, 76, 80, 82]},
      {"id": "SO-02", "name": "Kerguelen Shelf", "latitude": -49, "longitude": -140, "status": "online", "battery_pct": 76, "trend": [68, 70, 69, 73, 72, 75, 76]},
      {"id": "SO-03", "name": "Ross Sea", "latitude": -71, "longitude": 120, "status": "low power", "battery_pct": 34, "trend": [52, 50, 47, 44, 40, 37, 34]},
      {"id": "SO-04", "name": "Scheduled for December deployment", "status": "scheduled"}
    ],
    "satellite_link": {
      "title": "Satellite link — Iridium SBD",
      "todays_uplink_b": 214,
      "uplink_limit_b": 340,
      "backlog_queued": "0 days",
      "next_session": "03:40 UTC"
    }
  };

  static Map<String, dynamic> history(String buoyId) {
    const dates = ['Sep 14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27'];
    const battery = [91, 89, 88, 85, 84, 87, 86, 83, 80, 78, 79, 81, 82, 82];
    const temp = [-1.8, -1.7, -1.6, -1.5, -1.4, -1.6, -1.7, -1.5, -1.3, -1.2, -1.1, -1.2, -1.3, -1.2];
    const sal = [34.1, 34.2, 34.3, 34.4, 34.5, 34.1, 34.2, 34.3, 34.4, 34.5, 34.1, 34.2, 34.3, 34.4];
    const wind = [14, 16, 18, 20, 22, 24, 14, 16, 18, 20, 22, 24, 14, 16];
    return {
      "buoy": buoyId,
      "rows": [
        for (int i = 0; i < dates.length; i++)
          {
            "date": dates[i],
            "battery_pct": battery[i],
            "water_temp_c": temp[i],
            "salinity_psu": sal[i],
            "wind_ms": wind[i],
            "samples_logged": "6/6",
          }
      ]
    };
  }

  static final Map<String, dynamic> comparison = {
    "subtitle": "Deltas shown are change vs. the trailing 7-day average.",
    "buoys": [
      {"buoy": "SO-01 · Weddell Gyre", "note": "Stable, on schedule", "battery_pct": 82, "battery_pct_delta": 1, "water_temp_c": -1.2, "salinity_psu": 34.3, "dissolved_oxygen_mg_l": 6.1, "turbidity_ntu": 2.1, "generation_w": 41, "status": "Nominal"},
      {"buoy": "SO-02 · Kerguelen Shelf", "note": "Strongest generation, warmer water", "battery_pct": 76, "battery_pct_delta": -2, "water_temp_c": 2.4, "salinity_psu": 33.9, "dissolved_oxygen_mg_l": 7.4, "turbidity_ntu": 5.8, "generation_w": 53, "status": "Watch — turbidity"},
      {"buoy": "SO-03 · Ross Sea", "note": "Power-constrained, storm event active", "battery_pct": 34, "battery_pct_delta": -9, "water_temp_c": -1.6, "salinity_psu": 34.5, "dissolved_oxygen_mg_l": 5.9, "turbidity_ntu": 1.8, "generation_w": 18, "status": "Low power"}
    ],
    "radar": [
      {"buoy": "SO-01", "values": {"battery": 0.82, "stability": 0.85, "do": 0.70, "generation": 0.65, "uptime": 0.95}},
      {"buoy": "SO-02", "values": {"battery": 0.76, "stability": 0.70, "do": 0.85, "generation": 0.95, "uptime": 0.90}},
      {"buoy": "SO-03", "values": {"battery": 0.34, "stability": 0.60, "do": 0.65, "generation": 0.35, "uptime": 0.70}}
    ]
  };

  static final Map<String, dynamic> interpretation = {
    "insights": [
      {"tag": "Ocean · SO-01", "tone": "teal", "title": "Cold layer strengthening.", "body": "Surface temperature has fallen steadily over 14 days while salinity holds near 34.3 PSU — consistent with seasonal cooling rather than a mixing event."},
      {"tag": "Ocean · SO-02", "tone": "alert", "title": "Turbidity rising alongside DO.", "body": "A joint uptick in turbidity and dissolved oxygen over the last 3 samples is a pattern worth flagging as a possible early bloom signal."},
      {"tag": "Energy · fleet", "tone": "teal", "title": "June is the pinch point.", "body": "Modelled generation (~31 Wh/day) barely covers harsh-winter heater load (~25.5 Wh/day) — the tightest margin in the yearly cycle."}
    ],
    "energy_title": "Energy generation, SO-01 — modelled by month",
    "energy_by_month": [
      {"month": "Jan", "solar": 150, "wind": 14, "wave": 10},
      {"month": "Feb", "solar": 128, "wind": 22, "wave": 10},
      {"month": "Mar", "solar": 80, "wind": 18, "wave": 10},
      {"month": "Apr", "solar": 34, "wind": 16, "wave": 10},
      {"month": "May", "solar": 4, "wind": 12, "wave": 8},
      {"month": "Jun", "solar": 0, "wind": 14, "wave": 8},
      {"month": "Jul", "solar": 0, "wind": 18, "wave": 8},
      {"month": "Aug", "solar": 10, "wind": 16, "wave": 6},
      {"month": "Sep", "solar": 45, "wind": 12, "wave": 6},
      {"month": "Oct", "solar": 80, "wind": 16, "wave": 8},
      {"month": "Nov", "solar": 130, "wind": 20, "wave": 10},
      {"month": "Dec", "solar": 160, "wind": 22, "wave": 12}
    ],
    "note": {
      "title": "Reading the shape, not just the total.",
      "body": "Solar dominates in the Antarctic summer (Nov–Feb) and disappears entirely May–Jul. Wind fills part of that gap but is itself weakest in September. Wave generation is held flat at a conservative 24 Wh/day until real wave height data replaces the design assumption.\n\nThis is why the platform can't be tuned for one average day — the control system needs to reason about which source is available right now, not the yearly mean."
    },
    "coupling": [
      {"air_temp_c": -3.1, "water_temp_c": -1.8}, {"air_temp_c": -2.8, "water_temp_c": -1.7},
      {"air_temp_c": -2.6, "water_temp_c": -1.6}, {"air_temp_c": -2.2, "water_temp_c": -1.5},
      {"air_temp_c": -1.9, "water_temp_c": -1.4}, {"air_temp_c": -2.5, "water_temp_c": -1.6},
      {"air_temp_c": -2.9, "water_temp_c": -1.7}, {"air_temp_c": -2.3, "water_temp_c": -1.5},
      {"air_temp_c": -1.7, "water_temp_c": -1.3}, {"air_temp_c": -1.4, "water_temp_c": -1.2},
      {"air_temp_c": -1.1, "water_temp_c": -1.1}, {"air_temp_c": -1.5, "water_temp_c": -1.2},
      {"air_temp_c": -1.8, "water_temp_c": -1.3}, {"air_temp_c": -1.3, "water_temp_c": -1.2}
    ],
    "daylight": [
      {"month": "Jan", "hours": 20}, {"month": "Feb", "hours": 16}, {"month": "Mar", "hours": 11},
      {"month": "Apr", "hours": 6}, {"month": "May", "hours": 1.5}, {"month": "Jun", "hours": 0},
      {"month": "Jul", "hours": 0.5}, {"month": "Aug", "hours": 3}, {"month": "Sep", "hours": 9},
      {"month": "Oct", "hours": 14}, {"month": "Nov", "hours": 19}, {"month": "Dec", "hours": 22}
    ]
  };
}
