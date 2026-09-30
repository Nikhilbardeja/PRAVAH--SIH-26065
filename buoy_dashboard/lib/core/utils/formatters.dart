import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Suffix -> unit. Checked in order (longer suffixes first).
const Map<String, String> _units = {
  '_wm2': 'W/m²', '_mg_l': 'mg/L', '_psu': 'PSU', '_dbar': 'dbar', '_ntu': 'NTU', '_pct': '%',
  '_hpa': 'hPa', '_ms': 'm/s', '_deg': '°', '_hours': 'h', '_c': '°C',
  '_m': 'm', '_w': 'W', '_b': 'B', '_s': 's',
};

/// Friendlier labels for the fields people see most. Anything not listed
/// here still falls back to the automatic "snake_case -> Title Case".
const Map<String, String> _labelOverrides = {
  'water_temp_c': 'Water temperature',
  'air_temp_c': 'Air temperature',
  'wind_speed_ms': 'Wind speed',
  'wind_direction_deg': 'Wind direction',
  'current_speed_ms': 'Current speed',
  'current_direction_deg': 'Current direction',
  'atm_pressure_hpa': 'Air pressure',
  'pressure_dbar': 'Water pressure',
  'dissolved_oxygen_mg_l': 'Dissolved oxygen',
  'salinity_psu': 'Salinity',
  'turbidity_ntu': 'Turbidity',
  'humidity_pct': 'Humidity',
  'wave_height_m': 'Wave height',
  'wave_period_s': 'Wave period',
  'battery_pct': 'Battery',
  'generation_w': 'Power generated',
  'load_w': 'Power used',
  'solar_w': 'Solar',
  'wind_w': 'Wind',
  'wave_w': 'Wave',
  'solar_irradiance_wm2': 'Sunlight',
  'buoy_id': 'Buoy',
  'sim_time': 'Reading time',
  'received_at': 'Logged at',
  'depth_m': 'Sensor depth',
  'do': 'DO',
  'sensor_status': 'Sensors',
};

/// Human-readable versions of the ALL_CAPS event names the server sends.
const Map<String, String> _eventLabels = {
  'NORMAL': 'Normal',
  'STORM': 'Storm',
  'LOW_TEMPERATURE': 'Cold snap',
  'HIGH_CURRENT': 'Strong current',
  'LOW_SUNLIGHT': 'Low sunlight',
  'SEA_ICE': 'Sea ice',
  'SENSOR_DISTURBANCE': 'Sensor disturbance',
  'COMMUNICATION_OUTAGE': 'Link down',
};

String _suffixOf(String key) {
  for (final s in _units.keys) {
    if (key.endsWith(s)) return s;
  }
  return '';
}

String unitFor(String key) => _units[_suffixOf(key)] ?? '';

/// "dissolved_oxygen_mg_l" -> "Dissolved oxygen"
String labelFor(String key) {
  if (_labelOverrides.containsKey(key)) return _labelOverrides[key]!;
  final s = _suffixOf(key);
  var k = s.isEmpty ? key : key.substring(0, key.length - s.length);
  if (k.isEmpty) k = key;
  k = k.replaceAll('_', ' ').trim();
  if (k.isEmpty) return key;
  if (k.length <= 3) return k.toUpperCase(); // do -> DO, id -> ID
  return k[0].toUpperCase() + k.substring(1);
}

/// True for the ALL_CAPS event tokens the sim emits (e.g. "SEA_ICE").
bool _looksLikeEventToken(String s) =>
    s.length > 1 && s == s.toUpperCase() && s.contains(RegExp(r'[A-Z]')) && !s.contains(' ');

String formatValue(dynamic v, String key) {
  if (v == null) return '—';
  if (v is bool) return v ? 'Yes' : 'No';
  if (v is String && _looksLikeEventToken(v)) {
    return _eventLabels[v] ?? v.replaceAll('_', ' ').toLowerCase();
  }
  if (v is num) {
    final u = unitFor(key);
    final n = v.toString();
    if (u.isEmpty) return n;
    final tight = u == '°C' || u == '%' || u == '°';
    return tight ? '$n$u' : '$n $u';
  }
  return v.toString();
}

Color statusColor(AppColors c, dynamic s) {
  final t = (s ?? '').toString().toLowerCase();
  if (t.contains('online') || t == 'ok' || t.contains('nominal') || t == 'normal') return c.aurora;
  if (t.contains('low') || t.contains('warn') || t.contains('watch')) return c.solar;
  if (t.contains('fault') || t.contains('fail') || t.contains('error') || t.contains('offline') ||
      t.contains('storm') || t.contains('outage') || t.contains('down')) {
    return c.alert;
  }
  return c.muted;
}

Color sectionColor(AppColors c, String key) {
  final k = key.toLowerCase();
  if (k.contains('status')) return c.aurora;
  if (k.contains('current')) return c.teal;
  if (k.contains('ocean') || k.contains('water')) return c.wave;
  if (k.contains('atmos') || k.contains('wind')) return c.aurora;
  if (k.contains('position') || k.contains('solar')) return c.solar;
  return c.teal;
}

Color colorForSeries(AppColors c, String key, int i) {
  final k = key.toLowerCase();
  if (k.contains('solar')) return c.solar;
  if (k.contains('wind')) return c.aurora;
  if (k.contains('wave')) return c.wave;
  return c.palette[i % c.palette.length];
}
